"""Relève les cotes en direct de chaque partant des courses du jour stockées
par l'ingestion (source pmu ; l'ingestion ne garde que les courses françaises) à 60, 30, 10 et 2 minutes du départ prévu (table `cotes_instantanees`).

Une requête `participants` par course et par cible, jamais par partant. Une
cible ouvre à `heure_depart - cible` et ferme après une tolérance (5 min
pour H-60 et H-30, 2 min pour H-10 et H-2) : manquée, elle n'est jamais
prise en retard ; déjà relevée, jamais reprise ; en échec, retentée au
passage suivant tant que sa fenêtre est ouverte.

Usage :
    python -m app.jobs.cotes_instantanees   # boucle, un passage toutes les COTES_POLL_SECONDS
"""

import logging
import os
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Callable, List, Optional, Set, Tuple

from app.data import pmu_client
from app.data.repository import Repository

logger = logging.getLogger(__name__)

CIBLES_MINUTES = (60, 30, 10, 2)
POLL_DEFAUT_SECONDS = 30.0
POLL_MAX_SECONDS = 60.0  # au-delà, la fenêtre de 2 min de H-10 et H-2 peut être sautée


def _poll_seconds() -> float:
    brut = os.environ.get("COTES_POLL_SECONDS", str(POLL_DEFAUT_SECONDS))
    try:
        valeur = float(brut)
    except ValueError:
        logger.warning("COTES_POLL_SECONDS invalide (%r) : %ss utilisées", brut, POLL_DEFAUT_SECONDS)
        return POLL_DEFAUT_SECONDS
    if not 1.0 <= valeur <= POLL_MAX_SECONDS:
        borne = min(max(valeur, 1.0), POLL_MAX_SECONDS)
        logger.warning("COTES_POLL_SECONDS=%s hors de [1, %s] : %ss utilisées", brut, POLL_MAX_SECONDS, borne)
        return borne
    return valeur


POLL_SECONDS = _poll_seconds()


def tolerance(cible_minutes: int) -> timedelta:
    return timedelta(minutes=5 if cible_minutes >= 30 else 2)


@dataclass
class Bilan:
    pris: int = 0        # partants relevés (lignes écrites)
    manques: int = 0     # paires course-cible dont la fenêtre est passée sans relevé
    ignores: int = 0     # partants sans participation en base
    erreurs: int = 0     # requêtes ou écritures en échec, réponses vides (retentées au passage suivant)


def _signaler_manque(bilan: Bilan, course, cible: int, manques_signales, motif: str) -> None:
    cle = (course.id, cible)
    if manques_signales is not None and cle in manques_signales:
        return
    bilan.manques += 1
    logger.warning(
        "Instantané H-%d manqué (%s) : R%sC%s (course %s, départ %s)",
        cible, motif, course.numero_reunion, course.numero_course, course.id, course.heure_depart,
    )
    if manques_signales is not None:
        manques_signales.add(cle)


