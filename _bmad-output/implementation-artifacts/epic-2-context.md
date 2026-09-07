# Epic 2 Context: Alimenter la base sans saisie manuelle — ingestion PMU

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the daily race programme, its partants, and their performance history available in the database without any manual entry by the user, with delayed finalization of results so a late disqualification or stewards' inquiry doesn't corrupt an already-recorded outcome. This is the data foundation the scoring engine (Epic 1) and the mobile app (Epic 3) both depend on — without it, every course would require full manual entry.

## Stories

- Story 2.1: Tests for the persistence layer (`repository.py`) — done
- Story 2.2: Tests for the daily ingestion job (`jobs/ingest_daily.py`)
- Story 2.3: Tests for the historique backfill job (`jobs/backfill_historique.py`)

## Requirements & Constraints

- The day's programme, partants, and performance history must be persisted without manual entry (covers half of FR-1, backend side).
- A course not yet in the database can be imported on demand (FR-3) — served by `repository.upsert_course`/`save_partants`, already covered by Story 2.1.
- Results are finalized only once truly definitive (FR-16), and a late disqualification/incident correction must still be absorbed after initial finalization (FR-17) — this is exactly what `ingest_resultats_veille`'s re-check-before-finalizing loop exists for.
- `pmu_client.py`, `open_pmu_client.py`, and `repository.py` are already built, intact, and (per Story 2.1) tested. `jobs/ingest_daily.py` and `jobs/backfill_historique.py` are also already built and intact — the epic's remaining work is test coverage only, not new functionality, for both.

## Technical Decisions

- Hexagonal/ports-and-adapters (AD-1): `pmu_client.py`/`open_pmu_client.py` are driven ports (the network-calling boundary) — tests for anything in `jobs/` should mock these, never make real HTTP calls, and should exercise the real `Repository` against a temp-file SQLite (never `:memory:`) rather than mocking persistence.
- `num_pmu` is not a stable cross-course horse identifier (cahier backend §6.2) — `repository.upsert_cheval` matches by normalized name instead. Relevant if a job test constructs multi-course scenarios.
- `save_historique` (source="pmu") always overwrites a conflicting row; `ajouter_performance_historique_backfill` (source="open_pmu_api") never does — already pinned down in Story 2.1's tests, and `ingest_daily.py` is the real caller of `save_historique` in production.
- `terrain`/`niveau` are currently never populated by any real ingestion path (flagged in `deferred-work.md` from Story 2.1) — not this epic's job to fix, but relevant background if a job test seems to expect a non-null terrain/niveau from ingestion.

## Cross-Story Dependencies

- Story 2.2 and 2.3 both depend on the `Repository` test-fixture convention established in Story 2.1's `test_repository.py` (temp-file SQLite, `atexit` cleanup) rather than inventing a new one.
- Story 2.2 (`ingest_daily.py`) and Story 2.3 (`backfill_historique.py`) are independent of each other — neither calls the other — and can be built in either order.
