---
title: 'Per-horizon ML predictions: morning, H-60, H-30, H-15, H-10'
type: 'feature'
created: '2026-11-14'
status: 'done'
baseline_commit: '0e84e04195c2007a404ed76eb5f2f57f9eece067'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-modele-fondamental.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-modele-combine.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-cotes-instantanees.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Lazyd sells win predictions. The fundamental model (stage 2) and the odds combination (stage 3) only exist offline, and the backend still predicts with the legacy scoring engine. Customers need a morning prediction, then updates at H-60, H-30, H-15 and H-10.

**Approach:** A new `pronostics` backend service.
- **Morning.** Each morning it rebuilds the point-in-time feature state from finalised history up to the day before. It then publishes a fundamental-only prediction for every race of the day.
- **Horizons.** Each time the `cotes` service stores an H-60, H-30, H-15 or H-10 snapshot of a race, it recomputes that race's features with the runners actually running at that moment. It combines them with the snapshot's live odds as p ∝ exp(α·log p_fond + β·log p_mkt), and publishes a new timestamped version.
- **Coexistence.** The legacy engine keeps running unchanged.

## Boundaries & Constraints

**Always:**
- **Model inputs.**
  - The model, its feature list, categorical features and temperature are read from `params.json` and `model.cbm`, mounted read-only from `ml/runs/2026-11-09`.
  - α and β are read from `ajustement` in `ml/runs/2026-11-10-combine-r1/report.json`, also mounted read-only.
  - At startup the service logs the SHA-256 of both files and refuses to start if a file is missing, or if a model feature is not in `NOMS_FEATURES`.
- **Point in time.**
  - Today's rows come from `ConstructeurFeatures.lignes_course` on a state fed only with finalised races strictly before today. Today's races never update the state.
  - Values reach the model exactly as the training CSV did: `formater`, then float for numerics, and string or `MODALITE_ABSENTE` (`"__absent__"`) for categoricals.
- **Runners.** At a horizon, a runner whose snapshot `statut` is `NON_PARTANT` is excluded.
- **Market probability.**
  - p_mkt = 1/`cote_direct` of the horizon snapshot, normalised over the remaining runners.
  - If any remaining runner lacks a valid odds value (finite and > 1), publish p_fond renormalised, with `manques=["cotes_incompletes"]`.
- **Storage.**
  - One `prediction_runs` row per race and horizon, with `variante="ml"` and a new column `horizon` in {`matin`, `h60`, `h30`, `h15`, `h10`}.
  - `parametres` records the model and report hashes, α, β, the temperature and the last day in the state.
  - `prediction_chevaux` gets `probabilite` (the published value), `cote` (odds used) and a new column `probabilite_fondamentale`.
  - Runs are never rewritten, and never published at or after `heure_depart`.
- **Service.** A missed horizon (no snapshot) is logged, never faked. Per-race errors are isolated. The service polls every 30 s and runs the morning rebuild at the first pass on or after `PRONOSTICS_HEURE`, default 7 on the container clock, after the 6 o'clock ingestion.

**Ask First:**
- Showing these predictions in the API, dashboard or app, or stopping the legacy engine.
- Per-horizon α/β, or any refit.
- Publishing H-2.
- Copying the model into the image or committing it.

**Never:**
- Commit `ml/runs`, data or model binaries.
- Change `predict.py`, `scheduler.py`, the `cotes` service or `participations` odds.
- Use any post-race field.
- Add a dependency other than `catboost==1.2.10`.
- Use Alembic.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Morning | 07:00, 12 races today, none run | 12 `matin` runs; probabilities sum to 1 per race | N/A |
| Horizon | H-30 snapshot stored, no `h30` run | One `h30` run: combined probability plus fundamental probability, odds used | N/A |
| Already published | Same pass again | No new run | N/A |
| Non-runner | Snapshot statut NON_PARTANT for num 5 | num 5 absent; others renormalised | N/A |
| Missing odds | One runner `cote_direct` null | Fundamental-only run, `cotes_incompletes` | log |
| Started | now ≥ `heure_depart` | Nothing published | N/A |
| Late wake | Service starts at 15:00 | State rebuilt; `matin` for races not started yet | N/A |
| Race error | Feature or model error on one race | Other races published; retried next pass | log |

</frozen-after-approval>

## Code Map

