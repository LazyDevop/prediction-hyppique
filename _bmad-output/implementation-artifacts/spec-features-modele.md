---
title: 'Point-in-time feature table for the predictive model (roadmap stage 1)'
type: 'feature'
created: '2026-11-09'
status: 'done'
baseline_commit: '95ea6af90af138acb60b367e603861a551451ede'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/predictive-model-roadmap-2026-10-22.md'
  - '{project-root}/_bmad-output/planning-artifacts/research/api-field-inventory-2026-10-20/inventory.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Stage 2 of the roadmap trains a model on the rebuilt history. It needs one row per runner with features that use **only information known before that race**. A single post-race field, such as the arrival order, the race time or the closing odds, would make the backtest look excellent and fail live.

**Approach:**
- **Build.** A backend job builds a feature table from the database: one row per PARTANT runner of every finalised French race. Each row holds identifiers, label columns, market columns and features. Features come from two places only: the runner's pre-race turfinfo fields and earlier races (strictly earlier days).
- **Registry.** Every feature is declared in a registry with the source it is computed from.
- **Guard.** A test enforces the before-race rule.

## Boundaries & Constraints

**Always:**
- **Columns.** Each row has `course_id`, `date`, `discipline` and `num_pmu`, then three groups:
  - **Labels**: `rang`, `gagnant`, `place`;
  - **Market**: `cote_reference` (about H-30) and `cote_direct` (closing benchmark);
  - **Features**: the registered columns, prefixed `f_`.

  Labels and market columns are never features.
- **Pre-race fields only.** From the runner's own row, features read only the pre-race fields of `donnees_brutes`: `age`, `sexe`, `musique`, `nombreCourses`, `nombreVictoires`, `nombrePlaces`, `gainsParticipant`, `driverChange`, `deferre`, `oeilleres`, `handicapPoids`, `handicapValeur`, `handicapDistance`, `placeCorde`, `avisEntraineur`, `indicateurInedit`, `nomPere`, `nomPereMere`, `driver`, `entraineur`, plus the course's own pre-race fields.
  - The rebuild stores turfinfo's pre-race snapshot. Measured on Q1 2025: the first character of `musique` equals the previous race's rank in 97% of cases, and `nombreCourses` equals the previous value + 1 in 95% of cases.
- **Forbidden as features:** `ordreArrivee`, `incident`, `tempsObtenu`, `reductionKilometrique`, `distanceChevalPrecedent`, `commentaireApresCourse`, `dernierRapportDirect`, `dernierRapportReference`, `rang_arrivee` and `cote_direct`.
  - The same fields from **earlier** races are allowed, for example the past reduction kilométrique.
  - The H-30 odds are market data, never a feature. Stage 3 combines them with the model.
- **Point in time.** History features use only races on strictly earlier dates. Races are processed day by day: a day's rows are computed from state built before that day, then the day's results update the state. Driver, trainer and sire rates are updated the same way.
- **Feature set v1.** Names may vary; the meaning must not.
  - **Form:**
    - last 1/3/6 ranks relative to field size (unplaced or incident counts as worst);
    - win and place rates over the last 6 runs;
    - days since the last run;
    - number of known past runs.
  - **Speed (trot):** best and mean past reduction kilométrique, both in the same discipline and in the same discipline × distance band.
  - **Class:**
    - today's allocation against the mean allocation of past runs;
    - `handicapValeur`;
    - career earnings per run.
  - **People:** win and place rates of the driver/jockey and of the trainer over the previous 365 days, with their run counts, plus `driverChange`.
  - **Context:**
    - change of distance, discipline and racecourse versus the last run;
    - `placeCorde`, `handicapPoids`, `handicapDistance`;
    - `deferre` and `oeilleres` as categories;
    - `avisEntraineur`;
    - age and sex;
    - going of the day for galop.
  - **Field:** number of runners, plus this runner's form rate against the field mean (rank of `f_` win rate within the race).
  - **Pedigree:** the sire's win rate in this discipline, from earlier races, with its count.
- **Missing values.** A feature with no data is empty (null), never 0 or an average. Each rate is paired with its count.
- **Output.**
  - CLI: `python -m app.jobs.build_features --date-debut … --date-fin … --sortie <file.csv.gz>`.
  - It writes a gzip CSV with a header plus a sidecar `<file>.registry.json`, which lists every column with its group and source.
  - Rows are sorted by date, race and runner.
  - No new dependency (standard library and numpy only).
- **Throughput.** Five years must build in under 30 minutes on the developer machine: one chronological pass with running aggregates, never a per-row query.

**Ask First:**
- Adding a dependency (pandas, pyarrow).
- Writing features into the application database.
- Changing the rebuild or ingestion.

