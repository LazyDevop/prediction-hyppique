import json
from datetime import date
from pathlib import Path

import pytest

from app.data import open_pmu_client

FIXTURES = Path(__file__).parent / "fixtures" / "open_pmu"


def _load(name):
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


@pytest.fixture
def no_network(monkeypatch):
    monkeypatch.setattr(open_pmu_client.time, "sleep", lambda *_: None)


def test_requires_at_least_one_filter():
    with pytest.raises(ValueError):
        open_pmu_client.get_arrivees()


def test_date_envoyee_au_format_mois_jour_annee(monkeypatch, no_network):
    # Non-régression : l'API documente JJ/MOIS/ANNEE mais attend en réalité
    # MOIS/JOUR/ANNEE (vérifié manuellement, voir docstring du module). Le
    # 5 janvier ne doit jamais partir comme "05/01" (qui viserait le 1er mai
    # côté API) mais comme "01/05".
    captured = {}

    def fake_get(url, headers=None, params=None, timeout=None):
        captured.update(params or {})
        return _FakeResponse({"error": True, "message": []})

    monkeypatch.setattr(open_pmu_client.requests, "get", fake_get)
    open_pmu_client.get_arrivees(target_date=date(2026, 1, 5))
    assert captured["date"] == "01/05/2026"


def test_erreur_renvoie_liste_vide(monkeypatch, no_network):
    monkeypatch.setattr(open_pmu_client.requests, "get", lambda *a, **k: _FakeResponse({"error": True, "message": []}))
    result = open_pmu_client.get_arrivees(target_date=date(2020, 12, 25))
    assert result == []


class _FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        pass

    def json(self):
        return self._payload


def test_poid_du_cheval_jamais_expose(monkeypatch, no_network):
    # Le champ existe dans la fixture (bugué, égal à la distance) : on
    # vérifie qu'aucun attribut du dataclass n'y fait référence.
    monkeypatch.setattr(open_pmu_client.requests, "get", lambda *a, **k: _FakeResponse(_load("arrivees_exemple_doc.json")))
    result = open_pmu_client.get_arrivees(target_date=date(2026, 7, 6))
    cheval = result[0].chevaux[0]
    assert not hasattr(cheval, "poid_du_cheval")
    assert not hasattr(cheval, "poids")


def test_cotes_exposees_brutes_non_interpretees(monkeypatch, no_network):
    monkeypatch.setattr(open_pmu_client.requests, "get", lambda *a, **k: _FakeResponse(_load("arrivees_exemple_doc.json")))
    result = open_pmu_client.get_arrivees(target_date=date(2026, 7, 6))
    cheval = next(c for c in result[0].chevaux if c.num_pmu == 2)
    assert cheval.cotes_brutes == ["4.3", "3.3", "3.2"]


def test_rang_calcule_depuis_arrivee(monkeypatch, no_network):
    # arrivee = [7, 4, 2, 8, 3, 13, 12] dans la fixture doc.
    monkeypatch.setattr(open_pmu_client.requests, "get", lambda *a, **k: _FakeResponse(_load("arrivees_exemple_doc.json")))
    result = open_pmu_client.get_arrivees(target_date=date(2026, 7, 6))
    chevaux = {c.num_pmu: c for c in result[0].chevaux}
    assert chevaux[7].rang == 1
    assert chevaux[4].rang == 2
    assert chevaux[2].rang == 3
    assert chevaux[7].incident is None


def test_types_incoherents_geres_defensivement(monkeypatch, no_network):
    # annee_de_naissance en chaîne dans cette fixture (vs entier ailleurs).
    monkeypatch.setattr(open_pmu_client.requests, "get", lambda *a, **k: _FakeResponse(_load("arrivees_exemple_doc.json")))
    result = open_pmu_client.get_arrivees(target_date=date(2026, 7, 6))
    cheval = next(c for c in result[0].chevaux if c.num_pmu == 2)
    assert cheval.annee_naissance == 2019
    # corde = "" dans cette fixture -> None, pas une erreur de cast.
    assert cheval.corde is None


def test_non_partant_detecte_meme_present_dans_arrivee_details(monkeypatch, no_network):
    # Fixture réelle : num_pmu=1 (TORTISAMBERT) est à la fois dans
    # arrivee_details ET dans non_partants=[1] (incohérence source, gérée
    # défensivement : non-partant l'emporte, pas de rang attribué).
    monkeypatch.setattr(open_pmu_client.requests, "get", lambda *a, **k: _FakeResponse(_load("arrivees_reel.json")))
    result = open_pmu_client.get_arrivees(target_date=date(2026, 6, 7))
    cheval = next(c for c in result[0].chevaux if c.num_pmu == 1)
    assert cheval.incident == "NR"
    assert cheval.rang is None


def test_non_partants_type_liste_gere(monkeypatch, no_network):
    # Fixture réelle : non_partants est une LISTE (vs un entier 0 dans la
    # fixture doc quand il n'y a aucun non-partant) - les deux doivent
    # fonctionner sans lever d'exception.
    monkeypatch.setattr(open_pmu_client.requests, "get", lambda *a, **k: _FakeResponse(_load("arrivees_reel.json")))
    result = open_pmu_client.get_arrivees(target_date=date(2026, 6, 7))
    assert result[0].hippodrome == "Paris-Longchamp"
    assert result[0].discipline == "plat"


def test_discipline_mapping():
    assert open_pmu_client.DISCIPLINE_MAP["ATTELÉ"] == "trot"
    assert open_pmu_client.DISCIPLINE_MAP["PLAT"] == "plat"


def test_date_parsee_depuis_le_champ_reponse(monkeypatch, no_network):
    # Fixture réelle : "date": "2026-06-07T00:00:00.000Z". Contrairement au
    # PARAMÈTRE de requête, ce champ de réponse est fiable (voir docstring
    # _parse_date_brute) et sert quand aucune date n'est connue par ailleurs
    # (recherche par hippodrome seul, sans itérer jour par jour).
    monkeypatch.setattr(open_pmu_client.requests, "get", lambda *a, **k: _FakeResponse(_load("arrivees_reel.json")))
    result = open_pmu_client.get_arrivees(hippodrome="Paris-Longchamp")
    assert result[0].date == date(2026, 6, 7)


def test_parse_date_brute_defensif_sur_valeur_invalide():
    assert open_pmu_client._parse_date_brute(None) is None
    assert open_pmu_client._parse_date_brute("") is None
    assert open_pmu_client._parse_date_brute("pas-une-date") is None
