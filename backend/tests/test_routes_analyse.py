"""Regression pour le bug corrige (voir deferred-work.md) : les outsiders
virtuels (num_pmu=None) qu'analyse_course ajoute pour completer le champ de
calcul (cahier des charges 7.8) ne doivent jamais fuiter dans la reponse de
l'API /analyse."""

import atexit
import dataclasses
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

from app.api import routes_analyse
from app.data import vision_client
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


def test_analyse_params_age_min_seul_incoherent_avec_defaut_rejete_422():
    # Code review : un override PARTIEL (seul age_min, jamais age_max) doit
    # aussi etre rejete s'il devient incoherent une fois fusionne avec
    # DEFAULT_PARAMETERS["age_max"]=7 en aval - sinon la meme classe de bug
    # que cette story ferme (une plage d'age inversee) reste atteignable
    # via un override partiel plutot qu'un override complet. Amende la
    # formulation initiale du spec ("either one alone... is fine"), qui ne
    # comparait qu'aux valeurs soumises, jamais aux valeurs effectives
    # post-fusion.
    response = client.post("/analyse", json=_payload_deux_chevaux(params={"age_min": 10}))
    assert response.status_code == 422


@pytest.mark.parametrize("champ,valeur", [
    ("contraste", 0),
    ("contraste", -1),
    ("contraste", 51),
    ("fraction_kelly", -0.01),
    ("fraction_kelly", 1.01),
    ("bankroll", -1),
    ("malus_incident", -1),
    ("sensibilite_poids", -1),
    ("coef_inedit", -1),
    ("shrink", -1),
    ("age_min", -1),
    ("age_max", -1),
])
def test_analyse_params_hors_bornes_rejete_422(champ, valeur):
    # Chacune des 9 bornes du modele doit avoir sa propre preuve de rejet -
    # avant cette liste, 6 des 9 champs n'avaient aucun test qui aurait
    # echoue si leur borne etait accidentellement retiree (code review).
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


# ============ Story 4.2 : /extraction/fiche et /extraction/programme ============
# vision_client est mocke a son chemin d'import dans routes_analyse.py
# (`routes_analyse.vision_client.<fn>`) - jamais un appel HTTP reel a
# l'API Anthropic depuis ces tests.

FICHE_EXTRAITE = vision_client.FicheChevalExtraite(
    name="PASSAGE VALLET",
    num=101,
    age=5,
    poids=57.0,
    cote=6.5,
    perfs=[
        vision_client.PerfFicheExtraite(rank=1, part=12, incident="", niveau=2.3, dist=2000.0, terr=1.0),
        vision_client.PerfFicheExtraite(rank=None, part=None, incident="T", niveau=2.0, dist=1600.0, terr=0.97),
    ],
)

PROGRAMME_EXTRAIT = vision_client.ProgrammeExtrait(
    hippo="Vincennes",
    dist=2700.0,
    terr=1.0,
    niveau=2.3,
    partants=2,
    horses=[
        vision_client.HorseProgrammeExtrait(
            num=1, name="CHEVAL UN", age=5, poids=58.0, cote=3.2,
            perfs=[vision_client.PerfProgrammeExtraite(rank=1, incident=""),
                   vision_client.PerfProgrammeExtraite(rank=None, incident="D")],
        ),
        vision_client.HorseProgrammeExtrait(
            num=2, name="CHEVAL DEUX", age=4, poids=57.0, cote=None, perfs=[],
        ),
    ],
)


def test_extraction_fiche_png_valide_renvoie_200_et_les_donnees_mockees(monkeypatch):
    appels = []

    def _fake_extract_fiche_cheval(file_bytes, media_type):
        appels.append((file_bytes, media_type))
        return FICHE_EXTRAITE

    monkeypatch.setattr(routes_analyse.vision_client, "extract_fiche_cheval", _fake_extract_fiche_cheval)

    fichier_bytes = b"contenu-png-simule"
    response = client.post(
        "/extraction/fiche",
        files={"file": ("fiche.png", fichier_bytes, "image/png")},
    )

    assert response.status_code == 200
    assert response.json() == dataclasses.asdict(FICHE_EXTRAITE)
    assert appels == [(fichier_bytes, "image/png")]


def test_extraction_programme_pdf_valide_appelle_vision_client_avec_bytes_et_media_type_exacts(monkeypatch):
    appels = []

    def _fake_extract_programme(file_bytes, media_type):
        appels.append((file_bytes, media_type))
        return PROGRAMME_EXTRAIT

    monkeypatch.setattr(routes_analyse.vision_client, "extract_programme", _fake_extract_programme)

    fichier_bytes = b"%PDF-1.4 contenu-pdf-simule"
    response = client.post(
        "/extraction/programme",
        files={"file": ("programme.pdf", fichier_bytes, "application/pdf")},
    )

    assert response.status_code == 200
    assert response.json() == dataclasses.asdict(PROGRAMME_EXTRAIT)
    assert appels == [(fichier_bytes, "application/pdf")]


@pytest.mark.parametrize("endpoint,fn_name", [
    ("/extraction/fiche", "extract_fiche_cheval"),
    ("/extraction/programme", "extract_programme"),
])
def test_extraction_content_type_non_supporte_rejete_400_sans_appeler_vision_client(monkeypatch, endpoint, fn_name):
    appels = []
    monkeypatch.setattr(
        routes_analyse.vision_client, fn_name,
        lambda file_bytes, media_type: appels.append((file_bytes, media_type)),
    )

    response = client.post(endpoint, files={"file": ("notes.txt", b"pas une image", "text/plain")})

    assert response.status_code == 400
    assert appels == []


