"""Modèle combiné (étape 3, Benter) : logit conditionnel par course.

    p_i ∝ exp(α · log p_fond_i + β · log p_marché_i)

- p_fond : probabilité du modèle fondamental (étape 2), recalculée depuis
  `model.cbm` et la température de `params.json` ;
- p_marché : 1/`cote_reference` (H-30) normalisé dans la course.

α et β sont ajustés (Newton, gradient et hessien analytiques) sur les courses
de validation dont tous les partants ont une cote finie et positive. Le test
est évalué une seule fois. `cote_direct` (cote de clôture) n'est jamais une
entrée : elle n'apparaît que comme repère informatif dans le rapport.

    uv run python -m hippique_ml.combine --run <stage2_dir> --features <csv.gz> --sortie <dir>
"""

import argparse
import hashlib
import json
import math
import os
import sys
import time
from dataclasses import asdict, dataclass
from datetime import date, datetime, timezone
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
from catboost import CatBoost, CatBoostError

from hippique_ml.data import ErreurDonnees, Periodes, decouper, groupes, lire_registre, lire_table
from hippique_ml.evaluate import (
    GRAINE_BOOTSTRAP, PROBA_MIN, TIRAGES_BOOTSTRAP, _taux_egalites, calibration, intervalle_bootstrap,
)
from hippique_ml.model import debuts_groupes, pool, softmax_par_course
from hippique_ml.train import COLONNES_PREDICTIONS, _ecrire_json, _f, _ic, _pct, preparer_sortie, versions

PERIODES_COMBINE = ("validation", "test")
TOLERANCE_PREDICTIONS = 1e-9
THETA_DEPART = (0.0, 1.0)  # le marché seul
ITERATIONS_MAX = 100
DEMI_PAS_MAX = 40
GAIN_MIN_PAR_COURSE = 1e-10
NORME_GRADIENT_MAX_PAR_COURSE = 1e-6  # convergence : |∇ℓ| / courses sous ce seuil
CLES_PARAMS = ("periodes", "temperature", "features", "categoriques", "registre_git_sha")
COLONNES_SORTIE = COLONNES_PREDICTIONS + ["proba_marche", "proba_combinee"]


# --- Marché ------------------------------------------------------------------

def cotes_valides(cotes) -> np.ndarray:
    """Cote finie et strictement positive (NaN, 0, inf, négatif : invalide)."""
    c = pd.to_numeric(pd.Series(cotes), errors="coerce").to_numpy(dtype=float)
    with np.errstate(invalid="ignore"):
        return np.isfinite(c) & (c > 0)


def course_complete(partants: pd.DataFrame, colonne: str) -> np.ndarray:
    """Vrai pour chaque partant d'une course où tous les partants ont une cote valide."""
    ok = pd.Series(cotes_valides(partants[colonne].to_numpy()), index=partants.index)
    return ok.groupby(partants["course_id"].to_numpy(), sort=False).transform("all").to_numpy(dtype=bool)


def proba_marche(partants: pd.DataFrame, colonne: str) -> np.ndarray:
    """1/cote normalisé dans la course ; NaN pour les courses incomplètes."""
    complete = course_complete(partants, colonne)
    cotes = pd.to_numeric(partants[colonne], errors="coerce").to_numpy(dtype=float)
    inverse = np.where(complete, 1.0 / np.where(complete, cotes, 1.0), np.nan)
    sommes = pd.Series(inverse).groupby(partants["course_id"].to_numpy(), sort=False).transform("sum").to_numpy()
    return np.where(complete, inverse / np.where(complete, sommes, 1.0), np.nan)


# --- Logit conditionnel ------------------------------------------------------

def variables(p_fond: np.ndarray, p_marche: np.ndarray) -> np.ndarray:
    """x_i = (log p_fond_i, log p_marché_i), probabilités planchers à 1e-6."""
    return np.column_stack([
        np.log(np.maximum(np.asarray(p_fond, dtype=float), PROBA_MIN)),
        np.log(np.maximum(np.asarray(p_marche, dtype=float), PROBA_MIN)),
    ])


