"""Adaptateur d'extraction vision (Anthropic Claude) — seul module du dépôt
qui connaît la forme des requêtes/réponses de l'API Messages d'Anthropic
(même pattern d'isolation que pmu_client.py/open_pmu_client.py, AD-1/AD-3 de
l'architecture).

Deux fonctions normalisées : extract_fiche_cheval (fiche individuelle d'un
cheval) et extract_programme (programme complet d'une course). Chacune
retourne un dataclass typé, jamais un dict brut — la sortie du modèle de
vision, comme le JSON PMU, ne doit jamais être considérée fiable (parsing
défensif via _to_float/_to_int, cf. open_pmu_client.py).

Budget : VISION_DAILY_CALL_LIMIT (variable d'env, entier) est appliqué via un
compteur en mémoire remis à zéro au changement de date calendaire UTC (AD-3
autorise explicitement l'in-memory pour ce déploiement mono-process). Un
appel qui atteindrait ou dépasserait le plafond est refusé AVANT tout appel
HTTP (il ne consomme donc pas de budget) et journalisé en erreur.

Clé API : ANTHROPIC_API_KEY (variable d'env uniquement) — jamais codée en
dur, jamais incluse dans une ligne de log ou un message d'exception.

Ce module n'ajoute PAS le SDK `anthropic` : comme pmu_client.py et
open_pmu_client.py, il utilise `requests` en direct (une seule route POST,
une seule réponse à parser — le SDK n'apporterait rien ici).

Les deux prompts ci-dessous (PROMPT, RACE_PROMPT) sont portés VERBATIM depuis
docs/analyse_hippique_ia.jsx (lignes 291-305 et 307-319) — ne jamais les
reformuler ni les "améliorer" (NFR-6).
"""

import base64
import json
import logging
import os
import threading
from dataclasses import dataclass, field
from datetime import datetime, timezone
from datetime import date as date_type
from typing import Any, Dict, List, Optional

import requests

logger = logging.getLogger(__name__)

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_API_VERSION = "2023-06-01"
DEFAULT_MODEL = "claude-sonnet-5"
# Pas de valeur imposée par l'architecture (AD-3 : le plafond réel est une
# question ouverte du PRD, §9.4/§11.4) — ce défaut ne s'applique que si
# VISION_DAILY_CALL_LIMIT n'est pas configurée du tout, pour ne pas bloquer
# silencieusement un déploiement qui aurait oublié la variable.
DEFAULT_DAILY_CALL_LIMIT = 50

PROMPT = """Tu lis une fiche de cheval de course hippique (capture d'écran d'un site comme Geny, France Galop, PMU...).
Extrais les informations et réponds UNIQUEMENT avec un JSON valide, sans aucun texte autour, sans backticks, au format exact :
{"name":string,"num":number|null,"age":number|null,"poids":number|null,"cote":number|null,"perfs":[{"rank":number|null,"part":number|null,"incident":string,"niveau":number,"dist":number|null,"terr":number}]}

Règles :
- "num" = numéro de dossard du cheval si visible (ex: "101 - PASSAGE VALLET" -> 101). Attention : sur certains sites (ex. Genybet), ce numéro en tête de fiche peut parfois être élevé (ex. 604) et ne pas correspondre au vrai numéro de course PMU du jour — reste plausible mais à vérifier par l'utilisateur, ne pas le sur-interpréter comme certain.
- "poids" = poids porté / du jockey en kg (ex: "57 KG" -> 57).
- "perfs" = les courses de l'historique, triées de la PLUS RÉCENTE à la plus ancienne, maximum 6.
- "rank" = place obtenue (nombre). Sur les tableaux de performances (colonne "Rq"/Rang), un incident apparaît souvent directement comme une LETTRE à la place du chiffre (ex. "A" = Arrêté, "D" = Disqualifié, "T" = Tombé) — reconnais-la comme incident, mets rank=null.
- "incident" : code d'incident d'obstacle si la musique contient une lettre. Correspondances : T=Tombé, F=Fell, BD=Brought Down/tombé par un autre, U=désarçonné, A=Arrêté, RO=sorti de piste, RR=refus de partir, D=Disqualifié, R=Rétrogradé, NR=non partant. Sinon chaîne vide "". Dans une musique française, "0" = non placé (rank=10, incident=""), "T"/"A"/"D" etc = incident.
- "part" = nombre de partants de cette course. null si absent de la fiche.
- "dist" = distance en mètres.
- "terr" : échelle GAZON officielle France Galop (10 niveaux, du plus rapide au plus lourd) : très léger=1.08, léger=1.05, bon léger=1.02, bon=1, bon souple=0.97, souple=0.93, très souple=0.88, collant=0.83, lourd=0.77, très lourd=0.7. Échelle SABLE FIBRÉ/PSF distincte (Cagnes-sur-Mer, Deauville PSF...) : rapide=1.001, standard=0.99, lent=0.95. Ne confonds pas les deux échelles. Attention : "léger" = sol sec et ferme (rapide), PAS souple. "Super lourd" n'existe pas officiellement : si tu le lis, mets très lourd=0.7. Inconnu=1.
- "niveau" : Groupe I=5, Groupe II=4.5, Groupe III=4, Groupe IV=3.5, Listed=3. En dessous, les courses ordinaires (galop et trot) sont classées par LETTRE de A à G/H (A = la plus relevée) : Catégorie A=2.6, B=2.3, C=2, D=1.7, E=1.4, F=1.1, G ou H=1. Une "Course B" est cette Catégorie B (bon niveau intermédiaire), PAS une "Breeders Course" (terme non officiel). "Cond." (course à conditions) ou lettre inconnue=2. "Réclamer"/"À Réc."/claiming (les chevaux peuvent être achetés après course) = niveau modeste, mets 1.4 sauf indication contraire.
- Tout champ illisible ou absent : null (sauf terr et niveau qui ont des défauts)."""

