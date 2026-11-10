---
title: 'Fundamental model without odds, trained on the feature table (roadmap stage 2)'
type: 'feature'
created: '2026-11-09'
status: 'done'
baseline_commit: 'cd0df19ee146bf20acc04c0e633d0f5165847b95'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/predictive-model-roadmap-2026-10-22.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-features-modele.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Roadmap stage 2 needs a fundamental model that predicts each runner's win probability from the stage-1 features alone, without the odds. Its gate is to beat a uniform guess clearly on races it never saw: test log-loss of 2.30 or lower. The backend must stay light (numpy pinned to 1.26.4 for the server CPU), so the ML stack cannot go there.

**Approach:** Add a separate training project in `ml/`, with its own pinned dependencies (pandas, CatBoost). It reads the `build_features` CSV and its registry, then trains a CatBoost model with the `QuerySoftMax` loss. That loss is a softmax within each race, so the probabilities of each race sum to 1. The project evaluates the model on a strictly later test period and writes a report, the model file and the test predictions that stage 3 needs.

## Boundaries & Constraints

**Always:**
- **Project layout.** `ml/` is a standalone uv project: `pyproject.toml` and lock, Python 3.12, pinned `catboost`, `pandas` and `numpy`, `pytest` for development. It never imports `backend/app`, and the backend never imports `ml/`.
- **Inputs.**
  - The training features are exactly the registry columns with group `feature`. Labels, market columns and identifiers are never features.
  - The `categorical` type comes from the registry. Missing values stay missing (CatBoost handles NaN); nothing is imputed.
  - The script refuses a registry whose features include any column of another group.
- **Date splits.** Splits are by date only and configurable:
  - train: before 2025-04-20;
  - validation: 2025-04-20 → 2025-10-19 (early stopping and calibration only);
  - test: 2025-10-20 → 2026-09-19.

  The test period is used once, for the final report, and never for fitting or tuning.
- **Probabilities.** `group_id` = `course_id`, label = `gagnant`. The predicted probabilities of each race sum to 1 (softmax within the race), with one scalar temperature fitted on validation only. Races with no winner, or with a single runner, are excluded from training and evaluation and counted.
- **Report** (`report.json` + `report.md`), per period and per discipline:
  - races, runners;
  - model log-loss (−log p of the winner, mean per race), uniform log-loss, and the market log-loss from H-30 odds (`cote_reference`) on races where every runner has odds (informative only, not the gate);
  - top-pick win rate against the market favourite and against chance;
  - a 1,000-resample bootstrap 95% CI of model minus uniform and model minus market, by race;
  - calibration buckets, the same as the backend dashboard;
  - the 20 most important features;
  - the gate verdict (test log-loss ≤ 2.30) as a plain line.
- **Artefacts.** `run_dir/` holds `model.cbm`, `params.json` (seed, splits, temperature, feature list, input registry `git_sha`, ml package versions) and `test_predictions.csv.gz` (`course_id`, `num_pmu`, `date`, `discipline`, `proba_modele`, `gagnant`, `cote_reference`, `cote_direct`).
- **Reproducible.** A fixed seed; the same input and seed give the same metrics.
- **CLI.** `uv run python -m hippique_ml.train --features <csv.gz> --sortie <run_dir> [--train-fin …] [--valid-fin …] [--test-fin …]`.

**Ask First:**
- Adding LightGBM, XGBoost or any other model family.
- Hyperparameter search beyond a small fixed grid (depth 4/6/8 × learning rate 0.03/0.1, chosen on validation).
- Using odds as features.
- Wiring anything into the backend or the app.

**Never:**
- Fitting on, tuning on or early-stopping on the test period.
- Shuffling across dates.
- Dropping runners without counting them.
- Committing data files or model binaries to git.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Normal run | Feature CSV covering all three periods | Report + artefacts; per-race probabilities sum to 1 (±1e-9) | N/A |
| Leaky registry | Registry marks `cote_direct` or `rang` as `feature` | Refuses before training | non-zero exit, message |
| Period too small | Test or validation period has no race | Refuses with the period named | non-zero exit |
| Odd races | Race with no winner, dead heat (two `gagnant`), single runner | No winner or single runner: excluded and counted. Dead heat: kept, log-loss uses the summed probability of the winners | N/A |
| Missing odds | Some runners without `cote_reference` | Race excluded from the market comparison only, counted | N/A |
| Determinism | Same input and seed twice | Identical metrics | N/A |

</frozen-after-approval>

## Code Map

