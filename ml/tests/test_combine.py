import json
import math
from datetime import date, timedelta

import numpy as np
import pandas as pd
import pytest

from conftest import GRILLE_TEST, ITERATIONS_TEST, PERIODES, ecrire, lignes_synthetiques
from hippique_ml import combine
from hippique_ml.combine import (
    ajuster, combiner, course_complete, evaluer_periode_combine, log_vraisemblance, main, par_course_combine,
    porte, proba_marche, variables,
)
from hippique_ml.data import ErreurDonnees
from hippique_ml.model import softmax_par_course
from hippique_ml.train import executer as entrainer_etape2


def silence(*_):
    return None


def etape2(dossier, lignes):
    """Run d'étape 2 miniature : table synthétique + modèle entraîné."""
    dossier.mkdir(parents=True, exist_ok=True)
    features = ecrire(dossier, lignes)
    run = dossier / "run2"
    entrainer_etape2(features, str(run), PERIODES, grille=GRILLE_TEST, iterations=ITERATIONS_TEST, journal=silence)
    return features, str(run)


@pytest.fixture(scope="module")
def run_etape2(tmp_path_factory):
    lignes = lignes_synthetiques()
    features, run = etape2(tmp_path_factory.mktemp("etape2"), lignes)
    return features, run, lignes


def lancer(run, features, sortie):
    return combine.executer(run, features, str(sortie), journal=silence)


# --- Normal run ------------------------------------------------------------

def test_run_normal(run_etape2, tmp_path):
    features, run, _ = run_etape2
    sortie = tmp_path / "combine"
    rapport = lancer(run, features, sortie)
    for nom in ("combine.json", "report.json", "report.md", "test_predictions.csv.gz"):
        assert (sortie / nom).exists(), nom

    with open(f"{run}/params.json", encoding="utf-8") as fichier:
        params = json.load(fichier)
    coeffs = json.loads((sortie / "combine.json").read_text(encoding="utf-8"))
    for cle in ("alpha", "beta", "se_alpha", "se_beta", "run_etape2", "params_json_sha256", "versions"):
        assert cle in coeffs, cle
    assert coeffs["se_alpha"] > 0 and coeffs["se_beta"] > 0
    assert coeffs["versions"]["catboost"] and coeffs["versions"]["numpy"]
    assert len(coeffs["params_json_sha256"]) == 64
    assert len(coeffs["model_cbm_sha256"]) == 64 and len(coeffs["features_sha256"]) == 64
    assert coeffs["converge"] is True and coeffs["norme_gradient"] >= 0
    assert params["temperature"] == coeffs["temperature_etape2"]

    predictions = pd.read_csv(sortie / "test_predictions.csv.gz")
    assert list(predictions.columns) == [
        "course_id", "num_pmu", "date", "discipline", "proba_modele", "gagnant", "cote_reference", "cote_direct",
        "proba_marche", "proba_combinee",
    ]
    assert predictions["date"].min() >= "2025-01-28"
    for colonne in ("proba_combinee", "proba_marche", "proba_modele"):
        assert np.allclose(predictions.groupby("course_id")[colonne].sum(), 1.0, atol=1e-9), colonne
    test = rapport["resultats"]["test"]["global"]
    assert test["courses"] == 7 * 6 == predictions["course_id"].nunique()
    assert set(rapport["resultats"]["test"]["disciplines"]) == {"plat", "trot"}
    assert rapport["porte"]["passee"] == (
        test["combine_moins_marche"]["moyenne"] < 0 and test["combine_moins_marche"]["ic95_haut"] < 0)

    md = (sortie / "report.md").read_text(encoding="utf-8")
    assert "| α (fundamental) |" in md and "| β (market) |" in md
    assert md.count("Gate PASSED: test combined - market") + md.count("Gate FAILED: test combined - market") == 2
    assert "closing" in md


