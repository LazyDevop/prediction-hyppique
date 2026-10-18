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


def test_get_programme_lit_le_terrain_du_jour_au_penetrometre(monkeypatch, no_network):
    # Fixture réelle du 18/10/2026 réduite : ParisLongchamp C1-C2 (gazon
    # mesuré "Bon souple") et une course de trot (pas de pénétromètre).
    monkeypatch.setattr(pmu_client, "_get", lambda endpoint: _load("programme_18102026.json"))

    courses = pmu_client.get_programme(pmu_client.date(2026, 10, 18))

    terrains = {(c.numero_reunion, c.numero_course): c.terrain for c in courses}
    assert terrains == {(1, 1): "Bon souple", (1, 2): "Bon souple", (4, 1): None}


def test_normaliser_terrain_psf_sans_etat_est_silencieux(caplog):
    # La veille, une piste en sable fibré est annoncée "PSF" sans état
    # mesuré : c'est une mesure à venir, pas un libellé inconnu.
    with caplog.at_level("WARNING", logger=pmu_client.__name__):
        assert pmu_client.normaliser_terrain("PSF") is None
    assert caplog.text == ""


def test_get_historique_non_place_sans_rang_impute_au_milieu_de_la_zone_non_placee(monkeypatch, no_network):
    monkeypatch.setattr(pmu_client, "_get", lambda endpoint: _load("performances_15012022_R1_C1.json"))

    historique = pmu_client.get_historique(pmu_client.date(2022, 1, 15), 1, 1)

    # Places 1-5 affichées : zone non placée = 6..partants, milieu arrondi
    # vers le haut (le plus prudent) -> 16 partants : 11 ; 14 : 10 ; 15 : 11.
    imputes = {num: [(p.nb_participants, p.rang) for p in perfs if p.rang_impute]
               for num, perfs in historique.items()}
    assert imputes[9] == [(16, 11)]
    assert sorted(imputes[10]) == [(14, 10), (14, 10), (15, 11)]
    assert imputes[12] == [(14, 10)]
    assert all(not p.rang_impute for p in historique[1] if p.rang is not None and p.incident is None)


def _course_passee(nb_participants, places_affichees, ma_place):
    autres = [{"itsHim": False, "place": {"place": n, "statusArrivee": "PLACE"}} for n in places_affichees]
    moi = {"itsHim": True, "place": ma_place}
    return {"participants": [{"numPmu": 1, "coursesCourues": [
        {"date": 1767225600000, "hippodrome": "X", "discipline": "PLAT",
         "nbParticipants": nb_participants, "participants": autres + [moi]},
    ]}]}


@pytest.mark.parametrize("nb_participants, places_affichees, attendu", [
    (12, [], 7),          # aucune place affichée : zone 1..12
    (6, [1, 2, 3, 4, 5], 6),  # seule place restante
    (None, [1, 2, 3], None),  # partants inconnus : pas d'imputation
])
def test_get_historique_non_place_cas_limites(monkeypatch, no_network, nb_participants, places_affichees, attendu):
    data = _course_passee(nb_participants, places_affichees, {"statusArrivee": "NON_PLACE"})
    monkeypatch.setattr(pmu_client, "_get", lambda endpoint: data)

    perf = pmu_client.get_historique(pmu_client.date(2026, 1, 1), 1, 1)[1][0]

    assert perf.rang == attendu
    assert perf.rang_impute is (attendu is not None)


def test_get_historique_non_place_avec_rang_connu_n_est_pas_impute(monkeypatch, no_network):
    data = _course_passee(16, [1, 2, 3, 4, 5], {"place": 9, "statusArrivee": "NON_PLACE"})
    monkeypatch.setattr(pmu_client, "_get", lambda endpoint: data)

    perf = pmu_client.get_historique(pmu_client.date(2026, 1, 1), 1, 1)[1][0]

    assert (perf.rang, perf.rang_impute) == (9, False)
