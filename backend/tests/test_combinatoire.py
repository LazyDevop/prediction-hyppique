import pytest

from app.engine.combinatoire import (
    build_combinaisons,
    exact_ordered,
    exact_permutations_probabilities,
    exact_unordered,
    monte_carlo_place_probabilities,
)
from app.engine.scoring import CourseTarget, HorseAnalysis, Performance, analyse_course


def test_desordre_egale_somme_des_permutations_ordre():
    """L'aggregation "desordre" d'un ensemble doit etre exactement la somme
    des probabilites de toutes les permutations ordonnees de ce meme
    ensemble (cahier des charges 7.12) — pas une approximation."""
    probabilities = [0.4, 0.3, 0.2, 0.1]
    ordered = exact_ordered(probabilities, 2)
    unordered = exact_unordered(probabilities, 2)

    for entry in unordered:
        ensemble = frozenset(entry["ensemble"])
        somme_attendue = sum(
            o["probabilite"] for o in ordered if frozenset(o["ordre"]) == ensemble
        )
        assert entry["probabilite"] == pytest.approx(somme_attendue)


def test_ratio_desordre_ordre_croit_avec_la_taille_combinaison():
    """Cahier des charges section 9, cas 8 : le ratio desordre/ordre doit
    croitre avec la taille de la combinaison (~x2 pour couple, bien plus
    pour quinte) — signe que le calcul combinatoire est correct."""
    probabilities = [0.30, 0.22, 0.18, 0.13, 0.09, 0.05, 0.03]

    def meilleur_ratio(depth: int) -> float:
        ordered = exact_ordered(probabilities, depth)
        unordered = exact_unordered(probabilities, depth)
        return unordered[0]["probabilite"] / ordered[0]["probabilite"]

    ratio_couple = meilleur_ratio(2)
    ratio_tierce = meilleur_ratio(3)
    ratio_quarte = meilleur_ratio(4)

    assert ratio_couple > 1.0
    assert ratio_tierce > ratio_couple
    assert ratio_quarte > ratio_tierce


def test_exact_ordered_trie_par_probabilite_decroissante():
    probabilities = [0.1, 0.5, 0.25, 0.15]
    ordered = exact_ordered(probabilities, 2)
    probas = [item["probabilite"] for item in ordered]
    assert probas == sorted(probas, reverse=True)


def test_exact_permutations_probabilities_couvre_toutes_les_permutations():
    """Quand depth == nombre de chevaux, la somme de TOUTES les permutations
    doit valoir 1.0 (aucune masse de probabilite perdue ou dupliquee)."""
    probabilities = [0.5, 0.3, 0.2]
    toutes = exact_permutations_probabilities(probabilities, depth=3)
    assert len(toutes) == 6  # 3! permutations
    assert sum(toutes.values()) == pytest.approx(1.0)


def test_exact_unordered_somme_egale_1_quand_profondeur_couvre_tout_le_champ():
    probabilities = [0.5, 0.3, 0.2]
    unordered = exact_unordered(probabilities, depth=3)
    assert len(unordered) == 1  # un seul ensemble possible avec 3 chevaux et depth=3
    assert unordered[0]["probabilite"] == pytest.approx(1.0)


def test_monte_carlo_place_deterministe_avec_seed_fixe():
    probs = [0.5, 0.3, 0.2]
    result1 = monte_carlo_place_probabilities(probs, top_m=2, trials=5000, seed=42)
    result2 = monte_carlo_place_probabilities(probs, top_m=2, trials=5000, seed=42)
    assert result1 == result2


def test_monte_carlo_place_deux_chevaux_top2_toujours_ensemble():
    """Avec exactement 2 chevaux et top_m=2, la seule paire possible est
    necessairement dans le top 2 a chaque tirage — frequence de 1.0."""
    probs = [0.6, 0.4]
    result = monte_carlo_place_probabilities(probs, top_m=2, trials=2000, seed=0)
    assert result[(0, 1)] == pytest.approx(1.0)


def test_monte_carlo_place_seed_est_reellement_utilisee():
    """Deux seeds differentes doivent produire des tirages differents —
    preuve que `seed` influence reellement le resultat plutot que d'etre
    ignoree silencieusement."""
    probs = [0.4, 0.3, 0.2, 0.1]
    result_seed_0 = monte_carlo_place_probabilities(probs, top_m=2, trials=3000, seed=0)
    result_seed_1 = monte_carlo_place_probabilities(probs, top_m=2, trials=3000, seed=1)
    assert result_seed_0 != result_seed_1


def test_monte_carlo_place_top_m_supérieur_au_nombre_de_chevaux_est_borne():
    """top_m > n doit etre silencieusement borne a n (voir `top_m =
    min(top_m, n)`), pas lever d'exception ni produire des paires hors
    bornes."""
    probs = [0.5, 0.3, 0.2]
    result = monte_carlo_place_probabilities(probs, top_m=10, trials=1000, seed=0)
    for (a, b) in result:
        assert 0 <= a < len(probs)
        assert 0 <= b < len(probs)


def test_monte_carlo_place_top_m_un_ne_forme_aucune_paire():
    probs = [0.5, 0.3, 0.2]
    result = monte_carlo_place_probabilities(probs, top_m=1, trials=500, seed=0)
    assert result == {}


