---
title: 'Rebuild French race history from PMU turfinfo (5 years)'
type: 'feature'
created: '2026-10-20'
status: 'done'
baseline_commit: 'eeacfc5e3081e3d3f00ecda5121cac345c70232d'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/research/api-field-inventory-2026-10-20/inventory.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The database holds only the races ingested since the daily job started, and horse histories hold at most the last 10 past races per runner. There is no complete, unbiased history: every runner of every French race, with its result and odds. The engine needs it for history depth, and a future model needs it for training. The user chose 5 years.

**Approach:** Add a throttled, resumable CLI job. For each past day it walks turfinfo `programme` → French races → `participants` and stores courses, participations (with odds timestamps) and one past-performance row per runner. The other endpoint (`performances-detaillees`) names racecourses differently, and the job must never create duplicate history rows because of that.

## Boundaries & Constraints

**Always:**
- Requests go through `pmu_client` only, sequentially. Its 1-second delay per request is the throttle.
- **Re-running is safe and resumes.** A course already stored, `finalisee`, with participations is skipped without a `participants` call. The programme is still fetched once per day.
- **One failure never stops the run.** A failed day or course is logged with `logger.exception` and the job continues.
- Progress is logged per day (courses fetched, skipped, failed, cumulative) and as a final summary.
- Only dates strictly before yesterday are accepted. `--date-fin` ≥ yesterday is a CLI error. Every processed course is marked `finalisee` so the daily results job never revisits it.
- **Past-performance rows** are derived only from courses whose programme says `arrivee_definitive`, and only for runners with `statut == "PARTANT"`.
  - Fields: course date, hippodrome, discipline, allocation, distance and terrain.
  - `nb_participants` is the count of PARTANT runners.
  - `rang` comes from `ordreArrivee`, with `rang_impute=False`.
  - The incident is mapped with `pmu_client.STATUS_TO_INCIDENT`. An unmapped value is logged and stored as `None`, never guessed.
  - `source="pmu"` and `participation_id` set.
- **At most one history row per horse and day:**
  - a derived row is not written if any row already exists for that `(cheval_id, date_course)`;
  - `save_historique` replaces a same-day row with a different hippodrome name instead of adding a second one.
- Odds timestamps (`dateRapport`) are stored as naive UTC datetimes (`cote_reference_le`, `cote_direct_le`), from the daily ingestion and from the rebuild alike.

**Ask First:**
- Changing the `(cheval_id, date_course, hippodrome)` unique constraint.
- Deleting history rows beyond the same-day rule above.
- Any change to scoring or to `get_horses_for_course`.

**Never:**
- Parallel or unthrottled requests, or new dependencies.
- open-pmu-api.
- Computing features or using post-race fields as inputs (this job stores labels and benchmarks only).
- Running the 5-year import in tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| New day | 2 French races + 1 foreign; participants with ranks, an `ARRETE` and a `NON_PARTANT` | 2 courses `finalisee`; all participations stored with odds and timestamps; history rows for PARTANT runners only (`A` for ARRETE, `nb_participants` = PARTANT count) | N/A |
| Re-run | Same day already done | No `participants` call; no new rows | N/A |
| Interrupted day | 1 of 2 races stored | Only the missing race is fetched | N/A |
| Not definitive | `arrivee_definitive=False` | Course + participations stored and `finalisee`; no history rows | N/A |
| Existing same-day row | Horse already has a row that day (other hippodrome name) | Derived row skipped | N/A |
| Ingestion after rebuild | `save_historique` row same horse/day, other hippodrome name | One row remains, the `save_historique` one | N/A |
| Course API error | `get_participants` raises | Other races continue; failed course not `finalisee` | logged |
| Day API error | `get_programme` raises | Next day continues | logged |
| Bad dates | `--date-fin` ≥ yesterday, or fin < debut | CLI error, no request | argparse error |

</frozen-after-approval>

## Code Map

