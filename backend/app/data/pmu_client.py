import time
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional

import requests

BASE_URL = "https://offline.turfinfo.api.pmu.fr/rest/client/61/programme"
HEADERS = {
    "User-Agent": "prediction-hippique-backend/1.0 (personal project; contact: rogerbertrand360@gmail.com)"
}
REQUEST_DELAY_SECONDS = 1.0

DISCIPLINE_MAP = {
    "ATTELE": "trot",
    "MONTE": "trot",
    "PLAT": "plat",
    "HAIE": "obstacle",
    "STEEPLECHASE": "obstacle",
    "CROSS": "obstacle",
}

# DISQUALIFIE is the only statusArrivee value confirmed to represent a real
# incident (section 4.3 of the cahier des charges). NON_PLACE only means the
# horse finished outside the ~5-6 displayed positions - not an incident.
STATUS_TO_INCIDENT = {
    "DISQUALIFIE": "D",
}


def _get(endpoint: str) -> Any:
    response = requests.get(endpoint, headers=HEADERS, timeout=15)
    response.raise_for_status()
    time.sleep(REQUEST_DELAY_SECONDS)
    return response.json()


def _normalize_name(name: str) -> str:
    return " ".join(name.strip().upper().split())


def _epoch_ms_to_date(value: Optional[int]) -> Optional[date]:
    if value is None:
        return None
    return datetime.fromtimestamp(value / 1000).date()


def _epoch_ms_to_datetime(value: Optional[int]) -> Optional[datetime]:
    if value is None:
        return None
    return datetime.fromtimestamp(value / 1000)


@dataclass
class CourseInfo:
    date: date
    numero_reunion: int
    numero_course: int
    hippodrome: str
    pays: Optional[str]
    libelle: str
    discipline: str
    discipline_brute: str
    distance: Optional[float]
    allocation: Optional[float]
    corde: Optional[str]
    nb_partants_declares: Optional[int]
    arrivee_definitive: bool
    heure_depart: Optional[datetime]


@dataclass
class PartantInfo:
    num_pmu: int
    nom: str
    age: Optional[int]
    sexe: Optional[str]
    statut: Optional[str]
    driver_jockey: Optional[str]
    entraineur: Optional[str]
    musique: Optional[str]
    nombre_courses: int
    inedit: bool
    handicap_poids: Optional[float]
    cote_reference: Optional[float]
    cote_direct: Optional[float]
    ordre_arrivee: Optional[int]
    incident: Optional[str]
    raw: Dict[str, Any] = field(default_factory=dict)


@dataclass
class PerformancePassee:
    date: Optional[date]
    hippodrome: Optional[str]
    discipline: Optional[str]
    allocation: Optional[float]
    distance: Optional[float]
    nb_participants: Optional[int]
    rang: Optional[int]
    incident: Optional[str]


def get_programme(target_date: date, pays_filter: Optional[str] = "FRA") -> List[CourseInfo]:
    endpoint = f"{BASE_URL}/{target_date.strftime('%d%m%Y')}"
    data = _get(endpoint)
    reunions = data.get("programme", {}).get("reunions", [])

    courses: List[CourseInfo] = []
    for reunion in reunions:
        pays = (reunion.get("pays") or {}).get("code")
        if pays_filter is not None and pays != pays_filter:
            continue
        hippodrome = (reunion.get("hippodrome") or {}).get("libelleCourt", "")
        numero_reunion = reunion.get("numOfficiel")
        for course in reunion.get("courses", []):
            discipline_brute = course.get("discipline", "")
            courses.append(CourseInfo(
                date=target_date,
                numero_reunion=numero_reunion,
                numero_course=course.get("numOrdre"),
                hippodrome=hippodrome,
                pays=pays,
                libelle=course.get("libelleCourt") or course.get("libelle") or "",
                discipline=DISCIPLINE_MAP.get(discipline_brute, discipline_brute.lower()),
                discipline_brute=discipline_brute,
                distance=course.get("distance"),
                allocation=course.get("montantPrix"),
                corde=course.get("corde"),
                nb_partants_declares=course.get("nombreDeclaresPartants"),
                arrivee_definitive=bool(course.get("arriveeDefinitive")),
                heure_depart=_epoch_ms_to_datetime(course.get("heureDepart")),
            ))
    return courses


def get_participants(target_date: date, reunion: int, course: int) -> List[PartantInfo]:
    endpoint = f"{BASE_URL}/{target_date.strftime('%d%m%Y')}/R{reunion}/C{course}/participants"
    data = _get(endpoint)

    partants: List[PartantInfo] = []
    for cheval in data.get("participants", []):
        cote_ref = (cheval.get("dernierRapportReference") or {}).get("rapport")
        cote_direct = (cheval.get("dernierRapportDirect") or {}).get("rapport")
        handicap_poids_brut = cheval.get("handicapPoids")
        # handicapPoids est exprimé en dixièmes de kg (ex. 575 = 57.5 kg).
        handicap_poids = handicap_poids_brut / 10.0 if handicap_poids_brut is not None else None
        partants.append(PartantInfo(
            num_pmu=cheval.get("numPmu"),
            nom=cheval.get("nom", ""),
            age=cheval.get("age"),
            sexe=cheval.get("sexe"),
            statut=cheval.get("statut"),
            driver_jockey=cheval.get("driver") or cheval.get("jockey"),
            entraineur=cheval.get("entraineur"),
            musique=cheval.get("musique"),
            nombre_courses=cheval.get("nombreCourses", 0) or 0,
            inedit=bool(cheval.get("indicateurInedit")),
            handicap_poids=handicap_poids,
            cote_reference=cote_ref,
            cote_direct=cote_direct,
            ordre_arrivee=cheval.get("ordreArrivee"),
            incident=cheval.get("incident"),
            raw=cheval,
        ))
    return partants


def get_historique(target_date: date, reunion: int, course: int) -> Dict[int, List[PerformancePassee]]:
    endpoint = f"{BASE_URL}/{target_date.strftime('%d%m%Y')}/R{reunion}/C{course}/performances-detaillees/pretty"
    data = _get(endpoint)

    results: Dict[int, List[PerformancePassee]] = {}
    for cheval in data.get("participants", []):
        num_pmu = cheval.get("numPmu")
        performances: List[PerformancePassee] = []
        for course_passee in cheval.get("coursesCourues", []):
            propre_ligne = next(
                (p for p in course_passee.get("participants", []) if p.get("itsHim")),
                None,
            )
            place_info = (propre_ligne or {}).get("place", {}) or {}
            status_arrivee = place_info.get("statusArrivee")
            discipline_brute = course_passee.get("discipline", "")
            performances.append(PerformancePassee(
                date=_epoch_ms_to_date(course_passee.get("date")),
                hippodrome=course_passee.get("hippodrome"),
                discipline=DISCIPLINE_MAP.get(discipline_brute, discipline_brute.lower() or None),
                allocation=course_passee.get("allocation"),
                distance=course_passee.get("distance"),
                nb_participants=course_passee.get("nbParticipants"),
                rang=place_info.get("place"),
                incident=STATUS_TO_INCIDENT.get(status_arrivee),
            ))
        if num_pmu is not None:
            results[num_pmu] = performances
    return results
