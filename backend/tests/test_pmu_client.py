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
