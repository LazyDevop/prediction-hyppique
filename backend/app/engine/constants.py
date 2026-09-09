"""Coefficient tables mirrored in fixtures/engine_constants.json (Architecture
Spine AD-2) — a hand-edit here that isn't also applied there fails
backend/tests/test_scoring.py::test_fixture_constants_matches_constants_py."""

from dataclasses import dataclass
from typing import Dict, Optional

@dataclass(frozen=True)
class IncidentDefinition:
    malus: float
    chute: bool
    ignore: bool = False

TERRAIN_COEFFICIENTS_GRASS: Dict[str, float] = {
    "Très léger": 1.08,
    "Léger": 1.05,
    "Bon léger": 1.02,
    "Bon": 1.00,
    "Bon souple": 0.97,
    "Souple": 0.93,
    "Très souple": 0.88,
    "Collant": 0.83,
    "Lourd": 0.77,
    "Très lourd": 0.70,
}

TERRAIN_COEFFICIENTS_PSF: Dict[str, float] = {
    # 1.001 (not 1.00) matches docs/analyse_hippique_ia.jsx's own TERRAINS
    # table (line 16) and vision_client.py's verbatim-ported extraction
    # prompts (NFR-6) — a deliberate tiny offset from grass "Bon" (1.00) so a
    # value-based reverse lookup (mobile RaceConfigScreen) never confuses PSF
    # "Rapide" with grass "Bon", which this table previously did not honor.
    "Rapide": 1.001,
    "Standard": 0.99,
    "Lent": 0.95,
}

NIVEAU_COEFFICIENTS: Dict[str, float] = {
    "Groupe I": 5.0,
    "Groupe II": 4.5,
    "Groupe III": 4.0,
    "Groupe IV": 3.5,
    "Listed": 3.0,
    "Catégorie A": 2.6,
    "Catégorie B": 2.3,
    "Catégorie C": 2.0,
    "Handicap": 2.001,
    "Catégorie D": 1.7,
    "Catégorie E": 1.4,
    "Catégorie F": 1.1,
    "Catégorie G/H": 1.0,
    "Maiden": 1.001,
    "Inédits": 1.002,
}

INCIDENTS: Dict[str, IncidentDefinition] = {
    "T": IncidentDefinition(malus=1.2, chute=True),
    "F": IncidentDefinition(malus=1.2, chute=True),
    "BD": IncidentDefinition(malus=1.0, chute=True),
    "U": IncidentDefinition(malus=1.0, chute=True),
    "A": IncidentDefinition(malus=0.7, chute=False),
    "RO": IncidentDefinition(malus=0.7, chute=True),
    "RR": IncidentDefinition(malus=0.7, chute=False),
    "D": IncidentDefinition(malus=0.8, chute=False),
    "R": IncidentDefinition(malus=0.5, chute=False),
    "NR": IncidentDefinition(malus=0.0, chute=False, ignore=True),
}

def terrain_coefficient(label: Optional[str]) -> Optional[float]:
    if label is None:
        return None
    if label in TERRAIN_COEFFICIENTS_GRASS:
        return TERRAIN_COEFFICIENTS_GRASS[label]
    if label in TERRAIN_COEFFICIENTS_PSF:
        return TERRAIN_COEFFICIENTS_PSF[label]
    return None


RECENCE_STD = [1.00, 0.85, 0.70, 0.55, 0.42, 0.30]
RECENCE_FORME = [1.00, 0.65, 0.42, 0.28, 0.18, 0.12]
RECENCE_FLAT = [1.00, 1.00, 1.00, 1.00, 1.00, 1.00]

DEFAULT_PARAMETERS = {
    "malus_incident": 1.0,
    "sensibilite_poids": 1.0,
    "age_min": 4,
    "age_max": 7,
    "shrink": 2,
    "coef_inedit": 0.75,
    "contraste": 3,
    "bankroll": 100.0,
    "fraction_kelly": 0.25,
}
