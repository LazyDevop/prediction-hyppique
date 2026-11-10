---
title: 'Live odds snapshots at H-60, H-30, H-10 and H-2 (roadmap stage 0)'
type: 'feature'
created: '2026-11-10'
status: 'done'
baseline_commit: '9b017bbc718bdbf449a2acaf29c643298f3d6da0'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/predictive-model-roadmap-2026-10-22.md'
  - '{project-root}/_bmad-output/planning-artifacts/research/api-field-inventory-2026-10-20/inventory.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The combined model (stage 3) beats the H-30 reference odds, but the closing odds still beat it. We record no odds between H-30 and the start, so we cannot measure how the odds move. We also cannot refit the combination at the moment a bet is actually decided.

**Approach:** A small backend job records each runner's live PMU odds for every French race of the day at four targets before the scheduled start: 60, 30, 10 and 2 minutes. It writes one row per runner and target into a new table. It runs as its own lightweight Docker service. SQLite switches to WAL so that dashboard reads can no longer block these writes.

## Boundaries & Constraints

**Always:**
- **Source.**
  - Reuse `pmu_client.get_participants(date, R, C)`, the same turfinfo endpoint and pacing env vars as ingestion.
  - Make one request per race and target, never per runner.
  - Only races of the day stored with `source == "pmu"` (ingestion already keeps French races only, via `get_programme(pays_filter="FRA")`), with `heure_depart` and R/C numbers set.
- **Timing.**
  - Each target T opens at `heure_depart − T` and closes after a tolerance of 5 min for T ≥ 30 and 2 min for T ≤ 10.
  - A target missed past its window is never taken late. It is logged and counted as missed.
  - A target already stored is never re-taken.
  - Each race–target pair is attempted again on later polls while its window is open, for example after a network error.
  - Every time comparison uses the same clock as `heure_depart`, the container-local naive time used by `predict.predire_courses_a_venir`.