RACE_PROMPT = """Tu lis la capture d'écran d'un PROGRAMME de course hippique (liste des partants, type Geny/PMU/Equidia).
Extrais les informations et réponds UNIQUEMENT avec un JSON valide, sans aucun texte autour, sans backticks, au format exact :
{"hippo":string,"dist":number|null,"terr":number,"niveau":number,"partants":number|null,"horses":[{"num":number|null,"name":string,"age":number|null,"poids":number|null,"cote":number|null,"perfs":[{"rank":number|null,"incident":string}]}]}

Règles :
- "num" = numéro de dossard (colonne N°).
- "hippo" = nom de l'hippodrome. "dist" = distance en mètres (ex: "1,400 m" -> 1400).
- "terr" : échelle GAZON officielle (10 niveaux) : très léger=1.08, léger=1.05, bon léger=1.02, bon=1, bon souple=0.97, souple=0.93, très souple=0.88, collant=0.83, lourd=0.77, très lourd=0.7. Échelle SABLE FIBRÉ/PSF distincte : rapide=1.001, standard=0.99, lent=0.95. "Léger" = sol ferme et rapide, PAS souple. "Super lourd" n'existe pas officiellement (mets très lourd=0.7). Inconnu=1.
- "niveau" : Groupe I=5, Groupe II=4.5, Groupe III=4, Groupe IV=3.5, Listed=3. Courses ordinaires classées par LETTRE de A à G/H (A=la plus relevée, valable galop ET trot) : Catégorie A=2.6, B=2.3, C=2, D=1.7, E=1.4, F=1.1, G/H=1. "Cond."/handicap/lettre inconnue=2. "Réclamer"/"À Réc." (claiming, chevaux achetables après course) = niveau modeste, 1.4 sauf indication contraire.
- "partants" = nombre total de chevaux au départ (compte les lignes du tableau si non indiqué).
- Pour chaque cheval : "age" depuis la colonne S/A (ex: "M2"=2 ans, "F3"=3 ans, "H5"=5 ans). "poids" en kg. "cote" = la cote la plus récente visible (colonne Live sinon Réf.).
- "perfs" = la musique décodée, de la plus récente à la plus ancienne, maximum 6. Chaque élément : {"rank":place,"incident":code}. Un chiffre -> {"rank":ce chiffre,"incident":""}. "0" -> {"rank":10,"incident":""}. Une lettre d'incident -> {"rank":null,"incident":code} avec code parmi T,F,BD,U,A,RO,RR,D,R,NR (T=tombé, A=arrêté, D=disqualifié, etc). Ex: "1p T Ap" -> [{"rank":1,"incident":""},{"rank":null,"incident":"T"},{"rank":null,"incident":"A"}].
- Tout champ illisible ou absent : null."""


class VisionBudgetExceeded(Exception):
    """Levée quand VISION_DAILY_CALL_LIMIT est atteint/dépassé pour la date
    UTC courante — avant tout appel HTTP, qui n'est donc jamais émis."""


class VisionExtractionError(Exception):
    """Levée pour toute réponse HTTP non-2xx, ou toute sortie du modèle qui
    n'est pas un JSON exploitable une fois les fences ```json/``` retirées.
    Jamais une exception requests/json brute ne doit atteindre l'appelant."""


@dataclass
class PerfFicheExtraite:
    rank: Optional[int]
    part: Optional[int]
    incident: str
    niveau: Optional[float]
    dist: Optional[float]
    terr: Optional[float]


