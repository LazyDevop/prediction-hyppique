import json
import math
import re
import os
from datetime import date

import numpy as np
import pandas as pd
import pytest

from conftest import GRILLE_TEST, ITERATIONS_TEST, PERIODES, ecrire, lignes_synthetiques
from hippique_ml import evaluate
from hippique_ml.data import ErreurDonnees, Periodes, decouper, lire_registre, lire_table, valider_registre
from hippique_ml.model import ajuster_temperature, log_loss_moyen, softmax_par_course
from hippique_ml.train import executer, main


def lancer(features, sortie):
    return executer(features, str(sortie), PERIODES, grille=GRILLE_TEST, iterations=ITERATIONS_TEST,
                    journal=lambda *_: None)


# --- Normal run ------------------------------------------------------------

def test_run_normal_ecrit_rapport_et_artefacts(table_synthetique, tmp_path):
    sortie = tmp_path / "run"
    rapport = lancer(table_synthetique, sortie)
    for nom in ("model.cbm", "params.json", "report.json", "report.md", "test_predictions.csv.gz"):
        assert (sortie / nom).exists(), nom

    predictions = pd.read_csv(sortie / "test_predictions.csv.gz")
    assert list(predictions.columns) == [
        "course_id", "num_pmu", "date", "discipline", "proba_modele", "gagnant", "cote_reference", "cote_direct",
    ]
    assert predictions["date"].min() >= "2025-01-28"
    sommes = predictions.groupby("course_id")["proba_modele"].sum()
    assert np.allclose(sommes, 1.0, atol=1e-9)

    params = json.loads((sortie / "params.json").read_text(encoding="utf-8"))
    assert params["features"] == ["f_force", "f_bruit", "f_inedit", "f_sexe"]
    assert params["registre_git_sha"] == "abc123"
    assert params["temperature"] > 0 and params["graine"] == 42
    assert params["versions"]["catboost"] and params["versions"]["pandas"] and params["versions"]["numpy"]
    assert params["categoriques"] == ["f_sexe"]
    assert params["periodes"]["test"] == {"debut": "2025-01-28", "fin": "2025-02-03"}

    test = rapport["resultats"]["test"]["global"]
    assert test["courses"] == 7 * 6
    assert test["log_loss_modele"] < test["log_loss_uniforme"]  # f_force porte le signal
    assert set(rapport["resultats"]["test"]["disciplines"]) == {"plat", "trot"}
    assert len(rapport["importances"]) == 4 and rapport["importances"][0]["feature"] == "f_force"
    md = (sortie / "report.md").read_text(encoding="utf-8")
    assert "Gate PASSED: test log-loss" in md or "Gate FAILED: test log-loss" in md
    section_test = md.split("### test")[1].split("## Top 20")[0]
    assert "model − uniform" in section_test and "model − market" in section_test
    assert len(re.findall(r"\[[-+]\d\.\d{3}, [-+]\d\.\d{3}\]", section_test)) >= 2
    assert rapport["porte"]["passee"] == (test["log_loss_modele"] <= 2.30)


def test_categorie_absente_reste_une_modalite_sans_imputation(table_synthetique):
    registre = lire_registre(f"{table_synthetique}.registry.json")
    table = lire_table(table_synthetique, registre)
    assert table["f_bruit"].isna().sum() > 0  # numérique vide = NaN
    assert "__absent__" in set(table["f_sexe"])
    assert registre.categoriques == ["f_sexe"]


# --- Leaky registry --------------------------------------------------------

@pytest.mark.parametrize("colonne", ["cote_direct", "rang", "cote_reference", "gagnant", "course_id"])
def test_registre_fuyant_refuse(tmp_path, registre, colonne, capsys):
    for c in registre["colonnes"]:
        if c["nom"] == colonne:
            c["groupe"] = "feature"
    features = ecrire(tmp_path, lignes_synthetiques(jours=3), registre)
    code = main(["--features", features, "--sortie", str(tmp_path / "run")])
    assert code != 0
    assert colonne in capsys.readouterr().err
    assert not (tmp_path / "run").exists()


def test_registre_feature_non_prefixee_refusee(registre):
    registre["colonnes"].append({"nom": "ordreArrivee", "groupe": "feature", "type": "numeric"})
    with pytest.raises(ErreurDonnees, match="ordreArrivee"):
        valider_registre(registre)


# --- Period too small ------------------------------------------------------

