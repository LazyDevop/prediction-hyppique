import logging
import time
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional

import requests

from app.engine.constants import TERRAIN_COEFFICIENTS_GRASS, TERRAIN_COEFFICIENTS_PSF

logger = logging.getLogger(__name__)

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

# statusArrivee -> engine incident code (INCIDENTS in engine/constants.py),
# from a survey of 6,014 real arrivals. PLACE and NON_PLACE are not
# incidents: NON_PLACE only means the horse finished outside the displayed
# positions. A distanced horse is eliminated from the result, hence "D".
STATUS_TO_INCIDENT = {
    "DISQUALIFIE": "D",
    "DISQUALIFIE_POUR_ALLURE_IRREGULIERE": "D",
    "DISQUALIFIE_POTEAU_GALOP": "D",
    "DISTANCE": "D",
    "ARRETE": "A",
    "TOMBE": "T",
}
# TOMBE covers two raw codes: TB (horse fell) and TJ (jockey fell, seen even
# on the flat), which the engine scores as unseated.
RAW_VALUE_TO_INCIDENT = {
    "TJ": "U",
}
STATUTS_SANS_INCIDENT = {"PLACE", "NON_PLACE"}


# etatTerrain arrive en libellé texte, alors que le moteur indexe ses
# coefficients sur ses propres clés : le gazon correspond tel quel, la piste en
# sable fibré est préfixée "PSF" et accordée au féminin ("PSF Lente").
_TERRAIN_PAR_LIBELLE = {label.casefold(): label for label in TERRAIN_COEFFICIENTS_GRASS}
_TERRAIN_PAR_LIBELLE.update({f"psf {label}".casefold(): label for label in TERRAIN_COEFFICIENTS_PSF})
_TERRAIN_PAR_LIBELLE["psf lente"] = "Lent"
# La veille, une PSF est annoncée "PSF" sans état : mesure à venir, pas un
# libellé inconnu.
_PSF_SANS_ETAT = "psf"


def normaliser_terrain(libelle: Optional[str]) -> Optional[str]:
    if not libelle or not libelle.strip():
        return None
    cle = " ".join(libelle.split()).casefold()
    if cle == _PSF_SANS_ETAT:
        return None
    terrain = _TERRAIN_PAR_LIBELLE.get(cle)
    if terrain is None:
        # Jamais de valeur par défaut : un terrain deviné fausserait le
        # coefficient, alors qu'un terrain absent le laisse neutre.
        logger.warning("etatTerrain non reconnu : %r", libelle)
    return terrain


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
    terrain: Optional[str] = None


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
    terrain: Optional[str] = None
    rang_impute: bool = False


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
                terrain=normaliser_terrain((course.get("penetrometre") or {}).get("intitule")),
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


def _rang_impute_non_place(course_passee: Dict[str, Any]) -> Optional[int]:
    """NON_PLACE sans rang : le cheval a fini après la dernière place
    affichée, à une position inconnue. Le noter 0 l'assimilait à un dernier ;
    on retient le milieu de la zone non placée, arrondi vers le haut (côté
    prudent)."""
    nb_participants = course_passee.get("nbParticipants")
    if not nb_participants:
        return None
    places_affichees = [
        (p.get("place") or {}).get("place")
        for p in course_passee.get("participants", [])
        if not p.get("itsHim")
    ]
    premiere_non_affichee = max((n for n in places_affichees if isinstance(n, int)), default=0) + 1
    premiere_non_affichee = min(premiere_non_affichee, nb_participants)
    return (premiere_non_affichee + nb_participants + 1) // 2


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
            rang = place_info.get("place")
            rang_impute = False
            if rang is None and status_arrivee == "NON_PLACE":
                rang = _rang_impute_non_place(course_passee)
                rang_impute = rang is not None
            incident = RAW_VALUE_TO_INCIDENT.get(place_info.get("rawValue")) or STATUS_TO_INCIDENT.get(status_arrivee)
            if rang is None and incident is None and status_arrivee not in STATUTS_SANS_INCIDENT:
                # Sans rang ni incident, le moteur note la course 0 : un
                # nouveau statut doit être vu, pas absorbé en silence.
                logger.warning("statusArrivee non traduit : %r (rawValue %r)", status_arrivee, place_info.get("rawValue"))
            discipline_brute = course_passee.get("discipline", "")
            performances.append(PerformancePassee(
                date=_epoch_ms_to_date(course_passee.get("date")),
                hippodrome=course_passee.get("hippodrome"),
                discipline=DISCIPLINE_MAP.get(discipline_brute, discipline_brute.lower() or None),
                allocation=course_passee.get("allocation"),
                distance=course_passee.get("distance"),
                nb_participants=course_passee.get("nbParticipants"),
                rang=rang,
                incident=incident,
                terrain=normaliser_terrain(course_passee.get("etatTerrain")),
                rang_impute=rang_impute,
            ))
        if num_pmu is not None:
            results[num_pmu] = performances
    return results
