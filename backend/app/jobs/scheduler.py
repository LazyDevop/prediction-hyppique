import logging
import os
import time
from datetime import date, datetime

from app.data.repository import Repository
from app.jobs.ingest_daily import run

logger = logging.getLogger(__name__)

RUN_HOUR = int(os.environ.get("INGEST_HOUR", "6"))
CHECK_INTERVAL_SECONDS = 60


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    repository = Repository()
    last_run: date = None

    logger.info("Scheduler démarré, ingestion quotidienne à %dh", RUN_HOUR)

    # Ingestion immédiate au démarrage : la fenêtre horaire quotidienne peut
    # être manquée si la machine est éteinte/en veille à ce moment précis
    # (cas courant pour un usage personnel) — ne pas en dépendre uniquement.
    try:
        today = datetime.now().date()
        run(repository, today)
        last_run = today
    except Exception:
        logger.exception("Echec de l'ingestion au démarrage")

    while True:
        now = datetime.now()
        if now.hour == RUN_HOUR and last_run != now.date():
            try:
                run(repository, now.date())
                last_run = now.date()
            except Exception:
                logger.exception("Echec de l'ingestion quotidienne du %s", now.date())
        time.sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