def _logsumexp_par_course(s: np.ndarray, debuts: np.ndarray, tailles: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
    """(log Σ e^s par course, poids e^s / Σ e^s), stable ; s peut valoir -inf."""
    m = np.maximum.reduceat(s, debuts)
    m_safe = np.where(np.isfinite(m), m, 0.0)
    e = np.exp(s - np.repeat(m_safe, tailles))
    z = np.add.reduceat(e, debuts)
    with np.errstate(divide="ignore", invalid="ignore"):
        poids = e / np.repeat(z, tailles)
        log_z = np.log(z) + m_safe
    return log_z, poids


def log_vraisemblance(theta, X: np.ndarray, gagnants: np.ndarray, ids: np.ndarray,
                      debuts: Optional[np.ndarray] = None) -> Tuple[float, np.ndarray, np.ndarray]:
    """ℓ(θ) = Σ_r [log Σ_{w∈W_r} e^{θ·x_w} − log Σ_i e^{θ·x_i}], son gradient et son hessien.

    Ex aequo : W_r contient tous les gagnants (probabilité sommée).
    Gradient : E_q[x] − E_p[x] par course (q = p restreint aux gagnants).
    Hessien : Cov_q[x] − Cov_p[x] par course (Cov_q = 0 avec un seul gagnant)."""
    theta = np.asarray(theta, dtype=float)
    if debuts is None:
        debuts = debuts_groupes(ids)
    tailles = np.diff(np.r_[debuts, len(X)])
    # Décalage par course (sans effet sur ℓ) : x − x du premier partant. Une
    # variable constante dans la course devient exactement nulle.
    X = np.asarray(X, dtype=float)
    X = X - np.repeat(X[debuts], tailles, axis=0)
    s = X @ theta
    w = np.asarray(gagnants) > 0
    log_z, p = _logsumexp_par_course(s, debuts, tailles)
    log_zw, q = _logsumexp_par_course(np.where(w, s, -np.inf), debuts, tailles)
    ll = float(np.sum(log_zw - log_z))
    if not np.isfinite(ll):
        return -math.inf, np.full(2, np.nan), np.full((2, 2), np.nan)
    # Centrage dans la course : une variable constante dans chaque course a un
    # gradient et une covariance exactement nuls (pas de bruit d'arrondi).
    xp = X - np.repeat(np.add.reduceat(p[:, None] * X, debuts), tailles, axis=0)
    xq = X - np.repeat(np.add.reduceat(q[:, None] * X, debuts), tailles, axis=0)
    grad = q @ xp
    hess = (q[:, None] * xq).T @ xq - (p[:, None] * xp).T @ xp
    return ll, grad, hess


@dataclass
class Ajustement:
    alpha: float
    beta: float
    se_alpha: Optional[float]
    se_beta: Optional[float]
    log_vraisemblance: float
    log_vraisemblance_depart: float
    iterations: int
    courses: int
    partants: int
    identifiable: bool
    converge: bool
    norme_gradient: float

    @property
    def theta(self) -> np.ndarray:
        return np.array([self.alpha, self.beta])

    def to_dict(self) -> Dict:
        return asdict(self)


def ajuster(X: np.ndarray, gagnants: np.ndarray, ids: np.ndarray) -> Ajustement:
    """Maximum de vraisemblance conditionnelle, Newton avec demi-pas, départ (0, 1)."""
    debuts = debuts_groupes(ids)
    courses = len(debuts)
    if courses == 0:
        raise ErreurDonnees("aucune course de validation avec des cotes complètes : ajustement impossible")
    theta = np.array(THETA_DEPART, dtype=float)
    ll, g, h = log_vraisemblance(theta, X, gagnants, ids, debuts)
    ll_depart = ll
    seuil = GAIN_MIN_PAR_COURSE * courses
    iterations, arret = 0, "iterations_max"
    for iterations in range(1, ITERATIONS_MAX + 1):
        info = -h
        try:
            np.linalg.cholesky(info)
            pas = np.linalg.solve(info, g)
        except np.linalg.LinAlgError:
            pas = np.linalg.lstsq(info, g, rcond=None)[0]
        if not np.all(np.isfinite(pas)) or float(g @ pas) <= 0:
            pas = g  # repli : montée de gradient
        t, accepte = 1.0, None
        for _ in range(DEMI_PAS_MAX):
            candidat = theta + t * pas
            ll_c, g_c, h_c = log_vraisemblance(candidat, X, gagnants, ids, debuts)
            if ll_c > ll:
                accepte = (candidat, ll_c, g_c, h_c)
                break
            t /= 2
        if accepte is None:
            arret = "aucun_demi_pas"
            break
        gain = accepte[1] - ll
        theta, ll, g, h = accepte
        if gain < seuil:
            arret = "gain"
            break

    if not (np.isfinite(ll) and np.all(np.isfinite(g)) and np.all(np.isfinite(h))):
        raise ErreurDonnees("ajustement impossible : vraisemblance non finie (course sans gagnant ?)")
    norme = float(np.linalg.norm(g))
    # Convergé : arrêt sur un gain négligeable ou sans pas améliorant, gradient quasi nul.
    converge = arret != "iterations_max" and norme <= NORME_GRADIENT_MAX_PAR_COURSE * courses
    info = -h
    valeurs = np.linalg.eigvalsh(info)
    identifiable = bool(valeurs.min() > 1e-9 * max(valeurs.max(), 1e-300))
    se_alpha = se_beta = None
    if identifiable:
        try:
            np.linalg.cholesky(info)  # défini positif : vrai maximum
            variances = np.diag(np.linalg.inv(info))
            if np.all(np.isfinite(variances)) and np.all(variances > 0):
                se_alpha, se_beta = (float(v) for v in np.sqrt(variances))
        except np.linalg.LinAlgError:
            pass
    return Ajustement(
        alpha=float(theta[0]), beta=float(theta[1]), se_alpha=se_alpha, se_beta=se_beta,
        log_vraisemblance=ll, log_vraisemblance_depart=ll_depart, iterations=iterations,
        courses=courses, partants=int(len(X)), identifiable=identifiable, converge=bool(converge),
        norme_gradient=norme,
    )


def proba_combinee(theta, X: np.ndarray, ids: np.ndarray) -> np.ndarray:
    return softmax_par_course(X @ np.asarray(theta, dtype=float), ids)


# --- Évaluation à trois (combiné, marché, fondamental) ------------------------

def par_course_combine(partants: pd.DataFrame) -> pd.DataFrame:
    """Une ligne par course. Colonnes requises : course_id, discipline, gagnant,
    proba_modele, proba_marche, proba_combinee (NaN hors courses complètes),
    cote_reference, cote_direct."""
    t = partants[["course_id", "discipline", "gagnant", "proba_modele", "proba_marche", "proba_combinee",
                  "cote_reference", "cote_direct"]].copy().reset_index(drop=True)
    t["gagnant"] = (t["gagnant"] > 0).astype(int)
    t["complet"] = course_complete(t, "cote_reference")
    t["cloture_complet"] = course_complete(t, "cote_direct")
    t["proba_cloture"] = proba_marche(t, "cote_direct")
    ids = t["course_id"]
    g = t.groupby(ids, sort=False)
    courses = pd.DataFrame({
        "discipline": g["discipline"].first(),
        "partants": g.size(),
        "gagnants": g["gagnant"].sum(),
        "marche_complet": g["complet"].first(),
        "cloture_complet": g["cloture_complet"].first(),
    })
    for colonne, nom in (("proba_modele", "modele"), ("proba_marche", "marche"),
                         ("proba_combinee", "combine"), ("proba_cloture", "cloture")):
        p_gagnants = (t[colonne] * t["gagnant"]).groupby(ids, sort=False).sum(min_count=1)
        ll = -np.log(np.maximum(p_gagnants, PROBA_MIN))
        if nom == "cloture":
            ll = ll.where(courses["cloture_complet"])
        elif nom in ("marche", "combine"):
            ll = ll.where(courses["marche_complet"])
        courses[f"log_loss_{nom}"] = ll

    complets = t[t["complet"]]
    if len(complets):
        gc = complets.groupby("course_id", sort=False)
        courses["top_combine_gagne"] = _taux_egalites(
            complets["proba_combinee"] == gc["proba_combinee"].transform("max"), complets)
        courses["top_modele_gagne"] = _taux_egalites(
            complets["proba_modele"] == gc["proba_modele"].transform("max"), complets)
        courses["favori_gagne"] = _taux_egalites(
            complets["cote_reference"] == gc["cote_reference"].transform("min"), complets)
    else:
        courses["top_combine_gagne"] = courses["top_modele_gagne"] = courses["favori_gagne"] = np.nan
    return courses


def _moyenne(serie) -> Optional[float]:
    serie = pd.Series(serie, dtype=float).dropna()
    return float(serie.mean()) if len(serie) else None


def resumer_combine(courses: pd.DataFrame, partants: pd.DataFrame) -> Dict:
    c = courses[courses["marche_complet"]]
    p = partants[partants["course_id"].isin(c.index)]
    cloture = courses[courses["cloture_complet"]]
    return {
        "courses": int(len(c)),
        "partants": int(c["partants"].sum()),
        "courses_cotes_incompletes": int(len(courses) - len(c)),
        "partants_cotes_incompletes": int(courses["partants"].sum() - c["partants"].sum()),
        "log_loss_combine": _moyenne(c["log_loss_combine"]),
        "log_loss_marche": _moyenne(c["log_loss_marche"]),
        "log_loss_modele": _moyenne(c["log_loss_modele"]),
        "combine_moins_marche": intervalle_bootstrap((c["log_loss_combine"] - c["log_loss_marche"]).to_numpy()),
        "combine_moins_modele": intervalle_bootstrap((c["log_loss_combine"] - c["log_loss_modele"]).to_numpy()),
        "taux_top_combine": _moyenne(c["top_combine_gagne"]),
        "taux_favori": _moyenne(c["favori_gagne"]),
        "taux_top_modele": _moyenne(c["top_modele_gagne"]),
        "calibration_combine": calibration(p["proba_combinee"].to_numpy(), p["gagnant"].to_numpy()),
        "calibration_marche": calibration(p["proba_marche"].to_numpy(), p["gagnant"].to_numpy()),
        "cloture": {  # informatif : cote_direct n'est jamais une entrée du modèle
            "courses": int(len(cloture)),
            "log_loss_marche_cloture": _moyenne(cloture["log_loss_cloture"]),
        },
    }


def evaluer_periode_combine(partants: pd.DataFrame) -> Dict:
    courses = par_course_combine(partants)
    bilan = {"global": resumer_combine(courses, partants), "disciplines": {}}
    for discipline in sorted(courses["discipline"].unique()):
        bilan["disciplines"][discipline] = resumer_combine(
            courses[courses["discipline"] == discipline], partants[partants["discipline"] == discipline])
    return bilan


def porte(test_global: Dict, ajustement: Optional["Ajustement"] = None) -> Dict:
    ic = test_global["combine_moins_marche"]
    passe = bool(ic is not None and ic["moyenne"] < 0 and ic["ic95_haut"] < 0)
    etat = "PASSED" if passe else "FAILED"
    verdict = (f"Gate {etat}: test combined - market log-loss {_ic(ic)} "
               "(passes when the mean and the 95% CI upper bound are both below 0)")
    if ajustement is not None and not ajustement.converge:
        verdict += " [warning: the fit did not converge]"
    if ajustement is not None and not ajustement.identifiable:
        verdict += " [warning: coefficients not identifiable]"
    return {"passee": passe, "combine_moins_marche": ic, "verdict": verdict}


def combiner(validation: pd.DataFrame, test: pd.DataFrame) -> Tuple[Ajustement, Dict[str, pd.DataFrame]]:
    """Cœur sans entrée/sortie. Chaque partie a course_id (contigu), gagnant,
    proba_modele, cote_reference. Ajuste sur la validation seule, puis ajoute
    proba_marche et proba_combinee (NaN hors courses complètes) aux deux parties."""
    parties = {}
    for nom, partie in (("validation", validation), ("test", test)):
        sans_gagnant = int((partie.groupby("course_id")["gagnant"].max() <= 0).sum())
        if sans_gagnant:
            raise ErreurDonnees(f"{nom} : {sans_gagnant} course(s) sans gagnant (à écarter avant combinaison)")
        partie = partie.reset_index(drop=True).copy()
        partie["proba_marche"] = proba_marche(partie, "cote_reference")
        parties[nom] = partie
    v = parties["validation"]
    v_ok = v[course_complete(v, "cote_reference")]
    ajustement = ajuster(variables(v_ok["proba_modele"], v_ok["proba_marche"]),
                         v_ok["gagnant"].to_numpy(), groupes(v_ok))
    for partie in parties.values():
        ok = course_complete(partie, "cote_reference")
        partie["proba_combinee"] = np.nan
        if ok.any():
            sel = partie[ok]
            partie.loc[ok, "proba_combinee"] = proba_combinee(
                ajustement.theta, variables(sel["proba_modele"], sel["proba_marche"]), groupes(sel))
    return ajustement, parties


# --- Entrées ----------------------------------------------------------------

def _hash_fichier(chemin: str) -> str:
    with open(chemin, "rb") as fichier:
        return hashlib.sha256(fichier.read()).hexdigest()


def lire_params(run: str) -> Tuple[Dict, Periodes]:
    for nom in ("model.cbm", "params.json", "test_predictions.csv.gz"):
        if not os.path.isfile(os.path.join(run, nom)):
            raise ErreurDonnees(f"run d'étape 2 incomplet : {os.path.join(run, nom)} absent")
    try:
        with open(os.path.join(run, "params.json"), encoding="utf-8") as fichier:
            params = json.load(fichier)
        bornes = params["periodes"]
        periodes = Periodes(
            train_fin=date.fromisoformat(bornes["train"]["fin_exclue"]),
            valid_fin=date.fromisoformat(bornes["validation"]["fin"]),
            test_fin=date.fromisoformat(bornes["test"]["fin"]),
        )
        manquantes = [cle for cle in CLES_PARAMS if cle not in params]
        if manquantes:
            raise KeyError(", ".join(manquantes))
        temperature = params["temperature"]
        if isinstance(temperature, bool) or not isinstance(temperature, (int, float)):
            raise TypeError(f"température non numérique : {temperature!r}")
        temperature = float(temperature)
    except (json.JSONDecodeError, KeyError, TypeError, ValueError) as erreur:
        raise ErreurDonnees(f"params.json illisible ou incomplet dans {run} ({erreur!r})") from erreur
    if not (math.isfinite(temperature) and temperature > 0):
        raise ErreurDonnees(f"params.json : température invalide {temperature}")
    if periodes.bornes() != bornes:
        raise ErreurDonnees(f"params.json : périodes incohérentes {bornes}")
    params["temperature"] = temperature
    return params, periodes


def verifier_predictions(recalcul: pd.DataFrame, sauvegarde: pd.DataFrame) -> None:
    """Les probabilités de test recalculées doivent égaler celles du run (1e-9)."""
    cles = ["course_id", "num_pmu"]
    manquantes = [c for c in cles + ["proba_modele"] if c not in sauvegarde.columns]
    if manquantes:
        raise ErreurDonnees(f"test_predictions.csv.gz sans colonne(s) {', '.join(manquantes)}")
    for nom, cote in (("table recalculée", recalcul), ("test_predictions.csv.gz", sauvegarde)):
        doublons = int(cote.duplicated(cles).sum())
        if doublons:
            raise ErreurDonnees(f"{nom} : {doublons} partant(s) en double (course_id, num_pmu)")
    a = recalcul[cles + ["proba_modele"]]
    b = sauvegarde[cles + ["proba_modele"]].rename(columns={"proba_modele": "proba_run"})
    try:
        jointes = a.merge(b, on=cles, how="outer", indicator=True, validate="one_to_one")
    except (ValueError, pd.errors.MergeError) as erreur:
        raise ErreurDonnees(f"test_predictions.csv.gz incompatible avec la table ({erreur})") from erreur
    orphelins = int((jointes["_merge"] != "both").sum())
    if orphelins:
        raise ErreurDonnees(
            f"table différente du run : {orphelins} partant(s) de test présents d'un seul côté "
            "(test_predictions.csv.gz contre la table recalculée)")
    ecart = (jointes["proba_modele"] - jointes["proba_run"]).abs()
    if not (ecart <= TOLERANCE_PREDICTIONS).all():
        raise ErreurDonnees(
            f"table différente du run : probabilités de test recalculées != test_predictions.csv.gz "
            f"(écart max {float(ecart.max()):.3g}, {int((~(ecart <= TOLERANCE_PREDICTIONS)).sum())} partant(s))")


def executer(run: str, features: str, sortie: str, journal=print) -> Dict:
    debut = time.monotonic()
    # Refus immédiat, avant de lire la table ; preparer_sortie revérifie avant d'écrire.
    if os.path.exists(os.path.join(sortie, "report.json")):
        raise ErreurDonnees(f"le dossier {sortie} contient déjà un run (report.json) : choisir un autre --sortie")
    params, periodes = lire_params(run)
    registre = lire_registre(f"{features}.registry.json")
    if registre.git_sha != params["registre_git_sha"]:
        raise ErreurDonnees(
            f"registre différent du run : git_sha {registre.git_sha!r} != registre_git_sha "
            f"{params['registre_git_sha']!r} de params.json")
    if registre.features != params["features"] or registre.categoriques != params["categoriques"]:
        raise ErreurDonnees("registre différent du run : liste de features ou de catégorielles différente")
    table = lire_table(features, registre)
    decoupe, exclusions = decouper(table, periodes)

    modele = CatBoost()
    modele.load_model(os.path.join(run, "model.cbm"))
    parties = {}
    for nom in PERIODES_COMBINE:
        partie = decoupe[nom].copy()
        scores = modele.predict(pool(partie, registre, avec_label=False), prediction_type="RawFormulaVal")
        partie["proba_modele"] = softmax_par_course(scores, groupes(partie), params["temperature"])
        parties[nom] = partie
    sauvegarde = pd.read_csv(os.path.join(run, "test_predictions.csv.gz"))
    verifier_predictions(parties["test"], sauvegarde)
    journal("Probabilités de l'étape 2 recalculées : identiques au run (test)")
    for nom in PERIODES_COMBINE:
        n = int(pd.Series(course_complete(parties[nom], "cote_reference")).groupby(
            parties[nom]["course_id"].to_numpy()).first().sum())
        journal(f"{nom} : {parties[nom]['course_id'].nunique()} courses, {n} avec cotes H-30 complètes")
        if n == 0:
            raise ErreurDonnees(f"période {nom!r} sans course aux cotes H-30 complètes")
    preparer_sortie(sortie)  # avant l'ajustement ; dossier créé seulement si l'entrée est cohérente

    ajustement, parties = combiner(parties["validation"], parties["test"])
    journal(f"alpha = {ajustement.alpha:.4f} (se {_f(ajustement.se_alpha, 4)}), "
            f"beta = {ajustement.beta:.4f} (se {_f(ajustement.se_beta, 4)}), {ajustement.iterations} itération(s)")
    if not ajustement.identifiable:
        journal("  attention : hessien singulier, coefficients non identifiables (erreurs standard absentes)")
    if not ajustement.converge:
        journal(f"  attention : ajustement non convergé (|gradient| = {ajustement.norme_gradient:.3g})")

    resultats = {nom: evaluer_periode_combine(parties[nom]) for nom in PERIODES_COMBINE}
    verdict_porte = porte(resultats["test"]["global"], ajustement)
    hash_params = _hash_fichier(os.path.join(run, "params.json"))
    empreintes = {
        "params_json_sha256": hash_params,
        "model_cbm_sha256": _hash_fichier(os.path.join(run, "model.cbm")),
        "features_sha256": _hash_fichier(features),
    }
    combine = {
        "formule": "p_i ∝ exp(alpha · log p_fond_i + beta · log p_marche_i), p_marche = 1/cote_reference normalisé",
        **ajustement.to_dict(),
        "run_etape2": os.path.abspath(run),
        **empreintes,
        "temperature_etape2": params["temperature"],
        "registre_git_sha": registre.git_sha,
        "periode_ajustement": periodes.bornes()["validation"],
        "versions": versions(),
    }
    rapport = {
        "genere_le_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "run_etape2": os.path.abspath(run),
        **empreintes,
        "features": os.path.abspath(features),
        "bootstrap": {"tirages": TIRAGES_BOOTSTRAP, "graine": GRAINE_BOOTSTRAP, "unite": "course"},
        "periodes": {nom: periodes.bornes()[nom] for nom in PERIODES_COMBINE},
        "exclusions": {nom: exclusions[nom].to_dict() for nom in PERIODES_COMBINE},
        "ajustement": ajustement.to_dict(),
        "resultats": resultats,
        "porte": verdict_porte,
    }
    test = parties["test"]
    predictions = test[course_complete(test, "cote_reference")][COLONNES_SORTIE]

    # report.json en dernier : sa présence marque un run complet (refusé ensuite comme "déjà un run").
    _ecrire_json(os.path.join(sortie, "combine.json"), combine)
    with open(os.path.join(sortie, "report.md"), "w", encoding="utf-8") as fichier:
        fichier.write(rapport_markdown(rapport))
    predictions.to_csv(os.path.join(sortie, "test_predictions.csv.gz"), index=False, compression="gzip",
                       float_format="%.12g")
    _ecrire_json(os.path.join(sortie, "report.json"), rapport)
    journal(verdict_porte["verdict"])
    journal(f"Rapport : {os.path.join(sortie, 'report.md')} ({time.monotonic() - debut:.0f} s)")
    return rapport


# --- Rapport -----------------------------------------------------------------

def _ligne(nom: str, r: Dict) -> str:
    c = r["cloture"]
    return (
        f"| {nom} | {r['courses']} ({r['courses_cotes_incompletes']} excl.) | {r['partants']} "
        f"| {_f(r['log_loss_combine'])} | {_f(r['log_loss_marche'])} | {_f(r['log_loss_modele'])} "
        f"| {_ic(r['combine_moins_marche'])} | {_ic(r['combine_moins_modele'])} "
        f"| {_pct(r['taux_top_combine'])} | {_pct(r['taux_favori'])} | {_pct(r['taux_top_modele'])} "
        f"| {c['courses']} | {_f(c['log_loss_marche_cloture'])} |"
    )


def rapport_markdown(rapport: Dict) -> str:
    a = rapport["ajustement"]
    l: List[str] = ["# Combined model report (roadmap stage 3, Benter)", "",
                    f"**{rapport['porte']['verdict']}**", "",
                    f"Generated {rapport['genere_le_utc']} from stage-2 run `{rapport['run_etape2']}` "
                    f"(params.json sha256 `{rapport['params_json_sha256'][:16]}…`) and `{rapport['features']}`.", ""]
    l += ["## Model", "",
          "p_i ∝ exp(α · log p_fund_i + β · log p_mkt_i), with p_fund the stage-2 probability and p_mkt = "
          "1/`cote_reference` (H-30) normalised per race. Fitted by maximum conditional likelihood on "
          "validation races where every runner has odds; standard errors from the inverse Hessian.", "",
          "| coefficient | estimate | standard error |", "|---|---|---|",
          f"| α (fundamental) | {a['alpha']:.4f} | {_f(a['se_alpha'], 4)} |",
          f"| β (market) | {a['beta']:.4f} | {_f(a['se_beta'], 4)} |", "",
          f"Fit: {a['courses']} races, {a['partants']} runners, {a['iterations']} Newton iteration(s), "
          f"log-likelihood {a['log_vraisemblance_depart']:.3f} (market alone) → {a['log_vraisemblance']:.3f}, "
          f"converged: {'yes' if a['converge'] else 'NO'} (|gradient| {a['norme_gradient']:.2g})."
          + ("" if a["identifiable"] else " **Warning: singular Hessian, coefficients not identifiable.**"), ""]
    l += ["## Periods", ""]
    for nom, bornes in rapport["periodes"].items():
        l.append(f"- {nom}: {json.dumps(bornes)}")
    l += ["", "Excluded or flagged by the stage-2 rules, per period (races with incomplete odds are counted in "
          "the results tables as `excl.`):", ""]
    for nom, exclu in rapport["exclusions"].items():
        l.append(f"- {nom}: {json.dumps(exclu)}")
    l += ["", "## Results", "",
          "Races where every runner has a finite positive H-30 odds only. Log-loss is −log p(winner), mean per "
          "race (dead heats: summed winner probability). Differences are combined minus benchmark (negative = "
          f"combined better), with a {TIRAGES_BOOTSTRAP:,}-resample race bootstrap 95% CI (seed "
          f"{GRAINE_BOOTSTRAP}; races of the same day are resampled independently). Validation figures are in-sample "
          "(α and β are fitted there); only test figures are out of sample. Top pick and favourite ties count "
          "1/k. The closing-odds (`cote_direct`) market log-loss is informative only, on races where every "
          "runner has closing odds; it is never an input.", ""]
    entete = ("| scope | races | runners | combined LL | market LL | fundamental LL | combined − market "
              "| combined − fundamental | top pick combined | favourite | top pick fundamental "
              "| closing races | closing market LL |")
    for nom in PERIODES_COMBINE:
        res = rapport["resultats"][nom]
        l += [f"### {nom}", "", entete, "|" + "---|" * 13, _ligne("all", res["global"])]
        for discipline, r in res["disciplines"].items():
            l.append(_ligne(discipline, r))
        l += ["", "Calibration (all disciplines):", "",
              "| bucket | runners | combined mean p | combined win rate | market mean p | market win rate |",
              "|---|---|---|---|---|---|"]
        for tc, tm in zip(res["global"]["calibration_combine"], res["global"]["calibration_marche"], strict=True):
            l.append(f"| [{tc['borne_basse']}, {tc['borne_haute']}) | {tc['chevaux']} | {_f(tc['proba_moyenne'])} "
                     f"| {_f(tc['taux_victoire'])} | {_f(tm['proba_moyenne'])} | {_f(tm['taux_victoire'])} |")
        l.append("")
    l += ["## Gate", "", rapport["porte"]["verdict"], ""]
    return "\n".join(l)


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Modèle combiné fondamental + cotes H-30 (étape 3)")
    parser.add_argument("--run", required=True, help="Dossier du run d'étape 2 (model.cbm, params.json, …)")
    parser.add_argument("--features", required=True, help="CSV gzip de build_features utilisé par ce run")
    parser.add_argument("--sortie", required=True, help="Nouveau dossier de sortie")
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    try:
        executer(args.run, args.features, args.sortie)
    except (ErreurDonnees, OSError, CatBoostError, ValueError, KeyError) as erreur:
        print(f"Erreur : {erreur}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