def prendre_instantanes(
    repository: Repository,
    maintenant: datetime,
    manques_signales: Optional[Set[Tuple[int, int]]] = None,
    horloge: Optional[Callable[[], datetime]] = None,
) -> Bilan:
    """Un passage. `maintenant` est l'heure locale naïve du conteneur, la
    même horloge que `heure_depart` (comme predict.predire_courses_a_venir).

    `horloge` (facultatif) redonne l'heure courante sur la même horloge : la
    fenêtre est revérifiée juste avant la requête et à son retour, pour qu'un
    passage long (requêtes espacées) ne relève jamais une cible en retard.
    Sans elle, `maintenant` sert partout. Les cibles dues sont traitées de la
    plus urgente (fermeture la plus proche) à la moins urgente.

    `manques_signales` (facultatif, tenu par la boucle) : paires
    (course_id, cible) déjà comptées comme manquées, pour ne pas les
    recompter à chaque passage. Sans lui, chaque passage compte toutes les
    cibles manquées du jour."""
    horloge = horloge or (lambda: maintenant)
    bilan = Bilan()
    dues: List[Tuple[datetime, object, int]] = []
    # La veille aussi : une course juste après minuit ouvre ses cibles la veille au soir.
    jours = sorted({maintenant.date() - timedelta(days=1), maintenant.date()})
    for jour in jours:
        for course in repository.list_courses_for_date(jour):
            if (course.source != "pmu" or course.heure_depart is None
                    or course.numero_reunion is None or course.numero_course is None):
                continue
            ouvertes = [c for c in CIBLES_MINUTES if maintenant >= course.heure_depart - timedelta(minutes=c)]
            if not ouvertes:
                continue
            try:
                cibles_prises = {c for _, c in repository.instantanes_pris(course.id)}
            except Exception:
                bilan.erreurs += 1
                logger.exception("Lecture des instantanés de la course %s impossible, retentée au prochain passage",
                                 course.id)
                continue
            for cible in ouvertes:
                if cible in cibles_prises:
                    continue
                fermeture = course.heure_depart - timedelta(minutes=cible) + tolerance(cible)
                if maintenant > fermeture:
                    _signaler_manque(bilan, course, cible, manques_signales, "fenêtre passée")
                    continue
                dues.append((fermeture, course, cible))

    for fermeture, course, cible in sorted(dues, key=lambda d: (d[0], d[1].id, d[2])):
        if horloge() > fermeture:
            _signaler_manque(bilan, course, cible, manques_signales, "fenêtre fermée avant la requête")
            continue
        try:
            pris_le = datetime.now(timezone.utc).replace(tzinfo=None)  # juste avant la requête
            partants = pmu_client.get_participants(course.date, course.numero_reunion, course.numero_course)
            if horloge() > fermeture:
                _signaler_manque(bilan, course, cible, manques_signales, "réponse arrivée après la fenêtre")
                continue
            ecrites, ignores = repository.enregistrer_instantanes(course.id, cible, pris_le, partants)
        except Exception:
            bilan.erreurs += 1
            logger.exception(
                "Echec de l'instantané H-%d de R%sC%s (course %s), retenté au prochain passage",
                cible, course.numero_reunion, course.numero_course, course.id,
            )
            continue
        bilan.ignores += ignores
        if ecrites == 0:
            bilan.erreurs += 1
            logger.warning(
                "Instantané H-%d de R%sC%s vide : %d partant(s) reçu(s), %d ignoré(s), retenté au prochain passage",
                cible, course.numero_reunion, course.numero_course, len(partants), ignores,
            )
            continue
        bilan.pris += ecrites
        logger.info(
            "Instantané H-%d de R%sC%s : %d partant(s) relevé(s), %d ignoré(s)",
            cible, course.numero_reunion, course.numero_course, ecrites, ignores,
        )
    logger.info(
        "Passage des cotes : %d pris, %d manqué(s), %d ignoré(s), %d erreur(s)",
        bilan.pris, bilan.manques, bilan.ignores, bilan.erreurs,
    )
    return bilan


def boucle(repository: Repository, passages: Optional[int] = None, horloge: Callable[[], datetime] = datetime.now,
           attendre: Callable[[float], None] = time.sleep) -> None:
    """Passages successifs ; `passages` borne la boucle (tests). Une erreur
    d'un passage n'arrête jamais la boucle. Les manques signalés sont oubliés
    à chaque changement de jour."""
    manques_signales: Set[Tuple[int, int]] = set()
    jour = None
    n = 0
    while passages is None or n < passages:
        n += 1
        maintenant = horloge()
        if maintenant.date() != jour:
            manques_signales.clear()
            jour = maintenant.date()
        try:
            prendre_instantanes(repository, maintenant, manques_signales, horloge=horloge)
        except Exception:
            logger.exception("Echec du passage des cotes")
        attendre(POLL_SECONDS)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    logger.info("Instantanés de cotes démarrés : cibles %s min, passage toutes les %ss", CIBLES_MINUTES, POLL_SECONDS)
    boucle(Repository())


if __name__ == "__main__":
    main()
