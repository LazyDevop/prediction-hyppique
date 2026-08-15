import argparse
import logging
from datetime import date, timedelta

from app.data import pmu_client
from app.data.repository import Repository

logger = logging.getLogger(__name__)


def ingest_programme_du_jour(repository: Repository, target_date: date) -> None:
    """Récupère programme + partants + historique pour une date et les stocke."""
    courses = pmu_client.get_programme(target_date)
    logger.info("Programme %s : %d courses françaises trouvées", target_date, len(courses))

    for info in courses:
        course = repository.upsert_course(info)
        try:
            partants = pmu_client.get_participants(target_date, info.numero_reunion, info.numero_course)
            repository.save_partants(course.id, partants)

            historique = pmu_client.get_historique(target_date, info.numero_reunion, info.numero_course)
            repository.save_historique(course.id, historique)
        except Exception:
            logger.exception(
                "Echec ingestion R%sC%s (%s)", info.numero_reunion, info.numero_course, target_date
            )


def ingest_resultats_veille(repository: Repository, veille: date) -> None:
    """Repasse sur les courses d'une date passée pour en récupérer le résultat définitif."""
    courses = repository.get_unfinalized_courses_before(veille + timedelta(days=1))
    logger.info("%d course(s) à re-vérifier avant/le %s", len(courses), veille)

    programmes_par_date = {}
    for course in courses:
        if course.numero_reunion is None or course.numero_course is None:
            continue
        if course.date not in programmes_par_date:
            programmes_par_date[course.date] = pmu_client.get_programme(course.date)

        try:
            partants = pmu_client.get_participants(course.date, course.numero_reunion, course.numero_course)
        except Exception:
            logger.exception("Echec récupération résultat R%sC%s (%s)", course.numero_reunion, course.numero_course, course.date)
            continue

        arrivee_definitive = any(
            c.numero_reunion == course.numero_reunion and c.numero_course == course.numero_course and c.arrivee_definitive
            for c in programmes_par_date[course.date]
        )
        repository.update_resultats(course.id, partants, arrivee_definitive)


def run(repository: Repository, today: date, days_ahead: int = 1) -> None:
    ingest_programme_du_jour(repository, today)
    for offset in range(1, days_ahead + 1):
        ingest_programme_du_jour(repository, today + timedelta(days=offset))
    ingest_resultats_veille(repository, today - timedelta(days=1))


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description="Ingestion quotidienne du programme PMU")
    parser.add_argument("--date", type=lambda s: date.fromisoformat(s), default=date.today())
    parser.add_argument("--days-ahead", type=int, default=1)
    args = parser.parse_args()

    repository = Repository()
    run(repository, args.date, args.days_ahead)


if __name__ == "__main__":
    main()
