---
title: 'Story 2.2: Test coverage for jobs/ingest_daily.py'
type: 'chore'
created: '2026-09-07'
status: 'done'
review_loop_iteration: 1
context: ['{project-root}/docs/cahier_des_charges_backend_hippique.md']
baseline_commit: '4889c5a1aa635d9dff53b6e2a7710ce6e8a7bca4'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `backend/app/jobs/ingest_daily.py` — the daily job that populates the database without manual entry (Epic 2, FR-1/FR-16/FR-17) — is intact and already used in production, but has zero test coverage. Its two try/except resilience guards (one bad course must never abort a whole day's ingestion) and its programme-caching logic are exactly the kind of behavior that regresses silently.

**Approach:** Add `backend/tests/test_ingest_daily.py`. Use a real `Repository` against a temp-file SQLite (same convention as `test_repository.py`) so persistence side effects are verified for real; mock only the four `pmu_client` functions the job calls, since that module is the network-calling boundary (AD-1).

## Boundaries & Constraints

**Always:**
- Use the temp-file-SQLite `repo` fixture convention from `backend/tests/test_repository.py` (`tempfile.mkstemp` + `atexit` cleanup, never `:memory:`).
- Mock `app.jobs.ingest_daily.pmu_client.get_programme` / `get_participants` / `get_historique` (e.g. `unittest.mock.patch`) — never make real HTTP calls.
- Cover exactly these 7 behaviors (each verified by reading `ingest_daily.py`, not guessed):
  1. `ingest_programme_du_jour`: for each `CourseInfo` from `get_programme`, upserts the course, then persists its participants and historique.
  2. `ingest_programme_du_jour`: if fetching/saving one course's participants or historique raises, that exception is swallowed (logged) and the loop continues to the next course — verify via a second course still getting persisted.
  3. `ingest_resultats_veille`: calls `repository.get_unfinalized_courses_before(veille + 1 day)`; a course with `numero_reunion` or `numero_course` as `None` is skipped with zero PMU calls for it.
  4. `ingest_resultats_veille`: `get_programme` is called at most once per distinct course date, even when multiple unfinalized courses share that date (assert call count on the mock).
  5. `ingest_resultats_veille`: `arrivee_definitive` passed to `update_resultats` is read from the matching cached-programme entry's own field (`True` when matched entry says so, `False` when no matching entry is found).
  6. `ingest_resultats_veille`: if `get_participants` raises for one course, that course is skipped (logged, `update_resultats` never called for it) and the loop continues to the next course.
  7. `run(repository, today, days_ahead)`: calls `ingest_programme_du_jour` for `today` and for each of `today+1..today+days_ahead`, then `ingest_resultats_veille` for `today - 1 day` — verify the exact date sequence via the mocked `get_programme`'s call args, not just call count.

**Never:**
- Do not modify `ingest_daily.py`, `pmu_client.py`, or `repository.py` — read-only this story.
- Do not test `pmu_client.py`'s own HTTP/parsing logic — out of scope, it's the mocked boundary here.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| One course fails mid-ingestion | `get_participants` raises for course 2 of 2 | Course 1 fully persisted; course 2's failure logged, loop completes | Exception swallowed, not propagated |
| Shared date across unfinalized courses | 2 unfinalized courses, same `date` | `get_programme` called once for that date | N/A |
| No matching programme entry for a course | Cached programme has no entry for the course's reunion/course numbers | `update_resultats` called with `arrivee_definitive=False` | N/A |
| `run` with `days_ahead=2` | `today = 2026-03-10` | `ingest_programme_du_jour` called for 03-10, 03-11, 03-12; `ingest_resultats_veille` called for 03-09 | N/A |

</frozen-after-approval>

## Code Map

- `backend/tests/test_ingest_daily.py` -- TO CREATE
- `backend/app/jobs/ingest_daily.py` -- READ-ONLY -- `ingest_programme_du_jour` (L11-27), `ingest_resultats_veille` (L30-52), `run` (L55-59) — all under test
- `backend/app/data/repository.py` -- READ-ONLY -- real `Repository` used by tests; `get_unfinalized_courses_before`/`upsert_course`/`save_partants`/`save_historique`/`update_resultats` already covered by Story 2.1 (`test_repository.py`), reused here as the persistence side of these job tests
- `backend/app/data/pmu_client.py` -- READ-ONLY -- `CourseInfo`/`PartantInfo`/`PerformancePassee` dataclasses (L54-101) mocked functions must return; note `CourseInfo.arrivee_definitive: bool` (L68) is the field `ingest_resultats_veille` reads for finalization
- `backend/tests/test_repository.py` -- precedent -- `repo` fixture (L37-59) and `make_course_info`/`make_partant_info`/`make_performance_passee` helpers (L62-118) to reuse/adapt rather than reinvent

## Tasks & Acceptance

**Execution:**
- [x] `backend/tests/test_ingest_daily.py` -- 7 tests (one per Boundaries behavior, at minimum), reusing the `repo` fixture pattern and mocking `pmu_client`
- [x] Run `pytest backend/tests/ -v` -- all pass, no regressions

**Acceptance Criteria:**
- Given the 7 behaviors listed in Boundaries, when their respective tests run, then each passes and would fail if the corresponding real behavior were broken (not a vacuous assertion).
- Given the full backend test suite, when run after this story, then it passes with the new tests included and zero regressions in existing tests.

## Verification

**Commands:**
- `cd backend && pytest tests/ -v` -- expected: 92 + (≥7 new) passed, 0 regressions -- actual (implementation, pre-review): 99 passed (92 + 7 new in `test_ingest_daily.py`), 0 regressions. Run via a disposable `python:3.12-slim` Docker container (no local Python interpreter available; only the Microsoft Store stub was present) with the full repo mounted, `requirements.txt` + `requirements-dev.txt` + `httpx` installed.
- Post-review (3-lens review: blind-hunter, edge-case-hunter, verification-gap), re-verified independently in a fresh throwaway `uv venv .verify-venv4` (Python 3.12) + `uv pip install -r requirements-dev.txt httpx2` + `python -m pytest tests/ -v`, run from `backend/` -- **actual: 104 passed** (99 + 5 new tests added during review triage), 0 regressions. Throwaway venv removed after the run.

## Review Findings & Resolution

Three parallel review lenses ran against the implementation (blind-hunter, edge-case-hunter, verification-gap). Triage:

**Fixed directly (5 new tests + docstring correction):**
- `test_ingest_programme_du_jour_echec_historique_persiste_quand_meme_les_partants` — `get_participants` and `get_historique` share one try/except (ingest_daily.py:18-27); the implementation's only failure test made `get_participants` raise. This one makes `get_historique` raise instead, proving partants persist regardless and the loop still continues (blind-hunter + edge-case-hunter, independently convergent).
- `test_ingest_resultats_veille_course_avec_un_seul_numero_manquant_est_ignoree` — the `numero_reunion is None or numero_course is None` skip (ingest_daily.py:37) was only tested with BOTH fields None; a regression to `and` would have passed unnoticed. New test sets only one field to `None`.
- `test_ingest_resultats_veille_get_programme_une_fois_par_date_partagee` -- (existing) kept; new `test_ingest_resultats_veille_get_programme_une_fois_par_date_distincte` added alongside it — the existing test used a single shared date, unable to distinguish correct per-date caching from a bug that fetches only once globally. New test uses 2 distinct dates and asserts each is fetched exactly once.
- `test_ingest_resultats_veille_arrivee_definitive_ne_matche_pas_sur_numero_course_seul` — **verification-gap confirmed this exact mutation would slip through**: the existing match test used the same `numero_reunion` for both its matched/unmatched courses, so dropping the `numero_reunion` half of the `any(...)` conjunction (ingest_daily.py:48-51) changed nothing observable. New test uses courses with the same `numero_course` but different `numero_reunion`.
- `test_run_avec_days_ahead_par_defaut_ingere_today_et_today_plus_1` — `run()`'s default `days_ahead=1` (used by `main()` when `--days-ahead` is omitted) was never exercised; the only `run()` test passed `days_ahead=2` explicitly.
- Module docstring corrected: said "quatre fonctions" mockées, lists three (there is no fourth).

**Logged to `deferred-work.md`:**
- **PRODUCT-RELEVANT, not test-only:** `pmu_client.get_programme` has NO try/except guard in either `ingest_programme_du_jour` (L13) or `ingest_resultats_veille` (L40), unlike every other PMU call in the same functions. A single flaky fetch for one date aborts `run()` entirely — including skipping `ingest_resultats_veille` for yesterday. Flagged by blind-hunter and edge-case-hunter independently. Not fixed here (`ingest_daily.py` is read-only this story) — worth a dedicated follow-up story.
- Lower-priority: no `caplog` assertion on the two `logger.exception` calls; Test 2's failure scenario is the mirror image of the frozen I/O matrix's literal wording (functionally equivalent); no job-level test for the exact `veille+1` cutoff boundary (covered at the repository level by Story 2.1); temp-SQLite fixture cleanup/engine disposal (same class of finding as Story 2.1, not new).

## Suggested Review Order

1. [backend/app/jobs/ingest_daily.py:30-52](backend/app/jobs/ingest_daily.py#L30-L52) — `ingest_resultats_veille`, against the two new gap-closing tests below.
2. [backend/tests/test_ingest_daily.py](backend/tests/test_ingest_daily.py) — new `test_ingest_resultats_veille_arrivee_definitive_ne_matche_pas_sur_numero_course_seul` (verification-gap-confirmed fix) and `test_ingest_resultats_veille_get_programme_une_fois_par_date_distincte`.
3. [backend/tests/test_ingest_daily.py](backend/tests/test_ingest_daily.py) — new `test_ingest_programme_du_jour_echec_historique_persiste_quand_meme_les_partants`, against [backend/app/jobs/ingest_daily.py:11-27](backend/app/jobs/ingest_daily.py#L11-L27).
4. [_bmad-output/implementation-artifacts/deferred-work.md](_bmad-output/implementation-artifacts/deferred-work.md) — new entries, especially the unguarded `get_programme` product-relevant finding.
