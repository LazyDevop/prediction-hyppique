---
title: "Predictive Model Roadmap"
status: approved
created: 2026-10-22
approved_by: Lazyd (2026-10-22)
related:
  - architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md (AD-14)
  - research/api-field-inventory-2026-10-20/inventory.md
  - briefs/brief-prediction-hyppique-backoffice-2026-10-18/brief.md
---

# Predictive Model Roadmap

## Why

The current engine was measured on 3,166 replayed races with full turfinfo history, using the market's H-30 odds as the benchmark:

- **Worse than a uniform guess in every discipline.** Log-loss is 2.673 against 2.490 for uniform probabilities.
- **Barely uniform after recalibration.** On 1,001 later races, a temperature-scaled engine scores 2.417 against 2.426 for uniform. The market scores 2.009.
- **No information beyond the market.** In a two-input combination with the market, the engine's weight is 0.00.
- **A weak signal, far behind the market.** Its top pick wins 14% of races, against 9% at random and 30% for the market favourite.

The engine only reads public form that the odds already price in. The product's value and Kelly figures therefore rest on probabilities that are worse than chance.

## Targets, stated honestly

| Level | Meaning | Expectation |
|---|---|---|
| 1. Market level | Log-loss about 2.0, top pick about 30% | Very likely with ML and 5 years of data |
| 2. Beat the market | The combined model beats odds alone, out of time | Possible; small margin |
| 3. Profit | Beat the market plus the PMU takeout | Unproven: measure it, never promise it |

## Stages and gates

Each stage is gated on out-of-time test races that the model never saw during fitting. The benchmark is the market's log-loss on the same races.

| Stage | Deliverable | Gate |
|---|---|---|
| 0 | 5-year turfinfo rebuild. Live odds snapshots at H-60, H-30, H-10 and H-2 start now. | Data complete |
| 1 | Feature table built only from information known before the race. A test rejects post-race fields. | Test green |
| 2 | **Fundamental model without odds.** Gradient boosting (LightGBM or CatBoost), with probabilities normalised within each race. | Clearly better than uniform (≤ 2.30) |
| 3 | **Combined model (Benter).** Conditional logit of the fundamental probabilities and the H-30 odds. | **Beats the market** (2.009 on the current test set), bootstrap CI excluding zero |
| 4 | **Profit simulation after takeout**, per bet type, with exotic bets derived through Plackett-Luce | Positive on test races; otherwise no profit claim |
| 5 | Reference engine in the app (AD-14) | Confirmed on live predictions |

If stage 3 fails, the fallback is the product reframing raised by Victor: transparency, published calibration and odds movement.

## Features to build (stage 1)

- **Form.**
  - Past ranks relative to field size.
  - Trot reduction kilométrique normalised by racecourse and distance.
  - Winner's time and beaten margins.
- **Class.** Allocation against previous races, handicap value and earnings.
- **People.**
  - Driver, jockey and trainer strike rates, computed from earlier races only.
  - `driverChange`.
- **Context.**
  - Changes of distance, going or racecourse, and days since the last run.
  - Draw, weight, `deferre`, `oeilleres` and `avisEntraineur`.
- **Field strength.** Ratings of the other runners.
- **Pedigree.** Sire and dam-sire aptitude by going and distance.
- **Late information (live, from now on).** Odds movement between snapshots, `grossePrise` and `nombreIndicateurTendance`.

## Constraints

- **Training data.** Training never uses open-pmu-api data. Training, validation and test splits are by date only.
- **App honesty while the model is being built.** Value and Kelly are shown as **experimental** in the app until stage 3 passes (decision of 2026-10-22).
- **Data source risk.** The data comes from the unofficial PMU turfinfo API: requests are paced, and the risk documented in the parent brief stands.
