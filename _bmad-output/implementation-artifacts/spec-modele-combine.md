---
title: 'Combined model: fundamental probabilities and H-30 odds (roadmap stage 3, Benter)'
type: 'feature'
created: '2026-11-10'
status: 'done'
baseline_commit: 'c587a19aefd280551aaf93febe013f795de9864f'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/predictive-model-roadmap-2026-10-22.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-modele-fondamental.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The stage-2 fundamental model reads no odds. Out of time it scores 2.072, against 1.999 for the H-30 market. Roadmap stage 3 asks whether combining the two beats the market alone. That is the condition for the app to show value and Kelly as more than experimental.

**Approach:** Add a stage-3 CLI to `ml/`. It fits a conditional logit (Benter) per race:

p_i ∝ exp(α · log p_fund_i + β · log p_mkt_i)

- `p_fund` is the stage-2 probability.
- `p_mkt` is 1/`cote_reference`, normalised within the race.

It fits the two coefficients on the validation period only, then scores the test period once against the market.

## Boundaries & Constraints

**Always:**
- **Inputs.**
  - Stage-2 run folder: `model.cbm`, `params.json`, `test_predictions.csv.gz`.
  - The feature CSV it was trained on.
- **Rebuilding the stage-2 probabilities.**
  - Validation and test probabilities are recomputed from `model.cbm` and the temperature in `params.json`, using the periods in `params.json`.
  - The recomputed test probabilities must match `test_predictions.csv.gz` within 1e-9 for every row; otherwise the run refuses.
  - The registry `git_sha` must equal `params.json` `registre_git_sha`.
- **Fit.**
  - α and β are fitted by maximum conditional likelihood on validation races where every runner has a finite positive `cote_reference`.
  - Pure numpy (Newton, analytic gradient and Hessian), fixed starting point, deterministic.
  - Report α, β and their standard errors from the inverse Hessian.
- **Evaluation, per period (validation and test) and per discipline**, on races where every runner has odds:
  - races and runners;
  - log-loss of the combined model, the market and the fundamental model;
  - bootstrap 95% CI (1,000 resamples, by race) of combined − market and combined − fundamental;
  - top-pick win rate of the combined model against the market favourite (ties 1/k);
  - calibration buckets, the same as stage 2.

  Also report the market log-loss with the closing odds (`cote_direct`) on races where every runner has them. It is informative only.
- **Gate (test, all disciplines).** PASSED when the combined − market mean is below 0 and the CI upper bound is below 0. Print it as one plain line.
- **Artefacts** in a new `--sortie` folder, never overwriting an existing run:
  - `combine.json` (α, β, standard errors, input run path, its `params.json` hash, ml versions);
  - `report.json` and `report.md`;
  - `test_predictions.csv.gz`, with stage-2 columns plus `proba_marche` and `proba_combinee`. It covers market-complete test races only, for stage 4.
- **CLI.** `uv run python -m hippique_ml.combine --run <stage2_dir> --features <csv.gz> --sortie <dir>`. Bad input exits 2 with a message before fitting.

**Ask First:**
- Coefficients per discipline, extra terms (field size, odds movement, closing odds) or any model beyond the 2-coefficient logit.
- Adding a dependency (scipy, statsmodels).
- Retraining the stage-2 model.
- Wiring anything into the backend or the app.

**Never:**
- Fitting, choosing or calibrating on the test period.
- Using `cote_direct` (closing odds) as an input to the combined model.
- Changing stage-2 behaviour or its tests.
- Committing data files, runs or model binaries.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Normal run | Stage-2 run + its feature CSV | Report with α, β, the gate line; probabilities of each race sum to 1 (±1e-9) | N/A |
| Wrong table | CSV or registry differs from the run (git_sha, or recomputed test probabilities ≠ saved ones) | Refuses before fitting | exit 2, message |
| Missing odds | A runner without `cote_reference`, or with 0, inf or a non-number | Race left out of fit and evaluation, counted per period | N/A |
| Dead heat | Two winners | Log-loss uses the summed probability of the winners; the likelihood uses the same | N/A |
| Signal check | Synthetic data where the fundamental carries signal the odds lack | α > 0; combined beats market | test |
| No signal | Synthetic `p_fund` = uniform | α ≈ 0, β ≈ 1 ± 0.1; gate FAILED | test |
| Existing output | `--sortie` already holds `report.json` | Refuses, run left intact | exit 2 |

</frozen-after-approval>

## Code Map

- `ml/hippique_ml/data.py` -- reuse `lire_registre`, `lire_table`, `decouper`, `Periodes`, `ErreurDonnees`, `groupes`. `decouper` returns per-period exclusion counts. The periods are in stage-2 `params.json["periodes"]`, in the `Periodes.bornes()` format: train `fin_exclue`, validation `fin`, test `fin`.
- `ml/hippique_ml/model.py` -- reuse `pool(partie, registre, avec_label=False)` and `softmax_par_course(scores, ids, temperature)`, plus `debuts_groupes`, which requires contiguous races; `lire_table` sorts by date, course and runner. Load the model with `catboost.CatBoost().load_model(path)` and predict with `prediction_type="RawFormulaVal"`.
- `ml/hippique_ml/evaluate.py` -- reuse `intervalle_bootstrap`, `calibration`, `_taux_egalites`, `PROBA_MIN` and `TRANCHES_CALIBRATION`. `par_course` is model-vs-market specific; write a sibling for the three-way comparison, do not change it.
- `ml/hippique_ml/train.py` -- reuse the patterns, not the code paths: `preparer_sortie` (refuse an existing run), `versions()`, `_ecrire_json`, markdown helpers `_f`, `_ic` and `_pct`, and the `main` error handling (`ErreurDonnees`, `OSError`, `CatBoostError` → exit 2).
- `ml/tests/conftest.py` -- synthetic table builders (`lignes_synthetiques`, `ecrire`, `PERIODES`, `GRILLE_TEST`, `ITERATIONS_TEST`). The odds are a deterministic function of `f_force`, so the market already knows the signal. The signal-check test needs a hidden feature that the odds omit.
- Real stage-2 run: `ml/runs/2026-11-09/`, built from `C:\Users\lazyd\AppData\Local\Temp\claude\388e31520f96e488\4fab5698-bf1a-479d-ae46-cb6b98e0da71\scratchpad\full\features_2022-26.csv.gz`. On that run, validation has 5,372 market-complete races out of 6,685 and test has 9,498 out of 11,465.
- New: `ml/hippique_ml/combine.py`, `ml/tests/test_combine.py`, and a README section.

