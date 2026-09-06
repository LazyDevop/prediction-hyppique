import json
from pathlib import Path

import pytest

from app.engine.constants import (
    DEFAULT_PARAMETERS,
    INCIDENTS,
    NIVEAU_COEFFICIENTS,
    RECENCE_FLAT,
    RECENCE_FORME,
    RECENCE_STD,
    TERRAIN_COEFFICIENTS_GRASS,
    TERRAIN_COEFFICIENTS_PSF,
)
from app.engine.scoring import (
    CourseTarget,
    HorseAnalysis,
    Performance,
    analyse_course,
    compute_forme,
    compute_note,
)

# ---------------------------------------------------------------------------
# Fixture loader + assertion mini-language (Architecture Spine AD-2).
#
# `fixtures/engine_cases.json` (repo root — neutral, owned by neither
# backend/ nor mobile/) is the single source of truth for the 6 fixed-input
# -> fixed-or-tolerance-checked-output cases below, plus the canonical
# default engine parameters. This loader/runner is deliberately small and
# the assertion type list is closed (see the story's Boundaries & Constraints):
# sum_field_approx, field_in_range, field_equals, field_greater_than,
# field_less_than_with_aggregate, any_field_not_null. Comparative/structural
# tests (e.g. test_disqualification_vs_chute below) are NOT fixture-driven —
# they stay hand-written per AD-2.
# ---------------------------------------------------------------------------

_FIXTURE_PATH = Path(__file__).resolve().parents[2] / "fixtures" / "engine_cases.json"

with open(_FIXTURE_PATH, encoding="utf-8") as _f:
    _FIXTURE = json.load(_f)

_CASES_BY_ID: dict = {}
for _case in _FIXTURE["cases"]:
    _case_id = _case["id"]
    if _case_id in _CASES_BY_ID:
        raise ValueError(f"duplicate fixture case id: {_case_id!r}")
    _CASES_BY_ID[_case_id] = _case

# Story 1.2 (AD-2): fixtures/engine_constants.json mirrors constants.py's four
# coefficient tables (terrain, niveau, incidents, recence). Loaded here too so
# test_fixture_constants_matches_constants_py below can validate it against
# the real constants.py tables mechanically.
_CONSTANTS_FIXTURE_PATH = Path(__file__).resolve().parents[2] / "fixtures" / "engine_constants.json"


def _reject_duplicate_keys(pairs: list) -> dict:
    # A duplicated JSON key (e.g. two "T" entries under "incidents") would
    # otherwise be silently resolved last-key-wins by json.load, hiding a
    # hand-edit mistake in a fixture meant to be edited across two languages.
    seen: dict = {}
    for key, value in pairs:
        if key in seen:
            raise ValueError(f"duplicate key in engine_constants.json: {key!r}")
        seen[key] = value
    return seen


with open(_CONSTANTS_FIXTURE_PATH, encoding="utf-8") as _cf:
    _CONSTANTS_FIXTURE = json.load(_cf, object_pairs_hook=_reject_duplicate_keys)


def _build_performance(data: dict) -> Performance:
    return Performance(
        partants=data["partants"],
        rang=data.get("rang"),
        distance=data.get("distance"),
        terrain=data.get("terrain"),
        niveau=data.get("niveau"),
        incident=data.get("incident"),
    )


def _build_horse(data: dict) -> HorseAnalysis:
    return HorseAnalysis(
        nom=data["nom"],
        num_pmu=data.get("num_pmu"),
        age=data.get("age"),
        poids=data.get("poids"),
        cote=data.get("cote"),
        inedit=data.get("inedit", False),
        performances=[_build_performance(p) for p in data.get("performances", [])],
    )


def _build_target(data: dict) -> CourseTarget:
    return CourseTarget(
        distance=data["distance"],
        terrain=data.get("terrain"),
        niveau=data.get("niveau"),
        nb_partants_course=data.get("nb_partants_course", 0),
    )


def _matches(horse: HorseAnalysis, criteria: dict) -> bool:
    for field_name, expected in criteria.items():
        actual = getattr(horse, field_name)
        if isinstance(expected, dict):
            if "not_null" in expected:
                if (actual is not None) != expected["not_null"]:
                    return False
            else:
                raise ValueError(f"unsupported match operator: {expected!r}")
        elif actual != expected:
            return False
    return True


def _filter_by_criteria(horses: list, criteria: dict, label: str) -> list:
    # An empty {} would trivially match every horse -- almost certainly a
    # typo'd fixture, never an intentional "match everything" spelling (that
    # is simply omitting "match"/"filter" altogether).
    if not criteria:
        raise ValueError(f"empty {label!r} dict is not allowed (would match every horse)")
    return [h for h in horses if _matches(h, criteria)]


def _select(results: list, assertion: dict) -> list:
    if "index" in assertion:
        index = assertion["index"]
        assert 0 <= index < len(results), (
            f"index {index} out of range for {len(results)} result(s): {assertion}"
        )
        return [results[index]]
    if "match" in assertion:
        return _filter_by_criteria(results, assertion["match"], "match")
    return results