def test_cote_direct_jamais_une_entree(run_etape2, tmp_path):
    features, run, lignes = run_etape2
    a = lancer(run, features, tmp_path / "a")
    autres = [dict(l, cote_direct=round(l["cote_direct"] * 3 + 1, 1)) for l in lignes]
    features_b = ecrire(tmp_path, autres, nom="b.csv.gz")
    b = lancer(run, features_b, tmp_path / "b")
    assert a["ajustement"] == b["ajustement"]
    assert a["resultats"]["test"]["global"]["log_loss_combine"] == b["resultats"]["test"]["global"]["log_loss_combine"]
    assert (a["resultats"]["test"]["global"]["cloture"]["log_loss_marche_cloture"]
            != b["resultats"]["test"]["global"]["cloture"]["log_loss_marche_cloture"])


def test_determinisme(run_etape2, tmp_path):
    features, run, _ = run_etape2
    a, b = lancer(run, features, tmp_path / "a"), lancer(run, features, tmp_path / "b")
    assert a["ajustement"] == b["ajustement"] and a["resultats"] == b["resultats"]


# --- Wrong table -------------------------------------------------------------

def test_git_sha_different_refuse(run_etape2, tmp_path, capsys, registre):
    features, run, lignes = run_etape2
    registre["git_sha"] = "autre"
    autre = ecrire(tmp_path, lignes, registre)
    assert main(["--run", run, "--features", autre, "--sortie", str(tmp_path / "c")]) == 2
    assert "git_sha" in capsys.readouterr().err
    assert not (tmp_path / "c").exists()


def test_table_modifiee_refusee(run_etape2, tmp_path, capsys):
    features, run, lignes = run_etape2
    autres = [dict(l, f_force=round(l["f_force"] + 0.7 * (l["num_pmu"] % 3), 6))
              if l["date"] >= "2025-01-28" else l for l in lignes]
    autre = ecrire(tmp_path, autres)
    assert main(["--run", run, "--features", autre, "--sortie", str(tmp_path / "c")]) == 2
    assert "probabilités de test recalculées" in capsys.readouterr().err
    assert not (tmp_path / "c").exists()


def test_partants_de_test_differents_refuses(run_etape2, tmp_path, capsys):
    features, run, lignes = run_etape2
    derniere = max(l["course_id"] for l in lignes)
    autre = ecrire(tmp_path, [l for l in lignes if l["course_id"] != derniere])
    assert main(["--run", run, "--features", autre, "--sortie", str(tmp_path / "c")]) == 2
    assert "d'un seul côté" in capsys.readouterr().err
    assert not (tmp_path / "c").exists()


def test_run_incomplet_refuse(tmp_path, capsys, run_etape2):
    features, _, _ = run_etape2
    (tmp_path / "vide").mkdir()
    assert main(["--run", str(tmp_path / "vide"), "--features", features, "--sortie", str(tmp_path / "c")]) == 2
    assert "incomplet" in capsys.readouterr().err
    assert not (tmp_path / "c").exists()


# --- Missing odds ------------------------------------------------------------

def test_cotes_manquantes_exclues_et_comptees(run_etape2, tmp_path):
    features, run, lignes = run_etape2
    valid = sorted({l["course_id"] for l in lignes if "2025-01-21" <= l["date"] <= "2025-01-27"})
    test = sorted({l["course_id"] for l in lignes if l["date"] >= "2025-01-28"})
    abimees = {valid[0]: "", valid[1]: 0, test[0]: "", test[1]: 0, test[2]: -3}
    autres = [dict(l, cote_reference=abimees[l["course_id"]]) if l["course_id"] in abimees and l["num_pmu"] == 2
              else l for l in lignes]
    rapport = lancer(run, ecrire(tmp_path, autres), tmp_path / "c")
    v, t = rapport["resultats"]["validation"]["global"], rapport["resultats"]["test"]["global"]
    assert v["courses_cotes_incompletes"] == 2 and v["courses"] == 7 * 6 - 2
    assert t["courses_cotes_incompletes"] == 3 and t["courses"] == 7 * 6 - 3
    assert t["partants_cotes_incompletes"] == sum(l["course_id"] in test[:3] for l in lignes)
    assert rapport["ajustement"]["courses"] == 7 * 6 - 2
    predictions = pd.read_csv(tmp_path / "c" / "test_predictions.csv.gz")
    assert not set(test[:3]) & set(predictions["course_id"])


