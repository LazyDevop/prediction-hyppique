"""Comparaison des pronostics enregistrés avec les arrivées officielles.

Fonctions pures : aucune lecture de base ni d'API. Chaque métrique est
accompagnée de sa référence (favori du marché, hasard), sans laquelle un
taux de réussite isolé ne dit rien de la qualité du moteur.
"""

import math
from dataclasses import dataclass, field
from statistics import mean
from typing import Dict, List, Optional, Sequence

# Plancher de probabilité pour le log-loss : une probabilité nulle donnée au
# gagnant rendrait la moyenne infinie et masquerait toutes les autres courses.
PROBA_MIN = 1e-6

# Profondeur d'arrivée jugée par chaque pari en ordre / désordre.
PROFONDEUR_PARIS = {"couple": 2, "trio": 3, "quarte": 4, "quinte": 5}

TRANCHES_CALIBRATION = [(0.0, 0.05), (0.05, 0.1), (0.1, 0.2), (0.2, 0.3), (0.3, 0.5), (0.5, 1.0)]


@dataclass
class ChevalPredit:
    num_pmu: int
    probabilite: float
    cote: Optional[float]
    rang_arrivee: Optional[int]


@dataclass
class CoursePredite:
    discipline: str
    degradee: bool
    chevaux: List[ChevalPredit]
    course_id: Optional[int] = None
    # Pronostic fait dans l'app : qui (installation anonyme) et si
    # l'utilisateur a modifié les données avant de calculer.
    installation_id: Optional[str] = None
    donnees_modifiees: bool = False
    # Combinaisons proposées (dossards), absentes des pronostics enregistrés
    # avant leur ajout ; l'arrivée est sinon déduite des rangs des chevaux.
    combinaisons: Optional[dict] = None
    arrivee: List[int] = field(default_factory=list)
    nb_partants: Optional[int] = None


@dataclass
class EvaluationCourse:
    discipline: str
    degradee: bool
    gagnant_trouve: bool
    gagnant_dans_top3: bool
    favori_gagnant: Optional[bool]
    log_loss: float
    log_loss_hasard: float
    brier: float
    paires_calibration: List[tuple] = field(default_factory=list)
    course_id: Optional[int] = None
    installation_id: Optional[str] = None
    donnees_modifiees: bool = False
    paris: Dict[str, Optional[bool]] = field(default_factory=dict)


@dataclass
class TrancheCalibration:
    borne_basse: float
    borne_haute: float
    chevaux: int
    proba_moyenne: Optional[float]
    taux_victoire: Optional[float]


@dataclass
class Comparaison:
    paires: int
    utilisateurs: int
    taux_gagnant_app: Optional[float]
    taux_gagnant_auto: Optional[float]
    log_loss_app: Optional[float]
    log_loss_auto: Optional[float]


@dataclass
class Bilan:
    courses: int
    taux_gagnant: Optional[float]
    taux_top3: Optional[float]
    courses_avec_cotes: int
    taux_favori: Optional[float]
    log_loss: Optional[float]
    log_loss_hasard: Optional[float]
    brier: Optional[float]
    calibration: List[TrancheCalibration]
    paris: Dict[str, dict] = field(default_factory=dict)


def _places_payees(nb_partants: int) -> int:
    # Règle PMU du simple placé : 3 places à partir de 8 partants, 2 de 4 à 7.
    if nb_partants >= 8:
        return 3
    if nb_partants >= 4:
        return 2
    return 0


def evaluer_paris(
    combinaisons: Optional[dict], arrivee: List[int], nb_partants: int, numero_un_moteur: Optional[int],
) -> Dict[str, Optional[bool]]:
    """Pour chaque type de pari : True si l'une des combinaisons proposées
    gagne, False sinon, None s'il n'est pas évaluable (aucune combinaison
    proposée, arrivée connue sur trop peu de places, pas de placé)."""
    paris: Dict[str, Optional[bool]] = {}
    combinaisons = combinaisons or {}

    for pari, profondeur in PROFONDEUR_PARIS.items():
        proposees = combinaisons.get(pari) or {}
        tete = arrivee[:profondeur]
        complet = len(tete) == profondeur
        ordre, desordre = proposees.get("ordre") or [], proposees.get("desordre") or []
        paris[f"{pari}_ordre"] = any(list(c) == tete for c in ordre) if ordre and complet else None
        paris[f"{pari}_desordre"] = any(set(c) == set(tete) for c in desordre) if desordre and complet else None

    for pari, profondeur in (("couple_place", 3), ("deux_sur_quatre", 4)):
        proposees = combinaisons.get(pari) or []
        tete = set(arrivee[:profondeur])
        complet = len(tete) == profondeur
        paris[pari] = any(set(c) <= tete for c in proposees) if proposees and complet else None

    places = _places_payees(nb_partants)
    if places and numero_un_moteur is not None and len(arrivee) >= places:
        paris["place"] = numero_un_moteur in arrivee[:places]
    else:
        paris["place"] = None
    return paris


