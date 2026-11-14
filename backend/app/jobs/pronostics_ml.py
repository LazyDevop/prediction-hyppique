"""Publie les pronostics du modèle ML (variante "ml") : un pronostic du
matin, fondamental seul, puis un pronostic à H-60, H-30, H-15 et H-10, qui
combine le modèle fondamental aux cotes de l'instantané de cette cible
(spec-predictions-horizon.md).

- Matin : à la première passe à partir de PRONOSTICS_HEURE (7 h par défaut,
  horloge du conteneur, après l'ingestion de 6 h), l'état point-in-time est
  reconstruit en mémoire depuis les courses finalisées strictement
  antérieures au jour ; chaque course du jour pas encore partie reçoit un
  pronostic `matin`. Les courses du jour ne mettent jamais l'état à jour.
- Horizons : dès que le service `cotes` a stocké l'instantané H-60, H-30,
  H-15 ou H-10 d'une course, les lignes de la course sont recalculées avec
  les partants restants (un partant NON_PARTANT dans l'instantané est
  écarté) et combinées aux cotes : p ∝ exp(α·log p_fond + β·log p_marché),
  p_marché = 1/cote_direct normalisé. Une cote manquante ou invalide (non
  finie ou ≤ 1) : p_fond publié seul, manques=["cotes_incompletes"].
- Un pronostic n'est jamais réécrit ni publié à partir de `heure_depart`.
  Un horizon sans instantané est journalisé comme manqué, jamais simulé ;
  un instantané déjà dépassé par un plus récent n'est pas publié.
- Une erreur sur une course n'arrête ni la passe ni la boucle : la course
  est retentée à la passe suivante.

Usage :
    python -m app.jobs.pronostics_ml        # boucle, une passe toutes les PRONOSTICS_POLL_SECONDS
    python -m app.jobs.pronostics_ml --verifier 2026-03-14 \\
        --predictions /app/modele/fondamental/test_predictions.csv.gz
"""

import argparse
import csv
import gzip
import logging
import math
import os
import sys
import time
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Callable, Dict, List, Optional, Set, Tuple

from app.data.repository import Repository
from app.jobs.build_features import lire_courses_du_jour, lire_jours
from app.jobs.cotes_instantanees import tolerance
from app.model.features import ConstructeurFeatures, CourseRecord, PartantRecord
from app.model.inference import ErreurModele, ModeleML, charger, combiner

logger = logging.getLogger(__name__)

MATIN = "matin"
HORIZONS: Tuple[Tuple[str, int], ...] = (("h60", 60), ("h30", 30), ("h15", 15), ("h10", 10))
DOSSIER_FONDAMENTAL = os.environ.get("PRONOSTICS_MODELE_FONDAMENTAL", "/app/modele/fondamental")
DOSSIER_COMBINE = os.environ.get("PRONOSTICS_MODELE_COMBINE", "/app/modele/combine")
POLL_DEFAUT_SECONDS = 30.0
HEURE_DEFAUT = 7
TOLERANCE_VERIFICATION = 1e-6


def _env_nombre(nom: str, defaut: float, borne_min: float, borne_max: float) -> float:
    brut = os.environ.get(nom, str(defaut))
    try:
        valeur = float(brut)
    except ValueError:
        logger.warning("%s invalide (%r) : %s utilisé", nom, brut, defaut)
        return defaut
    if not borne_min <= valeur <= borne_max:
        logger.warning("%s=%s hors de [%s, %s] : %s utilisé", nom, brut, borne_min, borne_max, defaut)
        return defaut
    return valeur


def _env_heure(nom: str = "PRONOSTICS_HEURE", defaut: int = HEURE_DEFAUT) -> int:
    """Heure entière de 0 à 23 ; sinon avertissement et valeur par défaut."""
    brut = os.environ.get(nom, str(defaut)).strip()
    try:
        valeur = int(brut)
    except ValueError:
        logger.warning("%s invalide (%r, heure entière attendue) : %s utilisé", nom, brut, defaut)
        return defaut
    if not 0 <= valeur <= 23:
        logger.warning("%s=%s hors de [0, 23] : %s utilisé", nom, brut, defaut)
        return defaut
    return valeur


POLL_SECONDS = _env_nombre("PRONOSTICS_POLL_SECONDS", POLL_DEFAUT_SECONDS, 1.0, 60.0)
HEURE = _env_heure()
DELAI_REESSAI_ETAT = timedelta(minutes=5)


