"""Adaptateur pour open-pmu-api (https://open-pmu-api.vercel.app), MIT,
résultats PMU du 22/01/2004 à aujourd'hui.

Ne remplace PAS pmu_client.py (programme/partants à venir) : cette source ne
fournit que des ARRIVÉES déjà courues. Elle sert uniquement au backfill de
l'historique profond d'un cheval, là où performances-detaillees de l'API PMU
officielle se limite aux 5 dernières courses (section 5.1 du document
backend — même pattern adaptateur : rien de brut ne sort de ce module).

Avertissements vérifiés manuellement sur des réponses réelles, à respecter
strictement par tout code appelant :
- "poid_du_cheval" est bugué (constaté égal à la distance de la course sur
  plusieurs exemples) : jamais exposé par ce module, ne jamais le réintroduire
  sans une vérification manuelle sérieuse.
- "cotes" (tableau de 3 valeurs) a une sémantique non confirmée (cote de
  référence ? dernière cote ? à 3 horaires différents ?) : exposé tel quel
  sous "cotes_brutes", jamais interprété comme une cote finale utilisable
  pour calculer une value tant que ce n'est pas vérifié sur des courses à
  cotes connues.
- Le paramètre "date" est documenté "JJ/MOIS/ANNEE" mais l'API l'interprète
  en réalité en MOIS/JOUR/ANNEE (format américain) : vérifié manuellement en
  comparant le "date" renvoyé à la date demandée sur plusieurs exemples
  (ex. date=01/12/2019 renvoie le 12 janvier 2019, pas le 1er décembre ;
  date=07/01/2026 avec l'ordre mois/jour renvoie bien le "2026-07-01"
  attendu). Ce module envoie donc la date au format MOIS/JOUR/ANNEE réel,
  PAS celui de la documentation officielle — ne pas "corriger" ça sans
  revérifier, ce serait réintroduire le bug. Le champ "date_brute" de la
  réponse reste conservé à titre indicatif seulement ; le code appelant doit
  toujours utiliser la date qu'il a lui-même demandée (celle qu'on sait
  correcte), jamais recalculer quoi que ce soit depuis "date_brute".
- Types incohérents observés selon les réponses (ex. "non_partants" tantôt
  un entier 0, tantôt une liste de numéros ; "annee_de_naissance" tantôt une
  chaîne, tantôt un entier ; "corde" tantôt "", tantôt un entier) : tout est
  parsé défensivement, jamais avec un cast direct non protégé.
"""

import logging
import time
from dataclasses import dataclass, field
from datetime import date as date_type
from typing import Any, Dict, List, Optional

import requests

BASE_URL = "https://open-pmu-api.vercel.app/api/arrivees"
HEADERS = {
    "User-Agent": "prediction-hippique-backend/1.0 (personal project; contact: rogerbertrand360@gmail.com)"
}
REQUEST_DELAY_SECONDS = 1.0

logger = logging.getLogger(__name__)

DISCIPLINE_MAP = {
    "PLAT": "plat",
    "ATTELÉ": "trot",
    "ATTELE": "trot",
    "MONTÉ": "trot",
    "MONTE": "trot",
    "HAIES": "obstacle",
    "STEEPLE-CHASE": "obstacle",
    "STEEPLECHASE": "obstacle",
    "CROSS": "obstacle",
}

# Seul NON_PARTANT est un fait certain (liste explicite côté API). Un cheval
# absent de "arrivee" sans être dans "non_partants" a simplement fini hors du
# classement renvoyé (~7 premiers) : pas un incident, cf. piège équivalent
# avec NON_PLACE dans pmu_client.py (section 4.3 du document backend).
INCIDENT_NON_PARTANT = "NR"


def _normalize_name(name: str) -> str:
    return " ".join(name.strip().upper().split())


def _to_float(value: Any) -> Optional[float]:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _to_int(value: Any) -> Optional[int]:
    if value is None or value == "":
        return None
    try:
        return int(float(value))
    except (TypeError, ValueError):
        return None


def _parse_date_brute(value: Optional[str]) -> Optional[date_type]:
    """Parse le champ "date" de la réponse (ex. "2026-07-01T00:00:00.000Z").
    Fiable, contrairement au PARAMÈTRE "date" de la requête (voir
    avertissement module) : c'est l'interprétation du paramètre envoyé qui
    est buguée côté API, pas l'encodage ISO de ce champ en sortie - vérifié
    en comparant plusieurs dates demandées (au format corrigé MOIS/JOUR) à ce
    même champ dans leur réponse, toujours cohérent. À utiliser quand aucune
    date n'est connue par ailleurs (ex. recherche par hippodrome seul)."""
    if not value:
        return None
    try:
        return date_type.fromisoformat(value[:10])
    except ValueError:
        return None