## Tasks & Acceptance

**Execution:**
- [x] `ml/hippique_ml/combine.py` -- Load the run and table with consistency checks; rebuild validation and test probabilities; implement the conditional-logit Newton fit; evaluate; write the report and artefacts; add the CLI. -- The stage-3 deliverable.
- [x] `ml/tests/test_combine.py` -- One test per I/O matrix row on a tiny synthetic stage-2 run, plus unit tests: the Newton fit recovers known α and β on simulated races, and the likelihood gradient matches finite differences. -- Correctness.
- [x] `ml/README.md` -- Stage-3 section: command, outputs, gate. -- Usage.
- [x] Full run -- Run on `ml/runs/2026-11-09` and its feature table, and record the report path and gate verdict in the final summary. -- The gate answer.

**Acceptance Criteria:**
- Given the stage-2 run and its table, when `combine` runs, then `report.md` states α, β with standard errors, test combined − market with its CI, and the gate verdict, in under 10 minutes.
- Given `cd ml && uv run pytest -q`, then every test passes, including the 36 stage-2 tests unchanged.

## Spec Change Log

- 2026-11-10, review loop 1 (patches only, no intent change):
  - The fit records convergence (stop reason and |gradient|), and the gate line warns if the fit did not converge or is not identifiable.
  - Standard errors are reported only when the information matrix is positive definite, so no NaN reaches the JSON.
  - A race with no winner is refused by `combiner`.
  - `params.json` keys are required explicitly, including `categoriques`, and the validated temperature is used.
  - The saved predictions are checked for columns and duplicate keys.
  - The sha256 of `model.cbm` and of the feature CSV are recorded.
  - `report.json` is written last.
  - `ValueError` and `KeyError` exit 2.
  - New tests cover top-pick and favourite rates with a tie, market-complete filtering and calibration, every refusal path, and test labels and odds never changing the fit.
  - Deferred: a day-level bootstrap, renormalising races with one missing odds, and the closing-odds caveat for stage 4.

## Result

Full run `ml/runs/2026-11-10-combine-r1/report.md` (git-ignored). The fit on 5,372 validation races gives α = 0.389 (SE 0.027) and β = 0.774 (SE 0.028); it converged in 4 Newton steps.

| Test (9,498 market-complete races) | Log-loss | Top pick wins |
|---|---|---|
| Combined | 1.983 | 31.0% |
| H-30 market | 1.999 | 31.0% (favourite) |
| Fundamental | 2.076 | 26.5% |

**Gate PASSED: combined − market −0.016 [−0.020, −0.012].** It is also below 0 in every discipline: obstacle −0.018, plat −0.020, trot −0.013.

Caveat: the closing-odds market scores 1.924 on 10,962 races, which is better than the combined model.

## Design Notes

Conditional logit on race r with runners i, and features x_i = (log p_fund_i, log p_mkt_i):

- ℓ(θ) = Σ_r [ log Σ_{w∈W_r} e^{θ·x_w} − log Σ_i e^{θ·x_i} ]. W_r is the set of winners; for a dead heat this is the summed winner probability.
- The gradient is the mean of x over the winners minus the mean of x over the runners, both weighted by p. The Hessian is minus the p-weighted covariance of x.
- Start from θ = (0, 1), which is the market alone. Use Newton steps with step halving until ℓ stops improving, about 1e-10 per race.

Probabilities are floored at 1e-6 before the log, the same floor as the log-loss.

## Verification

**Commands:**
- `cd ml && uv run pytest -q` -- expected: all pass.
- `cd ml && uv run python -m hippique_ml.combine --run runs/2026-11-09 --features <full.csv.gz> --sortie runs/2026-11-10-combine` -- expected: report written, gate line present.

## Suggested Review Order

**The fit**

- Entry point: conditional log-likelihood, gradient and Hessian per race (dead heats summed).
  [`combine.py:96`](../../ml/hippique_ml/combine.py#L96)

- Newton with half-steps from the market alone (0, 1), convergence flag, guarded standard errors.
  [`combine.py:150`](../../ml/hippique_ml/combine.py#L150)

- Fit on validation only, then score both periods; test labels and odds never change the fit.
  [`combine.py:314`](../../ml/hippique_ml/combine.py#L314)

**Input consistency**

- Stage-2 probabilities recomputed and checked against the saved test predictions (1e-9).
  [`combine.py:377`](../../ml/hippique_ml/combine.py#L377)

- Run flow: params, registry and table checks before any folder is created; artefacts with hashes.
  [`combine.py:405`](../../ml/hippique_ml/combine.py#L405)

**Evaluation and gate**

- Three-way per-race metrics on market-complete races; ties 1/k.
  [`combine.py:218`](../../ml/hippique_ml/combine.py#L218)

- Gate: combined − market mean and CI upper bound below 0, with fit-quality warnings.
  [`combine.py:301`](../../ml/hippique_ml/combine.py#L301)
