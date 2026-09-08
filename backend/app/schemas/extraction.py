"""Schemas typés pour les réponses des endpoints /extraction/fiche et
/extraction/programme (Story 4.2). Miroir champ pour champ des dataclasses
de app.data.vision_client (FicheChevalExtraite/ProgrammeExtrait et leurs
imbriquées) — jamais un dict brut ou un dataclass passthrough (AD-4),
construit via .model_validate() sur l'objet renvoyé par vision_client
(cf. HorseOut dans app/schemas/analyse.py, même pattern)."""

from typing import List, Optional

from pydantic import BaseModel, ConfigDict


class PerfFicheOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    rank: Optional[int] = None
    part: Optional[int] = None
    incident: str
    niveau: Optional[float] = None
    dist: Optional[float] = None
    terr: Optional[float] = None


class FicheExtraiteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    name: Optional[str] = None
    num: Optional[int] = None
    age: Optional[int] = None
    poids: Optional[float] = None
    cote: Optional[float] = None
    perfs: List[PerfFicheOut] = []


class PerfProgrammeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    rank: Optional[int] = None
    incident: str


class HorseProgrammeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    num: Optional[int] = None
    name: Optional[str] = None
    age: Optional[int] = None
    poids: Optional[float] = None
    cote: Optional[float] = None
    perfs: List[PerfProgrammeOut] = []


class ProgrammeExtraitOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    hippo: Optional[str] = None
    dist: Optional[float] = None
    terr: Optional[float] = None
    niveau: Optional[float] = None
    partants: Optional[int] = None
    horses: List[HorseProgrammeOut] = []
