"""Reconstruction de l'historique des courses françaises depuis PMU turfinfo.

Pour chaque jour passé : programme -> courses françaises -> participants.
Stocke courses, participations (cotes horodatées) et une ligne d'historique
par partant effectif des courses à l'arrivée définitive. Ces données sont
des labels et des repères, jamais des features calculées ici. Chaque jour
qui apporte de nouvelles courses est ensuite rejoué (variante "rejeu", sans
voir son arrivée) pour apparaître au tableau de bord au fil de l'eau.

Bridé (requêtes séquentielles via pmu_client, 1 s entre chaque) et
reprenable : une course déjà stockée, finalisée et avec ses participations
n'est pas redemandée. Un échec (jour ou course) est journalisé et le job
continue.

Sur le serveur, par tranches (environ un jour et demi pour 5 ans) :
    docker compose exec ingestion python -m app.jobs.rebuild_historique \\
        --date-debut 2021-10-20 --date-fin 2022-10-19
"""

import argparse
import logging
import sys
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import List, Optional

from app.data import pmu_client
from app.jobs import predict
from app.data.repository import Repository

logger = logging.getLogger(__name__)


@dataclass
class Bilan:
    jours: int = 0
    jours_en_echec: int = 0
    courses_recuperees: int = 0
    courses_sautees: int = 0
    courses_en_echec: int = 0
    lignes_historique: int = 0
    jours_rejoues: int = 0


def _traiter_jour(repository: Repository, jour: date, bilan: Bilan, rejouer: bool = True) -> None:
    courses = pmu_client.get_programme(jour)
    recuperees = sautees = echecs = 0
    for info in courses:
        try:
            if info.numero_reunion is None or info.numero_course is None:
                raise ValueError("course sans numéro de réunion ou de course")
            if repository.course_complete(jour, info.numero_reunion, info.numero_course):
                sautees += 1
                continue
            # Participants d'abord : un échec réseau ne crée pas de course
            # vide. Une course restée sans participations (échec d'écriture)
            # n'est pas complète et sera reprise au prochain passage.
            partants = pmu_client.get_participants(jour, info.numero_reunion, info.numero_course)
            course = repository.upsert_course(info)
            repository.save_partants(course.id, partants)
            if info.arrivee_definitive:
                bilan.lignes_historique += repository.deriver_historique_course(course.id, partants)
            # En dernier : une interruption avant ce point laisse la course
            # non finalisée, donc reprise au prochain passage.
            repository.marquer_finalisee(course.id)
            recuperees += 1
        except Exception:
            echecs += 1
            logger.exception("Echec reconstruction R%sC%s (%s)", info.numero_reunion, info.numero_course, jour)

    # Rejeu du jour : l'historique des jours précédents est déjà en base
    # (parcours chronologique) et le rejeu ne lit que les performances
    # antérieures à la course. Un échec n'arrête pas la reconstruction.
    if rejouer and recuperees:
        try:
            predict.rejouer(repository, jour, datetime.now())
            bilan.jours_rejoues += 1
        except Exception:
            logger.exception("Echec du rejeu du %s", jour)

    bilan.courses_recuperees += recuperees
    bilan.courses_sautees += sautees
    bilan.courses_en_echec += echecs
    logger.info(
        "%s : %d course(s) récupérée(s), %d sautée(s), %d en échec | cumul : %d récupérées, %d sautées, %d en échec",
        jour, recuperees, sautees, echecs,
        bilan.courses_recuperees, bilan.courses_sautees, bilan.courses_en_echec,
    )


def rebuild_plage(repository: Repository, date_debut: date, date_fin: date, rejouer: bool = True) -> Bilan:
    bilan = Bilan()
    jour = date_debut
    while jour <= date_fin:
        bilan.jours += 1
        try:
            _traiter_jour(repository, jour, bilan, rejouer)
        except Exception:
            bilan.jours_en_echec += 1
            logger.exception("Echec du programme du %s", jour)
        jour += timedelta(days=1)

    logger.info(
        "Reconstruction %s -> %s terminée : %d jour(s) dont %d en échec, %d course(s) récupérée(s), "
        "%d sautée(s), %d en échec, %d ligne(s) d'historique écrite(s), %d jour(s) rejoué(s)",
        date_debut, date_fin, bilan.jours, bilan.jours_en_echec, bilan.courses_recuperees,
        bilan.courses_sautees, bilan.courses_en_echec, bilan.lignes_historique, bilan.jours_rejoues,
    )
    return bilan


def parse_args(argv: Optional[List[str]] = None, today: Optional[date] = None) -> argparse.Namespace:
    today = today or date.today()
    parser = argparse.ArgumentParser(description="Reconstruction de l'historique depuis PMU turfinfo")
    parser.add_argument("--date-debut", type=date.fromisoformat, required=True)
    parser.add_argument("--date-fin", type=date.fromisoformat, required=True)
    parser.add_argument("--sans-rejeu", action="store_true", help="Ne pas rejouer les jours récupérés")
    args = parser.parse_args(argv)
    veille = today - timedelta(days=1)
    # La veille et au-delà relèvent du job quotidien (résultats pas encore
    # définitifs) : ne jamais les marquer finalisées ici.
    if args.date_fin >= veille:
        parser.error(f"--date-fin doit être antérieure à la veille ({veille.isoformat()})")
    if args.date_fin < args.date_debut:
        parser.error("--date-fin doit être postérieure ou égale à --date-debut")
    return args


def main(argv: Optional[List[str]] = None) -> int:
    """Code de sortie 1 s'il reste des jours ou des courses en échec : la
    tranche est à relancer."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    args = parse_args(argv)
    bilan = rebuild_plage(Repository(), args.date_debut, args.date_fin, rejouer=not args.sans_rejeu)
    return 1 if bilan.jours_en_echec or bilan.courses_en_echec else 0


if __name__ == "__main__":
    sys.exit(main())