@pytest.mark.parametrize("periode, periodes", [
    ("test", Periodes(date(2025, 1, 21), date(2025, 1, 27), date(2025, 2, 3))),
    ("validation", Periodes(date(2025, 1, 21), date(2025, 1, 21), date(2025, 2, 3))),
    ("train", Periodes(date(2025, 1, 1), date(2025, 1, 27), date(2025, 2, 3))),
])
def test_periode_vide_refusee(tmp_path, periode, periodes, capsys):
    lignes = [l for l in lignes_synthetiques() if not (
        (periode == "test" and l["date"] >= "2025-01-28")
        or (periode == "validation" and "2025-01-21" <= l["date"] <= "2025-01-27"))]
    features = ecrire(tmp_path, lignes)
    code = main(["--features", features, "--sortie", str(tmp_path / "run"),
                 "--train-fin", periodes.train_fin.isoformat(), "--valid-fin", periodes.valid_fin.isoformat(),
                 "--test-fin", periodes.test_fin.isoformat()])
    assert code != 0
    assert f"'{periode}'" in capsys.readouterr().err


# --- Odd races -------------------------------------------------------------

def test_courses_atypiques(tmp_path):
    lignes = lignes_synthetiques()
    test_ids = sorted({l["course_id"] for l in lignes if l["date"] >= "2025-01-28"})
    sans_gagnant, ex_aequo, seul = test_ids[:3]
    for l in lignes:
        if l["course_id"] == sans_gagnant:
            l["gagnant"] = 0
        if l["course_id"] == ex_aequo and l["num_pmu"] in (1, 2):
            l["gagnant"] = 1
    n_ex_aequo = sum(l["course_id"] == ex_aequo for l in lignes)
    n_sans = sum(l["course_id"] == sans_gagnant for l in lignes)
    lignes = [l for l in lignes if l["course_id"] != seul or l["num_pmu"] == 1]
    lignes = [dict(l, gagnant=1) if l["course_id"] == seul else l for l in lignes]
    features = ecrire(tmp_path, lignes)

    registre = lire_registre(f"{features}.registry.json")
    decoupe, exclusions = decouper(lire_table(features, registre), PERIODES)
    assert exclusions["test"].courses_sans_gagnant == 1 and exclusions["test"].partants_sans_gagnant == n_sans
    assert exclusions["test"].courses_un_partant == 1 and exclusions["test"].partants_un_partant == 1
    assert exclusions["test"].courses_ex_aequo == 1
    assert exclusions["train"].courses_sans_gagnant == 0 and exclusions["validation"].courses_un_partant == 0
    assert ex_aequo in set(decoupe["test"]["course_id"])
    assert sans_gagnant not in set(decoupe["test"]["course_id"]) and seul not in set(decoupe["test"]["course_id"])

    rapport = lancer(features, tmp_path / "run")
    assert rapport["exclusions"]["test"]["courses_sans_gagnant"] == 1
    assert rapport["exclusions"]["test"]["courses_un_partant"] == 1
    assert rapport["resultats"]["test"]["global"]["courses"] == 7 * 6 - 2

    predictions = pd.read_csv(tmp_path / "run" / "test_predictions.csv.gz")
    course = predictions[predictions["course_id"] == ex_aequo]
    assert len(course) == n_ex_aequo
    attendu = -math.log(course.loc[course["gagnant"] == 1, "proba_modele"].sum())
    assert evaluate.par_course(course).loc[ex_aequo, "log_loss_modele"] == pytest.approx(attendu)


def test_ex_aequo_log_loss_somme_des_gagnants():
    partants = pd.DataFrame({
        "course_id": [1, 1, 1, 1], "discipline": "trot", "gagnant": [1, 1, 0, 0],
        "proba_modele": [0.4, 0.2, 0.3, 0.1], "cote_reference": [2.0, 4.0, 4.0, 8.0],
    })
    courses = evaluate.par_course(partants)
    assert courses.loc[1, "log_loss_modele"] == pytest.approx(-math.log(0.6))
    assert courses.loc[1, "log_loss_uniforme"] == pytest.approx(math.log(2))


# --- Missing odds ----------------------------------------------------------

def test_cotes_manquantes_exclues_du_marche_seulement():
    partants = pd.DataFrame({
        "course_id": [1, 1, 1, 2, 2, 2], "discipline": "plat", "gagnant": [1, 0, 0, 0, 1, 0],
        "proba_modele": [0.5, 0.3, 0.2, 0.2, 0.5, 0.3], "cote_reference": [2.0, 4.0, 4.0, 3.0, np.nan, 2.0],
    })
    bilan = evaluate.evaluer_periode(partants)["global"]
    assert bilan["courses"] == 2
    assert bilan["marche"]["courses"] == 1 and bilan["marche"]["courses_cotes_incompletes"] == 1
    # Course 1 : p marché = (1/2) / (1/2 + 1/4 + 1/4) = 0.5
    assert bilan["marche"]["log_loss_marche"] == pytest.approx(-math.log(0.5))
    assert bilan["marche"]["log_loss_modele"] == pytest.approx(-math.log(0.5))
    assert bilan["marche"]["taux_favori"] == 1.0
    assert bilan["log_loss_modele"] == pytest.approx((-math.log(0.5) - math.log(0.5)) / 2)
    assert bilan["taux_top_modele"] == 1.0


