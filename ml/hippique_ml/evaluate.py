"""Métriques du rapport, par course puis agrégées.

Définitions alignées sur le tableau de bord du backend
(`backend/app/engine/evaluation.py`), recopiées et non importées :
log-loss par course plancher 1e-6, tranches de calibration identiques.
Ex aequo : le log-loss porte sur la somme des probabilités des gagnants.
Égalités de premier choix ou de favori : chaque cheval à égalité compte pour
1/k (taux fractionnaire), jamais "le plus petit dossard".
"""

import math
from typing import Dict, List, Optional

import numpy as np
import pandas as pd

PROBA_MIN = 1e-6
TRANCHES_CALIBRATION = [(0.0, 0.05), (0.05, 0.1), (0.1, 0.2), (0.2, 0.3), (0.3, 0.5), (0.5, 1.0)]
TIRAGES_BOOTSTRAP = 1000
GRAINE_BOOTSTRAP = 20251020


def log_loss_course(probas, gagnants) -> float:
    p = float(np.sum(np.asarray(probas, dtype=float)[np.asarray(gagnants) > 0]))
    return -math.log(max(p, PROBA_MIN))


def probas_marche(cotes: pd.Series, ids: pd.Series) -> pd.Series:
    """1/cote normalisé dans la course (marge du PMU retirée)."""
    inverse = 1.0 / cotes
    return inverse / inverse.groupby(ids).transform("sum")


def par_course(partants: pd.DataFrame) -> pd.DataFrame:
    """Une ligne par course. Colonnes requises : course_id, discipline,
    gagnant, proba_modele, cote_reference."""
    t = partants[["course_id", "discipline", "gagnant", "proba_modele", "cote_reference"]].copy()
    t["gagnant"] = (t["gagnant"] > 0).astype(int)
    ids = t["course_id"]
    cote = t["cote_reference"]
    cote_ok = cote.notna() & np.isfinite(cote) & (cote > 0)
    t["cote_ok"] = cote_ok
    t["p_gagnant"] = t["proba_modele"] * t["gagnant"]
    t["p_marche"] = np.where(cote_ok, 1.0 / t["cote_reference"].where(cote_ok, 1.0), np.nan)
    g = t.groupby(ids, sort=False)
    courses = pd.DataFrame({
        "discipline": g["discipline"].first(),
        "partants": g.size(),
        "gagnants": g["gagnant"].sum(),
        "p_gagnants": g["p_gagnant"].sum(),
        "marche_complet": g["cote_ok"].all(),
    })
    courses["log_loss_modele"] = -np.log(np.maximum(courses["p_gagnants"], PROBA_MIN))
    courses["log_loss_uniforme"] = np.log(courses["partants"] / courses["gagnants"])
    courses["hasard"] = courses["gagnants"] / courses["partants"]

    courses["top_modele_gagne"] = _taux_egalites(t["proba_modele"] == g["proba_modele"].transform("max"), t)

    complets = t[t["course_id"].map(courses["marche_complet"])].copy()
    if len(complets):
        complets["p_marche"] = complets["p_marche"] / complets.groupby("course_id")["p_marche"].transform("sum")
        gm = complets.groupby("course_id", sort=False)
        p_m = (complets["p_marche"] * complets["gagnant"]).groupby(complets["course_id"]).sum()
        courses["log_loss_marche"] = -np.log(np.maximum(p_m, PROBA_MIN))
        favori = complets["cote_reference"] == gm["cote_reference"].transform("min")
        courses["favori_gagne"] = _taux_egalites(favori, complets)
    else:
        courses["log_loss_marche"] = np.nan
        courses["favori_gagne"] = np.nan
    return courses


def _taux_egalites(choisi: pd.Series, t: pd.DataFrame) -> pd.Series:
    """Part des chevaux choisis (à égalité) qui ont gagné, par course."""
    choisi = choisi.astype(float)
    gagnes = (choisi * t["gagnant"]).groupby(t["course_id"], sort=False).sum()
    return gagnes / choisi.groupby(t["course_id"], sort=False).sum()


def intervalle_bootstrap(differences: np.ndarray, graine: int = GRAINE_BOOTSTRAP,
                         tirages: int = TIRAGES_BOOTSTRAP) -> Optional[Dict[str, float]]:
    """Moyenne et IC à 95 % (percentiles) par rééchantillonnage des courses."""
    d = np.asarray(differences, dtype=float)
    if len(d) == 0:
        return None
    rng = np.random.default_rng(graine)
    moyennes = np.empty(tirages)
    for i in range(tirages):
        moyennes[i] = d[rng.integers(0, len(d), len(d))].mean()
    basse, haute = np.percentile(moyennes, [2.5, 97.5])
    return {"moyenne": float(d.mean()), "ic95_bas": float(basse), "ic95_haut": float(haute)}


def calibration(probas: np.ndarray, gagnants: np.ndarray) -> List[Dict]:
    p = np.asarray(probas, dtype=float)
    g = np.asarray(gagnants) > 0
    tranches = []
    for basse, haute in TRANCHES_CALIBRATION:
        dedans = ((p >= basse) & (p < haute)) | ((haute == 1.0) & (p == 1.0))
        n = int(dedans.sum())
        tranches.append({
            "borne_basse": basse, "borne_haute": haute, "chevaux": n,
            "proba_moyenne": float(p[dedans].mean()) if n else None,
            "taux_victoire": float(g[dedans].mean()) if n else None,
        })
    return tranches


def _moyenne(serie) -> Optional[float]:
    serie = pd.Series(serie, dtype=float).dropna()
    return float(serie.mean()) if len(serie) else None


def resumer(courses: pd.DataFrame, partants: pd.DataFrame) -> Dict:
    marche = courses[courses["marche_complet"]]
    return {
        "courses": int(len(courses)),
        "partants": int(courses["partants"].sum()),
        "log_loss_modele": _moyenne(courses["log_loss_modele"]),
        "log_loss_uniforme": _moyenne(courses["log_loss_uniforme"]),
        "modele_moins_uniforme": intervalle_bootstrap(
            (courses["log_loss_modele"] - courses["log_loss_uniforme"]).to_numpy()),
        "marche": {
            "courses": int(len(marche)),
            "courses_cotes_incompletes": int(len(courses) - len(marche)),
            "log_loss_modele": _moyenne(marche["log_loss_modele"]),
            "log_loss_marche": _moyenne(marche["log_loss_marche"]),
            "modele_moins_marche": intervalle_bootstrap(
                (marche["log_loss_modele"] - marche["log_loss_marche"]).to_numpy()),
            "taux_top_modele": _moyenne(marche["top_modele_gagne"]),
            "taux_favori": _moyenne(marche["favori_gagne"]),
        },
        "taux_top_modele": _moyenne(courses["top_modele_gagne"]),
        "taux_hasard": _moyenne(courses["hasard"]),
        "calibration": calibration(partants["proba_modele"].to_numpy(), partants["gagnant"].to_numpy()),
    }


def evaluer_periode(partants: pd.DataFrame) -> Dict:
    """Résumé global et par discipline d'une période."""
    courses = par_course(partants)
    bilan = {"global": resumer(courses, partants), "disciplines": {}}
    for discipline in sorted(courses["discipline"].unique()):
        bilan["disciplines"][discipline] = resumer(
            courses[courses["discipline"] == discipline], partants[partants["discipline"] == discipline],
        )
    return bilan