def evaluer_course(course: CoursePredite) -> Optional[EvaluationCourse]:
    chevaux = course.chevaux
    gagnant = next((c for c in chevaux if c.rang_arrivee == 1), None)
    if gagnant is None or not chevaux:
        return None

    classement = sorted(chevaux, key=lambda c: c.probabilite, reverse=True)
    arrivee = course.arrivee or [
        c.num_pmu for c in sorted((c for c in chevaux if c.rang_arrivee), key=lambda c: c.rang_arrivee)
    ]
    cotes = [c for c in chevaux if c.cote]
    favori = min(cotes, key=lambda c: c.cote) if cotes else None

    return EvaluationCourse(
        discipline=course.discipline,
        degradee=course.degradee,
        gagnant_trouve=classement[0] is gagnant,
        gagnant_dans_top3=gagnant in classement[:3],
        favori_gagnant=(favori is gagnant) if favori else None,
        log_loss=-math.log(max(gagnant.probabilite, PROBA_MIN)),
        log_loss_hasard=math.log(len(chevaux)),
        brier=sum((c.probabilite - (c is gagnant)) ** 2 for c in chevaux),
        paires_calibration=[(c.probabilite, c is gagnant) for c in chevaux],
        course_id=course.course_id,
        installation_id=course.installation_id,
        donnees_modifiees=course.donnees_modifiees,
        paris=evaluer_paris(course.combinaisons, arrivee, course.nb_partants or len(chevaux), classement[0].num_pmu),
    )


def _moyenne(valeurs: Sequence[float]) -> Optional[float]:
    return mean(valeurs) if valeurs else None


def agreger(evaluations: Sequence[EvaluationCourse]) -> Bilan:
    avec_cotes = [e for e in evaluations if e.favori_gagnant is not None]
    paires = [p for e in evaluations for p in e.paires_calibration]

    calibration = []
    for basse, haute in TRANCHES_CALIBRATION:
        dans_tranche = [(p, gagne) for p, gagne in paires if basse <= p < haute or (haute == 1.0 and p == 1.0)]
        calibration.append(TrancheCalibration(
            borne_basse=basse,
            borne_haute=haute,
            chevaux=len(dans_tranche),
            proba_moyenne=_moyenne([p for p, _ in dans_tranche]),
            taux_victoire=_moyenne([float(gagne) for _, gagne in dans_tranche]),
        ))

    return Bilan(
        courses=len(evaluations),
        taux_gagnant=_moyenne([float(e.gagnant_trouve) for e in evaluations]),
        taux_top3=_moyenne([float(e.gagnant_dans_top3) for e in evaluations]),
        courses_avec_cotes=len(avec_cotes),
        taux_favori=_moyenne([float(e.favori_gagnant) for e in avec_cotes]),
        log_loss=_moyenne([e.log_loss for e in evaluations]),
        log_loss_hasard=_moyenne([e.log_loss_hasard for e in evaluations]),
        brier=_moyenne([e.brier for e in evaluations]),
        calibration=calibration,
        paris={
            pari: {"courses": len(valeurs), "taux": _moyenne([float(v) for v in valeurs])}
            for pari in sorted({k for e in evaluations for k in e.paris})
            for valeurs in [[e.paris[pari] for e in evaluations if e.paris.get(pari) is not None]]
        },
    )


def comparer(app: Sequence[EvaluationCourse], auto: Sequence[EvaluationCourse]) -> Comparaison:
    """Pronostics faits dans l'app contre le pronostic automatique de la même
    course : seule une comparaison sur les mêmes courses dit si l'utilisateur
    (ses saisies, ses réglages) fait mieux que le moteur seul."""
    auto_par_course = {e.course_id: e for e in auto}
    paires = [(a, auto_par_course[a.course_id]) for a in app if a.course_id in auto_par_course]
    return Comparaison(
        paires=len(paires),
        utilisateurs=len({a.installation_id for a, _ in paires}),
        taux_gagnant_app=_moyenne([float(a.gagnant_trouve) for a, _ in paires]),
        taux_gagnant_auto=_moyenne([float(b.gagnant_trouve) for _, b in paires]),
        log_loss_app=_moyenne([a.log_loss for a, _ in paires]),
        log_loss_auto=_moyenne([b.log_loss for _, b in paires]),
    )