@dataclass
class Etat:
    """État point-in-time pour le programme d'un jour : construit sur les
    courses finalisées strictement antérieures, jamais mis à jour ensuite."""
    jour: date
    constructeur: ConstructeurFeatures
    manques_signales: Set[Tuple[int, str]] = field(default_factory=set)

    @property
    def dernier_jour(self) -> Optional[date]:
        return self.constructeur.dernier_jour


@dataclass
class Bilan:
    publies: int = 0       # pronostics enregistrés
    manques: int = 0       # horizons sans instantané publiable
    erreurs: int = 0       # courses en échec (retentées à la passe suivante)
    deja_publies: int = 0  # écriture refusée : horizon déjà publié (index unique)
    sans_partant: int = 0  # pronostics impossibles : aucun partant restant (signalés une fois)


def construire_etat(repository: Repository, jour: date) -> Etat:
    debut = time.monotonic()
    constructeur = ConstructeurFeatures()
    for courses in lire_jours(repository, jour - timedelta(days=1)):
        constructeur.traiter_jour(courses, emettre=False)
    logger.info(
        "État des features pour le %s : jours jusqu'au %s, %d cheval(aux), en %.0f s",
        jour, constructeur.dernier_jour, len(constructeur.chevaux), time.monotonic() - debut,
    )
    return Etat(jour=jour, constructeur=constructeur)


def jour_programme(maintenant: datetime, heure: int) -> date:
    """Programme à pronostiquer : celui du jour à partir de `heure`, celui de
    la veille avant (courses juste après minuit)."""
    return maintenant.date() if maintenant.hour >= heure else maintenant.date() - timedelta(days=1)


def _cote_stockee(cote) -> Optional[float]:
    if isinstance(cote, (int, float)) and not isinstance(cote, bool) and math.isfinite(cote):
        return float(cote)
    return None


def calculer(
    modele: ModeleML, etat: Etat, course: CourseRecord, effectifs: List[PartantRecord],
    cotes: Optional[Dict[int, Optional[float]]],
) -> Optional[Tuple[List[dict], List[str]]]:
    """(chevaux, manques) d'un pronostic, ou None sans partant restant.
    `cotes` None : matin, fondamental seul ; sinon cote_direct de
    l'instantané par dossard."""
    lignes = etat.constructeur.lignes_course(course, effectifs) if effectifs else []
    if not lignes:
        return None
    p_fond = modele.probas_fondamentales(lignes)
    nums = [l["num_pmu"] for l in lignes]
    manques: List[str] = []
    if cotes is None:
        publiee, cotes_utilisees = p_fond, [None] * len(nums)
    else:
        cotes_utilisees = [cotes.get(n) for n in nums]
        combinee = combiner(p_fond, cotes_utilisees, modele.alpha, modele.beta)
        if combinee is None:
            manques = ["cotes_incompletes"]
            publiee = p_fond
        else:
            publiee = combinee
    chevaux = [
        {"num_pmu": n, "probabilite": float(p), "probabilite_fondamentale": float(pf), "cote": _cote_stockee(c)}
        for n, p, pf, c in zip(nums, publiee, p_fond, cotes_utilisees)
    ]
    return chevaux, manques


def _signaler_sans_partant(bilan: Bilan, etat: Etat, course: CourseRecord, horizon: str) -> None:
    cle = (course.course_id, f"{horizon}:sans_partant")
    if cle in etat.manques_signales:
        return
    etat.manques_signales.add(cle)
    bilan.sans_partant += 1
    logger.warning("Pronostic %s de la course %s impossible : aucun partant restant", horizon, course.course_id)


def _signaler_manque(bilan: Bilan, etat: Etat, course: CourseRecord, horizon: str, motif: str) -> None:
    cle = (course.course_id, horizon)
    if cle in etat.manques_signales:
        return
    etat.manques_signales.add(cle)
    bilan.manques += 1
    logger.warning("Pronostic %s manqué (%s) : course %s", horizon, motif, course.course_id)