def _horses(n: int) -> list:
    return [
        HorseAnalysis(
            nom=f"H{i}", num_pmu=i + 1, age=5, poids=60, cote=2.0 + i, inedit=False,
            performances=[Performance(partants=10, rang=i + 1, distance=1600, terrain=1.0, niveau=3.0, incident=None)],
        )
        for i in range(n)
    ]


def test_build_combinaisons_structure_complete():
    horses = _horses(8)
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=8)
    results = analyse_course(horses, target)

    combinaisons = build_combinaisons(results, len(horses))

    assert set(combinaisons.keys()) == {
        "couple", "trio", "quarte", "quinte", "couple_place", "deux_sur_quatre",
    }
    for key in ("couple", "trio", "quarte", "quinte"):
        assert set(combinaisons[key].keys()) == {"ordre", "desordre"}


def test_build_combinaisons_nomme_uniquement_les_chevaux_reels():
    """Meme quand analyse_course ajoute des outsiders virtuels (cahier des
    charges 7.8), build_combinaisons ne doit jamais les nommer dans une
    combinaison — seuls les dossards reellement saisis apparaissent, pour
    les 4 familles ordre/desordre ET les deux paris Monte-Carlo."""
    horses = _horses(5)
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=14)
    results = analyse_course(horses, target)

    combinaisons = build_combinaisons(results, len(horses))

    dossards_reels = {h.num_pmu for h in horses}
    for key in ("couple", "trio", "quarte", "quinte"):
        for combo in combinaisons[key]["ordre"] + combinaisons[key]["desordre"]:
            assert all(d in dossards_reels for d in combo["dossards"])
    for key in ("couple_place", "deux_sur_quatre"):
        for combo in combinaisons[key]:
            assert all(d in dossards_reels for d in combo["dossards"])


def test_build_combinaisons_gate_correctement_par_profondeur():
    """Avec 3 chevaux saisis : couple (depth 2) et trio (depth 3) doivent
    etre satisfaisables et non vides, tandis que quarte (depth 4) et quinte
    (depth 5) doivent etre vides — la version precedente de ce test ne
    verifiait que "quinte est vide", incapable de distinguer un vrai
    gating par profondeur d'un bug qui viderait tout systematiquement."""
    horses = _horses(3)
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=3)
    results = analyse_course(horses, target)

    combinaisons = build_combinaisons(results, len(horses))

    assert combinaisons["couple"]["ordre"] != []
    assert combinaisons["couple"]["desordre"] != []
    assert combinaisons["trio"]["ordre"] != []
    assert combinaisons["trio"]["desordre"] != []
    assert combinaisons["quarte"]["ordre"] == []
    assert combinaisons["quarte"]["desordre"] == []
    assert combinaisons["quinte"]["ordre"] == []
    assert combinaisons["quinte"]["desordre"] == []


def test_build_combinaisons_troncature_a_trois_entrees():
    """couple/trio/quarte/quinte (ordre et desordre) et les paris
    Monte-Carlo sont tous plafonnes a 3 entrees, meme avec un pool de
    chevaux largement suffisant pour en produire davantage."""
    horses = _horses(8)
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=8)
    results = analyse_course(horses, target)

    combinaisons = build_combinaisons(results, len(horses))

    for key in ("couple", "trio", "quarte", "quinte"):
        assert len(combinaisons[key]["ordre"]) <= 3
        assert len(combinaisons[key]["desordre"]) <= 3
    for key in ("couple_place", "deux_sur_quatre"):
        assert len(combinaisons[key]) <= 3


def test_build_combinaisons_forme_dun_item_de_combinaison():
    horses = _horses(6)
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=6)
    results = analyse_course(horses, target)

    combinaisons = build_combinaisons(results, len(horses))

    item = combinaisons["couple"]["ordre"][0]
    assert set(item.keys()) == {"dossards", "noms", "probabilite"}
    assert len(item["dossards"]) == len(item["noms"]) == 2


def test_build_combinaisons_associe_le_bon_dossard_au_bon_nom():
    """Les chevaux ont des num_pmu volontairement dans le desordre (pas
    1..n dans l'ordre d'entree) pour prouver que _label associe le bon
    dossard au bon nom par identite du cheval, pas par coincidence d'index
    sequentiel."""
    horses = [
        HorseAnalysis(nom="Favori", num_pmu=42, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None)]),
        HorseAnalysis(nom="Outsider", num_pmu=7, age=5, poids=60, cote=15.0, inedit=False,
                      performances=[Performance(partants=10, rang=6, distance=1600, terrain=1.0, niveau=3.0, incident=None)]),
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=2)
    results = analyse_course(horses, target)

    combinaisons = build_combinaisons(results, len(horses))
    item = combinaisons["couple"]["desordre"][0]

    for dossard, nom in zip(item["dossards"], item["noms"]):
        attendu = next(h.nom for h in horses if h.num_pmu == dossard)
        assert nom == attendu


def test_build_combinaisons_avec_aucun_cheval():
    """Une course sans aucun cheval saisi doit degrader proprement (toutes
    les combinaisons vides), jamais lever d'exception."""
    combinaisons = build_combinaisons([], 0)

    for key in ("couple", "trio", "quarte", "quinte"):
        assert combinaisons[key]["ordre"] == []
        assert combinaisons[key]["desordre"] == []
    for key in ("couple_place", "deux_sur_quatre"):
        assert combinaisons[key] == []
