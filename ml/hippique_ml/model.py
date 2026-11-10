"""Modèle fondamental : CatBoost `QuerySoftMax` (softmax dans chaque course).

- Arrêt précoce et choix dans une petite grille fixe sur la validation.
- Une température scalaire ajustée sur la validation seule.
- Le test n'est jamais vu ici.
"""

import math
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

import numpy as np
import pandas as pd
from catboost import CatBoost, Pool

from hippique_ml.data import Registre, groupes, matrice

GRILLE: Tuple[Tuple[int, float], ...] = tuple((p, t) for p in (4, 6, 8) for t in (0.03, 0.1))
ITERATIONS = 3000
ARRET_PRECOCE = 100
GRAINE = 42
PROBA_MIN = 1e-6
BORNES_LOG_TEMPERATURE = (-3.0, 3.0)


def debuts_groupes(ids: np.ndarray) -> np.ndarray:
    """Indice de début de chaque course ; exige des courses contiguës."""
    if len(ids) == 0:
        return np.zeros(0, dtype=int)
    debuts = np.flatnonzero(np.r_[True, ids[1:] != ids[:-1]])
    if len(debuts) != len(np.unique(ids)):
        raise ValueError("les partants d'une même course doivent être contigus")
    return debuts


def softmax_par_course(scores: np.ndarray, ids: np.ndarray, temperature: float = 1.0) -> np.ndarray:
    """Probabilités dont la somme vaut 1 dans chaque course."""
    debuts = debuts_groupes(ids)
    z = np.asarray(scores, dtype=float) / temperature
    tailles = np.diff(np.r_[debuts, len(z)])
    z = z - np.repeat(np.maximum.reduceat(z, debuts), tailles)
    e = np.exp(z)
    return e / np.repeat(np.add.reduceat(e, debuts), tailles)


def log_loss_moyen(probas: np.ndarray, gagnants: np.ndarray, ids: np.ndarray) -> float:
    """Moyenne par course de −log(somme des probabilités des gagnants)."""
    debuts = debuts_groupes(ids)
    p_gagnants = np.add.reduceat(np.asarray(probas) * (np.asarray(gagnants) > 0), debuts)
    return float(np.mean(-np.log(np.maximum(p_gagnants, PROBA_MIN))))


def ajuster_temperature(scores: np.ndarray, gagnants: np.ndarray, ids: np.ndarray) -> float:
    """Température minimisant le log-loss (recherche dichotomique dorée sur log T)."""
    def perte(log_t: float) -> float:
        return log_loss_moyen(softmax_par_course(scores, ids, math.exp(log_t)), gagnants, ids)

    a, b = BORNES_LOG_TEMPERATURE
    phi = (math.sqrt(5) - 1) / 2
    c, d = b - phi * (b - a), a + phi * (b - a)
    fc, fd = perte(c), perte(d)
    for _ in range(80):
        if fc < fd:
            b, d, fd = d, c, fc
            c = b - phi * (b - a)
            fc = perte(c)
        else:
            a, c, fc = c, d, fd
            d = a + phi * (b - a)
            fd = perte(d)
    return math.exp((a + b) / 2)


def pool(partie: pd.DataFrame, registre: Registre, avec_label: bool = True) -> Pool:
    return Pool(
        data=matrice(partie, registre),
        label=partie["gagnant"].to_numpy(dtype=float) if avec_label else None,
        group_id=groupes(partie),
        cat_features=registre.categoriques,
    )


@dataclass
class Essai:
    profondeur: int
    taux_apprentissage: float
    iterations: int
    log_loss_validation: float


@dataclass
class ModeleFondamental:
    modele: CatBoost
    registre: Registre
    temperature: float
    essais: List[Essai]
    choisi: Essai
    graine: int

    def scores(self, partie: pd.DataFrame) -> np.ndarray:
        return self.modele.predict(pool(partie, self.registre, avec_label=False), prediction_type="RawFormulaVal")

    def predire(self, partie: pd.DataFrame) -> np.ndarray:
        return softmax_par_course(self.scores(partie), groupes(partie), self.temperature)

    def importances(self, n: int = 20) -> List[Dict[str, float]]:
        valeurs = self.modele.get_feature_importance(type="PredictionValuesChange")
        paires = sorted(zip(self.registre.features, valeurs), key=lambda p: (-p[1], p[0]))
        return [{"feature": nom, "importance": round(float(v), 6)} for nom, v in paires[:n]]


def entrainer(
    train: pd.DataFrame,
    validation: pd.DataFrame,
    registre: Registre,
    graine: int = GRAINE,
    grille: Sequence[Tuple[int, float]] = GRILLE,
    iterations: int = ITERATIONS,
    threads: Optional[int] = None,
    journal=print,
) -> ModeleFondamental:
    pool_train, pool_valid = pool(train, registre), pool(validation, registre)
    ids_valid, gagnants_valid = groupes(validation), validation["gagnant"].to_numpy()
    essais: List[Essai] = []
    meilleur: Optional[Tuple[Essai, CatBoost]] = None
    for profondeur, taux in grille:
        modele = CatBoost({
            "loss_function": "QuerySoftMax",
            "iterations": iterations,
            "depth": profondeur,
            "learning_rate": taux,
            "random_seed": graine,
            "od_type": "Iter",
            "od_wait": ARRET_PRECOCE,
            "use_best_model": True,
            "thread_count": threads or -1,
            "allow_writing_files": False,
            "verbose": 0,
        })
        modele.fit(pool_train, eval_set=pool_valid)
        scores = modele.predict(pool_valid, prediction_type="RawFormulaVal")
        essai = Essai(
            profondeur=profondeur, taux_apprentissage=taux, iterations=int(modele.tree_count_),
            log_loss_validation=log_loss_moyen(softmax_par_course(scores, ids_valid), gagnants_valid, ids_valid),
        )
        essais.append(essai)
        journal(
            f"  profondeur {profondeur}, taux {taux} : {essai.iterations} arbres, "
            f"log-loss validation {essai.log_loss_validation:.4f}"
        )
        if meilleur is None or essai.log_loss_validation < meilleur[0].log_loss_validation:
            meilleur = (essai, modele)
    choisi, modele = meilleur
    scores_valid = modele.predict(pool_valid, prediction_type="RawFormulaVal")
    temperature = ajuster_temperature(scores_valid, gagnants_valid, ids_valid)
    if min(abs(math.log(temperature) - borne) for borne in BORNES_LOG_TEMPERATURE) < 1e-3:
        journal(f"  attention : température {temperature:.4f} plafonnée à une borne de la recherche")
    return ModeleFondamental(
        modele=modele, registre=registre, temperature=temperature, essais=essais, choisi=choisi, graine=graine,
    )