@dataclass
class ArriveeCheval:
    num_pmu: int
    nom: str
    sexe: Optional[str]
    annee_naissance: Optional[int]
    jockey: Optional[str]
    entraineur: Optional[str]
    musique: Optional[str]
    cotes_brutes: List[str]  # sémantique non confirmée, voir avertissement module
    corde: Optional[int]
    rang: Optional[int]  # position dans l'arrivée ; None si non-partant ou hors classement renvoyé
    incident: Optional[str]


@dataclass
class Arrivee:
    reunion_course: Optional[str]  # "R1/C8" brut, non décomposé (fiabilité non vérifiée)
    date_brute: Optional[str]  # valeur brute renvoyée, conservée à titre indicatif
    date: Optional[date_type]  # date_brute parsée - fiable, voir _parse_date_brute
    hippodrome: str
    prix: str
    discipline: str
    discipline_brute: str
    distance: Optional[float]
    allocation: Optional[float]
    nb_partants: Optional[int]
    heure_depart: Optional[str]
    chevaux: List[ArriveeCheval] = field(default_factory=list)


def get_arrivees(
    target_date: Optional[date_type] = None,
    hippodrome: Optional[str] = None,
    prix: Optional[str] = None,
) -> List[Arrivee]:
    """Un seul filtre suffit (date, hippodrome ou prix) ; l'API exige au
    moins un paramètre. target_date est envoyée au format MOIS/JOUR/ANNEE
    réellement attendu par l'API (pas celui de sa documentation) — voir
    l'avertissement du module."""
    params: Dict[str, str] = {}
    if hippodrome:
        params["hippo"] = hippodrome
    if prix:
        params["prix"] = prix
    if target_date is not None:
        params["date"] = target_date.strftime("%m/%d/%Y")

    if not params:
        raise ValueError("get_arrivees nécessite au moins un filtre (date, hippodrome ou prix)")

    response = requests.get(BASE_URL, headers=HEADERS, params=params, timeout=15)
    response.raise_for_status()
    time.sleep(REQUEST_DELAY_SECONDS)
    data = response.json()

    if data.get("error"):
        return []

    arrivees: List[Arrivee] = []
    for course in data.get("message", []):
        non_partants_brut = course.get("non_partants")
        non_partants_numeros = set(non_partants_brut) if isinstance(non_partants_brut, list) else set()

        ordre_arrivee = course.get("arrivee") if isinstance(course.get("arrivee"), list) else []
        discipline_brute = course.get("type") or ""

        chevaux: List[ArriveeCheval] = []
        for num_pmu_str, detail in (course.get("arrivee_details") or {}).items():
            num_pmu = _to_int(num_pmu_str)
            if num_pmu is None or not isinstance(detail, dict):
                continue

            est_non_partant = num_pmu in non_partants_numeros
            rang = None
            if not est_non_partant and num_pmu in ordre_arrivee:
                rang = ordre_arrivee.index(num_pmu) + 1

            chevaux.append(ArriveeCheval(
                num_pmu=num_pmu,
                nom=detail.get("nom_cheval") or "",
                sexe=detail.get("sexe"),
                annee_naissance=_to_int(detail.get("annee_de_naissance")),
                jockey=detail.get("nom_jockey"),
                entraineur=detail.get("nom_entraineur"),
                musique=detail.get("musique"),
                cotes_brutes=list(detail.get("cotes") or []),
                corde=_to_int(detail.get("corde")),
                rang=rang,
                incident=INCIDENT_NON_PARTANT if est_non_partant else None,
            ))

        arrivees.append(Arrivee(
            reunion_course=course.get("r/c"),
            date_brute=course.get("date"),
            date=_parse_date_brute(course.get("date")),
            hippodrome=course.get("lieu") or "",
            prix=course.get("prix") or "",
            discipline=DISCIPLINE_MAP.get(discipline_brute.upper(), discipline_brute.lower()),
            discipline_brute=discipline_brute,
            distance=_to_float(course.get("distance")),
            allocation=_to_float(course.get("montant")),
            nb_partants=_to_int(course.get("partants")),
            heure_depart=course.get("heure_depart"),
            chevaux=chevaux,
        ))
    return arrivees
