"""Backfill de l'historique profond via open-pmu-api — commande séparée du
flux d'ingestion quotidien (section 6.1 du document backend), à lancer
manuellement. Comble la limite de performances-detaillees (5 dernières
courses seulement) sans toucher à pmu_client.py ni au job quotidien.

Usage :
    python -m app.jobs.backfill_historique --date-debut 2026-01-01 --date-fin 2026-01-31
    python -m app.jobs.backfill_historique --date-debut 2020-01-01 --date-fin 2020-12-31 --cheval "IDEFIX D'OLMEN"
    python -m app.jobs.backfill_historique --date-debut 2026-01-01 --date-fin 2026-03-31 --hippodrome Vincennes
"""

import argparse
import logging
from datetime import date, timedelta
from typing import List, Optional

from app.data import open_pmu_client
from app.data.pmu_client import _normalize_name
from app.data.repository import Repository

logger = logging.getLogger(__name__)


def backfill_plage(
    repository: Repository,
    date_debut: date,
    date_fin: date,
    cheval: Optional[str] = None,
    hippodrome: Optional[str] = None,
) -> None:
    cheval_normalise = _normalize_name(cheval) if cheval else None
    jour = date_debut
    total_ajoutees = 0
    total_doublons = 0

    while jour <= date_fin:
        try:
            arrivees = open_pmu_client.get_arrivees(target_date=jour, hippodrome=hippodrome)
        except Exception:
            logger.exception("Echec de récupération open-pmu-api pour le %s", jour)
            jour += timedelta(days=1)
            continue

        ajoutees_ce_jour = 0
        doublons_ce_jour = 0
        for arrivee in arrivees:
            for cheval_arrivee in arrivee.chevaux:
                if cheval_normalise is not None and _normalize_name(cheval_arrivee.nom) != cheval_normalise:
                    continue
                ajoutee = repository.ajouter_performance_historique_backfill(
                    nom_cheval=cheval_arrivee.nom,
                    date_course=jour,
                    hippodrome=arrivee.hippodrome,
                    discipline=arrivee.discipline,
                    allocation=arrivee.allocation,
                    distance=arrivee.distance,
                    nb_participants=arrivee.nb_partants,
                    rang=cheval_arrivee.rang,
                    incident=cheval_arrivee.incident,
                )
                if ajoutee:
                    ajoutees_ce_jour += 1
                else:
                    doublons_ce_jour += 1

        total_ajoutees += ajoutees_ce_jour
        total_doublons += doublons_ce_jour
        logger.info(
            "%s : %d réunion(s)/course(s) — %d ligne(s) ajoutée(s), %d doublon(s) ignoré(s) (cumul : %d ajoutées)",
            jour, len(arrivees), ajoutees_ce_jour, doublons_ce_jour, total_ajoutees,
        )
        jour += timedelta(days=1)

    logger.info(
        "Backfill terminé (%s → %s) : %d ligne(s) ajoutée(s) au total, %d doublon(s) ignoré(s)",
        date_debut, date_fin, total_ajoutees, total_doublons,
    )


def backfill_cheval_par_hippodromes_connus(
    repository: Repository,
    nom_cheval: str,
    hippodromes: List[str],
) -> int:
    """Backfill ciblé pour UN cheval, utilisé par POST /chevaux/{id}/backfill
    (endpoint appelé depuis la fiche cheval de l'app mobile — bouton "Voir
    tout l'historique", section 7.4 du document mobile). Interroge une fois
    par hippodrome déjà connu de ce cheval plutôt que de scanner des mois de
    dates un par un (?hippo=X seul renvoie tout l'historique de cet
    hippodrome depuis 2004 en un seul appel — vérifié manuellement). Retourne
    le nombre de lignes effectivement ajoutées."""
    cheval_normalise = _normalize_name(nom_cheval)
    total_ajoutees = 0

    for hippodrome in hippodromes:
        try:
            arrivees = open_pmu_client.get_arrivees(hippodrome=hippodrome)
        except Exception:
            logger.exception("Echec backfill par hippodrome pour %s / hippodrome=%s", nom_cheval, hippodrome)
            continue

        for arrivee in arrivees:
            for cheval_arrivee in arrivee.chevaux:
                if _normalize_name(cheval_arrivee.nom) != cheval_normalise:
                    continue
                ajoutee = repository.ajouter_performance_historique_backfill(
                    nom_cheval=cheval_arrivee.nom,
                    date_course=arrivee.date,
                    hippodrome=arrivee.hippodrome,
                    discipline=arrivee.discipline,
                    allocation=arrivee.allocation,
                    distance=arrivee.distance,
                    nb_participants=arrivee.nb_partants,
                    rang=cheval_arrivee.rang,
                    incident=cheval_arrivee.incident,
                )
                if ajoutee:
                    total_ajoutees += 1

    return total_ajoutees


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    parser = argparse.ArgumentParser(
        description="Backfill de l'historique profond (open-pmu-api), hors flux d'ingestion quotidien"
    )
    parser.add_argument("--date-debut", required=True, type=date.fromisoformat)
    parser.add_argument("--date-fin", required=True, type=date.fromisoformat)
    parser.add_argument("--cheval", default=None, help="Nom du cheval ciblé (sinon : tous les chevaux trouvés sur la période)")
    parser.add_argument("--hippodrome", default=None, help="Filtrer par hippodrome (optionnel)")
    args = parser.parse_args()

    if args.date_fin < args.date_debut:
        parser.error("--date-fin doit être postérieure ou égale à --date-debut")

    repository = Repository()
    backfill_plage(repository, args.date_debut, args.date_fin, cheval=args.cheval, hippodrome=args.hippodrome)


if __name__ == "__main__":
    main()