def _a_publier(
    repository: Repository, etat: Etat, bilan: Bilan, course: CourseRecord, depart: datetime, maintenant: datetime,
) -> List[Tuple[str, Optional[Dict[int, Tuple[Optional[str], Optional[float], datetime]]]]]:
    """Horizons à publier pour une course : le matin s'il manque, puis
    l'instantané le plus récent s'il n'est pas encore publié."""
    publies = repository.horizons_publies(course.course_id)
    a_faire: List[Tuple[str, Optional[Dict[int, Tuple[Optional[str], Optional[float], datetime]]]]] = []
    if MATIN not in publies:
        a_faire.append((MATIN, None))
    restants = [(nom, cible) for nom, cible in HORIZONS if nom not in publies]
    if not restants:
        return a_faire
    instantanes = repository.instantanes_course(course.course_id)
    pris = [cible for _, cible in HORIZONS if cible in instantanes]
    plus_recente = min(pris) if pris else None
    for nom, cible in restants:
        if cible == plus_recente:
            a_faire.append((nom, instantanes[cible]))
        elif cible in instantanes:
            _signaler_manque(bilan, etat, course, nom, f"instantané H-{plus_recente} plus récent")
        elif plus_recente is not None and cible > plus_recente:
            _signaler_manque(bilan, etat, course, nom, "pas d'instantané")
        elif maintenant > depart - timedelta(minutes=cible) + tolerance(cible):
            _signaler_manque(bilan, etat, course, nom, "pas d'instantané")
    return a_faire


def passage(
    repository: Repository, modele: ModeleML, etat: Etat, maintenant: datetime,
    horloge: Optional[Callable[[], datetime]] = None,
) -> Bilan:
    """Une passe sur le programme de `etat.jour`. `maintenant` et `horloge`
    sont l'heure locale naïve du conteneur, la même que `heure_depart` ;
    l'horloge est relue juste avant chaque écriture."""
    horloge = horloge or (lambda: maintenant)
    bilan = Bilan()
    parametres_base = dict(modele.parametres(), etat_jusqu_au=etat.dernier_jour.isoformat() if etat.dernier_jour else None)
    for course, depart in lire_courses_du_jour(repository, etat.jour):
        if maintenant >= depart:
            continue
        try:
            for horizon, instantane in _a_publier(repository, etat, bilan, course, depart, maintenant):
                effectifs = course.partants_effectifs()
                cotes = None
                parametres = dict(parametres_base, horizon=horizon)
                if instantane is not None:
                    non_partants = sorted(num for num, (statut, _, _) in instantane.items() if statut == "NON_PARTANT")
                    effectifs = [p for p in effectifs if p.num_pmu not in non_partants]
                    cotes = {num: cote for num, (_, cote, _) in instantane.items()}
                    utilises = [instantane[p.num_pmu][2] for p in effectifs if p.num_pmu in instantane]
                    parametres["instantane_pris_le"] = max(utilises).isoformat() if utilises else None
                    parametres["non_partants"] = non_partants
                resultat = calculer(modele, etat, course, effectifs, cotes)
                if resultat is None:
                    _signaler_sans_partant(bilan, etat, course, horizon)
                    continue
                chevaux, manques = resultat
                cree_le = horloge()
                if cree_le >= depart:
                    logger.warning("Pronostic %s de la course %s non publié : départ atteint", horizon, course.course_id)
                    break
                run_id = repository.enregistrer_pronostic_ml(
                    course.course_id, horizon, cree_le, chevaux, manques, parametres,
                )
                if run_id is None:
                    bilan.deja_publies += 1
                    logger.info("Pronostic %s de la course %s déjà publié", horizon, course.course_id)
                    continue
                bilan.publies += 1
                if manques:
                    logger.warning("Pronostic %s de la course %s : %s", horizon, course.course_id, ", ".join(manques))
                logger.info("Pronostic %s publié : course %s, %d partant(s)", horizon, course.course_id, len(chevaux))
        except Exception:
            bilan.erreurs += 1
            logger.exception("Echec du pronostic de la course %s, retenté à la passe suivante", course.course_id)
    if bilan.publies or bilan.manques or bilan.erreurs or bilan.sans_partant:
        logger.info(
            "Passe des pronostics ML : %d publié(s), %d manqué(s), %d sans partant, %d erreur(s)",
            bilan.publies, bilan.manques, bilan.sans_partant, bilan.erreurs,
        )
    return bilan


