from datetime import date, datetime, timezone
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, computed_field, field_validator


class CourseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    date: date
    heure_depart: Optional[datetime]
    hippodrome: str
    discipline: str
    distance: Optional[float]
    allocation: Optional[float]
    nb_partants: Optional[int]
    corde: Optional[str]
    terrain: Optional[str]
    niveau_estime: Optional[str]
    finalisee: bool
    source: str
    # Référence PMU (AD-12) : ajout additif, null pour une course sans
    # numéros (saisie manuelle, import photo).
    numero_reunion: Optional[int] = None
    numero_course: Optional[int] = None

    @computed_field
    @property
    def cle_course(self) -> Optional[str]:
        """Clé PMU `AAAAMMJJ-Rn-Cn` (AD-12), seul nom d'une course entre
        systèmes ; null si un des deux numéros manque ou est < 1."""
        if not self.numero_reunion or not self.numero_course or self.numero_reunion < 1 or self.numero_course < 1:
            return None
        return f"{self.date:%Y%m%d}-R{self.numero_reunion}-C{self.numero_course}"

    @field_validator("heure_depart")
    @classmethod
    def _marquer_utc(cls, v: Optional[datetime]) -> Optional[datetime]:
        # Stocké naïf en base mais toujours en UTC (le conteneur backend
        # tourne en UTC) : le marquer explicitement pour que le client
        # convertisse correctement vers son fuseau local.
        if v is not None and v.tzinfo is None:
            return v.replace(tzinfo=timezone.utc)
        return v


class PerformanceHistoriqueOut(BaseModel):
    date_course: Optional[date]
    hippodrome: Optional[str]
    discipline: Optional[str]
    allocation: Optional[float]
    distance: Optional[float]
    nb_participants: Optional[int]
    rang: Optional[int]
    rang_impute: bool = False
    terrain: Optional[str]
    incident: Optional[str]


class ParticipationOut(BaseModel):
    id: int
    course_id: int
    cheval_id: int
    nom: str
    num_pmu: Optional[int]
    age_a_la_course: Optional[int]
    poids: Optional[float]
    cote_reference: Optional[float]
    cote_direct: Optional[float]
    rang_arrivee: Optional[int]
    incident: Optional[str]
    inedit: bool
    driver: Optional[str]
    entraineur: Optional[str]
    performances: List[PerformanceHistoriqueOut]
