from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.engine.constants import DEFAULT_PARAMETERS


class EngineParamsIn(BaseModel):
    """Mirrors DEFAULT_PARAMETERS's keys/types (backend/app/engine/constants.py)
    so a mistyped key is rejected at the API boundary instead of being
    silently dropped by analyse_course's dict-merge. Bounds are traced to
    real engine failure modes in analyse_course/compute_note (Story 1.4,
    tightened during code review) — do not add bounds beyond these without
    a new story.

    Code review note: a partial override supplying only age_min (or only
    age_max) still gets merged over DEFAULT_PARAMETERS downstream in
    routes_analyse.py -- so age validity must be checked against the
    EFFECTIVE post-merge values, not just the two fields as submitted,
    or an inverted range slips through via a single-field override (the
    exact bug class this story exists to close)."""

    model_config = ConfigDict(extra="forbid")

    malus_incident: Optional[float] = Field(default=None, ge=0)
    sensibilite_poids: Optional[float] = Field(default=None, ge=0)
    age_min: Optional[int] = Field(default=None, ge=0)
    age_max: Optional[int] = Field(default=None, ge=0)
    shrink: Optional[float] = Field(default=None, ge=0)
    coef_inedit: Optional[float] = Field(default=None, ge=0)
    # gt=0 alone still allows an exponent large enough to overflow
    # score**contraste in scoring.py's Plackett-Luce step -- le=50 is well
    # above any sensible contraste (default 3) while staying far under the
    # float overflow threshold even for an unusually high score.
    contraste: Optional[float] = Field(default=None, gt=0, le=50)
    bankroll: Optional[float] = Field(default=None, ge=0)
    fraction_kelly: Optional[float] = Field(default=None, ge=0, le=1)

    @model_validator(mode="after")
    def _check_age_bounds(self) -> "EngineParamsIn":
        age_min = self.age_min if self.age_min is not None else DEFAULT_PARAMETERS["age_min"]
        age_max = self.age_max if self.age_max is not None else DEFAULT_PARAMETERS["age_max"]
        if age_min > age_max:
            raise ValueError(
                "age_min ne peut pas etre superieur a age_max (valeurs effectives "
                f"apres defauts : age_min={age_min}, age_max={age_max})"
            )
        return self


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
    params: Optional[EngineParamsIn] = None
    mode_recence: Literal["std", "forme", "flat"] = "std"


class HorseOut(BaseModel):
    # from_attributes on the model itself, not just at one call site — a
    # future second caller building a HorseOut from an object (rather than a
    # dict) shouldn't have to remember to repeat the flag (code review,
    # Story 1.3).
    model_config = ConfigDict(from_attributes=True)

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
    resultats: List[HorseOut]
    combinaisons: Combinaisons