def _run_assertion(results: list, assertion: dict) -> None:
    a_type = assertion["type"]

    if a_type == "sum_field_approx":
        total = sum(getattr(h, assertion["field"]) for h in results)
        assert abs(total - assertion["expected"]) < assertion["tolerance"]

    elif a_type == "field_in_range":
        selected = _select(results, assertion)
        assert selected, f"selector matched no horses: {assertion}"
        exclusive_min = assertion.get("exclusive_min", False)
        exclusive_max = assertion.get("exclusive_max", False)
        for h in selected:
            value = getattr(h, assertion["field"])
            if exclusive_min:
                assert value > assertion["min"]
            else:
                assert value >= assertion["min"]
            if exclusive_max:
                assert value < assertion["max"]
            else:
                assert value <= assertion["max"]

    elif a_type == "field_equals":
        selected = _select(results, assertion)
        assert selected, f"selector matched no horses: {assertion}"
        for h in selected:
            assert getattr(h, assertion["field"]) == assertion["expected"]

    elif a_type == "field_greater_than":
        selected = _select(results, assertion)
        assert selected, f"selector matched no horses: {assertion}"
        for h in selected:
            assert getattr(h, assertion["field"]) > assertion["than"]

    elif a_type == "field_less_than_with_aggregate":
        filtered = results
        if "filter" in assertion:
            filtered = _filter_by_criteria(filtered, assertion["filter"], "filter")
        assert filtered, f"selector matched no horses: {assertion}"
        values = [getattr(h, assertion["field"]) for h in filtered]
        aggregate = assertion.get("aggregate", "max")
        if aggregate == "max":
            agg_value = max(values)
        elif aggregate == "min":
            agg_value = min(values)
        else:
            raise ValueError(f"unknown aggregate: {aggregate!r}")
        assert agg_value < assertion["than"]

    elif a_type == "any_field_not_null":
        # AND across `fields` (a single horse must have every listed field
        # non-null), OR across horses (at least one such horse is enough) --
        # NOT an OR across fields, despite the type name reading that way.
        fields = assertion.get("fields") or [assertion["field"]]
        assert any(all(getattr(h, f) is not None for f in fields) for h in results)

    else:
        raise ValueError(f"Unknown fixture assertion type: {a_type!r}")


def _run_fixture_case(case_id: str) -> None:
    case = _CASES_BY_ID.get(case_id)
    assert case is not None, f"unknown fixture case id: {case_id!r}"
    try:
        horses = [_build_horse(h) for h in case["horses"]]
        target = _build_target(case["target"])
    except KeyError as exc:
        raise KeyError(f"fixture case {case_id!r} missing required key: {exc}") from exc
    params = case.get("params")
    mode_recence = case.get("mode_recence", "std")
    results = analyse_course(horses, target, params=params, mode_recence=mode_recence)
    for assertion in case["assertions"]:
        _run_assertion(results, assertion)


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
    _run_fixture_case("probabilities_sum_to_one")


def test_harville_sums():
    _run_fixture_case("harville_sums")


def test_bayes_shrinkage():
    _run_fixture_case("bayes_shrinkage")


def test_nr_excluded_from_forme():
    _run_fixture_case("nr_excluded_from_forme")


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
    _run_fixture_case("outsiders_virtuel_reduit")


def test_value_and_kelly():
    _run_fixture_case("value_and_kelly")


def test_fixture_default_parameters_matches_constants():
    # AD-2: the fixture's default_parameters block is validated against
    # constants.DEFAULT_PARAMETERS mechanically, not just visually kept in
    # sync — a deliberate hand-edit to either side must fail this test.
    assert _FIXTURE["default_parameters"] == DEFAULT_PARAMETERS


def test_fixture_constants_matches_constants_py():
    # Story 1.2 / AD-2: fixtures/engine_constants.json mirrors constants.py's
    # four coefficient tables exactly, mechanically — not just visually kept
    # in sync. A deliberate hand-edit to either side (including a single
    # INCIDENTS chute/ignore boolean, not just malus) must fail this test.
    # `.get(...)` + a named assertion message throughout: a fixture missing a
    # top-level table or an incident's malus/chute/ignore key should fail as
    # a readable diff, not a bare KeyError deep in a dict comprehension.
    for table_key, expected in (
        ("terrain_coefficients_grass", TERRAIN_COEFFICIENTS_GRASS),
        ("terrain_coefficients_psf", TERRAIN_COEFFICIENTS_PSF),
        ("niveau_coefficients", NIVEAU_COEFFICIENTS),
        ("recence_std", RECENCE_STD),
        ("recence_forme", RECENCE_FORME),
        ("recence_flat", RECENCE_FLAT),
    ):
        actual = _CONSTANTS_FIXTURE.get(table_key)
        assert actual is not None, f"fixture is missing top-level key: {table_key!r}"
        assert actual == expected, f"fixture[{table_key!r}] does not match constants.py"

    fixture_incidents_raw = _CONSTANTS_FIXTURE.get("incidents")
    assert fixture_incidents_raw is not None, "fixture is missing top-level key: 'incidents'"
    fixture_incidents = {}
    for code, entry in fixture_incidents_raw.items():
        for field_name in ("malus", "chute", "ignore"):
            assert field_name in entry, f"fixture incidents[{code!r}] is missing {field_name!r}"
        fixture_incidents[code] = (entry["malus"], entry["chute"], entry["ignore"])
    actual_incidents = {
        code: (defn.malus, defn.chute, defn.ignore)
        for code, defn in INCIDENTS.items()
    }
    assert fixture_incidents == actual_incidents