- `backend/app/jobs/ingest_daily.py:11-26` -- per-day programme → participants pattern to mirror; its CLI style.
- `backend/app/data/pmu_client.py:146-176` -- `get_programme(date)` (FRA filter, `CourseInfo.arrivee_definitive`, `terrain` from penetrometre).
- `backend/app/data/pmu_client.py:183-207` -- `get_participants`. `PartantInfo` (`:111-127`) carries `statut`, `ordre_arrivee`, raw `incident` and `raw`. Add `cote_reference_le` / `cote_direct_le` from `dernierRapport*.dateRapport` (epoch ms, convert as UTC).
- `backend/app/data/pmu_client.py:31-41` -- `STATUS_TO_INCIDENT` (raw status → engine code).
- `backend/app/data/repository.py:179-206` -- `upsert_course` (key: date + R + C).
- `backend/app/data/repository.py:236-260` -- `save_partants`: stores odds; set the two timestamp columns.
- `backend/app/data/repository.py:262-294` -- `save_historique` (upsert on the 3-column key): add the same-day replacement.
- `backend/app/data/repository.py:300-311` -- `update_resultats` sets `finalisee`.
- `backend/app/data/repository.py:29-75` -- `_migrate`: defensive `ALTER TABLE` pattern for the new `participations` columns.
- `backend/app/data/models.py:49-68` -- `Participation`. Add `cote_reference_le` and `cote_direct_le` (DateTime, nullable).
- `backend/tests/test_ingest_daily.py`, `backend/tests/test_repository.py` -- style: temporary SQLite file `Repository`, `pmu_client` mocked at the module boundary.
- Evidence: the programme and `performances-detaillees` name racecourses differently (`CAGNES/MER` vs `CAGNES-SUR-MER`, `BORELY` vs `MARSEILLE BORELY`, inventory sample). That is why identity is per horse and day.

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/data/models.py`, `backend/app/data/repository.py` (`_migrate`) -- Add the two timestamp columns with a migration. -- Odds snapshots need their time.
- [x] `backend/app/data/pmu_client.py` -- Parse the timestamps into `PartantInfo`. -- Same source for daily ingestion and rebuild.
- [x] `backend/app/data/repository.py` -- `save_partants` stores the timestamps. Add `course_complete(date, R, C) -> bool` (stored, `finalisee`, has participations) and `deriver_historique_course(course_id, partants)`. Make `save_historique` same-day aware. -- Persistence rules in one place.
- [x] `backend/app/jobs/rebuild_historique.py` -- New job: `rebuild_plage(repository, date_debut, date_fin)` and `main()` with `--date-debut` / `--date-fin` and the date guard. -- The rebuild.
- [x] `backend/tests/test_rebuild_historique.py` -- One test per I/O matrix row, `pmu_client` mocked. -- Edge cases.
- [x] `backend/tests/test_repository.py`, `backend/tests/test_pmu_client.py` -- Tests for the timestamps, the same-day `save_historique` rule and `deriver_historique_course`. -- Shared code paths.

**Acceptance Criteria:**
- Given an existing database created before this change, when `Repository()` starts, then the two columns exist and existing data is intact.
- Given the backend suite, when it runs, then everything passes.

## Design Notes

Usage on the server (runs about a day and a half for 5 years; run it in chunks):
`docker compose exec ingestion python -m app.jobs.rebuild_historique --date-debut 2021-10-20 --date-fin 2022-10-19`

## Verification

**Commands:**
- `cd backend && .venv/Scripts/python.exe -m pytest -q` -- expected: all pass.
- `cd backend && .venv/Scripts/python.exe -m app.jobs.rebuild_historique --date-debut 2026-10-01 --date-fin 2026-10-01` against a throwaway `DATABASE_URL` -- expected: about 40–50 French courses stored, log summary, second run skips all.

## Suggested Review Order

**The rebuild loop**

- Entry point: one day = programme, then each French race, skip-if-complete, store, finalise last.
  [`rebuild_historique.py:41`](../../backend/app/jobs/rebuild_historique.py#L41)

- Date guard: only before yesterday, so the daily results job never competes.
  [`rebuild_historique.py:98`](../../backend/app/jobs/rebuild_historique.py#L98)

- Exit code 1 when anything failed, so each yearly chunk can be re-run.
  [`rebuild_historique.py:114`](../../backend/app/jobs/rebuild_historique.py#L114)

**One history row per horse and day**

- Derived rows: PARTANT runners only, exact rank, mapped incident, skip if the day exists.
  [`repository.py:349`](../../backend/app/data/repository.py#L349)

- `save_historique` replaces a same-day row under another racecourse name, never its own writes.
  [`repository.py:317`](../../backend/app/data/repository.py#L317)

- Resume rule: stored, finalised and with participations.
  [`repository.py:332`](../../backend/app/data/repository.py#L332)

**Odds timestamps**

- `dateRapport` converted as UTC, independent of the host timezone; non-numeric ignored.
  [`pmu_client.py:96`](../../backend/app/data/pmu_client.py#L96)

- New nullable columns, added to older databases by `_migrate`.
  [`models.py:62`](../../backend/app/data/models.py#L62)
  [`repository.py:133`](../../backend/app/data/repository.py#L133)

**Tests**

- One test per I/O matrix row, `pmu_client` mocked.
  [`test_rebuild_historique.py:126`](../../backend/tests/test_rebuild_historique.py#L126)

- Ingestion after rebuild leaves a single row for the day.
  [`test_rebuild_historique.py:221`](../../backend/tests/test_rebuild_historique.py#L221)

- Same-day rule edge cases (no hippodrome, two rows in one call).
  [`test_repository.py:625`](../../backend/tests/test_repository.py#L625)
