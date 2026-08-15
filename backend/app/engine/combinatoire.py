import itertools
from collections import defaultdict
from typing import Dict, List, Sequence, Tuple

import numpy as np

from app.engine.scoring import HorseAnalysis


def exact_permutations_probabilities(probabilities: Sequence[float], depth: int) -> Dict[Tuple[int, ...], float]:
    result: Dict[Tuple[int, ...], float] = {}
    for perm in itertools.permutations(range(len(probabilities)), depth):
        prob = 1.0
        remaining = 1.0
        for position, index in enumerate(perm):
            p = probabilities[index]
            if position == 0:
                prob *= p
            else:
                if remaining <= 0:
                    prob = 0.0
                    break
                prob *= p / remaining
            remaining -= p
            if remaining < 0:
                remaining = 0.0
        result[perm] = prob
    return result


def exact_ordered(probabilities: Sequence[float], depth: int) -> List[Dict[str, object]]:
    if depth <= 0:
        return []
    perms = exact_permutations_probabilities(probabilities, depth)
    return [
        {"ordre": perm, "probabilite": prob}
        for perm, prob in sorted(perms.items(), key=lambda item: item[1], reverse=True)
    ]


def exact_unordered(probabilities: Sequence[float], depth: int) -> List[Dict[str, object]]:
    ordered = exact_ordered(probabilities, depth)
    groups: Dict[Tuple[int, ...], float] = defaultdict(float)
    for item in ordered:
        comb = tuple(sorted(item["ordre"]))
        groups[comb] += item["probabilite"]
    return [
        {"ensemble": comb, "probabilite": prob}
        for comb, prob in sorted(groups.items(), key=lambda item: item[1], reverse=True)
    ]


def monte_carlo_place_probabilities(probabilities: Sequence[float], top_m: int, trials: int = 20000, seed: int = 0) -> Dict[Tuple[int, int], float]:
    n = len(probabilities)
    if n == 0 or top_m <= 0:
        return {}
    top_m = min(top_m, n)

    # Tirage pondéré sans remise, vectorisé (clés d'Efraimidis-Spirakis :
    # trier par u_i^(1/poids_i) équivaut à un tirage séquentiel Plackett-Luce).
    rng = np.random.default_rng(seed)
    weights = np.clip(np.asarray(probabilities, dtype=float), 1e-12, None)
    keys = rng.random((trials, n)) ** (1.0 / weights)
    top_indices = np.argsort(-keys, axis=1)[:, :top_m]

    counts: Dict[Tuple[int, int], int] = {}
    for row in top_indices:
        for a, b in itertools.combinations(sorted(row.tolist()), 2):
            counts[(a, b)] = counts.get((a, b), 0) + 1
    return {pair: count / trials for pair, count in counts.items()}


def _label(reels: Sequence[HorseAnalysis], indices: Sequence[int]) -> Dict[str, object]:
    return {
        "dossards": [reels[i].num_pmu for i in indices],
        "noms": [reels[i].nom for i in indices],
    }


def _combo_ordre_desordre(reels: Sequence[HorseAnalysis], nb_reels: int, ordre_favoris: List[int], depth: int, pool_size: int) -> Dict[str, List[Dict[str, object]]]:
    pool = ordre_favoris[:min(pool_size, nb_reels)]
    if nb_reels < depth or len(pool) < depth:
        return {"ordre": [], "desordre": []}

    pool_probs = [reels[i].probabilite for i in pool]
    ordered = exact_ordered(pool_probs, depth)[:3]
    unordered = exact_unordered(pool_probs, depth)[:3]
    return {
        "ordre": [
            {**_label(reels, [pool[i] for i in item["ordre"]]), "probabilite": item["probabilite"]}
            for item in ordered
        ],
        "desordre": [
            {**_label(reels, [pool[i] for i in item["ensemble"]]), "probabilite": item["probabilite"]}
            for item in unordered
        ],
    }


def _combo_place(reels: Sequence[HorseAnalysis], nb_reels: int, probabilites_champ: Sequence[float], top_m: int) -> List[Dict[str, object]]:
    counts = monte_carlo_place_probabilities(probabilites_champ, top_m)
    reels_pairs = {pair: p for pair, p in counts.items() if pair[0] < nb_reels and pair[1] < nb_reels}
    best = sorted(reels_pairs.items(), key=lambda item: item[1], reverse=True)[:3]
    return [{**_label(reels, list(pair)), "probabilite": p} for pair, p in best]


def build_combinaisons(horses: Sequence[HorseAnalysis], nb_reels: int) -> Dict[str, object]:
    """Combinaisons calculées sur le résultat complet d'analyse_course (réels +
    outsiders virtuels). nb_reels est le nombre de chevaux réellement saisis :
    seuls eux peuvent être nommés dans une combinaison, mais la probabilité de
    chaque ordre reste calculée sur le champ complet (les outsiders virtuels
    absorbent leur part de probabilité, cf. section 7.12 du cahier des charges)."""
    probabilites_champ = [h.probabilite for h in horses]
    reels = list(horses[:nb_reels])
    ordre_favoris = sorted(range(nb_reels), key=lambda i: reels[i].probabilite, reverse=True)

    return {
        "couple": _combo_ordre_desordre(reels, nb_reels, ordre_favoris, 2, 8),
        "trio": _combo_ordre_desordre(reels, nb_reels, ordre_favoris, 3, 7),
        "quarte": _combo_ordre_desordre(reels, nb_reels, ordre_favoris, 4, 7),
        "quinte": _combo_ordre_desordre(reels, nb_reels, ordre_favoris, 5, 7),
        "couple_place": _combo_place(reels, nb_reels, probabilites_champ, 3),
        "deux_sur_quatre": _combo_place(reels, nb_reels, probabilites_champ, 4),
    }