@pytest.mark.parametrize("cote", [np.nan, 0.0, np.inf, -2.0, "NP"])
def test_cote_invalide_rend_la_course_incomplete(cote):
    partants = pd.DataFrame({"course_id": [1, 1, 2, 2], "cote_reference": [2.0, cote, 3.0, 1.5]})
    assert list(course_complete(partants, "cote_reference")) == [False, False, True, True]
    p = proba_marche(partants, "cote_reference")
    assert np.isnan(p[:2]).all() and p[2:].sum() == pytest.approx(1.0)


# --- Dead heat -----------------------------------------------------------------

def test_ex_aequo_somme_des_gagnants():
    partants = pd.DataFrame({
        "course_id": [1, 1, 1, 1], "discipline": "trot", "gagnant": [1, 1, 0, 0],
        "proba_modele": [0.4, 0.2, 0.3, 0.1], "cote_reference": [2.0, 4.0, 4.0, 8.0],
        "cote_direct": [2.0, 4.0, 4.0, 8.0],
    })
    partants["proba_marche"] = proba_marche(partants, "cote_reference")
    theta = np.array([0.6, 0.8])
    X = variables(partants["proba_modele"], partants["proba_marche"])
    partants["proba_combinee"] = softmax_par_course(X @ theta, partants["course_id"].to_numpy())
    courses = par_course_combine(partants)
    p = partants["proba_combinee"].to_numpy()
    assert courses.loc[1, "log_loss_combine"] == pytest.approx(-math.log(p[0] + p[1]))
    assert courses.loc[1, "log_loss_modele"] == pytest.approx(-math.log(0.6))
    assert courses.loc[1, "log_loss_marche"] == pytest.approx(-math.log((0.5 + 0.25) / 1.125))
    ll, _, _ = log_vraisemblance(theta, X, partants["gagnant"].to_numpy(), partants["course_id"].to_numpy())
    assert ll == pytest.approx(math.log(p[0] + p[1]))


# --- Signal check ----------------------------------------------------------------

def lignes_signal_cache(jours=34, courses_par_jour=25, graine=3, poids_cache=1.5):
    """Le gagnant dépend de f_force et de f_bruit ; les cotes ne connaissent que f_force."""
    rng = np.random.default_rng(graine)
    lignes, course_id = [], 0
    for j in range(jours):
        jour = date(2025, 1, 1) + timedelta(days=j)
        for _ in range(courses_par_jour):
            course_id += 1
            n = int(rng.integers(5, 12))
            force, cache = rng.normal(size=n), rng.normal(size=n)
            gagnant = int(np.argmax(force + poids_cache * cache + rng.gumbel(size=n)))
            p_marche = np.exp(force) / np.exp(force).sum()
            for i in range(n):
                cote = round(max(1.1, 0.85 / p_marche[i]), 1)
                lignes.append({
                    "course_id": course_id, "date": jour.isoformat(),
                    "discipline": "trot" if course_id % 2 else "plat", "num_pmu": i + 1,
                    "rang": 1 if i == gagnant else "", "gagnant": int(i == gagnant), "place": int(i == gagnant),
                    "cote_reference": cote, "cote_direct": cote,
                    "f_force": round(float(force[i]), 6), "f_bruit": round(float(cache[i]), 6),
                    "f_inedit": int(rng.integers(0, 2)), "f_sexe": "M" if i % 2 else "F",
                })
    return lignes


def test_signal_absent_des_cotes(tmp_path):
    features, run = etape2(tmp_path / "e2", lignes_signal_cache())
    rapport = lancer(run, features, tmp_path / "c")
    assert rapport["ajustement"]["alpha"] > 0
    test = rapport["resultats"]["test"]["global"]
    assert test["log_loss_combine"] < test["log_loss_marche"]
    assert rapport["porte"]["passee"]


