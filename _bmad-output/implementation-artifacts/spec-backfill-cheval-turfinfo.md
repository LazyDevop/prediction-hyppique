---
title: 'Per-horse history refresh from PMU turfinfo instead of open-pmu-api'
type: 'bugfix'
created: '2026-10-20'
status: 'done'
baseline_commit: '6581649c77dcd2800f54fa2fe5778c9573cd8824'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/research/api-field-inventory-2026-10-20/inventory.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The mobile "Voir tout l'historique" button calls `POST /chevaux/{id}/backfill`, which pulls history from open-pmu-api. That source only covers the daily Quinté+ and its ~7 finishers, so it adds only a horse's good runs (`source="open_pmu_api"`) and biases its history. The pending server purge would be undone at every tap.

**Approach:** The endpoint refreshes the horse's history from PMU turfinfo `performances-detaillees` (up to 10 complete past races, `source="pmu"`, existing NON_PLACE imputation) through its most recent known participation. The whole open-pmu write path is removed, so no code can write `open_pmu_api` rows any more. The response contract stays the same.

## Boundaries & Constraints

**Always:**
- The response stays `List[PerformanceHistoriqueOut]`, newest first, and returns everything in the database for the horse.
- A network or API failure never fails the request: log it and return what is already stored.
- 404 "Cheval introuvable" is unchanged.
- Rows are written through the existing `Repository.save_historique`, which upserts on `(cheval_id, date_course, hippodrome)` with `source="pmu"`.

**Ask First:**
- Removing or changing `open_pmu_client.py` itself (the read-only adapter stays).
- Any change to the mobile API contract or to the mobile UI text.

**Never:**
- Write `source="open_pmu_api"` rows.
- Call open-pmu-api from the endpoint.
- Build the 5-year rebuild job (deferred, separate spec).
- Change scoring.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Horse with participation | Horse in a stored course (date, R, C) | `get_historique` is called for its latest participation (most recent course date). Rows are saved as `pmu`. Full DB history is returned, newest first, with `rang_impute`. | N/A |
| Several participations | Horse in courses of 2026-10-01 and 2026-10-18 | Only the 2026-10-18 course is queried. | N/A |
| No participation | Horse known only by history rows | No API call; DB history returned. | N/A |
| API failure | `get_historique` raises | 200 with DB history unchanged. | `logger.exception`, no rethrow |
| Unknown horse | id absent | 404 "Cheval introuvable" | — |

</frozen-after-approval>

## Code Map