def boucle(
    repository: Repository, modele: ModeleML, passages: Optional[int] = None,
    horloge: Callable[[], datetime] = datetime.now, attendre: Callable[[float], None] = time.sleep,
    heure: int = HEURE, construire: Callable[[Repository, date], Etat] = construire_etat,
) -> Optional[Etat]:
    """Passes successives ; `passages` borne la boucle (tests). L'état est
    reconstruit à la première passe où le programme change (à `heure`) ;
    une reconstruction en échec est retentée au plus toutes les
    DELAI_REESSAI_ETAT. Une erreur n'arrête jamais la boucle."""
    etat: Optional[Etat] = None
    prochain_essai: Optional[datetime] = None
    n = 0
    while passages is None or n < passages:
        n += 1
        try:
            maintenant = horloge()
            jour = jour_programme(maintenant, heure)
            if (etat is None or etat.jour != jour) and (prochain_essai is None or maintenant >= prochain_essai):
                try:
                    etat = construire(repository, jour)
                    prochain_essai = None
                except Exception:
                    prochain_essai = horloge() + DELAI_REESSAI_ETAT
                    logger.exception("Echec de la reconstruction de l'état du %s, nouvel essai à %s",
                                     jour, prochain_essai)
            if etat is not None and etat.jour == jour:
                passage(repository, modele, etat, horloge(), horloge=horloge)
        except Exception:
            logger.exception("Echec de la passe des pronostics ML")
        attendre(POLL_SECONDS)
    return etat


# -- vérification de parité avec l'entraînement

def lire_predictions(chemin: str, jour: date) -> Dict[Tuple[int, int], float]:
    with gzip.open(chemin, "rt", encoding="utf-8", newline="") as f:
        return {
            (int(r["course_id"]), int(r["num_pmu"])): float(r["proba_modele"])
            for r in csv.DictReader(f) if r["date"] == jour.isoformat()
        }


def verifier(repository: Repository, modele: ModeleML, jour: date, chemin_predictions: str) -> Dict[str, float]:
    """Recalcule les probabilités fondamentales d'un jour passé (état des
    jours strictement antérieurs, liste finale des partants, comme la table
    d'entraînement) et les compare aux prédictions sauvegardées."""
    attendues = lire_predictions(chemin_predictions, jour)
    constructeur = ConstructeurFeatures()
    lignes: List[dict] = []
    for courses in lire_jours(repository, jour):
        if courses[0].date < jour:
            constructeur.traiter_jour(courses, emettre=False)
            continue
        for course in courses:
            lignes.extend(constructeur.lignes_course(course, course.partants_effectifs()))
    probas = modele.probas_fondamentales(lignes)
    calculees = {(l["course_id"], l["num_pmu"]): float(p) for l, p in zip(lignes, probas)}
    ecarts = [abs(calculees[k] - v) for k, v in attendues.items() if k in calculees]
    bilan = {
        "attendus": len(attendues),
        "compares": len(ecarts),
        "manquants": sum(1 for k in attendues if k not in calculees),
        "en_plus": sum(1 for k in calculees if k not in attendues),
        "ecart_max": max(ecarts) if ecarts else math.nan,
    }
    logger.info(
        "Vérification du %s : %d partant(s) attendu(s), %d comparé(s), %d manquant(s), %d en plus "
        "(courses écartées de l'entraînement), écart maximal %.3g",
        jour, bilan["attendus"], bilan["compares"], bilan["manquants"], bilan["en_plus"], bilan["ecart_max"],
    )
    return bilan


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Pronostics du modèle ML (matin et horizons)")
    parser.add_argument("--verifier", type=date.fromisoformat, metavar="JOUR",
                        help="Compare les probabilités fondamentales d'un jour passé aux prédictions d'entraînement")
    parser.add_argument("--predictions", help="test_predictions.csv.gz (avec --verifier)")
    args = parser.parse_args(argv)
    if args.verifier is not None and not args.predictions:
        parser.error("--verifier exige --predictions")
    return args


def main(argv: Optional[List[str]] = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    args = parse_args(argv)
    try:
        modele = charger(DOSSIER_FONDAMENTAL, DOSSIER_COMBINE)
    except (ErreurModele, ImportError, OSError) as erreur:
        logger.error("Modèle ML refusé, service non démarré : %s", erreur)
        return 1
    logger.info(
        "Modèle ML : %d features, température %.4f, alpha %.4f, beta %.4f",
        len(modele.features), modele.temperature, modele.alpha, modele.beta,
    )
    repository = Repository()
    if args.verifier is not None:
        bilan = verifier(repository, modele, args.verifier, args.predictions)
        ok = (bilan["compares"] > 0 and bilan["manquants"] == 0 and bilan["en_plus"] == 0
              and bilan["ecart_max"] < TOLERANCE_VERIFICATION)
        return 0 if ok else 1
    logger.info("Pronostics ML démarrés : matin à partir de %d h, passe toutes les %ss", HEURE, POLL_SECONDS)
    boucle(repository, modele)
    return 0


if __name__ == "__main__":
    sys.exit(main())