# --- No signal -------------------------------------------------------------------

def courses_simulees(n_courses, graine, partants=8):
    """Cotes = probabilités vraies exactes ; le fondamental est uniforme."""
    rng = np.random.default_rng(graine)
    ids = np.repeat(np.arange(n_courses), partants)
    vrai = softmax_par_course(rng.normal(size=len(ids)) * 1.2, ids)
    gagnant = np.zeros(len(ids), dtype=int)
    for k in range(n_courses):
        gagnant[k * partants + rng.choice(partants, p=vrai[k * partants:(k + 1) * partants])] = 1
    return pd.DataFrame({
        "course_id": ids + graine * 1_000_000, "discipline": np.where(ids % 2, "trot", "plat"), "gagnant": gagnant,
        "proba_modele": 1.0 / partants, "cote_reference": 1.0 / vrai, "cote_direct": 1.0 / vrai,
    })


def test_fondamental_uniforme_sans_signal():
    ajustement, parties = combiner(courses_simulees(3000, 1), courses_simulees(3000, 2))
    assert abs(ajustement.alpha) < 1e-9
    assert ajustement.beta == pytest.approx(1.0, abs=0.1)
    assert not ajustement.identifiable  # log p_fond constant dans chaque course
    verdict = porte(evaluer_periode_combine(parties["test"])["global"])
    assert not verdict["passee"] and verdict["verdict"].startswith("Gate FAILED")


# --- Existing output -------------------------------------------------------------

def test_sortie_existante_refusee(run_etape2, tmp_path, capsys):
    features, run, _ = run_etape2
    sortie = tmp_path / "c"
    sortie.mkdir()
    (sortie / "report.json").write_text("{}", encoding="utf-8")
    assert main(["--run", run, "--features", features, "--sortie", str(sortie)]) == 2
    assert "déjà un run" in capsys.readouterr().err
    assert (sortie / "report.json").read_text(encoding="utf-8") == "{}"
    assert sorted(p.name for p in sortie.iterdir()) == ["report.json"]


# --- Fit units -------------------------------------------------------------------

def _simuler_logit(theta, n_courses=4000, partants=7, graine=5):
    rng = np.random.default_rng(graine)
    ids = np.repeat(np.arange(n_courses), partants)
    X = rng.normal(size=(len(ids), 2)) * [1.0, 1.5]
    p = softmax_par_course(X @ np.asarray(theta), ids)
    gagnants = np.zeros(len(ids), dtype=int)
    for k in range(n_courses):
        gagnants[k * partants + rng.choice(partants, p=p[k * partants:(k + 1) * partants])] = 1
    return X, gagnants, ids


def test_newton_retrouve_alpha_beta():
    X, gagnants, ids = _simuler_logit((0.7, 0.4))
    a = ajuster(X, gagnants, ids)
    assert a.identifiable
    assert a.alpha == pytest.approx(0.7, abs=max(0.1, 3 * a.se_alpha))
    assert a.beta == pytest.approx(0.4, abs=max(0.1, 3 * a.se_beta))
    assert a.log_vraisemblance >= a.log_vraisemblance_depart
    _, grad, _ = log_vraisemblance(a.theta, X, gagnants, ids)
    assert np.abs(grad).max() < 1e-4


def test_gradient_et_hessien_par_differences_finies():
    X, gagnants, ids = _simuler_logit((0.3, 0.9), n_courses=200)
    gagnants[1] = 1  # un ex aequo dans la première course
    theta, h = np.array([0.5, 0.6]), 1e-5
    _, grad, hess = log_vraisemblance(theta, X, gagnants, ids)
    for j in range(2):
        e = np.zeros(2)
        e[j] = h
        lp, gp, _ = log_vraisemblance(theta + e, X, gagnants, ids)
        lm, gm, _ = log_vraisemblance(theta - e, X, gagnants, ids)
        assert grad[j] == pytest.approx((lp - lm) / (2 * h), rel=1e-5, abs=1e-6)
        assert hess[:, j] == pytest.approx((gp - gm) / (2 * h), rel=1e-4, abs=1e-5)


