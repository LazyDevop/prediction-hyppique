from typing import Dict, List, Literal, Optional

from pydantic import BaseModel


class PerformanceIn(BaseModel):
    partants: int
    rang: Optional[int] = None
    distance: Optional[float] = None
    terrain: Optional[float] = None
    niveau: Optional[float] = None
    incident: Optional[str] = None


class HorseIn(BaseModel):
    nom: str
    num_pmu: Optional[int] = None
    age: Optional[int] = None
    poids: Optional[float] = None
    cote: Optional[float] = None
    inedit: bool = False
    performances: List[PerformanceIn] = []


class AnalyseIn(BaseModel):
    course_id: Optional[int] = None
    chevaux: Optional[List[HorseIn]] = None
    distance: Optional[float] = None
    terrain: Optional[float] = None
    niveau: Optional[float] = None
    nb_partants_course: Optional[int] = None
    params: Optional[Dict[str, float]] = None
    mode_recence: Literal["std", "forme", "flat"] = "std"


class HorseOut(BaseModel):
    nom: str
    num_pmu: Optional[int] = None
    age: Optional[int] = None
    poids: Optional[float] = None
    cote: Optional[float] = None
    inedit: bool = False
    score: float
    probabilite: float
    top1: float
    top2: float
    top3: float
    top4: float
    value: Optional[float] = None
    kelly: Optional[float] = None
    mise: Optional[float] = None


class ComboItem(BaseModel):
    dossards: List[Optional[int]]
    noms: List[str]
    probabilite: float


class ComboOrdreDesordre(BaseModel):
    ordre: List[ComboItem]
    desordre: List[ComboItem]


class Combinaisons(BaseModel):
    couple: ComboOrdreDesordre
    trio: ComboOrdreDesordre
    quarte: ComboOrdreDesordre
    quinte: ComboOrdreDesordre
    couple_place: List[ComboItem]
    deux_sur_quatre: List[ComboItem]


class AnalyseOut(BaseModel):
    resultats: List[Dict]
    combinaisons: Combinaisons
