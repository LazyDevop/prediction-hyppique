"""Regression pour le bug corrige (voir deferred-work.md) : les outsiders
virtuels (num_pmu=None) qu'analyse_course ajoute pour completer le champ de
calcul (cahier des charges 7.8) ne doivent jamais fuiter dans la reponse de
l'API /analyse."""

import atexit
import os
import tempfile

_tmp_db_fd, _tmp_db_path = tempfile.mkstemp(suffix=".db", prefix="test_routes_analyse_")
os.close(_tmp_db_fd)


def _cleanup_tmp_db() -> None:
    try:
        os.remove(_tmp_db_path)
    except OSError:
        pass


atexit.register(_cleanup_tmp_db)
os.environ.setdefault("DATABASE_URL", f"sqlite:///{_tmp_db_path}")

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_analyse_ne_renvoie_jamais_d_outsiders_virtuels():
    payload = {
        "chevaux": [
            {
                "nom": f"Cheval {i}",
                "num_pmu": i,
                "age": 5,
                "poids": 60,
                "cote": 3.0,
                "inedit": False,
                "performances": [],
            }
            for i in range(1, 6)
        ],
        "distance": 1600,
        "terrain": 1.0,
        "niveau": 3.0,
        "nb_partants_course": 14,
    }
    response = client.post("/analyse", json=payload)
    assert response.status_code == 200

    resultats = response.json()["resultats"]
    assert len(resultats) == 5
    assert all(r["num_pmu"] is not None for r in resultats)

    champs_attendus = {
        "nom", "num_pmu", "age", "poids", "cote", "inedit", "score",
        "probabilite", "top1", "top2", "top3", "top4", "value", "kelly", "mise",
    }
    for r in resultats:
        assert set(r.keys()) == champs_attendus
        # champs internes de HorseAnalysis qui ne doivent jamais fuiter
        assert "performances" not in r
        assert "nb_perfs" not in r
        assert "forme" not in r
        assert "c_poids" not in r
        assert "c_age" not in r


def test_analyse_valeurs_correctement_mappees_par_cheval():
    # Story 1.3 (code review) : le test precedent ne verifie que l'ensemble
    # des cles, pas que les valeurs sont bien celles du BON cheval - une
    # erreur d'association dans HorseOut.model_validate(horse) (ex. champs
    # decales entre deux chevaux) passerait inapercue. Cotes distinctes pour
    # pouvoir re-associer chaque resultat a son cheval d'origine sans
    # ambiguite, et verifier au moins une relation attendue (value/kelly/mise
    # tous non-nuls ensemble ou tous nuls ensemble, jamais un melange).
    chevaux = [
        {"nom": "Favori", "num_pmu": 1, "age": 5, "poids": 58, "cote": 2.0, "inedit": False, "performances": []},
        {"nom": "Outsider", "num_pmu": 2, "age": 7, "poids": 62, "cote": 15.0, "inedit": False, "performances": []},
    ]
    payload = {"chevaux": chevaux, "distance": 1600, "terrain": 1.0, "niveau": 3.0, "nb_partants_course": 2}
    response = client.post("/analyse", json=payload)
    assert response.status_code == 200

    resultats = {r["nom"]: r for r in response.json()["resultats"]}
    assert set(resultats.keys()) == {"Favori", "Outsider"}

    # nom -> num_pmu/age/poids/cote doivent correspondre exactement a l'entree
    # soumise pour CE cheval, pas a un autre (preuve qu'il n'y a pas eu de
    # decalage entre l'entree et la sortie).
    for cheval_in in chevaux:
        r = resultats[cheval_in["nom"]]
        assert r["num_pmu"] == cheval_in["num_pmu"]
        assert r["age"] == cheval_in["age"]
        assert r["poids"] == cheval_in["poids"]
        assert r["cote"] == cheval_in["cote"]

    # value/kelly/mise sont soit tous renseignes soit tous None ensemble pour
    # un meme cheval (cote connue > 1 dans ce payload) - jamais un melange
    # partiel qui trahirait un decalage de champ.
    for r in resultats.values():
        valeurs = (r["value"], r["kelly"], r["mise"])
        assert all(v is not None for v in valeurs) or all(v is None for v in valeurs)


def test_analyse_chevaux_sans_num_pmu_produit_resultats_vide():
    # Un cheval soumis sans num_pmu (Optional cote schema HorseIn) suit le
    # meme filtre que les outsiders virtuels (num_pmu is None) - resultats
    # vide doit rester une reponse 200 valide pour List[HorseOut], pas une
    # erreur.
    payload = {
        "chevaux": [
            {"nom": "SansDossard", "age": 5, "poids": 60, "cote": 3.0, "inedit": False, "performances": []},
        ],
        "distance": 1600, "terrain": 1.0, "niveau": 3.0, "nb_partants_course": 1,
    }
    response = client.post("/analyse", json=payload)
    assert response.status_code == 200
    assert response.json()["resultats"] == []


def test_analyse_champs_optionnels_none_traversent_le_schema():
    # cote/poids/age omis (None) doivent survivre a
    # HorseOut.model_validate(horse) tels quels, pas etre convertis en 0 ou
    # en erreur de validation - et l'absence de cote doit laisser
    # value/kelly/mise a None (cahier des charges 7.11 : "Cote manquante").
    payload = {
        "chevaux": [
            {"nom": "DonneesIncompletes", "num_pmu": 9, "inedit": False, "performances": []},
        ],
        "distance": 1600, "terrain": 1.0, "niveau": 3.0, "nb_partants_course": 1,
    }
    response = client.post("/analyse", json=payload)
    assert response.status_code == 200

    resultat = response.json()["resultats"][0]
    assert resultat["age"] is None
    assert resultat["poids"] is None
    assert resultat["cote"] is None
    assert resultat["value"] is None
    assert resultat["kelly"] is None
    assert resultat["mise"] is None