def test_dsl_selection_actually_filters_not_vacuous():
    # Hand-written (NOT fixture-JSON) regression on the DSL's own selection
    # machinery (_matches/_select/_run_assertion). Code review found that the
    # two fixture cases that exercise "match"/"filter" today
    # (test_bayes_shrinkage, test_outsiders_virtuel_reduit) both happen to
    # pass regardless of whether selection/filtering is broken, inverted, or
    # skipped entirely -- their asserted bound holds for the whole result set
    # anyway. This stub is engineered so the filtered-in and filtered-out
    # groups have deliberately OPPOSITE values on the asserted field, so a
    # broken/inverted/skipped selector is caught red-handed.
    stub_results = [
        HorseAnalysis(nom="Real1", num_pmu=1, score=0.2, probabilite=0.2),
        HorseAnalysis(nom="Real2", num_pmu=2, score=0.3, probabilite=0.3),
        HorseAnalysis(nom="Virtual", num_pmu=None, score=0.9, probabilite=0.9),
    ]

    # -- _matches directly: a real horse matches num_pmu-not-null, the
    # virtual one doesn't.
    assert _matches(stub_results[0], {"num_pmu": {"not_null": True}}) is True
    assert _matches(stub_results[2], {"num_pmu": {"not_null": True}}) is False

    # -- _select directly: "match" narrows to exactly the intended horse,
    # never the whole list nor its complement.
    assert [h.nom for h in _select(stub_results, {"match": {"nom": "Real1"}})] == ["Real1"]
    assert _select(stub_results, {"index": 2}) == [stub_results[2]]

    # -- _run_assertion / field_less_than_with_aggregate: filtering to real
    # horses (low probabilite) and excluding the virtual one (high
    # probabilite) passes; a filter that selects the virtual horse instead
    # (or a skipped/inverted filter, which would include 0.9) fails.
    _run_assertion(stub_results, {
        "type": "field_less_than_with_aggregate", "aggregate": "max",
        "field": "probabilite", "than": 0.5,
        "filter": {"num_pmu": {"not_null": True}},
    })
    with pytest.raises(AssertionError):
        _run_assertion(stub_results, {
            "type": "field_less_than_with_aggregate", "aggregate": "max",
            "field": "probabilite", "than": 0.5,
            "filter": {"num_pmu": {"not_null": False}},
        })

    # -- _run_assertion / field_in_range via "match": Real2's score (0.3) is
    # well outside Real1's range (0.15-0.25), so matching the wrong horse
    # would visibly fail rather than coincidentally pass.
    _run_assertion(stub_results, {
        "type": "field_in_range", "match": {"nom": "Real1"}, "field": "score",
        "min": 0.15, "max": 0.25,
    })
    with pytest.raises(AssertionError):
        _run_assertion(stub_results, {
            "type": "field_in_range", "match": {"nom": "Real2"}, "field": "score",
            "min": 0.15, "max": 0.25,
        })


def test_dsl_guards_reject_malformed_or_ambiguous_assertions():
    # Hand-written coverage for the DSL's defensive guards added in code
    # review: an out-of-range index, an empty match/filter dict, an unknown
    # match operator, an unknown aggregate, and a selector matching nothing
    # must all fail loudly and specifically, never silently pass or raise a
    # confusing bare KeyError/IndexError.
    stub_results = [
        HorseAnalysis(nom="Only", num_pmu=1, score=0.5, probabilite=0.5),
    ]

    with pytest.raises(AssertionError):
        _select(stub_results, {"index": 5})

    with pytest.raises(ValueError):
        _select(stub_results, {"match": {}})

    with pytest.raises(ValueError):
        _matches(stub_results[0], {"num_pmu": {"unsupported_op": True}})

    with pytest.raises(ValueError):
        _run_assertion(stub_results, {
            "type": "field_less_than_with_aggregate", "aggregate": "median",
            "field": "probabilite", "than": 1.0,
        })

    with pytest.raises(AssertionError):
        _run_assertion(stub_results, {
            "type": "field_equals", "match": {"nom": "Nobody"},
            "field": "score", "expected": 0.5,
        })

    with pytest.raises(AssertionError):
        _run_fixture_case("this-case-id-does-not-exist-in-the-fixture")


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
