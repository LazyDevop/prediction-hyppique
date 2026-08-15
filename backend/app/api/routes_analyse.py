from fastapi import APIRouter, HTTPException

from app.engine.combinatoire import build_combinaisons
from app.engine.scoring import CourseTarget, HorseAnalysis, Performance, analyse_course
from app.data.repository import Repository
from app.schemas.analyse import AnalyseIn, AnalyseOut, HorseIn

router = APIRouter()
repository = Repository()


def _build_horse_analysis(horse_in: HorseIn) -> HorseAnalysis:
    return HorseAnalysis(
        nom=horse_in.nom,
        num_pmu=horse_in.num_pmu,
        age=horse_in.age,
        poids=horse_in.poids,
        cote=horse_in.cote,
        inedit=horse_in.inedit,
        performances=[Performance(**perf.model_dump()) for perf in horse_in.performances],
    )


@router.post("/analyse", response_model=AnalyseOut)
def analyse(request: AnalyseIn):
    if request.course_id is not None:
        course = repository.get_course_by_id(request.course_id)
        if course is None:
            raise HTTPException(status_code=404, detail="Course introuvable")
        horses = repository.get_horses_for_course(course)
        target = CourseTarget(
            distance=course.distance,
            terrain=None,
            niveau=None,
            nb_partants_course=course.nb_partants or len(horses),
        )
    else:
        if not request.chevaux:
            raise HTTPException(status_code=400, detail="Aucun cheval fourni")
        horses = [_build_horse_analysis(cheval) for cheval in request.chevaux]
        target = CourseTarget(
            distance=request.distance,
            terrain=request.terrain,
            niveau=request.niveau,
            nb_partants_course=request.nb_partants_course or len(horses),
        )
    results = analyse_course(horses, target, request.params, mode_recence=request.mode_recence)
    combinaisons = build_combinaisons(results, len(horses))
    return AnalyseOut(resultats=[horse.__dict__ for horse in results], combinaisons=combinaisons)

@router.post("/extraction/fiche")
def extraction_fiche(image: bytes):
    raise HTTPException(status_code=501, detail="Non implémenté")

@router.post("/extraction/programme")
def extraction_programme(image: bytes):
    raise HTTPException(status_code=501, detail="Non implémenté")
