import pytest

from app.engine.constants import DEFAULT_PARAMETERS, RECENCE_FORME, RECENCE_STD
from app.engine.scoring import (
    CourseTarget,
    HorseAnalysis,
    Performance,
    analyse_course,
    compute_forme,
    compute_note,
)


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


def test_terrain_inconnu_traite_comme_neutre():
    # perf_connu a un terrain volontairement DIFFERENT de la cible (0.7 vs
    # 1.0, dt=0.3 -> bucket 0.9, cf compute_note) : sa note n'est donc pas
    # neutre par coïncidence, contrairement à la version précédente de ce
    # test où terrain=1.0=target.terrain rendait dt=0 impossible à
    # distinguer d'un vrai None-traité-comme-neutre. perf_neutre_control a
    # un terrain qui correspond exactement à la cible (dt=0 par le chemin
    # "connu" normal, PAS par le branchement None) et sert de référence pour
    # ce que "neutre" doit vraiment donner.
    perf_connu_different = Performance(partants=10, rang=1, distance=1600, terrain=0.7, niveau=3.0, incident=None)
    perf_inconnu = Performance(partants=10, rang=1, distance=1600, terrain=None, niveau=3.0, incident=None)
    perf_neutre_control = Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None)
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=1)

    note_connu_different = compute_note(perf_connu_different, target)
    note_inconnu = compute_note(perf_inconnu, target)
    note_neutre_control = compute_note(perf_neutre_control, target)

    # terrain=None doit produire EXACTEMENT le même résultat que le cas
    # "connu et neutre par construction" (c_terr=1.0 via dt=0) ...
    assert note_inconnu == note_neutre_control
    # ... et être strictement différent du cas "connu mais différent"
    # (c_terr=0.9), ce qui prouve que le traitement neutre du None n'est pas
    # une coïncidence.
    assert note_inconnu != note_connu_different
    assert note_connu_different < note_neutre_control


def test_niveau_inconnu_traite_comme_neutre():
    perf = Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=None, incident=None)
    target_niveau_connu = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=1)
    target_niveau_inconnu = CourseTarget(distance=1600, terrain=1.0, niveau=None, nb_partants_course=1)
    assert compute_note(perf, target_niveau_connu) == compute_note(perf, target_niveau_inconnu)


def test_analyse_course_sans_params_egale_defauts_explicites():
    horses = [
        HorseAnalysis(nom=f"H{i}", num_pmu=i, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None)])
        for i in range(5)
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=5)
    sans_params = analyse_course(horses, target)
    # Passe directement les VRAIS défauts (import depuis constants.py) plutôt
    # qu'une copie retapée à la main : si DEFAULT_PARAMETERS est un jour
    # retuné, ce test continue de vérifier ce qu'il prétend vérifier au lieu
    # de comparer contre une copie figée et périmée.
    avec_defauts_explicites = analyse_course(horses, target, params=DEFAULT_PARAMETERS, mode_recence="std")
    assert [round(h.score, 9) for h in sans_params] == [round(h.score, 9) for h in avec_defauts_explicites]


def test_analyse_course_params_partiel_ne_touche_pas_les_autres_defauts():
    horses = [
        HorseAnalysis(nom="A", num_pmu=1, age=5, poids=60, cote=2.0, inedit=False,
                      performances=[Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=3.0, incident=None)]),
        HorseAnalysis(nom="B", num_pmu=2, age=5, poids=60, cote=3.0, inedit=False,
                      performances=[Performance(partants=10, rang=5, distance=1600, terrain=1.0, niveau=3.0, incident=None)]),
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=2)
    defauts = analyse_course(horses, target)
    shrink_modifie = analyse_course(horses, target, params={"shrink": 10})

    # shrink plus fort rapproche les scores de la moyenne du lot -> ecart reduit
    ecart_defaut = abs(defauts[0].score - defauts[1].score)
    ecart_shrink_fort = abs(shrink_modifie[0].score - shrink_modifie[1].score)
    assert ecart_shrink_fort < ecart_defaut

    # bankroll/fraction_kelly non surcharges restent aux defauts (100, 0.25).
    # Assertion de prémisse explicite d'abord : sans elle, si aucun cheval ne
    # satisfaisait jamais "kelly is not None and kelly > 0", la boucle
    # ci-dessous passerait silencieusement sans rien vérifier.
    assert any(h.kelly is not None and h.kelly > 0 for h in shrink_modifie)
    for horse in shrink_modifie:
        if horse.kelly is not None and horse.kelly > 0:
            assert horse.mise == pytest.approx(100.0 * horse.kelly * 0.25)