- **Storage.** New table `cotes_instantanees`, with one row per (`participation_id`, `cible_minutes`), unique. Columns:
  - `course_id`, `participation_id`, `num_pmu`, `cible_minutes`;
  - `pris_le` (UTC naive);
  - `cote_direct`, `cote_direct_le`, `cote_reference`, `cote_reference_le` (`dateRapport`, UTC naive, as in `Participation`);
  - `statut` (raw);
  - `brut` (JSON of the runner's raw `dernierRapportDirect` and `dernierRapportReference` objects, including `favoris`, `grossePrise` and `nombreIndicateurTendance` when present).

  A runner whose `num_pmu` has no participation in the database is skipped and counted, never created.
- **Schema.** Create the table and its unique index through `Repository._migrate`, the existing pattern, on top of `Base.metadata.create_all`.
- **WAL.** On every SQLite connection: `PRAGMA journal_mode=WAL` and `PRAGMA busy_timeout=30000`. Applied through a SQLAlchemy `connect` event in `Repository`.
- **Service.** `python -m app.jobs.cotes_instantanees` polls every 30 s (`COTES_POLL_SECONDS`) and survives any per-race error. A new `cotes` service in `docker-compose.yml` uses the same image and volume as `ingestion`.
- **Logs.** Each pass logs the counts of taken, missed and skipped runners.

**Ask First:**
- Using the snapshots in predictions, the dashboard, the app, the feature table or the stage-3 combination.
- Switching to the online endpoint `online.turfinfo.api.pmu.fr/rest/client/1` if the offline endpoint's live odds turn out frozen.
- Targets other than 60, 30, 10 and 2, or snapshots after the start.

**Never:**
- Updating `participations` odds columns from snapshots.
- Calling the API for races outside today's window or for past days.
- Adding a dependency.
- Alembic migrations (AD-13 is not implemented; follow `_migrate`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Due target | Now = start − 30 min + 1 min, H-30 not stored | One row per runner, `cible_minutes` = 30 | N/A |
| Already taken | Same poll again | No request, no new row | N/A |
| Missed | Now = start − 30 + 6 min, H-30 absent | No request; counted as missed | log |
| Several due | Machine wakes at start − 9 min | H-10 taken; H-60 and H-30 missed | log |
| API error | `get_participants` raises inside the window | No row; retried next poll | log, continue |
| Unknown runner | `num_pmu` not in DB | Skipped and counted | log |
| Non-runner | `statut` NON_PARTANT, odds null | Row stored with null odds and the raw status | N/A |
| Unusable race | `source` ≠ pmu, `heure_depart` null, or no R/C number | Ignored | N/A |
| WAL | New `Repository` on a file DB | `PRAGMA journal_mode` returns `wal` | test |

</frozen-after-approval>

## Code Map

- `backend/app/data/pmu_client.py:203-237` -- `get_participants` returns `PartantInfo`. It carries `cote_reference`, `cote_direct`, `cote_reference_le` and `cote_direct_le` (UTC naive, via `_epoch_ms_to_utc_naive`) and `statut`, but not the raw rapport dicts. Add an optional raw field (for example `rapports_bruts`) without changing the existing fields. `_epoch_ms_to_datetime` (line 98) builds `heure_depart` in container-local time. Pacing comes from `PMU_REQUEST_DELAY`, `PMU_REQUEST_JITTER` and `PMU_REQUEST_TIMEOUT`.
- `backend/app/data/models.py` -- `Course` (date, numero_reunion, numero_course, heure_depart, source; no country column) and `Participation`. Add the `CoteInstantanee` model here.
- `backend/app/data/repository.py:30` -- `create_engine(..., check_same_thread=False)`; add the `connect` event here. `_migrate` (around line 41) is where columns and tables are added idempotently. `list_courses_for_date` is reused by `predict.py:51-61`.
- `backend/app/jobs/predict.py:51-61` -- the pattern for upcoming races (`heure_depart > maintenant`, same clock).
- `backend/app/jobs/scheduler.py` -- the existing loop; leave it unchanged. The new service is separate so the hourly prediction pass cannot delay H-2.
- `docker-compose.yml` -- services `api` and `ingestion` (volume `hippique_data`, `DATABASE_URL`, `.env`). Add `cotes` the same way.
- Tests: style of `backend/tests/test_rebuild_historique.py` (temporary SQLite `Repository`, monkeypatched `pmu_client`, `time.sleep` neutralised by an autouse fixture).

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/data/models.py`, `backend/app/data/repository.py` -- `CoteInstantanee` model, unique index, `_migrate` step, WAL and busy_timeout connect event, plus repository helpers: list the stored (participation, target) pairs for a course, and insert one snapshot. -- Storage.
- [x] `backend/app/data/pmu_client.py` -- Expose the raw `dernierRapportDirect` and `dernierRapportReference` dicts on `PartantInfo`, as an optional field. -- Keep `favoris`, `grossePrise` and trend fields.
- [x] `backend/app/jobs/cotes_instantanees.py` -- `prendre_instantanes(repository, maintenant) -> Bilan` (taken, missed, skipped, errors) plus a polling `main`. -- The job.
- [x] `docker-compose.yml` -- `cotes` service. -- Deployment.
- [x] `backend/tests/test_cotes_instantanees.py` -- One test per I/O matrix row, with a fake clock and a fake `get_participants`. -- Correctness.

**Acceptance Criteria:**
- Given the backend suite, when it runs, then every test passes, including the existing 334.
- Given `docker compose up -d cotes`, when a French race of the day reaches start − 30 min, then within one poll its runners have an H-30 row, and the log shows the counts.

## Verification

**Commands:**
- `cd backend && .venv/Scripts/python.exe -m pytest -q` -- expected: all pass.
- `docker compose up -d --build cotes && docker compose logs -f cotes` -- expected: passes logged every 30 s, and snapshots taken as races approach.

**Manual checks:**
- On a live race day, compare `cote_direct_le` between the H-60 and H-2 rows of one race. If it never changes, the offline endpoint is frozen, so raise the Ask First item about the online endpoint.

## Spec Change Log

- 2026-11-10, review loop 1 (patches only, no intent change):
  - Due targets are handled most urgent first.
  - The window is re-checked with the live clock before each request and when it returns, so a slow pass can never store a late snapshot. `pris_le` is taken just before the request.
  - An empty response counts as an error and is retried.
  - A database read error is isolated per race.
  - A race just after midnight is still covered; it belongs to the previous day's programme.
  - Missed targets are forgotten when the day changes.
  - `COTES_POLL_SECONDS` is validated (1–60 s).
  - `busy_timeout` is set before WAL, and a failed switch to WAL is logged.
  - `brut` is NULL when no raw data exists.
  - New tests: the 5-min tolerance for H-60 and H-30, the H-2 bound at the start, the clock re-check, urgency order, empty response, midnight, per-race isolation, and the `boucle` loop.
  - Deferred: healthcheck and runbook, FK delete rules.

## Suggested Review Order

**Timing (the reason this job exists)**

- Entry point: one pass collects due targets, most urgent first, never late.
  [`cotes_instantanees.py:73`](../../backend/app/jobs/cotes_instantanees.py#L73)

- Window re-checked with the live clock before the request and when it returns.
  [`cotes_instantanees.py:121`](../../backend/app/jobs/cotes_instantanees.py#L121)

- Polling loop: one missed-target set per day; a failed pass never stops it.
  [`cotes_instantanees.py:159`](../../backend/app/jobs/cotes_instantanees.py#L159)

**Storage**

- One snapshot per race and target in one transaction; unknown runners skipped; no rewrite.
  [`repository.py:175`](../../backend/app/data/repository.py#L175)

- WAL with a 30 s busy timeout on every SQLite connection.
  [`repository.py:26`](../../backend/app/data/repository.py#L26)

- New table, unique on (participation, target), created through `_migrate`.
  [`models.py:155`](../../backend/app/data/models.py#L155)

**Peripherals**

- Raw `dernierRapport*` objects kept (favoris, grossePrise, trend).
  [`pmu_client.py:239`](../../backend/app/data/pmu_client.py#L239)

- Separate `cotes` service, so the hourly prediction pass cannot delay H-2.
  [`docker-compose.yml:30`](../../docker-compose.yml#L30)