# --- Determinism -----------------------------------------------------------

def test_determinisme(table_synthetique, tmp_path):
    a = lancer(table_synthetique, tmp_path / "a")
    b = lancer(table_synthetique, tmp_path / "b")
    assert a["resultats"] == b["resultats"]
    assert a["modele"] == b["modele"]
    pa = pd.read_csv(tmp_path / "a" / "test_predictions.csv.gz")
    pb = pd.read_csv(tmp_path / "b" / "test_predictions.csv.gz")
    pd.testing.assert_frame_equal(pa, pb)


# --- Metric units ----------------------------------------------------------

def test_log_loss_uniforme_vaut_log_n():
    n = 8
    partants = pd.DataFrame({
        "course_id": [1] * n, "discipline": "trot", "gagnant": [0] * (n - 1) + [1],
        "proba_modele": [1 / n] * n, "cote_reference": [5.0] * n,
    })
    courses = evaluate.par_course(partants)
    assert courses.loc[1, "log_loss_modele"] == pytest.approx(math.log(n))
    assert courses.loc[1, "log_loss_uniforme"] == pytest.approx(math.log(n))


def test_modele_parfait_vaut_zero():
    assert evaluate.log_loss_course([0.0, 1.0, 0.0], [0, 1, 0]) == pytest.approx(0.0)
    ids = np.array([1, 1, 2, 2])
    assert log_loss_moyen(np.array([1.0, 0.0, 0.0, 1.0]), np.array([1, 0, 0, 1]), ids) == pytest.approx(0.0)


def test_plancher_log_loss():
    assert evaluate.log_loss_course([1.0, 0.0], [0, 1]) == pytest.approx(-math.log(1e-6))


def test_softmax_par_course_somme_un():
    ids = np.array([1, 1, 1, 2, 2])
    p = softmax_par_course(np.array([1.0, 2.0, 3.0, 1000.0, -1000.0]), ids, 0.7)
    assert p[:3].sum() == pytest.approx(1.0, abs=1e-12) and p[3:].sum() == pytest.approx(1.0, abs=1e-12)
    with pytest.raises(ValueError):
        softmax_par_course(np.zeros(3), np.array([1, 2, 1]))


def test_temperature_retrouvee():
    rng = np.random.default_rng(1)
    ids = np.repeat(np.arange(3000), 6)
    scores = rng.normal(size=len(ids)) * 2
    vrai = softmax_par_course(scores, ids, 2.0)
    gagnants = np.zeros(len(ids), dtype=int)
    for k in range(3000):
        gagnants[k * 6 + rng.choice(6, p=vrai[k * 6:(k + 1) * 6])] = 1
    assert ajuster_temperature(scores, gagnants, ids) == pytest.approx(2.0, rel=0.15)


def test_calibration_tranches_backend():
    tranches = evaluate.calibration(np.array([0.01, 0.07, 0.5, 1.0]), np.array([0, 1, 1, 1]))
    assert [t["chevaux"] for t in tranches] == [1, 1, 0, 0, 0, 2]
    assert tranches[-1]["taux_victoire"] == 1.0


def test_bootstrap_ic_contient_moyenne_et_deterministe():
    d = np.random.default_rng(3).normal(-0.1, 0.5, size=500)
    a, b = evaluate.intervalle_bootstrap(d), evaluate.intervalle_bootstrap(d)
    assert a == b
    assert a["ic95_bas"] < a["moyenne"] < a["ic95_haut"]
    assert evaluate.intervalle_bootstrap(np.array([])) is None


# --- Test period never used for fitting --------------------------------------

def test_labels_du_test_sans_effet_sur_l_ajustement(tmp_path):
    lignes = lignes_synthetiques()
    rng = np.random.default_rng(7)
    melange = [dict(l) for l in lignes]
    for course_id in sorted({l["course_id"] for l in melange if l["date"] >= "2025-01-28"}):
        course = [l for l in melange if l["course_id"] == course_id]
        nouveau = int(rng.integers(0, len(course)))
        for i, l in enumerate(course):
            l["gagnant"] = int(i == nouveau)
            l["f_force"] = round(float(rng.normal()), 6)
    a = lancer(ecrire(tmp_path, lignes, nom="a.csv.gz"), tmp_path / "a")
    b = lancer(ecrire(tmp_path, melange, nom="b.csv.gz"), tmp_path / "b")
    assert a["modele"] == b["modele"]  # température, arbres, grille
    assert a["resultats"]["train"] == b["resultats"]["train"]
    assert a["resultats"]["validation"] == b["resultats"]["validation"]


