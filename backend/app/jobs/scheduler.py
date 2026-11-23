import logging
import os
import time
from datetime import date, datetime, timedelta
from typing import Optional

from app.data.repository import Repository
from app.jobs.ingest_daily import rafraichir_terrains_du_jour, run
from app.jobs.predict import predire_courses_a_venir

logger = logging.getLogger(__name__)

RUN_HOUR = int(os.environ.get("INGEST_HOUR", "6"))
CHECK_INTERVAL_SECONDS = 60
TERRAIN_REFRESH_INTERVAL = timedelta(hours=1)
# Délai entre deux tentatives d'ingestion après un échec (réseau coupé...).
INGEST_RETRY_INTERVAL = timedelta(minutes=15)


def ingestion_due(
    now: datetime, last_run: Optional[date], last_attempt: Optional[datetime]
) -> bool:
    """Ingestion du jour due : dès RUN_HOUR et tant qu'elle n'a pas réussi.

    Un PC en veille pendant toute l'heure RUN_HOUR ne fait plus sauter la
    journée : l'ingestion part au réveil. Après un échec, nouvel essai au plus
    tôt INGEST_RETRY_INTERVAL plus tard.
    """
    if now.hour < RUN_HOUR or last_run == now.date():
        return False
    return last_attempt is None or now - last_attempt >= INGEST_RETRY_INTERVAL


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    repository = Repository()
    last_run: Optional[date] = None
    last_attempt: Optional[datetime] = None
    last_terrain_refresh: Optional[datetime] = None

    logger.info("Scheduler démarré, ingestion quotidienne à %dh", RUN_HOUR)

    # Ingestion immédiate au démarrage : la fenêtre horaire quotidienne peut
    # être manquée si la machine est éteinte/en veille à ce moment précis
    # (cas courant pour un usage personnel) — ne pas en dépendre uniquement.
    try:
        last_attempt = datetime.now()
        today = last_attempt.date()
        run(repository, today)
        last_run = today
    except Exception:
        logger.exception("Echec de l'ingestion au démarrage")

    while True:
        now = datetime.now()
        if ingestion_due(now, last_run, last_attempt):
            last_attempt = now
            try:
                run(repository, now.date())
                last_run = now.date()
            except Exception:
                logger.exception("Echec de l'ingestion quotidienne du %s", now.date())
        # Le pénétromètre est mesuré le matin, après l'ingestion de 6h, et
        # peut être remesuré dans la journée.
        if last_terrain_refresh is None or now - last_terrain_refresh >= TERRAIN_REFRESH_INTERVAL:
            try:
                rafraichir_terrains_du_jour(repository, now.date())
            except Exception:
                logger.exception("Echec du rafraîchissement des terrains du %s", now.date())
            # Après le terrain : le dernier pronostic avant le départ doit
            # intégrer la mesure du matin. Un pronostic par heure et par course
            # à venir, jamais réécrit (tableau de bord).
            try:
                predire_courses_a_venir(repository, now)
            except Exception:
                logger.exception("Echec des pronostics du %s", now.date())
            last_terrain_refresh = now
        time.sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