**Never:**
- Training a model in this spec.
- Imputing features.
- Using open-pmu data.
- Reading odds as features.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two days | Horse runs on D1 (wins) and D2 | D2 row: last rank = 1, win rate 1/1, days since = D2−D1; D1 row: no history (nulls, count 0) | N/A |
| Same-day isolation | Driver wins R1 and drives in R5 the same day | R5 driver rate excludes the R1 win | N/A |
| Non-runner | `statut` NON_PARTANT | No row; never counted in history | N/A |
| Unplaced or incident | Past run with no rank or with an incident | Counts as worst relative rank, and as a run in the counts | N/A |
| Unfinalised race | `finalisee` false | No row | N/A |
| Leakage guard | A forbidden field registered as a feature, or a feature that changes when the race's own result changes | Test fails | test |
| Missing data | Trot race, no `placeCorde` | Empty cell | N/A |
| Bad dates | fin < debut | CLI error | argparse |

</frozen-after-approval>

## Code Map

- `backend/app/data/models.py` -- `Course` (date, heure_depart, discipline, distance, allocation, terrain, hippodrome, finalisee), `Participation` (cheval_id, num_pmu, rang_arrivee, incident, cote_reference, cote_direct, driver, entraineur, donnees_brutes JSON).
- `backend/app/jobs/rebuild_historique.py`, `backend/app/data/repository.py` -- how rows were stored; `rang_arrivee` comes from `ordreArrivee`.
- `backend/app/data/pmu_client.py:31-41` -- `STATUS_TO_INCIDENT`; raw incident values in `donnees_brutes["incident"]`.
- Evidence: in the rebuild, `donnees_brutes` keys include `musique`, `nombreCourses`, `gainsParticipant`, `driverChange`, `handicapPoids`, `nomPere` and `nomPereMere`. Trot rows also carry `reductionKilometrique`, `deferre`, `handicapDistance` and `avisEntraineur` (inventory §3).
- Placement: pure computation in `backend/app/model/features.py` (new package, no I/O, testable on plain records), plus job `backend/app/jobs/build_features.py` (reads the DB through SQLAlchemy in date order, streams rows).
- Tests style: `backend/tests/test_rebuild_historique.py` (temporary SQLite `Repository`, builders).

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/model/__init__.py`, `backend/app/model/features.py` -- Feature registry (name → group, source fields, "before race" flag) and the day-by-day state machine computing rows. -- Single source of truth for what a feature reads.
- [x] `backend/app/jobs/build_features.py` -- CLI: streams finalised French races in date order from the DB into `features.py` and writes the CSV and registry sidecar, with progress logs. -- The deliverable.
- [x] `backend/tests/test_features.py` -- One test per I/O row, plus:
  - a registry test asserting no forbidden field is a feature source;
  - a perturbation test: changing a race's own result, closing odds and post-race fields leaves that race's features unchanged. -- The leakage guard.
- [x] `backend/tests/test_build_features.py` -- End to end on a small temporary database: header, groups, sort order, sidecar, gzip. -- Output contract.

**Acceptance Criteria:**
- Given the local database, when the job runs over 2025-10-20 → 2026-09-19, then it completes in under 10 minutes and logs row and race counts.
- Given the backend suite, when it runs, then everything passes.

## Design Notes

Relative rank: `(rank − 1) / (field − 1)` in [0, 1]. Unplaced or incident = 1. A field of one gives null.

## Verification

**Commands:**
- `cd backend && .venv/Scripts/python.exe -m pytest -q` -- expected: all pass.
- `docker compose exec api python -m app.jobs.build_features --date-debut 2025-10-20 --date-fin 2026-09-19 --sortie /app/data/features_2025-26.csv.gz` -- expected: about 9,000+ races, completes and logs counts.

## Suggested Review Order

**Leakage guard**

- Entry point: forbidden post-race fields, the single list every feature source is checked against.
  [`features.py:48`](../../backend/app/model/features.py#L48)

- Features only ever see the runner through this whitelisted pre-race view.
  [`features.py:256`](../../backend/app/model/features.py#L256)

- Day-by-day pass: rows from yesterday's state, then today's results update it.
  [`features.py:461`](../../backend/app/model/features.py#L461)

- Perturbation test: changing a race's own result, odds and post-race fields leaves its features unchanged.
  [`test_features.py:416`](../../backend/tests/test_features.py#L416)

**The job**

- Streams finalised pmu races in date order, atomic CSV + registry, skipped-row counts.
  [`build_features.py:168`](../../backend/app/jobs/build_features.py#L168)

- Exit code 1 on failure, existing output left intact.
  [`build_features.py:267`](../../backend/app/jobs/build_features.py#L267)

**Feature computation**

- Running aggregates per horse, person (365 days), sire × discipline and trot speed band.
  [`features.py:445`](../../backend/app/model/features.py#L445)
