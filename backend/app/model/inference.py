"""Inférence du modèle fondamental (étape 2) et combinaison aux cotes
(étape 3, Benter), pour le service `jobs/pronostics_ml.py`.

Référence : `ml/hippique_ml/model.py` (scores `RawFormulaVal`, softmax par
course divisée par la température) et `ml/hippique_ml/combine.py`
(p ∝ exp(α·log p_fond + β·log p_marché), probabilités planchers à 1e-6).
Le backend n'importe jamais `ml/` : ces règles sont recopiées ici.

Les valeurs arrivent au modèle exactement comme le CSV d'entraînement :
`formater`, puis float pour les numériques (vide = NaN) et chaîne ou
MODALITE_ABSENTE pour les catégories (vide = MODALITE_ABSENTE).
"""

import hashlib
import json
import logging
import math
import os
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Sequence

import numpy as np

from app.jobs.build_features import formater
from app.model.features import NOMS_FEATURES

logger = logging.getLogger(__name__)

MODALITE_ABSENTE = "__absent__"
PROBA_MIN = 1e-6


class ErreurModele(Exception):
    """Fichier du modèle ou des paramètres absent ou incohérent : le service refuse de démarrer."""


def sha256_fichier(chemin: str) -> str:
    h = hashlib.sha256()
    with open(chemin, "rb") as f:
        for bloc in iter(lambda: f.read(1 << 20), b""):
            h.update(bloc)
    return h.hexdigest()


def _fini(valeur: Any) -> bool:
    return isinstance(valeur, (int, float)) and not isinstance(valeur, bool) and math.isfinite(valeur)


@dataclass
class ModeleML:
    modele: Any  # catboost.CatBoost
    features: List[str]
    categoriques: List[str]
    temperature: float
    alpha: float
    beta: float
    sha_modele: str
    sha_params: str
    sha_rapport: str

    def parametres(self) -> Dict[str, Any]:
        return {
            "modele_sha256": self.sha_modele,
            "params_sha256": self.sha_params,
            "rapport_sha256": self.sha_rapport,
            "alpha": self.alpha,
            "beta": self.beta,
            "temperature": self.temperature,
        }

    # -- fondamental

    def matrice(self, lignes: Sequence[Dict[str, Any]]) -> List[List[Any]]:
        categoriques = set(self.categoriques)
        donnees = []
        for ligne in lignes:
            valeurs = []
            for nom in self.features:
                texte = formater(ligne[nom])
                if nom in categoriques:
                    valeurs.append(texte if texte != "" else MODALITE_ABSENTE)
                else:
                    valeurs.append(float(texte) if texte != "" else math.nan)
            donnees.append(valeurs)
        return donnees

    def scores(self, lignes: Sequence[Dict[str, Any]]) -> np.ndarray:
        from catboost import Pool

        pool = Pool(data=self.matrice(lignes), cat_features=list(self.categoriques), feature_names=list(self.features))
        return np.asarray(self.modele.predict(pool, prediction_type="RawFormulaVal"), dtype=float)

    def probas_fondamentales(self, lignes: Sequence[Dict[str, Any]]) -> np.ndarray:
        """Probabilité fondamentale de chaque ligne ; somme 1 dans chaque
        course (`course_id`). Ordre des lignes conservé."""
        if not lignes:
            return np.zeros(0)
        return softmax_par_course(self.scores(lignes), [l["course_id"] for l in lignes], self.temperature)


def softmax_par_course(scores: np.ndarray, ids: Sequence[Any], temperature: float = 1.0) -> np.ndarray:
    z = np.asarray(scores, dtype=float) / temperature
    ids = list(ids)
    resultat = np.empty_like(z)
    for course in dict.fromkeys(ids):
        idx = np.array([i for i, c in enumerate(ids) if c == course])
        zc = z[idx] - z[idx].max()
        e = np.exp(zc)
        resultat[idx] = e / e.sum()
    return resultat


def cote_valide(cote: Any) -> bool:
    """Cote utilisable pour le marché : finie et > 1."""
    return _fini(cote) and cote > 1.0


def proba_marche(cotes: Sequence[Any]) -> Optional[np.ndarray]:
    """1/cote normalisé sur les partants ; None si une cote est invalide."""
    if not cotes or not all(cote_valide(c) for c in cotes):
        return None
    inverse = 1.0 / np.asarray(cotes, dtype=float)
    return inverse / inverse.sum()


