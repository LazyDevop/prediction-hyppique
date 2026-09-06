---
title: 'Story 1.3: Type /analyse response via HorseOut (fixes AD-4)'
type: 'bugfix'
created: '2026-09-06'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md']
baseline_commit: 'c1387e59637d4ec71620b56199eeb906663a23cd'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `routes_analyse.py`'s `/analyse` endpoint ships `resultats=[horse.__dict__ for horse in results if horse.num_pmu is not None]`, typed as a bare `List[Dict]` on `AnalyseOut`. The already-defined `HorseOut` Pydantic schema is never used — a live violation of Architecture AD-4, and the exact anti-pattern (raw dataclass dump instead of a typed schema) that let internal-only fields (`performances`, `nb_perfs`, `forme`, `c_poids`, `c_age`) leak into the public API response.

**Approach:** Type `AnalyseOut.resultats` as `List[HorseOut]`; construct each `HorseOut` via `HorseOut.model_validate(horse, from_attributes=True)`, which reads only `HorseOut`'s declared fields off the `HorseAnalysis` dataclass instance rather than dumping everything. Add a contract test proving the real response only ever contains `HorseOut`'s declared fields.

## Boundaries & Constraints

**Always:**
- `HorseOut.model_validate(horse, from_attributes=True)` (or equivalent per-model `from_attributes=True` config) is how each result is built — never `horse.__dict__`, never a hand-written field-by-field dict.
- The existing filter (`if horse.num_pmu is not None`, excluding virtual outsiders) is preserved exactly — this story fixes the typing, not the filtering (already fixed in an earlier story).
- `HorseOut`'s field set is unchanged — this story does not add or remove fields from the public contract, only enforces it's actually used.
- The `/analyse` route keeps `response_model=AnalyseOut` (already present) so FastAPI's own response validation is the enforcement mechanism, not a manual check.

**Never:**
- Do not change `analyse_course`, `HorseAnalysis`, or any engine file — this is a schema/API-layer fix only.
- Do not change `Combinaisons`/`ComboItem` or anything about the `combinaisons` field of `AnalyseOut`.
- Do not add authentication, pagination, or any capability beyond the typing fix.

</frozen-after-approval>

## Code Map

- `backend/app/schemas/analyse.py` -- MODIFY -- `AnalyseOut.resultats: List[Dict]` -> `List[HorseOut]`
- `backend/app/api/routes_analyse.py` -- MODIFY -- the `resultats = [...]` line, construct `HorseOut` per horse instead of `.__dict__`
- `backend/app/engine/scoring.py` -- READ-ONLY -- `HorseAnalysis`'s full field set (includes non-`HorseOut` fields: `performances`, `nb_perfs`, `forme`, `c_poids`, `c_age`) — what must NOT leak
- `backend/tests/test_routes_analyse.py` -- MODIFY -- extend the existing test (or add one) asserting the response contains only `HorseOut`'s fields

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/schemas/analyse.py` -- `AnalyseOut.resultats: List[HorseOut]` -- makes the schema real instead of aspirational
- [x] `backend/app/api/routes_analyse.py` -- build `HorseOut.model_validate(horse, from_attributes=True)` per (filtered) horse -- closes AD-4's violation
- [x] `backend/tests/test_routes_analyse.py` -- assert the JSON response's result objects contain exactly `HorseOut`'s field set, nothing more -- proves the leak is closed, not just renamed
- [x] Run `pytest backend/tests/ -v` -- 57 passed, verified independently

**Acceptance Criteria:**
- Given a `POST /analyse` request with real horses, when the response is parsed, then every object in `resultats` has exactly the keys `nom, num_pmu, age, poids, cote, inedit, score, probabilite, top1, top2, top3, top4, value, kelly, mise` — no `performances`, `nb_perfs`, `forme`, `c_poids`, or `c_age`.
- Given the same request, when `nb_partants_course` exceeds the horse count (virtual outsiders exist), then `resultats` still excludes them (pre-existing behavior, unchanged).

## Verification

**Commands:**
- `cd backend && pytest tests/ -v` -- expected: 60 passed, no regressions

## Suggested Review Order

**The fix itself (AD-4)**

- Entry point: the schema fix — `resultats` is now really `List[HorseOut]`.
  [`analyse.py:75`](../../backend/app/schemas/analyse.py#L75)

- `HorseOut.model_config` — `from_attributes` on the model, not the call site (tightened during review).
  [`analyse.py:36`](../../backend/app/schemas/analyse.py#L36)

- The construction site itself — one line, replacing the `.__dict__` anti-pattern.
  [`routes_analyse.py:54`](../../backend/app/api/routes_analyse.py#L54)

**Regression coverage (strengthened during review)**

- The original field-set/leak test.
  [`test_routes_analyse.py:31`](../../backend/tests/test_routes_analyse.py#L31)

- Per-horse value-mapping check — proves no field got attached to the wrong horse.
  [`test_routes_analyse.py:71`](../../backend/tests/test_routes_analyse.py#L71)

**Peripherals**

- Edge cases: all-filtered-out horses, and `None` propagation through `Optional` fields.
  [`test_routes_analyse.py:108`](../../backend/tests/test_routes_analyse.py#L108)