# --- Input guards ------------------------------------------------------------

def _refus(tmp_path, lignes, capsys, attendu):
    features = ecrire(tmp_path, lignes)
    code = main(["--features", features, "--sortie", str(tmp_path / "run")])
    assert code == 2
    assert attendu in capsys.readouterr().err
    assert not (tmp_path / "run").exists()


def test_date_vide_refusee(tmp_path, capsys):
    lignes = lignes_synthetiques(jours=3)
    lignes[5]["date"] = ""
    _refus(tmp_path, lignes, capsys, "date")


def test_cote_non_numerique_refusee(tmp_path, capsys):
    lignes = lignes_synthetiques(jours=3)
    lignes[0]["cote_reference"] = "NP"
    _refus(tmp_path, lignes, capsys, "cote_reference")


def test_cote_infinie_refusee(tmp_path, capsys):
    lignes = lignes_synthetiques(jours=3)
    lignes[0]["cote_reference"] = "inf"
    _refus(tmp_path, lignes, capsys, "infinie")


@pytest.mark.parametrize("valeur", ["", 2])
def test_gagnant_vide_ou_hors_0_1_refuse(tmp_path, capsys, valeur):
    lignes = lignes_synthetiques(jours=3)
    lignes[0]["gagnant"] = valeur
    _refus(tmp_path, lignes, capsys, "gagnant")


def test_partant_en_double_refuse(tmp_path, capsys):
    lignes = lignes_synthetiques(jours=3)
    lignes.insert(1, dict(lignes[0]))
    _refus(tmp_path, lignes, capsys, "double")


def test_course_sur_deux_dates_refusee(tmp_path, capsys):
    lignes = lignes_synthetiques(jours=3)
    premiere = [l for l in lignes if l["course_id"] == 1]
    premiere[-1]["date"] = "2025-01-02"
    _refus(tmp_path, lignes, capsys, "plusieurs dates")


def test_registre_illisible_refuse(tmp_path, capsys):
    features = ecrire(tmp_path, lignes_synthetiques(jours=3))
    with open(f"{features}.registry.json", "w", encoding="utf-8") as fichier:
        fichier.write("{pas du json")
    assert main(["--features", features, "--sortie", str(tmp_path / "run")]) == 2
    assert "registre illisible" in capsys.readouterr().err


def test_run_existant_jamais_ecrase(table_synthetique, tmp_path, capsys):
    sortie = tmp_path / "run"
    sortie.mkdir()
    (sortie / "report.json").write_text("{}", encoding="utf-8")
    with pytest.raises(ErreurDonnees, match="déjà un run"):
        lancer(table_synthetique, sortie)
    assert (sortie / "report.json").read_text(encoding="utf-8") == "{}"


def test_egalites_comptees_a_parts_egales():
    partants = pd.DataFrame({
        "course_id": [1, 1, 1], "discipline": "plat", "gagnant": [0, 1, 0],
        "proba_modele": [0.4, 0.4, 0.2], "cote_reference": [3.0, 3.0, 5.0],
    })
    bilan = evaluate.evaluer_periode(partants)["global"]
    assert bilan["taux_top_modele"] == pytest.approx(0.5)
    assert bilan["marche"]["taux_favori"] == pytest.approx(0.5)


def test_cote_manquante_comptee_dans_un_run(tmp_path):
    lignes = lignes_synthetiques()
    course = min(l["course_id"] for l in lignes if l["date"] >= "2025-01-28")
    for l in lignes:
        if l["course_id"] == course and l["num_pmu"] == 1:
            l["cote_reference"] = ""
    rapport = lancer(ecrire(tmp_path, lignes), tmp_path / "run")
    test = rapport["resultats"]["test"]["global"]
    assert test["courses"] == 7 * 6
    assert test["marche"]["courses_cotes_incompletes"] == 1 and test["marche"]["courses"] == 7 * 6 - 1


def test_bootstrap_mille_tirages():
    assert evaluate.TIRAGES_BOOTSTRAP == 1000


def test_aucun_import_du_backend():
    dossier = os.path.join(os.path.dirname(__file__), "..", "hippique_ml")
    for nom in os.listdir(dossier):
        if nom.endswith(".py"):
            source = open(os.path.join(dossier, nom), encoding="utf-8").read()
            assert not re.search(r"^\s*(from|import)\s+(app|backend)\b", source, re.M), nom
