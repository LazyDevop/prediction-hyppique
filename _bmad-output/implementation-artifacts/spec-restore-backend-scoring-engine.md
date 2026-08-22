---
title: 'Reconstruct corrupted backend scoring engine (main.py + scoring.py)'
type: 'bugfix'
created: '2026-08-22'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/docs/cahier_des_charges_backend_hippique.md']
baseline_commit: 'c0c2e7944a352643782aa8ee0ed1b1d9eaecb69c'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `backend/app/main.py` and `backend/app/engine/scoring.py` contain only corrupted binary placeholder data (confirmed: one repeating 512-byte block, zero recoverable information) since the repo's initial commit. `scoring.py` is the product's core differentiator and its absence blocks the backend from importing or running at all.

**Approach:** Rebuild `scoring.py` as a faithful Python port of the already-validated JS reference engine (`docs/analyse_hippique_ia.jsx`, `docs/analyse_hippique_v2.html`), governed formula-by-formula by `docs/cahier_des_charges_backend_hippique.md` section 7, driven test-first by the existing `backend/tests/test_scoring.py`. Rebuild `main.py` as a minimal FastAPI entrypoint wiring the three existing routers.

## Boundaries & Constraints

**Always:**
- Import constants from `backend/app/engine/constants.py` (`RECENCE_STD/FORME/FLAT`, `INCIDENTS`, `DEFAULT_PARAMETERS`) — never redefine them in `scoring.py`.
- Match every formula in cahier des charges section 7 exactly (note calculation, distance/terrain/niveau coefficients, incident malus, bayesian shrinkage §7.7, virtual outsiders §7.8, Plackett-Luce probabilities §7.9, Harville top1-4 §7.10, value/Kelly §7.11), cross-checked against `computeNote`/`runModel` (jsx) and `computeNote`/`analyseHorse`/`calculate` (html).
- `backend/tests/test_scoring.py` passes unmodified — it is the executable contract (dataclasses `CourseTarget`, `HorseAnalysis`, `Performance`; functions `compute_forme(performances, mode)`, `analyse_course(horses, target, params=None, mode_recence="std")`).
- NR-incident performances are filtered out before `forme`/`nb_perfs` aggregation (mirrors the JS `.filter` step in `runModel`) — never counted, never influence the average.
- `analyse_course` accepts the exact call shape used by `routes_analyse.py`: third positional `params: Optional[dict]` merged over `DEFAULT_PARAMETERS`, keyword `mode_recence` selecting the matching `RECENCE_*` list.
- Where either side of a ratio is `None` (`Performance.terrain` or `Performance.niveau`/`CourseTarget.niveau` — both occur via `repository.py`'s course_id path, which sets `niveau=None`), treat the coefficient as neutral (`1.0`), exactly like the documented `terrain=None` rule — never raise or silently default to a guessed number.
- `main.py` exposes a module-level `app` (uvicorn target `app.main:app` per `Dockerfile`), including `routes_courses.router`, `routes_chevaux.router`, `routes_analyse.router` with **no path prefix** (`postman_collection.json` pins bare paths `/courses`, `/analyse`, `/extraction/*`).

**Never:**
- Do not modify `constants.py`, `combinatoire.py`, any schema, or any route file's call signature.
- Do not implement the bodies of `/extraction/fiche` / `/extraction/programme` (intact 501 stubs, out of scope).
- Do not touch the mobile Dart port (deferred — see `deferred-work.md`).
- Do not wire `app/api/__init__.py`'s `router` — it is unused elsewhere and unrelated to the three real routers.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Terrain unknown | `Performance.terrain=None` | `c_terr == 1.0`, no exception | N/A |
| Niveau unknown | `CourseTarget.niveau=None` (course_id path) | `c_niv == 1.0`, no exception | N/A |
| NR performance | Horse has 1 NR-incident perf + 1 normal perf | `nb_perfs == 1`, NR excluded from `forme` | N/A |
| No params override | `analyse_course(horses, target)` (2-arg call, as in tests) | Uses `DEFAULT_PARAMETERS` and `mode_recence="std"` | N/A |
| Partial params override | `params={"shrink": 4}` | Only `shrink` changes; other defaults untouched | N/A |

</frozen-after-approval>

## Code Map

- `backend/app/engine/scoring.py` -- TO CREATE (corrupted, no recoverable content) -- dataclasses + `compute_note`/`compute_forme`/`analyse_course`
- `backend/app/main.py` -- TO CREATE (corrupted) -- FastAPI `app`, includes the 3 routers below
- `backend/tests/test_scoring.py` -- READ-ONLY, intact -- executable contract, run to verify
- `backend/app/engine/constants.py` -- READ-ONLY, intact -- source of all coefficient tables and `DEFAULT_PARAMETERS`
- `backend/app/engine/combinatoire.py` -- READ-ONLY consumer -- imports `HorseAnalysis`, reads `.probabilite/.num_pmu/.nom` post-analyse
- `backend/app/api/routes_analyse.py` -- READ-ONLY consumer -- pins `analyse_course`'s exact call shape and the `niveau=None` course_id path
- `backend/app/data/repository.py` -- READ-ONLY consumer -- `get_horses_for_course` builds `HorseAnalysis`/`Performance` from DB rows
- `backend/app/schemas/analyse.py` -- READ-ONLY -- `HorseOut` names expected result fields (score, probabilite, top1-4, value, kelly, mise)
- `backend/app/api/routes_courses.py`, `routes_chevaux.py` -- READ-ONLY -- routers to wire into `main.py`
- `backend/Dockerfile`, `docker-compose.yml`, `backend/postman_collection.json` -- READ-ONLY -- confirm `app.main:app` entrypoint and unprefixed route paths
- `docs/cahier_des_charges_backend_hippique.md` §7, §9 -- reference spec (formulas, test cases)
- `docs/analyse_hippique_ia.jsx`, `docs/analyse_hippique_v2.html` -- reference JS implementation to port

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/engine/scoring.py` -- implement dataclasses + `compute_note`/`compute_forme`/`analyse_course` per cahier des charges §7 and the JS reference -- restores the core engine
- [x] `backend/app/main.py` -- create FastAPI app wiring `routes_courses`, `routes_chevaux`, `routes_analyse` with no prefix -- restores backend bootability
- [x] Run `backend/tests/test_scoring.py` -- fix forward until all 9 tests pass -- proves faithful port
- [x] `backend/tests/test_scoring.py` -- add 4 tests covering the I/O matrix rows not exercised by the original 9 (terrain=None, niveau=None, no-params-override equivalence, partial-params-override isolation) -- durable regression coverage for the matrix, not just ad-hoc verification

**Acceptance Criteria:**
- Given the 9 tests in `backend/tests/test_scoring.py`, when run via pytest, then all pass.
- Given `python -c "import app.main"` from `backend/`, when executed, then it succeeds with no ImportError.
- Given a `Performance(terrain=None)`, when `compute_note` runs, then it returns a value without raising, using `c_terr=1.0`.
- Given a horse with one NR-incident performance and one normal one, when `analyse_course` runs, then `nb_perfs == 1`.

## Spec Change Log

## Design Notes

NR filtering happens once, before `compute_forme` is ever called for that horse (mirrors `runModel`'s `.filter` pass in the JS reference) — `compute_forme` itself assumes an already-clean list and only truncates to the 6 most recent. `params` merging is a shallow dict merge: `{**DEFAULT_PARAMETERS, **(params or {})}` — never a partial per-key fallback inside the formulas themselves.

## Verification

**Commands:**
- `cd backend && pytest tests/test_scoring.py -v` -- expected: 9 passed
- `cd backend && python -c "import app.main"` -- expected: exits 0, no ImportError

## Suggested Review Order

**Core engine — per-performance formula (cahier des charges §7.5-7.6)**

- Entry point: the note formula for one past performance — distance/terrain/niveau coefficients, all three nullable-safe.
  [`scoring.py:117`](../../backend/app/engine/scoring.py#L117)

- Recency-weighted average across a horse's last 6 performances; assumes NR already filtered by the caller.
  [`scoring.py:158`](../../backend/app/engine/scoring.py#L158)

**Core engine — course-level orchestration (cahier des charges §7.7-7.11)**

- Full pipeline: NR filtering, Bayesian shrinkage, virtual outsiders, Plackett-Luce probabilities, Harville top1-4, value/Kelly.
  [`scoring.py:204`](../../backend/app/engine/scoring.py#L204)

- Virtual-outsider construction — real horses vs. placeholder field-fillers, the split `combinatoire.py` depends on.
  [`scoring.py:273`](../../backend/app/engine/scoring.py#L273)

- Extended Harville recursion to Top4 (exact, not Monte Carlo) — needed for the `sum(Top4) ≈ 4` test precision.
  [`scoring.py:299`](../../backend/app/engine/scoring.py#L299)

**API wiring**

- Three intact routers assembled with no path prefix, matching `postman_collection.json`'s bare paths.
  [`main.py:15`](../../backend/app/main.py#L15)

**Tests — peripherals**

- New coefficient-bucket tests proving `compute_note` behaves differently on real distance/terrain/niveau gaps, not just on `None`.
  [`test_scoring.py:213`](../../backend/tests/test_scoring.py#L213)

- Regression proof that `main.py`'s three routers actually resolve (the only test main.py has).
  [`test_main.py:41`](../../backend/tests/test_main.py#L41)