- `backend/app/api/routes_chevaux.py` -- the endpoint. It currently uses `get_hippodromes_connus` and `backfill_cheval_par_hippodromes_connus` (open-pmu). The response omits `rang_impute`.
- `backend/app/data/pmu_client.py:233` -- `get_historique(date, reunion, course) -> Dict[num_pmu, List[PerformancePassee]]`. Returns every runner of that race. Reuse as is.
- `backend/app/data/repository.py:262` -- `save_historique(course_id, historique)`: maps num_pmu to a participation and upserts `pmu` rows. Reuse.
- `backend/app/data/repository.py:223` -- `get_hippodromes_connus`: open-pmu only. Remove.
- `backend/app/data/repository.py:299` -- `ajouter_performance_historique_backfill`: the only `open_pmu_api` writer. Remove.
- `backend/app/data/models.py:71-90` -- `PerformanceHistorique`; the comment describes the two-source rule. `Course` has `date`, `numero_reunion`, `numero_course`; `Participation` links `cheval_id` and `course_id`.
- `backend/app/jobs/backfill_historique.py` + `backend/tests/test_backfill_historique.py` -- open-pmu backfill CLI and its tests. Remove both.
- `backend/tests/test_repository.py:217-330,468-500` -- tests using the two removed repository methods (sections 4, 5, 9).
- `backend/tests/test_purge_open_pmu.py` -- builds `open_pmu_api` rows with the removed method.
- `backend/tests/test_main.py:58` -- route wiring test (404). Keep it green.
- `backend/tests/test_routes_dashboard.py:18-35` -- pattern: temporary SQLite `Repository` with `monkeypatch.setattr(module, "repository", repo)` and `TestClient(app)`.
- `mobile/lib/repository/course_repository.dart:73` -- doc comment says the backend uses open-pmu-api. Comment only.

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/data/repository.py` -- Add `derniere_participation(cheval_id) -> Optional[Course]`, returning the course with the most recent `date` among the horse's participations. Remove `get_hippodromes_connus` and `ajouter_performance_historique_backfill`. -- Single entry point for the refresh; no open-pmu writer left.
- [x] `backend/app/api/routes_chevaux.py` -- Refresh through `pmu_client.get_historique` on `derniere_participation`, saved with `save_historique`, inside try/except. Include `rang_impute` in the output. Update the docstring. -- The redirect.
- [x] `backend/app/jobs/backfill_historique.py`, `backend/tests/test_backfill_historique.py` -- Delete. -- open-pmu write path.
- [x] `backend/app/data/models.py` -- Update the `PerformanceHistorique` comment: only `pmu` rows are written now, and legacy `open_pmu_api` rows are removed by `purge_open_pmu`. -- Keep the docs truthful.
- [x] `backend/tests/test_repository.py` -- Drop sections 5 and 9. In section 4, insert the conflicting legacy row directly through a `Session` (`source="open_pmu_api"`). Add a test for `derniere_participation`. -- Coverage follows the code.
- [x] `backend/tests/test_purge_open_pmu.py` -- Build legacy rows directly through a `Session` instead of the removed method. -- The purge must still be testable.
- [x] `backend/tests/test_routes_chevaux.py` -- New. One test per I/O matrix row, with `pmu_client.get_historique` mocked and asserting the call arguments. -- Edge cases.
- [x] `mobile/lib/repository/course_repository.dart` -- Fix the doc comment (PMU history, up to 10 races). -- Docs.

**Acceptance Criteria:**
- Given the codebase after the change, when searching `backend/app` for `open_pmu_api` writes or for imports of `backfill_historique`, then none remain, apart from `purge_open_pmu.py`, which only deletes.
- Given the full backend suite, when it runs, then it passes.

## Verification

**Commands:**
- `cd backend && .venv/Scripts/python.exe -m pytest -q` -- expected: all tests pass.
- `grep -rn "ajouter_performance_historique_backfill\|backfill_historique\|get_hippodromes_connus" backend/app backend/tests` -- expected: no match.

## Suggested Review Order

**Refresh from turfinfo instead of open-pmu**

- Entry point: the endpoint now refreshes through the horse's latest participation.
  [`routes_chevaux.py:36`](../../backend/app/api/routes_chevaux.py#L36)

- Same race-level call as daily ingestion; failure keeps stored history.
  [`routes_chevaux.py:39`](../../backend/app/api/routes_chevaux.py#L39)

- Latest race chosen by date then start time; races without R/C excluded.
  [`repository.py:223`](../../backend/app/data/repository.py#L223)

- Response now carries the imputed-rank marker the schema already declared.
  [`routes_chevaux.py:59`](../../backend/app/api/routes_chevaux.py#L59)

**Removing the open-pmu write path**

- Model comment: only `pmu` rows are written; legacy rows go via the purge.
  [`models.py:77`](../../backend/app/data/models.py#L77)

- Purge deletes orphan horses first, via subquery, before their open-pmu rows.
  [`purge_open_pmu.py:63`](../../backend/app/jobs/purge_open_pmu.py#L63)

- Orphan rule: no participation, no other-source (or NULL-source) row, has open-pmu row.
  [`purge_open_pmu.py:37`](../../backend/app/jobs/purge_open_pmu.py#L37)

**Tests and peripherals**

- One test per I/O matrix row, `get_historique` mocked with call assertions.
  [`test_routes_chevaux.py:86`](../../backend/tests/test_routes_chevaux.py#L86)

- `derniere_participation` ignores other horses' later races.
  [`test_repository.py:434`](../../backend/tests/test_repository.py#L434)

- A horse with no data at all must survive the purge.
  [`test_purge_open_pmu.py:52`](../../backend/tests/test_purge_open_pmu.py#L52)

- Mobile doc comment only; no contract change.
  [`course_repository.dart:76`](../../mobile/lib/repository/course_repository.dart#L76)
