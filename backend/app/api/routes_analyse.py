from typing import Any, Callable, Optional, Type, TypeVar

from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel, ValidationError

from app.engine.combinatoire import build_combinaisons
from app.engine.scoring import CourseTarget, HorseAnalysis, Performance, analyse_course
from app.data import vision_client
from app.data.repository import Repository
from app.schemas.analyse import AnalyseIn, AnalyseOut, HorseIn, HorseOut
from app.schemas.extraction import FicheExtraiteOut, ProgrammeExtraitOut

router = APIRouter()
repository = Repository()

# Types acceptés pour /extraction/fiche et /extraction/programme, validés
# AVANT tout appel à vision_client — un type non supporté ne doit jamais
# consommer de budget vision (Story 4.2, ferme l'item "media_type never
# validated" logué dans deferred-work.md par la review de la Story 4.1).
ACCEPTED_EXTRACTION_CONTENT_TYPES = {
    "image/png",
    "image/jpeg",
    "image/webp",
    "image/gif",
    "application/pdf",
}

# Mitigation simple contre l'épuisement mémoire d'un upload volumineux avant
# même que le garde-fou de budget de vision_client ne s'applique (revue de
# code, Story 4.2) — ne remplace pas un vrai streaming/limite au niveau
# serveur, juste un plafond raisonnable pour une fiche/programme scanné(e).
MAX_EXTRACTION_FILE_SIZE_BYTES = 20 * 1024 * 1024  # 20 Mo

_SchemaT = TypeVar("_SchemaT", bound=BaseModel)


def _validate_extraction_content_type(content_type: Optional[str]) -> None:
    # Insensible à la casse et aux paramètres de type ("image/png;
    # charset=binary") - un client/proxy qui normalise différemment le
    # header ne doit pas se voir rejeter un type par ailleurs supporté
    # (revue de code, Story 4.2).
    normalise = (content_type or "").split(";")[0].strip().lower()
    if normalise not in ACCEPTED_EXTRACTION_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Type de fichier non supporté")


async def _run_extraction(
    file: UploadFile,
    extract_fn: Callable[[bytes, Optional[str]], Any],
    schema: Type[_SchemaT],
) -> _SchemaT:
    """Chemin commun aux deux endpoints d'extraction (Story 4.2, revue de
    code : évite la duplication du try/except entre les deux routes et leur
    garantit un comportement identique). Le mapping vers une erreur HTTP se
    termine ici, pas dans les fonctions de route : une réponse mal formée
    par vision_client (ValidationError sur le schema) est traitée comme un
    échec d'extraction (502), jamais comme une 500 brute non documentée."""
    _validate_extraction_content_type(file.content_type)
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Fichier vide")
    if len(file_bytes) > MAX_EXTRACTION_FILE_SIZE_BYTES:
        raise HTTPException(status_code=413, detail="Fichier trop volumineux")

    try:
        extrait = extract_fn(file_bytes, file.content_type)
        return schema.model_validate(extrait)
    except vision_client.VisionBudgetExceeded:
        raise HTTPException(status_code=429, detail="Budget quotidien d'extraction vision épuisé")
    except (vision_client.VisionExtractionError, ValidationError):
        raise HTTPException(status_code=502, detail="Échec de l'extraction vision")


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
    params = request.params.model_dump(exclude_none=True) if request.params is not None else None
    results = analyse_course(horses, target, params, mode_recence=request.mode_recence)
    combinaisons = build_combinaisons(results, len(horses))
    # analyse_course renvoie les chevaux reels PUIS des outsiders virtuels
    # (num_pmu=None) qui ne comptent que pour le calcul de probabilites/
    # Harville, jamais pour l'affichage (cahier des charges 7.8) : ne pas les
    # exposer dans la reponse API, sous peine de faire apparaitre de faux
    # chevaux dans le client.
    resultats = [
        HorseOut.model_validate(horse)
        for horse in results
        if horse.num_pmu is not None
    ]
    return AnalyseOut(resultats=resultats, combinaisons=combinaisons)

@router.post("/extraction/fiche", response_model=FicheExtraiteOut)
async def extraction_fiche(file: UploadFile = File(...)):
    return await _run_extraction(file, vision_client.extract_fiche_cheval, FicheExtraiteOut)

@router.post("/extraction/programme", response_model=ProgrammeExtraitOut)
async def extraction_programme(file: UploadFile = File(...)):
    return await _run_extraction(file, vision_client.extract_programme, ProgrammeExtraitOut)