def test_ajustement_sans_course_refuse():
    with pytest.raises(ErreurDonnees):
        ajuster(np.zeros((0, 2)), np.zeros(0), np.zeros(0))


# --- Review loop 1: rates, filtering, refusals, test isolation -------------------

def _partants(lignes):
    t = pd.DataFrame(lignes, columns=["course_id", "discipline", "gagnant", "proba_modele", "proba_marche",
                                      "proba_combinee", "cote_reference", "cote_direct"])
    return t


def test_taux_top_et_favori_avec_egalite_et_course_incomplete():
    partants = _partants([
        # course 1 : complète ; égalité du combiné (0.4/0.4), gagnant = dossard 2 ; favori unique gagnant
        (1, "plat", 0, 0.5, 0.3, 0.4, 3.0, 3.0),
        (1, "plat", 1, 0.3, 0.5, 0.4, 2.0, 2.0),
        (1, "plat", 0, 0.2, 0.2, 0.2, 5.0, 5.0),
        # course 2 : complète ; le top combiné perd, le favori perd, le top fondamental gagne
        (2, "plat", 0, 0.2, 0.6, 0.6, 1.5, 1.5),
        (2, "plat", 1, 0.8, 0.4, 0.4, 3.0, 3.0),
        # course 3 : cote manquante -> hors comparaison, quelle que soit sa réussite
        (3, "plat", 1, 0.9, np.nan, np.nan, np.nan, 2.0),
        (3, "plat", 0, 0.1, np.nan, np.nan, 4.0, 4.0),
    ])
    bilan = evaluer_periode_combine(partants)["global"]
    assert bilan["courses"] == 2 and bilan["courses_cotes_incompletes"] == 1
    assert bilan["taux_top_combine"] == pytest.approx((0.5 + 0.0) / 2)
    assert bilan["taux_favori"] == pytest.approx((1.0 + 0.0) / 2)
    assert bilan["taux_top_modele"] == pytest.approx((0.0 + 1.0) / 2)
    # Log-loss fondamental sur les seules courses complètes (course 3 exclue).
    assert bilan["log_loss_modele"] == pytest.approx((-math.log(0.3) - math.log(0.8)) / 2)
    assert bilan["log_loss_combine"] == pytest.approx((-math.log(0.4) - math.log(0.4)) / 2)
    assert bilan["log_loss_marche"] == pytest.approx((-math.log(0.5) - math.log(0.4)) / 2)
    # Calibration : 5 partants des courses complètes, construite sur proba_combinee.
    assert sum(t["chevaux"] for t in bilan["calibration_combine"]) == 5
    assert sum(t["chevaux"] for t in bilan["calibration_marche"]) == 5
    tranche = next(t for t in bilan["calibration_combine"] if t["borne_basse"] == 0.3)
    assert tranche["chevaux"] == 3 and tranche["proba_moyenne"] == pytest.approx(0.4)


def _params(run):
    with open(f"{run}/params.json", encoding="utf-8") as fichier:
        return json.load(fichier)


def _copie_run(run, dossier, **changements):
    import shutil
    copie = dossier / "run_copie"
    shutil.copytree(run, copie)
    params = _params(run)
    params.update(changements)
    (copie / "params.json").write_text(json.dumps(params), encoding="utf-8")
    return str(copie)


@pytest.mark.parametrize("changement, message", [
    ({"temperature": 0}, "température invalide"),
    ({"temperature": "0.9"}, "params.json illisible"),
    ({"periodes": {"train": {"debut": None, "fin_exclue": "2025-01-21"},
                   "validation": {"debut": "2025-01-19", "fin": "2025-01-27"},
                   "test": {"debut": "2025-01-28", "fin": "2025-02-03"}}}, "périodes incohérentes"),
    ({"features": ["f_force"]}, "liste de features"),
    ({"categoriques": []}, "liste de features ou de catégorielles"),
])
def test_params_incoherents_refuses(run_etape2, tmp_path, capsys, changement, message):
    features, run, _ = run_etape2
    copie = _copie_run(run, tmp_path, **changement)
    assert main(["--run", copie, "--features", features, "--sortie", str(tmp_path / "c")]) == 2
    if message:
        assert message in capsys.readouterr().err
    assert not (tmp_path / "c").exists()


