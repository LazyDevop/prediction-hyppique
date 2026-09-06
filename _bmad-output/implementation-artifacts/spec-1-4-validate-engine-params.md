---
title: 'Story 1.4: Validate engine params at the API boundary'
type: 'bugfix'
created: '2026-09-06'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/implementation-artifacts/deferred-work.md']
baseline_commit: '61a9d41c077cda63fd7a786db56e65ee37e6b949'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `AnalyseIn.params: Optional[Dict[str, float]]` accepts anything — a mistyped key (`"shrnk"`) is silently dropped by `analyse_course`'s dict-merge over `DEFAULT_PARAMETERS`, and a malformed value (negative `shrink`, `age_min > age_max`) either crashes deep inside the engine or silently produces wrong scores. Last item of the Epic 1 dev-agent debt list (`deferred-work.md`).

**Approach:** Replace the raw dict with a typed `EngineParamsIn` Pydantic model mirroring `DEFAULT_PARAMETERS`'s keys, `extra="forbid"` so an unknown key becomes an automatic 422, per-field bounds justified by what each parameter actually does in `analyse_course`/`compute_note`, and a model validator rejecting `age_min > age_max`. `routes_analyse.py` converts the validated model to a plain dict (`exclude_none`) before calling `analyse_course` — the engine itself is untouched.

## Boundaries & Constraints

**Always:**
- `EngineParamsIn`'s field names match `DEFAULT_PARAMETERS`'s keys exactly: `malus_incident, sensibilite_poids, age_min, age_max, shrink, coef_inedit, contraste, bankroll, fraction_kelly`. All `Optional[float] = None` (or `Optional[int] = None` for `age_min`/`age_max`, matching `DEFAULT_PARAMETERS`'s actual types) — a partial override (only some keys set) must keep working exactly as today.
- `model_config = ConfigDict(extra="forbid")` on `EngineParamsIn` — an unrecognized key is a FastAPI 422, not a silently-dropped value.
- Bounds, each traced to a real engine failure mode (not invented): `shrink >= 0`, `malus_incident >= 0`, `sensibilite_poids >= 0`, `bankroll >= 0`, `coef_inedit >= 0` (all are multipliers/counts that go negative only by mistake); `contraste > 0` strictly (zero or negative degenerates or inverts the Plackett-Luce `max(score, 0.0001) ** contraste` ranking in `analyse_course`); `fraction_kelly` in `[0, 1]` (it's a fraction of the Kelly stake, cahier des charges §7.11).
- A model-level validator rejects `age_min > age_max` when both are provided (either one alone, or neither, is fine — no cross-field requirement when only one is set).
- `analyse_course`'s own signature and internals are untouched — it still receives a plain `Optional[dict]`, unaware anything upstream changed.
- Every existing test in `test_scoring.py`/`test_routes_analyse.py` that passes `params=` a plain dict directly to `analyse_course` (not through the API) keeps working untouched — this story only adds validation at the FastAPI boundary.

**Never:**
- Do not add bounds beyond the ones listed above (no inventing constraints on `age_min`/`age_max` individually, `malus_incident`'s upper bound, etc.) — if a case for more turns up later, that's a new story.
- Do not change `constants.py`, `scoring.py`, or `combinatoire.py`.

</frozen-after-approval>

## Code Map

- `backend/app/schemas/analyse.py` -- MODIFY -- add `EngineParamsIn`; change `AnalyseIn.params: Optional[Dict[str, float]]` -> `Optional[EngineParamsIn]`
- `backend/app/api/routes_analyse.py` -- MODIFY -- convert `request.params` to a plain dict (`.model_dump(exclude_none=True)` if present, else `None`) before calling `analyse_course`
- `backend/app/engine/constants.py` -- READ-ONLY -- `DEFAULT_PARAMETERS`'s exact keys/types, the contract `EngineParamsIn` must mirror
- `backend/app/engine/scoring.py` -- READ-ONLY -- `analyse_course`'s use of each parameter (`contraste` as the Plackett-Luce exponent, `fraction_kelly`/`bankroll` in the Kelly stake, `shrink` in Bayesian shrinkage, `age_min`/`age_max` in `_compute_c_age`) — the reasoning behind each bound
- `backend/tests/test_routes_analyse.py` -- MODIFY -- add the 4 validation-path tests

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/schemas/analyse.py` -- add `EngineParamsIn` (bounds + `extra="forbid"`), repoint `AnalyseIn.params`
- [x] `backend/app/api/routes_analyse.py` -- pass a plain dict to `analyse_course`, not the Pydantic model
- [x] `backend/tests/test_routes_analyse.py` -- 4 new tests (unknown key -> 422, negative `shrink` -> 422, `age_min > age_max` -> 422, valid partial override -> 200 and behaves as before)
- [x] Run `pytest backend/tests/ -v` -- 64 passed, verified independently

**Acceptance Criteria:**
- Given `POST /analyse` with `params={"shrnk": 2, ...}`, when processed, then the response is 422, not a 200 that silently ignored the typo.
- Given `params={"shrink": -1}` (or any out-of-bounds value from the list above), when processed, then the response is 422.
- Given `params={"age_min": 8, "age_max": 4}`, when processed, then the response is 422.
- Given `params={"shrink": 5}` (a valid partial override, everything else defaulted), when processed, then the response is 200 and the result reflects the overridden `shrink` with all other defaults intact — matching `test_analyse_course_params_partiel_ne_touche_pas_les_autres_defauts`'s existing behavior, now reachable through the real API too.

## Verification

**Commands:**
- `cd backend && pytest tests/ -v` -- expected: 78 passed (64 from initial implementation + patches added during code review)

## Suggested Review Order

**The fix (EngineParamsIn)**

- Entry point: the model itself — bounds, `extra="forbid"`, and the code-review note on why age validation checks effective (post-merge) values.
  [`analyse.py:6`](../../backend/app/schemas/analyse.py#L6)

- The age-bounds validator — tightened during review to compare against `DEFAULT_PARAMETERS` fallbacks, not just the two submitted fields.
  [`analyse.py:40`](../../backend/app/schemas/analyse.py#L40)

- The construction site — converts the validated model to the plain dict `analyse_course` already expects.
  [`routes_analyse.py:47`](../../backend/app/api/routes_analyse.py#L47)

**Regression coverage (most of it added/corrected during review)**

- The single most important test: proves a *partial* override (`age_min` alone) is caught, not just a full one.
  [`test_routes_analyse.py:191`](../../backend/tests/test_routes_analyse.py#L191)

- Parametrized coverage for all 9 bounds — 6 of 9 had zero coverage before review.
  [`test_routes_analyse.py:204`](../../backend/tests/test_routes_analyse.py#L204)

**Peripherals**

- Valid partial override still works and defaults survive the new schema round-trip.
  [`test_routes_analyse.py:226`](../../backend/tests/test_routes_analyse.py#L226)