def combiner(p_fond: Sequence[float], cotes: Sequence[Any], alpha: float, beta: float) -> Optional[np.ndarray]:
    """p ∝ exp(α·log p_fond + β·log p_marché) sur une course ; None si une
    cote manque ou est invalide."""
    p_mkt = proba_marche(cotes)
    if p_mkt is None:
        return None
    s = (alpha * np.log(np.maximum(np.asarray(p_fond, dtype=float), PROBA_MIN))
         + beta * np.log(np.maximum(p_mkt, PROBA_MIN)))
    e = np.exp(s - s.max())
    return e / e.sum()


# -- chargement

def _lire_json(chemin: str) -> Dict[str, Any]:
    try:
        with open(chemin, encoding="utf-8") as f:
            brut = json.load(f)
    except ValueError as erreur:
        raise ErreurModele(f"{chemin} illisible ({erreur})") from erreur
    if not isinstance(brut, dict):
        raise ErreurModele(f"{chemin} : objet JSON attendu")
    return brut


def charger(dossier_fondamental: str, dossier_combine: str) -> ModeleML:
    """Charge et valide `params.json` + `model.cbm` (étape 2) et l'ajustement
    α, β de `report.json` (étape 3). Refuse (ErreurModele) un fichier absent,
    une feature hors NOMS_FEATURES ou un modèle qui ne correspond pas à ses
    paramètres. Journalise le SHA-256 de chaque fichier."""
    chemin_params = os.path.join(dossier_fondamental, "params.json")
    chemin_modele = os.path.join(dossier_fondamental, "model.cbm")
    chemin_rapport = os.path.join(dossier_combine, "report.json")
    for chemin in (chemin_params, chemin_modele, chemin_rapport):
        if not os.path.isfile(chemin):
            raise ErreurModele(f"fichier absent : {chemin}")
    shas = {chemin: sha256_fichier(chemin) for chemin in (chemin_params, chemin_modele, chemin_rapport)}
    for chemin, sha in shas.items():
        logger.info("Modèle ML : %s sha256=%s", chemin, sha)

    params = _lire_json(chemin_params)
    features = params.get("features")
    categoriques = params.get("categoriques")
    temperature = params.get("temperature")
    if not isinstance(features, list) or not features or not all(isinstance(f, str) for f in features):
        raise ErreurModele("params.json : liste 'features' absente ou vide")
    if not isinstance(categoriques, list) or not all(isinstance(c, str) for c in categoriques):
        raise ErreurModele("params.json : liste 'categoriques' absente")
    inconnues = [f for f in features if f not in NOMS_FEATURES]
    if inconnues:
        raise ErreurModele(f"features du modèle absentes de NOMS_FEATURES : {', '.join(inconnues)}")
    hors_liste = [c for c in categoriques if c not in features]
    if hors_liste:
        raise ErreurModele(f"catégories hors de la liste des features : {', '.join(hors_liste)}")
    if not _fini(temperature) or temperature <= 0:
        raise ErreurModele(f"params.json : température invalide ({temperature!r})")

    ajustement = _lire_json(chemin_rapport).get("ajustement")
    if not isinstance(ajustement, dict):
        raise ErreurModele("report.json : section 'ajustement' absente")
    alpha, beta = ajustement.get("alpha"), ajustement.get("beta")
    if not _fini(alpha) or not _fini(beta):
        raise ErreurModele(f"report.json : alpha/beta invalides ({alpha!r}, {beta!r})")

    import catboost
    from catboost import CatBoost

    versions = params.get("versions")
    attendue = versions.get("catboost") if isinstance(versions, dict) else None
    if attendue is not None and catboost.__version__ != attendue:
        raise ErreurModele(f"catboost {catboost.__version__} installé, modèle entraîné avec {attendue}")

    modele = CatBoost()
    try:
        modele.load_model(chemin_modele)
    except Exception as erreur:
        raise ErreurModele(f"model.cbm illisible ({erreur})") from erreur
    if list(modele.feature_names_ or []) != features:
        raise ErreurModele("model.cbm : features différentes de params.json")
    indices_cat = sorted(modele.get_cat_feature_indices())
    if indices_cat != sorted(features.index(c) for c in categoriques):
        raise ErreurModele("model.cbm : features catégorielles différentes de params.json")

    return ModeleML(
        modele=modele, features=features, categoriques=categoriques, temperature=float(temperature),
        alpha=float(alpha), beta=float(beta), sha_modele=shas[chemin_modele], sha_params=shas[chemin_params],
        sha_rapport=shas[chemin_rapport],
    )