def test_params_sans_categoriques_refuse(run_etape2, tmp_path, capsys):
    features, run, _ = run_etape2
    copie = _copie_run(run, tmp_path)
    params = _params(copie)
    del params["categoriques"]
    with open(f"{copie}/params.json", "w", encoding="utf-8") as fichier:
        json.dump(params, fichier)
    assert main(["--run", copie, "--features", features, "--sortie", str(tmp_path / "c")]) == 2
    assert "categoriques" in capsys.readouterr().err
    assert not (tmp_path / "c").exists()


def test_validation_sans_cotes_refusee_avant_sortie(run_etape2, tmp_path, capsys):
    features, run, lignes = run_etape2
    sans = [dict(l, cote_reference="") if "2025-01-21" <= l["date"] <= "2025-01-27" else l for l in lignes]
    autre = ecrire(tmp_path, sans)
    assert main(["--run", run, "--features", autre, "--sortie", str(tmp_path / "c")]) == 2
    assert "sans course aux cotes" in capsys.readouterr().err
    assert not (tmp_path / "c").exists()


def test_test_jamais_utilise_pour_l_ajustement():
    validation = courses_simulees(800, 11)
    test_a = courses_simulees(500, 12)
    test_b = test_a.copy()
    rng = np.random.default_rng(4)
    test_b["cote_reference"] = test_b["cote_reference"] * rng.uniform(0.5, 2.0, len(test_b))
    test_b["gagnant"] = test_b.groupby("course_id")["gagnant"].transform(lambda s: np.roll(s.to_numpy(), 1))
    a, _ = combiner(validation, test_a)
    b, _ = combiner(validation, test_b)
    assert a.to_dict() == b.to_dict()


def test_course_sans_gagnant_refusee():
    validation = courses_simulees(200, 21)
    validation.loc[validation["course_id"] == validation["course_id"].iloc[0], "gagnant"] = 0
    with pytest.raises(ErreurDonnees, match="sans gagnant"):
        combiner(validation, courses_simulees(100, 22))


def test_predictions_sauvegardees_en_double_refusees():
    recalcul = pd.DataFrame({"course_id": [1, 1], "num_pmu": [1, 2], "proba_modele": [0.4, 0.6]})
    sauvegarde = pd.concat([recalcul, recalcul.iloc[[0]]])
    with pytest.raises(ErreurDonnees, match="double"):
        combine.verifier_predictions(recalcul, sauvegarde)
    with pytest.raises(ErreurDonnees, match="colonne"):
        combine.verifier_predictions(recalcul, recalcul.drop(columns=["proba_modele"]))


def test_convergence_signalee():
    X, gagnants, ids = _simuler_logit((0.7, 0.4), n_courses=500)
    a = ajuster(X, gagnants, ids)
    assert a.converge and a.norme_gradient < 1e-6 * a.courses
    ancien = combine.ITERATIONS_MAX
    combine.ITERATIONS_MAX = 1
    try:
        b = ajuster(X, gagnants, ids)
    finally:
        combine.ITERATIONS_MAX = ancien
    assert not b.converge
    verdict = porte({"combine_moins_marche": {"moyenne": -0.1, "ic95_bas": -0.2, "ic95_haut": -0.05}}, b)
    assert "did not converge" in verdict["verdict"]


def test_erreurs_standard_jamais_nan_dans_le_json(tmp_path):
    ajustement, _ = combiner(courses_simulees(500, 31), courses_simulees(200, 32))
    texte = json.dumps(ajustement.to_dict(), allow_nan=False)  # lève si NaN
    assert "se_alpha" in texte
