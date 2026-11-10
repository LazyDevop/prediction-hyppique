# hippique-ml — fundamental model (roadmap stage 2)

Offline training project, separate from the backend. It never imports
`backend/app`, and the backend never imports it: the backend keeps its light
stack (numpy 1.26.4) while this project pins its own CatBoost, pandas and
numpy (see `pyproject.toml` and `uv.lock`, Python 3.12).

## What it does

- Reads the `build_features` table (`<file>.csv.gz`) and its registry
  (`<file>.csv.gz.registry.json`).
- Features are exactly the registry columns of group `feature`. A registry
  that marks an identifier, label or market column (`cote_direct`, `rang`, …)
  as a feature is refused before training. Missing numeric values stay NaN;
  a missing category is kept as its own level (`__absent__`); nothing is imputed.
- Splits by date only (defaults):
  - train: before 2025-04-20;
  - validation: 2025-04-20 → 2025-10-19 (early stopping, the fixed
    depth 4/6/8 × learning rate 0.03/0.1 grid, temperature);
  - test: 2025-10-20 → 2026-09-19, used once for the report.
- Trains CatBoost `QuerySoftMax` (softmax within each race, `group_id` =
  `course_id`, label = `gagnant`), then fits one temperature on validation.
  Races with no winner or a single runner are excluded and counted; dead heats
  are kept (log-loss on the summed probability of the winners).

## 1. Build the feature table

From a fresh copy of the container database (the live one keeps being written):

```sh
docker compose exec -T api python -c "import sqlite3; s=sqlite3.connect('/app/data/hippique.db'); d=sqlite3.connect('/tmp/copy.db'); s.backup(d); d.close()"
MSYS_NO_PATHCONV=1 docker cp prediction-hyppique-api-1:/tmp/copy.db ./hippique_copy.db
MSYS_NO_PATHCONV=1 docker compose exec -T api rm /tmp/copy.db

cd backend
DATABASE_URL=sqlite:///../hippique_copy.db .venv/Scripts/python.exe -m app.jobs.build_features \
    --date-debut 2022-10-23 --date-fin 2026-09-19 --sortie ../ml/data/features_2022-26.csv.gz
```

## 2. Train

```sh
cd ml
uv sync
uv run python -m hippique_ml.train --features data/features_2022-26.csv.gz --sortie runs/<date> \
    [--train-fin 2025-04-20] [--valid-fin 2025-10-19] [--test-fin 2026-09-19] [--graine 42]
```

`--train-fin` is the first validation day, `--valid-fin` the last validation
day, `--test-fin` the last test day. Bad input exits with code 2 and a
message, before any training: a leaky or unreadable registry, an empty period,
a non-numeric or infinite value, an empty date or id, a `gagnant` other than
0/1, a duplicate runner, a race spread over several dates or disciplines, or
a `--sortie` that already holds a run (`report.json`). A run is never
overwritten: pick a new `--sortie`.

`runs/<date>/` then holds:

- `report.md`, `report.json` — per period and discipline: races, runners,
  model / uniform / market (H-30 `cote_reference`) log-loss, bootstrap 95% CIs
  of model − uniform and model − market, top-pick rate against the favourite
  and chance, calibration buckets, the 20 most important features and the gate
  line (test log-loss ≤ 2.30). Exclusions are counted per period. Ties for
  top pick or favourite count 1/k per tied runner. Validation figures are
  optimistic (validation picks the early stop, grid point and temperature);
  only test figures are out of sample;
- `model.cbm`, `params.json` (seed, splits, temperature, features, registry
  `git_sha`, package versions);
- `test_predictions.csv.gz` (`course_id`, `num_pmu`, `date`, `discipline`,
  `proba_modele`, `gagnant`, `cote_reference`, `cote_direct`) for stage 3.

Data files and model binaries are git-ignored.

## 3. Combine with the market (roadmap stage 3, Benter)

```sh
cd ml
uv run python -m hippique_ml.combine --run runs/<stage2_dir> --features data/features_2022-26.csv.gz --sortie runs/<date>-combine
```

Fits a conditional logit per race,
`p_i ∝ exp(α · log p_fund_i + β · log p_mkt_i)`, where `p_fund` is the stage-2
probability and `p_mkt` is 1/`cote_reference` (H-30 odds) normalised within
the race. Probabilities are floored at 1e-6 before the log.

- **Inputs and checks.** The stage-2 run folder (`model.cbm`, `params.json`,
  `test_predictions.csv.gz`) and the feature CSV it was trained on. Validation
  and test probabilities are recomputed from `model.cbm`, the temperature and
  the periods in `params.json`. The run is refused (exit 2, before fitting)
  when the registry `git_sha` differs from `registre_git_sha`, when the
  feature list differs, or when any recomputed test probability differs from
  `test_predictions.csv.gz` by more than 1e-9.
- **Fit.** α and β by maximum conditional likelihood on validation races
  where every runner has a finite positive `cote_reference`. Pure numpy
  Newton (analytic gradient and Hessian, step halving), starting from the
  market alone (α = 0, β = 1). Standard errors come from the inverse Hessian.
  The test period is never used for fitting. `cote_direct` (closing odds) is
  never an input.
- **Evaluation**, per period (validation, test) and discipline, on races
  where every runner has odds (others are counted as `excl.`): log-loss of the
  combined model, the market and the fundamental model; bootstrap 95% CIs of
  combined − market and combined − fundamental; top-pick win rate of the
  combined model against the market favourite (ties 1/k); calibration buckets.
  The closing-odds market log-loss is shown for information only.
- **Gate.** PASSED when the test combined − market mean and its CI upper bound
  are both below 0.
  The verdict line warns when the fit did not converge or the coefficients are
  not identifiable.

`--sortie` must be a new folder (an existing `report.json` is never
overwritten). It then holds `combine.json` (α, β, standard errors, input run
path, sha256 of `params.json`, `model.cbm` and the feature CSV, convergence
flag, package versions), `report.json`, `report.md` and
`test_predictions.csv.gz` (stage-2 columns plus `proba_marche` and
`proba_combinee`, market-complete test races only, for stage 4).

## Tests

```sh
cd ml && uv run pytest -q
```
