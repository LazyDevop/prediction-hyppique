"""Purge des lignes d'historique issues d'open-pmu-api.

Cette source ne renvoie que le Quinté+ du jour et ses ~7 premiers arrivés
(inventaire du 20/10/2026, _bmad-output/planning-artifacts/research/
api-field-inventory-2026-10-20) : les lignes backfillées ne contiennent que
les bonnes courses d'un cheval et faussent son historique. On les supprime,
ainsi que les chevaux créés par ce seul backfill (ni participation ni autre
historique). Les lignes de source "pmu" ne sont jamais touchées.

Usage :
    python -m app.jobs.purge_open_pmu            # simulation, rien n'est supprimé
    python -m app.jobs.purge_open_pmu --executer
"""

import argparse
import logging
from dataclasses import dataclass

from sqlalchemy import delete, exists, func, or_, select
from sqlalchemy.orm import Session

from app.data.models import Cheval, Participation, PerformanceHistorique
from app.data.repository import Repository

logger = logging.getLogger(__name__)

SOURCE_OPEN_PMU = "open_pmu_api"


@dataclass
class BilanPurge:
    lignes: int
    chevaux_orphelins: int
    execute: bool


def _chevaux_orphelins():
    """Chevaux sans participation ni historique d'une autre source."""
    return select(Cheval.id).where(
        ~exists().where(Participation.cheval_id == Cheval.id),
        ~exists().where(
            PerformanceHistorique.cheval_id == Cheval.id,
            # Une source NULL (ligne ancienne) compte comme une autre source.
            or_(PerformanceHistorique.source.is_(None), PerformanceHistorique.source != SOURCE_OPEN_PMU),
        ),
        exists().where(
            PerformanceHistorique.cheval_id == Cheval.id,
            PerformanceHistorique.source == SOURCE_OPEN_PMU,
        ),
    )


def purger(repository: Repository, executer: bool = False) -> BilanPurge:
    with Session(repository.engine) as session:
        lignes = session.scalar(
            select(func.count()).select_from(PerformanceHistorique).where(PerformanceHistorique.source == SOURCE_OPEN_PMU)
        )
        orphelins = session.scalar(select(func.count()).select_from(_chevaux_orphelins().subquery()))
        if executer:
            # Les chevaux d'abord : une fois leurs lignes open-pmu supprimées,
            # plus rien ne les distinguerait d'un cheval sans données. La
            # sous-requête évite une liste d'identifiants en paramètres.
            session.execute(delete(Cheval).where(Cheval.id.in_(_chevaux_orphelins())))
            session.execute(delete(PerformanceHistorique).where(PerformanceHistorique.source == SOURCE_OPEN_PMU))
            session.commit()
    return BilanPurge(lignes=lignes, chevaux_orphelins=orphelins, execute=executer)


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description="Supprime l'historique backfillé depuis open-pmu-api")
    parser.add_argument("--executer", action="store_true", help="Supprimer réellement (sinon simulation)")
    args = parser.parse_args()

    bilan = purger(Repository(), executer=args.executer)
    logger.info(
        "%s : %d ligne(s) open-pmu, %d cheval(aux) orphelin(s)",
        "Supprimé" if bilan.execute else "Simulation, rien supprimé", bilan.lignes, bilan.chevaux_orphelins,
    )


if __name__ == "__main__":
    main()
