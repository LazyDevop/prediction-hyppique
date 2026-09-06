"""Regression pour le bug corrige (voir deferred-work.md) : les outsiders
virtuels (num_pmu=None) qu'analyse_course ajoute pour completer le champ de
calcul (cahier des charges 7.8) ne doivent jamais fuiter dans la reponse de
l'API /analyse."""

import atexit
import os
import tempfile

import pytest

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


def _payload_deux_chevaux(params=None):
    payload = {
        "chevaux": [
            {"nom": "A", "num_pmu": 1, "age": 5, "poids": 60, "cote": 2.0, "inedit": False,
             "performances": [{"partants": 10, "rang": 1, "distance": 1600, "terrain": 1.0, "niveau": 3.0, "incident": None}]},
            {"nom": "B", "num_pmu": 2, "age": 5, "poids": 60, "cote": 3.0, "inedit": False,
             "performances": [{"partants": 10, "rang": 5, "distance": 1600, "terrain": 1.0, "niveau": 3.0, "incident": None}]},
        ],
        "distance": 1600, "terrain": 1.0, "niveau": 3.0, "nb_partants_course": 2,
    }
    if params is not None:
        payload["params"] = params
    return payload


def test_analyse_params_cle_inconnue_rejetee_422():
    # Story 1.4 : une cle mal orthographiee (ex. "shrnk" pour "shrink") doit
    # etre rejetee explicitement (422), pas silencieusement ignoree par le
    # dict-merge d'analyse_course sur DEFAULT_PARAMETERS.
    response = client.post("/analyse", json=_payload_deux_chevaux(params={"shrnk": 2}))
    assert response.status_code == 422


def test_analyse_params_shrink_negatif_rejete_422():
    # shrink < 0 n'a pas de sens (facteur de retrecissement bayesien vers la
    # moyenne du lot, scoring.py) et doit etre rejete a la frontiere API.
    response = client.post("/analyse", json=_payload_deux_chevaux(params={"shrink": -1}))
    assert response.status_code == 422


def test_analyse_params_age_min_superieur_age_max_rejete_422():
    response = client.post("/analyse", json=_payload_deux_chevaux(params={"age_min": 8, "age_max": 4}))
    assert response.status_code == 422


def test_analyse_params_age_min_egal_age_max_accepte_200():
    # Borne : age_min == age_max est une plage valide (un seul age optimal),
    # pas une inversion - ne doit jamais etre rejete.
    response = client.post("/analyse", json=_payload_deux_chevaux(params={"age_min": 5, "age_max": 5}))
    assert response.status_code == 200


def test_analyse_params_age_min_seul_reste_accepte_200():
    # Spec 1.4 (frozen intent) : "either one alone, or neither, is fine - no
    # cross-field requirement when only one is set". Un override partiel qui
    # ne fournit que age_min (jamais age_max) ne doit jamais etre rejete pour
    # incoherence avec la valeur par defaut de age_max - ce n'est pas une
    # borne prevue par cette story.
    response = client.post("/analyse", json=_payload_deux_chevaux(params={"age_min": 10}))
    assert response.status_code == 200


@pytest.mark.parametrize("champ,valeur", [
    ("contraste", 0),
    ("contraste", -1),
    ("fraction_kelly", -0.01),
    ("fraction_kelly", 1.01),
    ("bankroll", -1),
    ("malus_incident", -1),
    ("sensibilite_poids", -1),
    ("coef_inedit", -1),
    ("shrink", -1),
])
def test_analyse_params_hors_bornes_rejete_422(champ, valeur):
    # Chacune des bornes du modele (spec 1.4) a sa propre preuve de rejet.
    response = client.post("/analyse", json=_payload_deux_chevaux(params={champ: valeur}))
    assert response.status_code == 422, f"{champ}={valeur} aurait du etre rejete"


def test_analyse_params_override_partiel_valide_200():
    # Story 1.4 : un override partiel valide (seul shrink est fourni, le
    # reste par defaut) doit repondre 200 et se comporter comme
    # test_analyse_course_params_partiel_ne_touche_pas_les_autres_defauts
    # (test_scoring.py), maintenant atteignable via la vraie API : un shrink
    # plus fort rapproche les scores des deux chevaux (ecart reduit).
    reponse_defaut = client.post("/analyse", json=_payload_deux_chevaux())
    reponse_shrink = client.post("/analyse", json=_payload_deux_chevaux(params={"shrink": 10}))
    assert reponse_defaut.status_code == 200
    assert reponse_shrink.status_code == 200

    scores_defaut = {r["nom"]: r["score"] for r in reponse_defaut.json()["resultats"]}
    scores_shrink = {r["nom"]: r["score"] for r in reponse_shrink.json()["resultats"]}

    ecart_defaut = abs(scores_defaut["A"] - scores_defaut["B"])
    ecart_shrink_fort = abs(scores_shrink["A"] - scores_shrink["B"])
    assert ecart_shrink_fort < ecart_defaut

    # bankroll/fraction_kelly non surcharges doivent rester aux vrais
    # defauts (100, 0.25) a travers le round-trip du nouveau schema, pas
    # seulement "ne pas planter" (test_scoring.py:490-493, ported ici).
    for r in reponse_shrink.json()["resultats"]:
        if r["kelly"] is not None and r["kelly"] > 0:
            assert r["mise"] == pytest.approx(100.0 * r["kelly"] * 0.25)
