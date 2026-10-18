import json
from pathlib import Path

import pytest

from app.data import pmu_client

FIXTURES = Path(__file__).parent / "fixtures" / "pmu"


def _load(name):
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


@pytest.fixture
def no_network(monkeypatch):
    monkeypatch.setattr(pmu_client.time, "sleep", lambda *_: None)


def test_get_programme_filters_to_france_and_maps_discipline(monkeypatch, no_network):
    monkeypatch.setattr(pmu_client, "_get", lambda endpoint: _load("programme_15012022.json"))

    courses = pmu_client.get_programme(pmu_client.date(2022, 1, 15))

    assert len(courses) > 0
    assert all(c.pays == "FRA" for c in courses)
    premiere = next(c for c in courses if c.numero_reunion == 1 and c.numero_course == 1)
    assert premiere.hippodrome == "VINCENNES"
    assert premiere.discipline == "trot"
    assert premiere.discipline_brute == "ATTELE"


def test_get_participants_maps_inedit_and_cote(monkeypatch, no_network):
    monkeypatch.setattr(pmu_client, "_get", lambda endpoint: _load("participants_15012022_R1_C1.json"))

    partants = pmu_client.get_participants(pmu_client.date(2022, 1, 15), 1, 1)

    cheval = next(p for p in partants if p.num_pmu == 1)
    assert cheval.nom == "IDEFIX D'OLMEN"
    assert cheval.inedit is False
    assert cheval.cote_reference == 4.8
    assert cheval.ordre_arrivee == 10


def test_get_historique_matches_itshim_not_first_entry(monkeypatch, no_network):
    monkeypatch.setattr(pmu_client, "_get", lambda endpoint: _load("performances_15012022_R1_C1.json"))

    historique = pmu_client.get_historique(pmu_client.date(2022, 1, 15), 1, 1)

    performances = historique[1]
    assert len(performances) == 5
    # La première course de la fixture liste IDEFIX D'OLMEN en 6e position
    # (itsHim=True) alors que participants[0] est un autre cheval (I LOVE YOU
    # TEK) : si on lisait l'index 0 on récupérerait le résultat du mauvais cheval.
    disqualifications = [p for p in performances if p.incident == "D"]
    assert len(disqualifications) == 3
    places = [p for p in performances if p.rang is not None]
    assert [p.rang for p in places] == [2, 1]


def test_get_historique_normalise_etat_terrain_gazon_et_psf(monkeypatch, no_network):
    # Fixture réelle (ParisLongchamp R1C3 du 18/10/2026, réduite à 3 partants)
    monkeypatch.setattr(pmu_client, "_get", lambda endpoint: _load("performances_18102026_R1_C3.json"))

    historique = pmu_client.get_historique(pmu_client.date(2026, 10, 18), 1, 3)

    assert [p.terrain for p in historique[1]] == ["Souple", "Bon souple", "Bon souple", "Bon souple", "Bon"]
    assert historique[6][-1].terrain == "Standard"


@pytest.mark.parametrize("brut, attendu", [
    ("Bon", "Bon"),
    ("Très souple", "Très souple"),
    ("Très léger", "Très léger"),
    ("Très lourd", "Très lourd"),
    ("PSF Standard", "Standard"),
    ("PSF Lente", "Lent"),
    ("PSF Rapide", "Rapide"),
    ("  bon SOUPLE ", "Bon souple"),
    (None, None),
    ("", None),
])
def test_normaliser_terrain(brut, attendu):
    assert pmu_client.normaliser_terrain(brut) == attendu


def test_normaliser_terrain_libelle_inconnu_renvoie_none_et_journalise(caplog):
    with caplog.at_level("WARNING", logger=pmu_client.__name__):
        assert pmu_client.normaliser_terrain("Gelé") is None
    assert "Gelé" in caplog.text


def test_normaliser_terrain_couvre_toutes_les_cles_du_moteur():
    from app.engine.constants import TERRAIN_COEFFICIENTS_GRASS, TERRAIN_COEFFICIENTS_PSF

    for label in TERRAIN_COEFFICIENTS_GRASS:
        assert pmu_client.normaliser_terrain(label) == label
    for label in TERRAIN_COEFFICIENTS_PSF:
        assert pmu_client.normaliser_terrain(f"PSF {label}") == label