def test_compute_note_distance_buckets():
    # dd<=200 -> 1.0, dd<=500 -> 0.9, sinon 0.8 (cahier des charges 7.5).
    # sb=1.0 (rang=1/partants=10) et c_terr=c_niv=1.0 (terrain/niveau
    # identiques à la cible) isolent donc c_dist tel quel dans la note.
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=1)
    perf_proche = Performance(partants=10, rang=1, distance=1750, terrain=1.0, niveau=3.0, incident=None)  # dd=150
    perf_moyen = Performance(partants=10, rang=1, distance=2000, terrain=1.0, niveau=3.0, incident=None)   # dd=400
    perf_loin = Performance(partants=10, rang=1, distance=2300, terrain=1.0, niveau=3.0, incident=None)    # dd=700

    assert compute_note(perf_proche, target) == pytest.approx(1.0)
    assert compute_note(perf_moyen, target) == pytest.approx(0.9)
    assert compute_note(perf_loin, target) == pytest.approx(0.8)


def test_compute_note_terrain_buckets():
    # dt<0.05 -> 1.0, dt<=0.10 -> 0.95, sinon 0.9 (cahier des charges 7.5).
    # sb=1.0 et c_dist=c_niv=1.0 isolent c_terr tel quel dans la note.
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=1)
    perf_proche = Performance(partants=10, rang=1, distance=1600, terrain=1.02, niveau=3.0, incident=None)  # dt=0.02
    perf_moyen = Performance(partants=10, rang=1, distance=1600, terrain=0.93, niveau=3.0, incident=None)   # dt=0.07
    perf_loin = Performance(partants=10, rang=1, distance=1600, terrain=0.83, niveau=3.0, incident=None)    # dt=0.17

    assert compute_note(perf_proche, target) == pytest.approx(1.0)
    assert compute_note(perf_moyen, target) == pytest.approx(0.95)
    assert compute_note(perf_loin, target) == pytest.approx(0.9)


def test_compute_note_niveau_ratio_eloigne_de_un():
    # c_niv = clamp(sqrt(niveau/cible), 0.55, 1.5) (cahier des charges 7.5).
    # sb=1.0 et c_dist=c_terr=1.0 isolent c_niv tel quel dans la note.
    target = CourseTarget(distance=1600, terrain=1.0, niveau=2.0, nb_partants_course=1)
    perf_tres_superieur = Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=5.0, incident=None)
    # ratio=5/2=2.5, sqrt=1.581... -> clampé au plafond 1.5
    perf_legerement_inferieur = Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=1.0, incident=None)
    # ratio=1/2=0.5, sqrt=0.707... -> pas de clamp
    perf_tres_inferieur = Performance(partants=10, rang=1, distance=1600, terrain=1.0, niveau=0.2, incident=None)
    # ratio=0.2/2=0.1, sqrt=0.316... -> clampé au plancher 0.55

    assert compute_note(perf_tres_superieur, target) == pytest.approx(1.5)
    assert compute_note(perf_legerement_inferieur, target) == pytest.approx(0.5 ** 0.5)
    assert compute_note(perf_tres_inferieur, target) == pytest.approx(0.55)


def test_analyse_course_cheval_inedit_utilise_coef_inedit():
    # Cahier des charges 7.7 : un cheval inédit (fait connu, pas une donnée
    # manquante) reçoit score = base * coef_inedit * c_poids * c_age, avec
    # base = moyenne_forme du lot (calculée sur les chevaux ayant des perfs).
    horses = [
        HorseAnalysis(nom="Veteran", num_pmu=1, age=5, poids=60, cote=3.0, inedit=False,
                      performances=[Performance(partants=10, rang=2, distance=1600, terrain=1.0, niveau=3.0, incident=None)]),
        HorseAnalysis(nom="Debutant", num_pmu=2, age=5, poids=60, cote=5.0, inedit=True, performances=[]),
    ]
    target = CourseTarget(distance=1600, terrain=1.0, niveau=3.0, nb_partants_course=2)
    results = analyse_course(horses, target)

    debutant = next(h for h in results if h.nom == "Debutant")
    assert debutant.nb_perfs == 0

    with_data = [h for h in results if h.nb_perfs > 0]
    moyenne_forme = sum(h.forme for h in with_data) / len(with_data)
    base = moyenne_forme if moyenne_forme > 0 else 1.0
    expected_score = base * DEFAULT_PARAMETERS["coef_inedit"] * debutant.c_poids * debutant.c_age

    assert debutant.score == pytest.approx(expected_score)
