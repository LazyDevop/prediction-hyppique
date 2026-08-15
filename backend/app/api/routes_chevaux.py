import logging
from datetime import date
from typing import List

from fastapi import APIRouter, HTTPException

from app.data.repository import Repository
from app.jobs.backfill_historique import backfill_cheval_par_hippodromes_connus
from app.schemas.course import PerformanceHistoriqueOut

logger = logging.getLogger(__name__)

router = APIRouter()
repository = Repository()


@router.post("/chevaux/{cheval_id}/backfill", response_model=List[PerformanceHistoriqueOut])
def backfill_cheval(cheval_id: int):
    """Bouton "Voir tout l'historique" de la fiche cheval (section 7.4 du
    document mobile) : complète l'historique de CE cheval via open-pmu-api
    et renvoie l'intégralité (en lecture seule côté client — ne remplace pas
    les 6 lignes utilisées par le moteur). Un échec réseau vers open-pmu-api
    ne fait pas échouer la requête : on renvoie ce qui est déjà en base
    plutôt qu'une erreur, l'enrichissement est un bonus, pas une condition
    de disponibilité de la fiche."""
    cheval = repository.get_cheval_by_id(cheval_id)
    if cheval is None:
        raise HTTPException(status_code=404, detail="Cheval introuvable")

    hippodromes = repository.get_hippodromes_connus(cheval_id)
    if hippodromes:
        try:
            backfill_cheval_par_hippodromes_connus(repository, cheval.nom_normalise, hippodromes)
            cheval = repository.get_cheval_by_id(cheval_id)
        except Exception:
            logger.exception("Echec backfill pour le cheval %s", cheval_id)

    perfs_triees = sorted(
        cheval.performances_historiques,
        key=lambda p: p.date_course or date.min,
        reverse=True,
    )
    return [
        PerformanceHistoriqueOut(
            date_course=p.date_course,
            hippodrome=p.hippodrome,
            discipline=p.discipline,
            allocation=p.allocation,
            distance=p.distance,
            nb_participants=p.nb_participants,
            rang=p.rang,
            terrain=p.terrain,
            incident=p.incident,
        )
        for p in perfs_triees
    ]