@dataclass
class FicheChevalExtraite:
    name: Optional[str]
    num: Optional[int]
    age: Optional[int]
    poids: Optional[float]
    cote: Optional[float]
    perfs: List[PerfFicheExtraite] = field(default_factory=list)


@dataclass
class PerfProgrammeExtraite:
    rank: Optional[int]
    incident: str


@dataclass
class HorseProgrammeExtrait:
    num: Optional[int]
    name: Optional[str]
    age: Optional[int]
    poids: Optional[float]
    cote: Optional[float]
    perfs: List[PerfProgrammeExtraite] = field(default_factory=list)


@dataclass
class ProgrammeExtrait:
    hippo: Optional[str]
    dist: Optional[float]
    terr: Optional[float]
    niveau: Optional[float]
    partants: Optional[int]
    horses: List[HorseProgrammeExtrait] = field(default_factory=list)


# ============ Compteur quotidien en mémoire (AD-3) ============
_daily_call_count = 0
_daily_call_count_date: Optional[date_type] = None
# Protège la séquence lire-comparer-incrémenter ci-dessous : FastAPI exécute
# les handlers synchrones dans un threadpool, donc deux requêtes concurrentes
# pourraient sinon toutes deux lire un compteur sous le plafond avant que
# l'une ou l'autre ne l'incrémente, dépassant le plafond que ce module existe
# précisément pour garantir (AD-3) - revue de code, "mono-process" ne veut
# pas dire "mono-thread".
_daily_call_count_lock = threading.Lock()


def _enforce_budget() -> None:
    """Vérifie et consomme le budget d'appels du jour. Doit être appelée en
    tout premier, avant toute construction de requête ou appel HTTP : un
    appel refusé ne doit jamais avoir consommé de budget ni touché le réseau."""
    global _daily_call_count, _daily_call_count_date

    limit_raw = os.environ.get("VISION_DAILY_CALL_LIMIT")
    try:
        limit = int(limit_raw) if limit_raw is not None else DEFAULT_DAILY_CALL_LIMIT
    except ValueError:
        logger.error("VISION_DAILY_CALL_LIMIT invalide (%r) - utilisation du défaut %s", limit_raw, DEFAULT_DAILY_CALL_LIMIT)
        limit = DEFAULT_DAILY_CALL_LIMIT

    with _daily_call_count_lock:
        today = datetime.now(timezone.utc).date()
        if _daily_call_count_date != today:
            _daily_call_count_date = today
            _daily_call_count = 0

        if _daily_call_count >= limit:
            logger.error(
                "Plafond quotidien d'appels vision atteint (%s/%s) - appel refusé sans requête HTTP",
                _daily_call_count, limit,
            )
            raise VisionBudgetExceeded(f"Plafond quotidien d'appels vision atteint ({limit})")

        _daily_call_count += 1


# ============ Parsing défensif de la sortie modèle (non fiable) ============
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


def _to_optional_str(value: Any) -> Optional[str]:
    if value is None:
        return None
    return str(value)


def _to_str(value: Any) -> str:
    if value is None:
        return ""
    return str(value)


def _build_content_block(file_bytes: bytes, media_type: str) -> Dict[str, Any]:
    """media_type == "application/pdf" -> bloc "document" ; tout autre
    (image/*) -> bloc "image". Mirrors docs/analyse_hippique_ia.jsx:322-325."""
    encoded = base64.b64encode(file_bytes).decode("ascii")
    if media_type == "application/pdf":
        return {
            "type": "document",
            "source": {"type": "base64", "media_type": "application/pdf", "data": encoded},
        }
    return {
        "type": "image",
        "source": {"type": "base64", "media_type": media_type, "data": encoded},
    }