- `backend/app/model/features.py` -- `ConstructeurFeatures`:
  - `traiter_jour(courses, emettre=False)` builds the state, in strict date order;
  - `lignes_course(course, effectifs)` emits the rows without mutating anything;
  - `CourseRecord` and `PartantRecord` (`statut`, `est_partant` from `brut`);
  - `NOMS_FEATURES`.
- `backend/app/jobs/build_features.py:49` -- `lire_jours(repository, date_fin)`. It only reads finalised `pmu` races; reuse it for the state. Factor its row-to-record code so a new reader can load today's races, which are not finalised (`source=="pmu"`, `heure_depart` set). `formater` is at line 113. A full replay up to 2026-11-12 took 59 s and 307 MB.
- `ml/hippique_ml/model.py:36,74,100` -- the inference reference: `RawFormulaVal` scores, then a softmax per race divided by the temperature. `pool` passes the categoricals by name. `ml/hippique_ml/data.py:146` covers CSV parsing and `MODALITE_ABSENTE`.
- `ml/hippique_ml/combine.py:59-71,314` -- `course_complete` and `proba_marche` give the reference market rule and the combination formula.
- `backend/app/data/models.py:110-153` -- `PredictionRun` and `PredictionCheval`; add `horizon` and `probabilite_fondamentale`. `CoteInstantanee` is at line 155 (`statut`, `cote_direct`, `cible_minutes`).
- `backend/app/data/repository.py` -- add the columns in `_migrate` (pattern around line 125-141). `save_prediction_run` (line 497) takes `HorseAnalysis`; add an ML-specific writer instead of bending it. `instantanes_pris` is at line 168. `courses_evaluables` filters by `variante`, so `ml` runs never reach the dashboard (`routes_dashboard.py` only allows live, rejeu and app).
- `backend/app/jobs/cotes_instantanees.py` -- the polling loop pattern to follow (`boucle`, live clock, injected `horloge`/`attendre`, per-race isolation).
- `docker-compose.yml` -- add the `pronostics` service like `cotes`, with two read-only bind mounts: `./ml/runs/2026-11-09:/app/modele/fondamental:ro` and `./ml/runs/2026-11-10-combine-r1:/app/modele/combine:ro`.
- `backend/requirements.txt` -- add `catboost==1.2.10`, compatible with the pinned `numpy==1.26.4`.

## Tasks & Acceptance

**Execution:**
- [x] `backend/requirements.txt` -- add `catboost==1.2.10` -- inference.
- [x] `backend/app/data/models.py`, `backend/app/data/repository.py` -- new columns, `_migrate` step, `enregistrer_pronostic_ml(...)`, and `horizons_publies(course_id)` -- storage.
- [x] `backend/app/jobs/build_features.py` -- reader of today's races, sharing the row-to-record code with `lire_jours` -- live rows.
- [x] `backend/app/model/inference.py` (new) -- load and validate the model and parameters; `probas_fondamentales(lignes)`; `combiner(p_fond, cotes, alpha, beta)` -- model.
- [x] `backend/app/jobs/pronostics_ml.py` (new) -- `passage(...)`, `boucle`, `main`, and a `--verifier JOUR --predictions <csv>` mode -- service and parity.
- [x] `docker-compose.yml` -- `pronostics` service -- deployment.
- [x] `backend/tests/test_pronostics_ml.py` -- one test per I/O matrix row, with a tiny CatBoost model trained in a fixture; tests for the categorical encoding and the combination formula -- correctness.

**Acceptance Criteria:**
- Given the backend suite, when it runs, then every test passes, including the existing 366.
- Given the mounted run, when `--verifier` runs on a test-period day, then the backend's fundamental probabilities match `test_predictions.csv.gz` within 1e-6 for every runner.
- Given `docker compose up -d pronostics` on a race day, when an H-30 snapshot lands, then within one poll an `h30` run exists for that race.

## Design Notes

The state is built once per day, in memory, because a full replay takes about a minute. Recomputing the rows at each horizon from fresh database rows picks up late non-runners and the morning terrain update. The training rows used the final runner list, so this is closer to training than the morning list.

## Verification

**Commands:**
- `cd backend && .venv/Scripts/python.exe -m pytest -q` -- expected: all pass.
- `docker compose run --rm pronostics python -m app.jobs.pronostics_ml --verifier 2026-03-14 --predictions /app/modele/fondamental/test_predictions.csv.gz` -- expected: maximum gap below 1e-6, 0 missing runners.