@pytest.mark.parametrize("endpoint,fn_name", [
    ("/extraction/fiche", "extract_fiche_cheval"),
    ("/extraction/programme", "extract_programme"),
])
def test_extraction_budget_vision_epuise_renvoie_429_message_generique(monkeypatch, endpoint, fn_name):
    def _raise_budget(file_bytes, media_type):
        raise vision_client.VisionBudgetExceeded("Plafond quotidien d'appels vision atteint (50)")

    monkeypatch.setattr(routes_analyse.vision_client, fn_name, _raise_budget)

    response = client.post(endpoint, files={"file": ("fiche.png", b"donnees", "image/png")})

    assert response.status_code == 429
    detail = response.json()["detail"]
    # Le detail doit rester generique/surete-utilisateur, jamais l'echo du
    # message brut de l'exception capturee (Boundaries & Constraints du spec).
    assert "50" not in detail
    assert "Plafond quotidien" not in detail


@pytest.mark.parametrize("endpoint,fn_name", [
    ("/extraction/fiche", "extract_fiche_cheval"),
    ("/extraction/programme", "extract_programme"),
])
def test_extraction_echec_vision_renvoie_502_message_generique(monkeypatch, endpoint, fn_name):
    def _raise_extraction_error(file_bytes, media_type):
        raise vision_client.VisionExtractionError("fragment de reponse upstream sensible")

    monkeypatch.setattr(routes_analyse.vision_client, fn_name, _raise_extraction_error)

    response = client.post(endpoint, files={"file": ("fiche.png", b"donnees", "image/png")})

    assert response.status_code == 502
    detail = response.json()["detail"]
    assert "fragment de reponse upstream sensible" not in detail


@pytest.mark.parametrize("endpoint,fn_name,content_type", [
    ("/extraction/fiche", "extract_fiche_cheval", "image/jpeg"),
    ("/extraction/fiche", "extract_fiche_cheval", "image/webp"),
    ("/extraction/fiche", "extract_fiche_cheval", "image/gif"),
])
def test_extraction_accepte_individuellement_chaque_type_image_supporte(monkeypatch, endpoint, fn_name, content_type):
    # verification-gap (revue de code) : seuls image/png et application/pdf
    # etaient exerces par les tests precedents - un retrecissement silencieux
    # de ACCEPTED_EXTRACTION_CONTENT_TYPES (perdant jpeg/webp/gif) serait
    # passe inapercu. Chacun des 3 types restants ici, individuellement.
    monkeypatch.setattr(routes_analyse.vision_client, fn_name, lambda file_bytes, media_type: FICHE_EXTRAITE)

    response = client.post(endpoint, files={"file": ("fiche", b"donnees", content_type)})

    assert response.status_code == 200


@pytest.mark.parametrize("content_type_envoye", ["IMAGE/PNG", "image/png; charset=binary", " image/png "])
def test_extraction_content_type_normalise_avant_comparaison(monkeypatch, content_type_envoye):
    # blind-hunter + edge-case-hunter (revue de code) : la casse ou un
    # parametre de type ("; charset=...") ne doivent pas faire rejeter a
    # tort un type par ailleurs supporte.
    monkeypatch.setattr(routes_analyse.vision_client, "extract_fiche_cheval", lambda fb, mt: FICHE_EXTRAITE)

    response = client.post("/extraction/fiche", files={"file": ("fiche.png", b"donnees", content_type_envoye)})

    assert response.status_code == 200


def test_extraction_fichier_vide_rejete_400_sans_appeler_vision_client(monkeypatch):
    # edge-case-hunter (revue de code) : un upload de 0 octet avec un
    # content-type accepte ne doit pas consommer de budget vision pour rien.
    appels = []
    monkeypatch.setattr(
        routes_analyse.vision_client, "extract_fiche_cheval",
        lambda file_bytes, media_type: appels.append((file_bytes, media_type)),
    )

    response = client.post("/extraction/fiche", files={"file": ("fiche.png", b"", "image/png")})

    assert response.status_code == 400
    assert appels == []


def test_extraction_fichier_trop_volumineux_rejete_413_sans_appeler_vision_client(monkeypatch):
    appels = []
    monkeypatch.setattr(
        routes_analyse.vision_client, "extract_fiche_cheval",
        lambda file_bytes, media_type: appels.append((file_bytes, media_type)),
    )
    trop_gros = b"x" * (routes_analyse.MAX_EXTRACTION_FILE_SIZE_BYTES + 1)

    response = client.post("/extraction/fiche", files={"file": ("fiche.png", trop_gros, "image/png")})

    assert response.status_code == 413
    assert appels == []


def test_extraction_reponse_mal_formee_de_vision_client_renvoie_502_pas_500(monkeypatch):
    # edge-case-hunter (revue de code) : si vision_client renvoyait jamais un
    # objet dont un champ imbrique requis (incident: str, sans defaut sur
    # PerfFicheOut) est absent - ValidationError - la route doit degrader
    # vers le meme 502 documente, pas une 500 brute non geree. Un objet SANS
    # aucun attribut ne suffit pas a le prouver : perfs a un defaut ([]) au
    # niveau racine, donc il faut une entree de perfs elle-meme incomplete.
    class _PerfSansIncident:
        rank = 1
        part = None
        niveau = None
        dist = None
        terr = None
        # "incident" delibrement absent : champ requis sur PerfFicheOut.

    class _FicheAvecPerfMalformee:
        name = "X"
        num = None
        age = None
        poids = None
        cote = None
        perfs = [_PerfSansIncident()]

    monkeypatch.setattr(
        routes_analyse.vision_client, "extract_fiche_cheval",
        lambda file_bytes, media_type: _FicheAvecPerfMalformee(),
    )

    response = client.post("/extraction/fiche", files={"file": ("fiche.png", b"donnees", "image/png")})

    assert response.status_code == 502
