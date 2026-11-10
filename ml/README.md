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

## Tests

```sh
cd ml && uv run pytest -q
```
