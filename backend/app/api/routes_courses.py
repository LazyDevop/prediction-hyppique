import logging
from datetime import date
from typing import List, Optional

from fastapi import APIRouter, HTTPException, Query

from app.schemas.course import CourseOut, ParticipationOut, PerformanceHistoriqueOut
from app.data import pmu_client
from app.data.repository import Repository
from app.data.models import Course

logger = logging.getLogger(__name__)

router = APIRouter()
repository = Repository()

@router.get("/courses", response_model=List[CourseOut])
def list_courses(date: Optional[date] = Query(None)):
    if date is None:
        raise HTTPException(status_code=400, detail="Le paramètre date est requis")
    courses = repository.list_courses_for_date(date)
    return [CourseOut.model_validate(course) for course in courses]

def _completer_historique_manquant(course: Course) -> Course:
    """Auto-guérison : si un partant non inédit n'a aucune performance passée
    en base (souvent un échec réseau transitoire pendant l'ingestion), on
    retente la récupération PMU à la demande plutôt que de le traiter en
    silence comme "données non saisies"."""
    manque_historique = any(
        not part.inedit and not part.cheval.performances_historiques
        for part in course.participations
    )
    if not manque_historique or course.numero_reunion is None or course.numero_course is None:
        return course

    try:
        historique = pmu_client.get_historique(course.date, course.numero_reunion, course.numero_course)
        repository.save_historique(course.id, historique)
        return repository.get_course_by_id(course.id)
    except Exception:
        logger.exception("Echec de la récupération à la demande de l'historique (course %s)", course.id)
        return course


@router.get("/courses/{course_id}/partants", response_model=List[ParticipationOut])
def get_partants(course_id: int):
    course = repository.get_course_by_id(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course introuvable")
    course = _completer_historique_manquant(course)
    return [
        ParticipationOut(
            id=part.id,
            course_id=part.course_id,
            cheval_id=part.cheval_id,
            nom=part.cheval.nom_normalise,
            num_pmu=part.num_pmu,
            age_a_la_course=part.age_a_la_course,
            poids=part.poids,
            cote_reference=part.cote_reference,
            cote_direct=part.cote_direct,
            rang_arrivee=part.rang_arrivee,
            incident=part.incident,
            inedit=part.inedit,
            driver=part.driver,
            entraineur=part.entraineur,
            performances=[
                PerformanceHistoriqueOut(
                    date_course=perf.date_course,
                    hippodrome=perf.hippodrome,
                    discipline=perf.discipline,
                    allocation=perf.allocation,
                    distance=perf.distance,
                    nb_participants=perf.nb_participants,
                    rang=perf.rang,
                    terrain=perf.terrain,
                    incident=perf.incident,
                )
                # Les plus récentes d'abord (C1..) : mêmes conventions que le
                # moteur (section 7.3) - voir repository.get_horses_for_course.
                for perf in sorted(
                    part.cheval.performances_historiques,
                    key=lambda p: p.date_course or date.min,
                    reverse=True,
                )
            ],
        )
        for part in course.participations
    ]

@router.post("/courses/{course_id}/importer")
def importer_course(course_id: int):
    course = repository.get_course_by_id(course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course introuvable")
    repository.import_course(course_id)
    return {"status": "ok", "course_id": course_id}