def _call_anthropic(content_block: Dict[str, Any], prompt: str) -> Any:
    # Vérifiée AVANT le budget : une clé absente garantit qu'aucune requête
    # réseau ne partira jamais, donc ce cas ne doit pas consommer de budget
    # (contrairement à un échec réseau/HTTP réel après une tentative
    # effective - voir _enforce_budget) - revue de code.
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        # Ne jamais mentionner la clé elle-même (absente ici) dans le message.
        logger.error("ANTHROPIC_API_KEY n'est pas configurée - appel vision annulé")
        raise VisionExtractionError("ANTHROPIC_API_KEY n'est pas configurée")

    _enforce_budget()

    model = os.environ.get("ANTHROPIC_VISION_MODEL", DEFAULT_MODEL)
    headers = {
        "x-api-key": api_key,
        "anthropic-version": ANTHROPIC_API_VERSION,
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "max_tokens": 2000,
        "messages": [{
            "role": "user",
            "content": [content_block, {"type": "text", "text": prompt}],
        }],
    }

    try:
        response = requests.post(ANTHROPIC_API_URL, headers=headers, json=payload, timeout=60)
    except requests.RequestException as exc:
        logger.error("Appel HTTP à l'API de vision échoué : %s", exc)
        raise VisionExtractionError("Appel à l'API de vision échoué") from exc

    if not (200 <= response.status_code < 300):
        logger.error("Réponse non-2xx de l'API de vision (statut %s)", response.status_code)
        raise VisionExtractionError(f"Réponse non-2xx de l'API de vision (statut {response.status_code})")

    try:
        data = response.json()
    except ValueError as exc:
        logger.error("Enveloppe de réponse de l'API de vision non-JSON : %s", exc)
        raise VisionExtractionError("Enveloppe de réponse de l'API de vision non-JSON") from exc

    blocks = data.get("content") or [] if isinstance(data, dict) else []
    text = "\n".join(
        block.get("text", "") for block in blocks if isinstance(block, dict) and block.get("type") == "text"
    )
    # Mirrors docs/analyse_hippique_ia.jsx:339-341 (fence stripping).
    cleaned = text.replace("```json", "").replace("```", "").strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as exc:
        logger.error("Sortie du modèle de vision non-JSON après retrait des fences : %s", exc)
        raise VisionExtractionError("Sortie du modèle de vision non-JSON") from exc


# ============ Parsing des schémas normalisés ============
def _parse_perf_fiche(raw: Dict[str, Any]) -> PerfFicheExtraite:
    return PerfFicheExtraite(
        rank=_to_int(raw.get("rank")),
        part=_to_int(raw.get("part")),
        incident=_to_str(raw.get("incident")),
        niveau=_to_float(raw.get("niveau")),
        dist=_to_float(raw.get("dist")),
        terr=_to_float(raw.get("terr")),
    )


def _parse_fiche(data: Dict[str, Any]) -> FicheChevalExtraite:
    perfs_raw = data.get("perfs")
    perfs = perfs_raw if isinstance(perfs_raw, list) else []
    return FicheChevalExtraite(
        name=_to_optional_str(data.get("name")),
        num=_to_int(data.get("num")),
        age=_to_int(data.get("age")),
        poids=_to_float(data.get("poids")),
        cote=_to_float(data.get("cote")),
        perfs=[_parse_perf_fiche(p) for p in perfs if isinstance(p, dict)],
    )


def _parse_perf_programme(raw: Dict[str, Any]) -> PerfProgrammeExtraite:
    return PerfProgrammeExtraite(
        rank=_to_int(raw.get("rank")),
        incident=_to_str(raw.get("incident")),
    )


def _parse_horse_programme(raw: Dict[str, Any]) -> HorseProgrammeExtrait:
    perfs_raw = raw.get("perfs")
    perfs = perfs_raw if isinstance(perfs_raw, list) else []
    return HorseProgrammeExtrait(
        num=_to_int(raw.get("num")),
        name=_to_optional_str(raw.get("name")),
        age=_to_int(raw.get("age")),
        poids=_to_float(raw.get("poids")),
        cote=_to_float(raw.get("cote")),
        perfs=[_parse_perf_programme(p) for p in perfs if isinstance(p, dict)],
    )


def _parse_programme(data: Dict[str, Any]) -> ProgrammeExtrait:
    horses_raw = data.get("horses")
    horses = horses_raw if isinstance(horses_raw, list) else []
    return ProgrammeExtrait(
        hippo=_to_optional_str(data.get("hippo")),
        dist=_to_float(data.get("dist")),
        terr=_to_float(data.get("terr")),
        niveau=_to_float(data.get("niveau")),
        partants=_to_int(data.get("partants")),
        horses=[_parse_horse_programme(h) for h in horses if isinstance(h, dict)],
    )


# ============ API publique ============
def extract_fiche_cheval(file_bytes: bytes, media_type: str) -> FicheChevalExtraite:
    content_block = _build_content_block(file_bytes, media_type)
    data = _call_anthropic(content_block, PROMPT)
    if not isinstance(data, dict):
        logger.error("Extraction vision (fiche) : JSON racine n'est pas un objet")
        raise VisionExtractionError("Sortie du modèle de vision non-JSON")
    return _parse_fiche(data)


def extract_programme(file_bytes: bytes, media_type: str) -> ProgrammeExtrait:
    content_block = _build_content_block(file_bytes, media_type)
    data = _call_anthropic(content_block, RACE_PROMPT)
    if not isinstance(data, dict):
        logger.error("Extraction vision (programme) : JSON racine n'est pas un objet")
        raise VisionExtractionError("Sortie du modèle de vision non-JSON")
    return _parse_programme(data)
