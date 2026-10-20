import logging
from datetime import date
from typing import List

from fastapi import APIRouter, HTTPException

from app.data import pmu_client
from app.data.repository import Repository
from app.schemas.course import PerformanceHistoriqueOut

logger = logging.getLogger(__name__)

router = APIRouter()
repository = Repository()


@router.post("/chevaux/{cheval_id}/backfill", response_model=List[PerformanceHistoriqueOut])
def backfill_cheval(cheval_id: int):
    """Bouton "Voir tout l'historique" de la fiche cheval (section 7.4 du
    document mobile) : rafraîchit l'historique de CE cheval depuis PMU
    turfinfo (performances-detaillees de sa dernière participation connue,
    jusqu'à 10 courses passées, source "pmu", NON_PLACE imputés) et renvoie
    l'intégralité de ce qui est en base, du plus récent au plus ancien.
    performances-detaillees couvre toute la course : l'historique des autres
    partants connus de cette course est rafraîchi au passage (même upsert
    "pmu" que l'ingestion quotidienne).
    open-pmu-api n'est plus interrogé : il ne couvre que le Quinté+ et ses
    premiers arrivés, et biaisait l'historique vers les bonnes courses.
    Un échec réseau ou API ne fait pas échouer la requête : on renvoie ce qui
    est déjà en base, le rafraîchissement est un bonus, pas une condition de
    disponibilité de la fiche."""
    cheval = repository.get_cheval_by_id(cheval_id)
    if cheval is None:
        raise HTTPException(status_code=404, detail="Cheval introuvable")

    course = repository.derniere_participation(cheval_id)
    if course is not None:
        try:
            historique = pmu_client.get_historique(course.date, course.numero_reunion, course.numero_course)
            repository.save_historique(course.id, historique)
            cheval = repository.get_cheval_by_id(cheval_id) or cheval
        except Exception:
            logger.exception("Echec du rafraichissement de l'historique du cheval %s", cheval_id)

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
            rang_impute=p.rang_impute,
            terrain=p.terrain,
            incident=p.incident,
        )
        for p in perfs_triees
    ]
