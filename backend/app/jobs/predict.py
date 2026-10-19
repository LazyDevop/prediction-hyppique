"""Enregistre un pronostic par course avant son départ, pour pouvoir le
comparer plus tard à l'arrivée officielle (tableau de bord).

Usage :
    python -m app.jobs.predict                      # courses du jour pas encore parties
    python -m app.jobs.predict --rejouer 2026-10-18 # recalcul a posteriori, variante "rejeu"
"""

import argparse
import logging
from datetime import date, datetime
from typing import List, Optional

from app.data.models import Course
from app.data.repository import Repository
from app.engine.constants import terrain_coefficient
from app.engine.scoring import CourseTarget, HorseAnalysis, analyse_course

logger = logging.getLogger(__name__)


def donnees_manquantes(course: Course, horses: List[HorseAnalysis]) -> List[str]:
    manques = []
    # Le trot n'a pas d'état de terrain : son absence n'y est pas un manque.
    if course.discipline != "trot" and course.terrain is None:
        manques.append("terrain_du_jour")
    if any(not h.inedit and not h.performances for h in horses):
        manques.append("historique_absent")
    return manques


def predire_course(repository: Repository, course: Course, variante: str, maintenant: datetime) -> Optional[int]:
    horses = repository.get_horses_for_course(course, avant=course.date)
    if not horses:
        return None
    manques = donnees_manquantes(course, horses)
    cible = CourseTarget(
        distance=course.distance,
        terrain=terrain_coefficient(course.terrain),
        niveau=None,
        nb_partants_course=course.nb_partants or len(horses),
    )
    return repository.save_prediction_run(course.id, analyse_course(horses, cible), variante, maintenant, manques)


def predire_courses_a_venir(repository: Repository, maintenant: datetime) -> None:
    a_venir = [
        c for c in repository.list_courses_for_date(maintenant.date())
        if c.heure_depart is not None and c.heure_depart > maintenant
    ]
    for course in a_venir:
        try:
            predire_course(repository, course, "live", maintenant)
        except Exception:
            logger.exception("Echec du pronostic de la course %s", course.id)
    logger.info("%d pronostic(s) enregistré(s) pour les courses à venir du %s", len(a_venir), maintenant.date())


def rejouer(repository: Repository, jour: date, maintenant: datetime) -> None:
    courses = repository.list_courses_for_date(jour)
    for course in courses:
        predire_course(repository, course, "rejeu", maintenant)
    logger.info("%d course(s) du %s rejouée(s)", len(courses), jour)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description="Enregistre les pronostics des courses")
    parser.add_argument("--rejouer", type=date.fromisoformat, default=None,
                        help="Recalcule a posteriori les courses de cette date (variante rejeu)")
    args = parser.parse_args()

    repository = Repository()
    if args.rejouer:
        rejouer(repository, args.rejouer, datetime.now())
    else:
        predire_courses_a_venir(repository, datetime.now())


if __name__ == "__main__":
    main()
