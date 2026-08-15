import pytest

from app.engine.constants import RECENCE_FORME, RECENCE_STD
from app.engine.scoring import CourseTarget, HorseAnalysis, Performance, analyse_course, compute_forme


def test_mode_recence_std_vs_forme_utilisent_des_courbes_distinctes():
    # Non-régression : compute_forme(mode="std") doit utiliser RECENCE_STD, pas
    # RECENCE_FORME (bug constaté : les deux branches renvoyaient RECENCE_FORME).
    performances = [
        Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None),
        Performance(partants=10, rang=10, distance=1600, terrain=1.0, niveau=3.0, incident=None),
    ]
    forme_std = compute_forme(performances, mode="std")
    forme_agressif = compute_forme(performances, mode="forme")
    assert RECENCE_STD[1] != RECENCE_FORME[1]
    assert forme_std != forme_agressif


def test_compute_forme_tronque_a_6_performances():
    # Historique profond (backfill) : seules les 6 plus récentes comptent,
    # le reste est ignoré plutôt que d'étendre les tableaux de pondération
    # (section 7.3, choix documenté dans compute_forme).
    six_victoires = [
        Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None)
        for _ in range(6)
    ]
    forme_6 = compute_forme(six_victoires, mode="std")

    dix_victoires = six_victoires + [
        Performance(partants=10, rang=10, distance=1600, terrain=1.0, niveau=3.0, incident=None)
        for _ in range(4)
    ]
    forme_10_avec_mauvaises_en_queue = compute_forme(dix_victoires, mode="std")

    assert forme_6 == forme_10_avec_mauvaises_en_queue


def test_probabilities_sum_to_one():
    horses = [
        HorseAnalysis(nom=f"H{i}", num_pmu=i, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None)]
                      ) for i in range(5)
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=5)
    results = analyse_course(horses, target)
    assert abs(sum(h.probabilite for h in results) - 1.0) < 1e-6


def test_harville_sums():
    horses = [
        HorseAnalysis(nom=f"H{i}", num_pmu=i, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[Performance(partants=10, rang=i + 1, distance=1600, terrain=1.0, niveau=3.0, incident=None)]
                      ) for i in range(6)
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=6)
    results = analyse_course(horses, target)
    assert abs(sum(h.top1 for h in results) - 1.0) < 1e-6
    assert abs(sum(h.top2 for h in results) - 2.0) < 1e-6
    assert abs(sum(h.top3 for h in results) - 3.0) < 1e-6
    assert abs(sum(h.top4 for h in results) - 4.0) < 1e-6


def test_bayes_shrinkage():
    horses = [
        HorseAnalysis(nom="A", num_pmu=1, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None)]),
        HorseAnalysis(nom="B", num_pmu=2, age=5, poids=60, cote=3.0, inedit=False,
                      performances=[Performance(partants=10, rang=5, distance=1600, terrain=1.0, niveau=3.0, incident=None)]),
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=2)
    results = analyse_course(horses, target)
    horse_a = next(h for h in results if h.nom == "A")
    assert horse_a.score < 1.0
    assert horse_a.score > 0.65


def test_nr_excluded_from_forme():
    horses = [
        HorseAnalysis(nom="NR", num_pmu=1, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[
                          Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident="NR"),
                          Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None),
                      ])
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=1)
    results = analyse_course(horses, target)
    assert results[0].nb_perfs == 1
    assert results[0].forme > 0


def test_disqualification_vs_chute():
    horses = [
        HorseAnalysis(nom="D", num_pmu=1, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident="D")]),
        HorseAnalysis(nom="T", num_pmu=2, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident="T")]),
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=2)
    results = analyse_course(horses, target)
    score_d = next(h.score for h in results if h.nom == "D")
    score_t = next(h.score for h in results if h.nom == "T")
    assert score_d > score_t


def test_outsiders_virtuel_reduit():
    horses = [
        HorseAnalysis(nom=f"H{i}", num_pmu=i, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None)])
        for i in range(5)
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=14)
    results = analyse_course(horses, target)
    favouri_prob = max(h.probabilite for h in results if h.num_pmu is not None)
    assert favouri_prob < 0.5


def test_value_and_kelly():
    horses = [
        HorseAnalysis(nom=f"H{i}", num_pmu=i, age=5, poids=60, cote=cote, inedit=False,
                      performances=[Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None)])
        for i, cote in enumerate([2.4, 3.6, 5.0, 7.0, 11.0])
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=5)
    results = analyse_course(horses, target)
    assert any(h.value is not None and h.mise is not None for h in results)