**Manual checks:**
- On a race day, query `prediction_runs` where `variante='ml'`: expect one `matin` run and up to four horizon runs per race, all with `cree_le` before `heure_depart`.

## Spec Change Log

- 2026-11-14, review loop 1 (patches only, no intent change):
  - A partial unique index on (course_id, horizon) for `variante='ml'` guarantees one run per race and horizon.
  - A race with no remaining runner is reported once, then skipped.
  - A failed state rebuild is retried at most every 5 min.
  - The service refuses to start, with a clean message, if catboost is missing or its version differs from training.
  - Horizon runs record the snapshot `pris_le` and the excluded non-runners.
  - `PRONOSTICS_HEURE` is validated (an integer from 0 to 23).
  - `--verifier` also fails on extra runners.
  - The tests that do not need the model run without catboost.
  - New tests: model refusals, the `--verifier` exit code, h60 then h30, a race with no start time.
  - Deferred:
    - retraining on the rebuilt history;
    - catboost on the VPS CPU, and image size;
    - healthcheck;
    - races before 7 h;
    - the Python 3.15 dev venv.

## Result

- Backend suite: 422 pass in Python 3.12 with catboost. In `backend/.venv` (Python 3.15, no catboost wheel), 384 pass and 38 model tests are skipped.
- Parity with training, on the DB copy of 2026-11-09:
  - 2026-03-14: 394 runners, maximum gap 4.96e-11;
  - 2026-08-30: 247 runners, maximum gap 4.99e-11;
  - in both cases, 0 missing and 0 extra.
- On the current DB the gap reaches 0.086, because the rebuild added history after training. Retraining is deferred.
- The live acceptance criterion (an `h30` run after a real snapshot) is not yet checked: the service has not been started.

## Suggested Review Order

**Publication logic (entry point)**

- One pass: morning and horizon runs, never after the start, errors isolated per race.
  [`pronostics_ml.py:211`](../../backend/app/jobs/pronostics_ml.py#L211)

- Which horizon is due: the newest unpublished snapshot; older ones logged as missed.
  [`pronostics_ml.py:184`](../../backend/app/jobs/pronostics_ml.py#L184)

- Per race: features from the snapshot's runners, fundamental probability, then the combination.
  [`pronostics_ml.py:136`](../../backend/app/jobs/pronostics_ml.py#L136)

- Daily state rebuilt on finalised history strictly before the programme day.
  [`pronostics_ml.py:112`](../../backend/app/jobs/pronostics_ml.py#L112)

- Loop: rebuild when the programme changes, retry every 5 min on failure.
  [`pronostics_ml.py:267`](../../backend/app/jobs/pronostics_ml.py#L267)

**Model and parity**

- Startup checks: hashes, features, categoricals, temperature, α/β, catboost version.
  [`inference.py:151`](../../backend/app/model/inference.py#L151)

- Values encoded exactly like the training CSV (`formater`, float or `__absent__`).
  [`inference.py:73`](../../backend/app/model/inference.py#L73)

- Combination p ∝ exp(α log p_fond + β log p_mkt); None when an odds value is invalid.
  [`inference.py:126`](../../backend/app/model/inference.py#L126)

- Parity gate against `test_predictions.csv.gz`.
  [`pronostics_ml.py:310`](../../backend/app/jobs/pronostics_ml.py#L310)

**Live rows (point in time)**

- Today's races, finalised or not, through the same row-to-record code as training.
  [`build_features.py:123`](../../backend/app/jobs/build_features.py#L123)

- Shared row-to-record conversion.
  [`build_features.py:58`](../../backend/app/jobs/build_features.py#L58)

**Storage**

- ML writer: variante `ml`, horizon, fundamental probability; returns None on a duplicate.
  [`repository.py:249`](../../backend/app/data/repository.py#L249)

- Idempotent migration of the columns and the partial unique index.
  [`repository.py:140`](../../backend/app/data/repository.py#L140)

- Model columns and index declaration.
  [`models.py:119`](../../backend/app/data/models.py#L119)

**Peripherals**

- `pronostics` service with read-only model mounts.
  [`docker-compose.yml:47`](../../docker-compose.yml#L47)

- The single new dependency.
  [`requirements.txt:15`](../../backend/requirements.txt#L15)

- Tests: the I/O matrix, refusals, parity, the loop.
  [`test_pronostics_ml.py:1`](../../backend/tests/test_pronostics_ml.py#L1)