- `backend/app/jobs/build_features.py` -- produces the input: gzip CSV sorted by date, `course_id`, `num_pmu`, plus `<csv>.registry.json`. The registry lists columns with `nom`, `groupe` (`id` / `label` / `marche` / `feature`), `type` (`numeric` / `categorical` / `flag`) and `sources`, and also records `git_sha`, `parametres` and `ecartees`.
- `backend/app/engine/evaluation.py` -- dashboard metric definitions: log-loss per race (floored at 1e-6), calibration buckets `TRANCHES_CALIBRATION`. Mirror them, do not import.
- Sample input: `C:\Users\lazyd\AppData\Local\Temp\claude\388e31520f96e488\4fab5698-bf1a-479d-ae46-cb6b98e0da71\scratchpad\out\features_2025-26.csv.gz` (2025-10-20 → 2026-09-19 only). The full run needs the 2022-10 → 2026-09 table, built with `build_features` on a fresh copy of the container database.
- New: `ml/pyproject.toml`, `ml/hippique_ml/{__init__,data,model,evaluate,train}.py`, `ml/tests/`, `ml/README.md`. Add `ml/runs/` and `*.csv.gz` under `ml/` to `.gitignore`.

## Tasks & Acceptance

**Execution:**
- [x] `ml/pyproject.toml`, `ml/README.md`, `.gitignore` -- uv project, pinned deps, how to build features and run training. -- Isolated environment.
- [x] `ml/hippique_ml/data.py` -- Load CSV + registry, validate groups and types, split by date, count exclusions. -- Leakage and split guard.
- [x] `ml/hippique_ml/model.py` -- CatBoost QuerySoftMax fit with early stopping on validation, small fixed grid, temperature fit, per-race softmax prediction. -- The model.
- [x] `ml/hippique_ml/evaluate.py` -- Metrics, bootstrap CI, calibration, top-pick rates, market comparison. -- Report numbers.
- [x] `ml/hippique_ml/train.py` -- CLI writing report and artefacts. -- Entry point.
- [x] `ml/tests/` -- One test per I/O matrix row on a small synthetic CSV + registry, plus metric unit tests (uniform log-loss = log n; a perfect model = 0). -- Correctness.
- [x] Full run -- Build the full feature table from a fresh database copy, train, and save the report path in the final summary. -- The gate answer.

**Acceptance Criteria:**
- Given the full feature table, when training runs, then `report.md` states the test log-loss, the uniform and market comparisons with CIs, and the gate verdict.
- Given `cd ml && uv run pytest`, then all tests pass, and the backend suite is untouched and still passes.

## Verification

**Commands:**
- `cd ml && uv run pytest -q` -- expected: all pass.
- `cd backend && .venv/Scripts/python.exe -m pytest -q` -- expected: all pass (unchanged).
- `cd ml && uv run python -m hippique_ml.train --features <full.csv.gz> --sortie runs/<date>` -- expected: report written; gate line present.

## Spec Change Log

- 2026-11-10, review loop 1 (no intent change):
  - Input guards: a bad CSV or registry now exits 2 with a message before training.
  - Infinite odds no longer count as market odds.
  - Top-pick and favourite ties count 1/k.
  - Exclusions are counted per period.
  - An existing run is never overwritten, and the output folder is checked before training.
  - The temperature warns when it hits a search bound.
  - The report flags validation figures as optimistic and prints the model − uniform CI under the gate.
  - Deferred: `has_time`, a relative gate, training speed and progress logs, small-sample CIs, the `hatchling` pin, and SQLite WAL in the backend.

## Result

Full run `ml/runs/2026-11-09/report.md` (git-ignored). Input: 41,580 races, 495,133 runners, 2022-10-23 → 2026-09-19.

Chosen setting: depth 6, learning rate 0.03, 896 trees, temperature 0.966.

| Test (11,465 races) | Model | Benchmark | Model − benchmark (95% CI) |
|---|---|---|---|
| Uniform | 2.072 | 2.430 | −0.358 [−0.373, −0.346] |
| Market, H-30 odds (9,498 races) | 2.076 | 1.999 | +0.077 [+0.066, +0.088] |

**Gate PASSED: test log-loss 2.072 ≤ 2.30.**

Top pick wins 27.0% of races, against 31.0% for the market favourite and 9.2% by chance.

## Suggested Review Order

**Leakage and split guard**

- Entry point: id, label and market columns can never be features; the registry is refused before training.
  [`data.py:122`](../../ml/hippique_ml/data.py#L122)

- Strict input contract: bad dates, ids, labels, duplicates or multi-date races exit 2.
  [`data.py:146`](../../ml/hippique_ml/data.py#L146)

- Date-only split, per-period exclusions, an explicit overlap check.
  [`data.py:220`](../../ml/hippique_ml/data.py#L220)

- Shuffling the test labels changes neither the fitted model nor the train and validation results.
  [`test_train.py:243`](../../ml/tests/test_train.py#L243)

**The model**

- Grid with early stopping on validation only; the test is never passed in.
  [`model.py:126`](../../ml/hippique_ml/model.py#L126)

- Temperature fitted on validation scores, with a warning at a search bound.
  [`model.py:155`](../../ml/hippique_ml/model.py#L155)

**Metrics and report**

- Per-race metrics: finite odds only, dead heats summed, ties counted 1/k.
  [`evaluate.py:34`](../../ml/hippique_ml/evaluate.py#L34)

- Run flow: the output folder is checked before training, the gate verdict, the artefacts.
  [`train.py:42`](../../ml/hippique_ml/train.py#L42)

