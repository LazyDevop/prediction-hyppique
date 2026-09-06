---
title: 'Story 1.1: Shared fixture for engine test cases and default parameters'
type: 'chore'
created: '2026-09-06'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md']
baseline_commit: 'a9a93c134d45d7ad1816aaaddf7c078be9197d67'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `backend/tests/test_scoring.py` hand-encodes its fixed-input/fixed-output test cases and the engine's default parameters. Architecture Spine AD-2 requires these to live in a shared, language-neutral fixture so a future Dart port (Epic 3) can't silently diverge from the Python engine on either.

**Approach:** Extract the 6 currently-existing cases that are genuinely fixed-input → fixed-or-tolerance-checked-output (not comparative-between-two-results, which AD-2 explicitly carves out and leaves hand-written) into `fixtures/engine_cases.json`, plus the canonical default parameters mirroring `DEFAULT_PARAMETERS`. Adapt `test_scoring.py` to load and iterate this file for those 6 cases via a small, typed assertion mini-language; leave the other 11 tests (comparative/structural, e.g. `test_disqualification_vs_chute`, the terrain/niveau-neutral-equivalence pair, the params-override pair) exactly as they are.

## Boundaries & Constraints

**Always:**
- The 6 fixture-eligible cases: `test_probabilities_sum_to_one`, `test_harville_sums`, `test_bayes_shrinkage`, `test_nr_excluded_from_forme`, `test_outsiders_virtuel_reduit`, `test_value_and_kelly`. Every one of these tests must still exist as a named pytest function, must still pass, and must assert exactly what it asserts today — the fixture changes *where the numbers live*, not what's verified.
- `fixtures/engine_cases.json` lives at the repository root (Architecture AD-2 — neutral, owned by neither `backend/` nor `mobile/`).
- The default-parameters block in the fixture must be validated against `backend/app/engine/constants.py`'s `DEFAULT_PARAMETERS` (a test asserting equality) — not just visually similar, mechanically checked.
- Assertion types needed, minimum: sum-of-field-approx-equals (harville, probability-sum), field-in-range (bayes shrinkage bounds), field-equals (nb_perfs), field-greater-than (forme > 0), field-less-than-with-aggregate (outsider max probability), any-field-not-null (value/Kelly). Keep this list closed — do not invent assertion types beyond what these 6 cases need.
- The 11 comparative/structural tests are untouched: same code, same assertions, same pass/fail behavior before and after this change.

**Ask First:**
- None anticipated — this is a mechanical extraction of already-decided, already-passing test cases.

**Never:**
- Do not touch `test_combinatoire.py`, `scoring.py`, `combinatoire.py`, or `constants.py`'s values (validate against them, never edit them).
- Do not start the Dart-side fixture consumer — that's Epic 3 work, out of scope here (this fixture existing and being correct is the prerequisite, not the port itself).
- Do not fold the 4 remaining coefficient tables (terrain/niveau/incidents/récence) into this file — that's Story 1.2 (`fixtures/engine_constants.json`), a separate story.

</frozen-after-approval>

## Code Map

- `fixtures/engine_cases.json` -- TO CREATE -- the shared fixture (new file, repo root)
- `backend/tests/test_scoring.py` -- MODIFY -- 6 tests switch from hand-coded literals to fixture-driven; 11 others untouched
- `backend/app/engine/scoring.py` -- READ-ONLY -- `analyse_course`, `HorseAnalysis`, `Performance`, `CourseTarget` signatures the fixture's `horses`/`target` blocks must match exactly
- `backend/app/engine/constants.py` -- READ-ONLY -- `DEFAULT_PARAMETERS`, the validation target for the fixture's defaults block
- `_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md` -- AD-2 (§Invariants & Rules) -- the binding constraint on scope and file location

## Tasks & Acceptance

**Execution:**
- [x] `fixtures/engine_cases.json` -- create with `default_parameters` block + 6 cases (id, horses, target, optional params/mode_recence, assertions[]) -- the shared source of truth AD-2 requires
- [x] `backend/tests/test_scoring.py` -- add a small fixture-loader + assertion-DSL runner; rewrite the 6 eligible tests to iterate fixture cases by id; add one test validating the fixture's `default_parameters` against `constants.DEFAULT_PARAMETERS` -- closes the loop AD-2 exists for
- [x] Run `pytest backend/tests/test_scoring.py -v` -- 20 tests pass (17 original + default-parameters validation test + 2 hand-written DSL regression tests added during review) -- proves the extraction changed nothing observable, verified independently; full backend suite (56 tests) also passes with no regressions

**Acceptance Criteria:**
- Given the fixture file and the rewritten tests, when `pytest` runs, then all 17 `test_scoring.py` tests pass, including the 11 untouched comparative ones.
- Given a deliberately-wrong value hand-edited into `fixtures/engine_cases.json`'s `default_parameters` (a manual check, not an automated one), when the new default-parameters-validation test runs, then it fails — proving the check is real, not a no-op.
- Given `fixtures/engine_cases.json`, when inspected, then no case includes `test_disqualification_vs_chute`-style comparative content — only the 6 named fixed-input/fixed-output cases.

## Design Notes

Assertion DSL shape (minimum, closed set — see Boundaries):
```json
{"type": "sum_field_approx", "field": "probabilite", "expected": 1.0, "tolerance": 1e-6}
{"type": "field_in_range", "match": {"nom": "A"}, "field": "score", "min": 0.65, "max": 1.0}
{"type": "field_equals", "index": 0, "field": "nb_perfs", "expected": 1}
{"type": "any_field_not_null", "field": "value"}
```
`match`/`index` select which horse(s) in the result list an assertion applies to; omit both to apply over the whole list (as `sum_field_approx` and `any_field_not_null` do).

## Verification

**Commands:**
- `cd backend && pytest tests/test_scoring.py -v` -- expected: 20 passed

## Suggested Review Order

**The shared fixture (AD-2's actual deliverable)**

- Entry point: what the fixture claims to be, and its scope boundary (does NOT include the coefficient tables — that's Story 1.2).
  [`engine_cases.json:2`](../../fixtures/engine_cases.json#L2)

- The 6 fixed-input/fixed-output cases and their assertions — the content this whole story exists to extract.
  [`engine_cases.json:14`](../../fixtures/engine_cases.json#L14)

**The assertion DSL — closed-set, defensively guarded**

- `_run_assertion`: all 6 assertion types, now with explicit guards (empty-selection, unknown aggregate) added during review.
  [`test_scoring.py:110`](../../backend/tests/test_scoring.py#L110)

- `_matches`/`_filter_by_criteria`/`_select`: selection primitives — reject empty/unsupported criteria rather than silently matching everything.
  [`test_scoring.py:75`](../../backend/tests/test_scoring.py#L75)

**Regression coverage added during review (closes the "broken-verification" gap)**

- Proves broken/inverted/skipped selection would actually be caught — the review's central finding.
  [`test_scoring.py:263`](../../backend/tests/test_scoring.py#L263)

- Proves every new guard (bad index, empty dict, unknown operator, unknown aggregate, empty selection) fails loudly.
  [`test_scoring.py:319`](../../backend/tests/test_scoring.py#L319)

**Peripherals**

- The 6 migrated tests, now one-liners delegating to the fixture.
  [`test_scoring.py:218`](../../backend/tests/test_scoring.py#L218)

- Mechanical parity check: fixture defaults vs. `constants.DEFAULT_PARAMETERS`.
  [`test_scoring.py:256`](../../backend/tests/test_scoring.py#L256)
