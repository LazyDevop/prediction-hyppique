"""Réception des pronostics calculés dans l'app mobile, pour les évaluer
comme ceux du moteur automatique (tableau de bord, variante "app")."""

from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.data.repository import Repository
from app.engine.constants import terrain_coefficient
from app.engine.scoring import HorseAnalysis

router = APIRouter()
repository = Repository()

# Écart toléré entre le terrain envoyé et la mesure : les coefficients sont
# des flottants, et le plus petit écart entre deux niveaux vaut 0.01.
TOLERANCE_TERRAIN = 0.005


def maintenant() -> datetime:
    return datetime.now()


class ChevalPronostiqueIn(BaseModel):
    num_pmu: int
    probabilite: float = Field(ge=0.0, le=1.0)
    cote: Optional[float] = None
    top2: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    top3: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    top4: Optional[float] = Field(default=None, ge=0.0, le=1.0)
    value: Optional[float] = None
    mise: Optional[float] = None


class PronosticAppIn(BaseModel):
    course_id: int
    installation_id: str = Field(min_length=8, max_length=64)
    chevaux: List[ChevalPronostiqueIn] = Field(min_length=1)
    parametres: dict = {}
    reglages_par_defaut: bool
    donnees_modifiees: bool
    terrain: Optional[float] = None
    # Combinaisons affichées par l'app, en dossards, par type de pari.
    combinaisons: Optional[dict] = None


@router.post("/pronostics", status_code=201)
def enregistrer_pronostic(pronostic: PronosticAppIn):
    course = repository.get_course_by_id(pronostic.course_id)
    if course is None:
        raise HTTPException(status_code=404, detail="Course introuvable")
    # Horodaté par le serveur, jamais par le téléphone : un pronostic reçu
    # après le départ ne peut pas compter comme un pronostic.
    instant = maintenant()
    if course.heure_depart is not None and instant > course.heure_depart:
        raise HTTPException(status_code=409, detail="Course déjà partie : pronostic non enregistré")

    mesure = terrain_coefficient(course.terrain)
    terrain_modifie = (
        pronostic.terrain is not None and mesure is not None and abs(pronostic.terrain - mesure) > TOLERANCE_TERRAIN
    ) or (pronostic.terrain is not None and mesure is None)

    run_id = repository.save_prediction_run(
        course.id,
        [
            HorseAnalysis(nom="", num_pmu=c.num_pmu, probabilite=c.probabilite, cote=c.cote,
                          top2=c.top2, top3=c.top3, top4=c.top4, value=c.value, mise=c.mise)
            for c in pronostic.chevaux
        ],
        "app",
        instant,
        [],
        installation_id=pronostic.installation_id,
        donnees_modifiees=pronostic.donnees_modifiees,
        reglages_par_defaut=pronostic.reglages_par_defaut,
        terrain_modifie=terrain_modifie,
        parametres=pronostic.parametres,
        combinaisons=pronostic.combinaisons,
    )
    return {"id": run_id}
