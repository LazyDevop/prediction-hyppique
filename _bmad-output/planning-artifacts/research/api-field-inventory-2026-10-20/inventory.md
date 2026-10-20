---
title: "Empirical Field Inventory: PMU turfinfo API and open-pmu-api"
created: 2026-10-20
author: Mary (Business Analyst), with Lazyd
method: real responses, not documentation
related:
  - ../../briefs/brief-prediction-hyppique-backoffice-2026-10-18/brief.md
  - ../../sprint-change-proposal-2026-10-18.md
---

# Empirical Field Inventory: PMU turfinfo API and open-pmu-api

## Summary

1. **open-pmu-api cannot be used to train a model.** It returns **one race per day, the Quinté+**, and details only the **~7 finishers** (46% of runners). The ~6,000 races already historised from it are about 6,000 Quintés, with the losing horses missing. Any model trained on them, and any horse history built from them, sees only good runs.
2. **The PMU turfinfo API is the real historical source.** For past dates back to at least 2014 it returns the full programme (about 46 French races per day) and **every runner**, with about 60 fields per runner.
3. **The odds are timestamped, and the meaning of both odds is now established.**
   - `dernierRapportDirect` is the **closing odds**. Its timestamp falls a median of 1–2 minutes after the scheduled start.
   - `dernierRapportReference` is the **reference odds, about 30 minutes before the start** (since 2018).
   - The favourite at closing odds wins **27%** of races (154 races), which is the expected rate. The 6% favourite rate seen in live on 19/10 was therefore a data-capture problem, not the market.
4. **Some runner fields are only known after the race.** These are `ordreArrivee`, `tempsObtenu`, `reductionKilometrique`, `distanceChevalPrecedent`, `incident`, `commentaireApresCourse` and the closing odds. They must never be used as features for the race itself. Using them is the main leakage risk for any model.
5. **The going (`etatTerrain`) is a galop-only field.** It is filled for 86–100% of past flat and jumps races, and for **0–1% of trotting races**. The back-office brief's target of "≥ 95% past-race going filled" holds only for galop. For trot, a missing going is the normal state, not a gap.
6. **The `online/client/1` and `offline/client/61` endpoints return identical fields** (14 races compared, 2025–2026). This closes the parity question raised in the back-office brief.

## Method

- **Sample.** 29 dates between 2014 and 2026: the first Sunday of March and the second Wednesday of September of each year, plus 07/06, 06/07 and 18/10/2026.
- **Selection.** For each date, up to 6 French races were taken in round-robin across disciplines. That gives 173 races and **1,898 runners**: 384 flat, 448 harness trot, 397 mounted trot, 669 jumps.
- **Calls.** Endpoints called: `programme`, `participants`, `performances-detaillees` (2 races per date, 575 horses, 2,500+ past races) and `online/client/1` for parity. open-pmu `arrivees?date=` was called for every date.
- **Measure.** A field counts as *filled* when it is present and not null or empty. Rates are given per discipline and per period.
- **Errors.** One timeout (2018). `performances-detaillees` answered HTTP 204 for two races in 2014–2015, which means past performances are not available for the oldest dates.
- **Limits.** One or two dates per year and 6 races per date. The rates are indicative to about ±5 points, not exact. The sample includes no weekday in winter or summer.
- **Reproducibility.** `scripts/collect.py` and `scripts/analyse.py`. Full per-field rates are in `field-fill-rates.json`.

## 1. open-pmu-api

| Fact | Measured |
|---|---|
| Races returned per date | **1, always the Quinté+** (28 of 28 dates) |
| Horses detailed per race | median 7 of median 15 starters (**46% of runners**) |
| Horses outside the first ~7 | absent: no name, no odds, no rank |
| Latest day (18/10/2026) | empty: the source lags behind |
| `cotes` (3 values) | `cotes[2]` equals the PMU closing odds in **82%** of cases (102 of 125). `cotes[0]` and `cotes[1]` are earlier snapshots, often close to the reference odds. |
| `poids_cheval` | still unreliable (see the warning in `open_pmu_client.py`) |
| Schema drift | the live response now has a `statistiques` block (favourite, market median, parsed musique) and numeric `cotes`, which differ from the test fixture. The client should be checked against the current shape. |

**Consequences**
- The ~6,000 historised races are a **biased sample**: Quintés only (large handicaps, mostly), finishers only.
- [`backfill_historique.py`](../../../../backend/app/jobs/backfill_historique.py) adds **only the good runs** to a horse's history. Every backfilled horse looks more consistent than it is. This bias feeds the current engine's history features today.
- The only reliable use of open-pmu: a quick check of Quinté results, and possibly the `musique` string, which covers about 12 runs and includes the bad ones.

## 2. PMU turfinfo: race level (`programme`)

All fields are known **before** the race unless marked otherwise.

| Field | Fill | Notes |
|---|---|---|
| `discipline`, `specialite`, `distance`, `heureDepart`, `hippodrome.*`, `conditions`, `conditionSexe`, `montantPrix`, `montantOffert1er..5eme`, `nombreDeclaresPartants`, `categorieParticularite` | 93–100% | Core race description. |
| `corde` | 98–100% flat/trot, 0% jumps | Rail side. |
| `conditionAge` | 100% galop, 0% trot | |
| `typePiste` | 78% flat, 66% jumps, 0% trot | Turf or PSF (fibre sand). |
| `parcours` | 59% flat, 53% jumps | Course variant. |
| `penetrometre.intitule` / `valeurMesure` | **98% galop**, 7–12% trot | **Race-day going.** Measured on race day; `heureMesure` gives the time. |
| `cagnottes[]` | 4% | Jackpot. Affects the pool, not the race. |
| `ordreArrivee`, `dureeCourse`, `incidents[]` (except `NON_PARTANT`), `arriveeDefinitive` | 98–100% | **After the race.** Labels, never features. `NON_PARTANT` is known before the start. |

## 3. PMU turfinfo: runner level (`participants`)

### Known before the race (candidate features)

| Field | All | Flat | Trot (harness / mounted) | Jumps | Notes |
|---|---|---|---|---|---|
| `age`, `sexe`, `race`, `robe`, `driver`, `entraineur`, `proprietaire`, `nomPere`, `nomMere` | 100 | 100 | 100 / 100 | 100 | Identity and pedigree. |
| `nombreCourses`, `nombreVictoires`, `nombrePlaces` | 100 | 100 | 100 / 100 | 100 | Career counts at race time. |
| `nombrePlacesSecond` / `Troisieme` | 90 | 89 | 94 / 87 | 90 | 74% in 2014–17. |
| `musique` | 95 | 89 | 100 / 100 | 93 | Recent form string. |
| `gainsParticipant.*` | ~100 | | | | Earnings (career, year, victories). |
| `driverChange` | 100 | | | | **Late driver or jockey change.** Answers the brief's "model is blind to last-minute driver change" point. |
| `oeilleres` | 100 | | | | Blinkers. |
| `deferre` | 25 | 0 | 51 / 60 | 0 | Unshod: a strong trot signal. Missing means shod. |
| `handicapPoids` | 75 | 100 | 0 / 95 | 100 | Weight in tenths of kg. |
| `handicapValeur` | 28 | 58 | 0 | 45 | Official handicap rating. |
| `handicapDistance` | 45 | 0 | 100 / 100 | 0 | Trot start distance (handicap). |
| `placeCorde` | 30 | 100 | 40 / 0 | 0 | Stall or draw. |
| `poidsConditionMonte` | 14 | 19 | 0 | 29 | Weight after the jockey's allowance. |
| `avisEntraineur` | 20 | 0 | 49 / 40 | 0 | **Trainer's opinion** (POSITIF / NEUTRE / NEGATIF), trot only, since 2022 (46%). Never read today. |
| `indicateurInedit`, `jumentPleine`, `engagement`, `supplement` | 100 | | | | Flags. |
| `nomPereMere`, `eleveur`, `paysEntrainement` | 22–87 | | | | Pedigree and origin, uneven. |
| `dernierRapportReference.*` | 89 | 87 | 95 / 91 | 84 | **Odds about 30 minutes before the start** (median −30 min since 2018, −59 min in 2014–17). Also `favoris`, `grossePrise` and `nombreIndicateurTendance`. |

### Known only after the race (labels or forbidden features)

| Field | Fill | Notes |
|---|---|---|
| `ordreArrivee` | 81 | Missing when the horse did not finish. |
| `incident` | 19 | DAI, ARRETE, TOMBE… |
| `tempsObtenu`, `reductionKilometrique` | 83 / 70 trot | Race time. Useful **as history** for later races, never for this one. |
| `distanceChevalPrecedent` | 88 flat, 65 jumps | Beaten margin. Same rule as race time. |
| `commentaireApresCourse` | 2 (8 in 2025–26) | Post-race comment. |
| `dernierRapportDirect.*` | 93 | **Closing odds**: timestamp at median +1–2 min after the scheduled start. This is the market benchmark for evaluation. It is not available when a prediction is made earlier. |

## 4. PMU turfinfo: past performances (`performances-detaillees`)

- **Depth.** Median **5** past races per horse, p90 and max **10**. This is deeper than the "capped at 5" assumed in the back-office brief.
- **Availability.** Not available for some 2014–2015 dates (HTTP 204).
- **Fill rates of the past-race fields:**

| Field | Fill | Notes |
|---|---|---|
| `date`, `hippodrome`, `discipline`, `distance`, `nbParticipants`, `nomPrix` | 100 | |
| `allocation` | 98 | |
| `tempsDuPremier` | 91 | Winner's time. |
| `place.statusArrivee` | 100 | PLACE, NON_PLACE, DISQUALIFIE… |
| `place.place` | 85 | Missing when the horse was not placed (NON_PLACE, imputed since commit `0bf26f1`). |
| `etatTerrain` | **HAIE 94–99, PLAT 95–97, STEEPLE 86–100, CROSS 64; ATTELE 0–1, MONTE 0** | Galop only. |
| `nomJockey` | 99 | |
| `poidsJockey` | 73 | |
| `oeillere` | 72 | Declining in recent years. |
| `distanceAvecPrecedent` | 42 | |
| `reductionKilometrique` | 17 (46 in 2025–26) | Trot speed in past races. The best trot form signal, improving over time. |
| `distanceParcourue` | 29 | |
| `participants[]` (other runners) | 100 | The full field of each past race, with places. Enables opponent-strength features. |

## 5. Answers to open questions

| Question (source) | Answer |
|---|---|
| Can we train a model on the ~6,000 open-pmu races? | **No.** Quinté only, finishers only. |
| Is the race-day going available? (back-office brief: "source not yet located") | **Yes**, `programme…penetrometre`: 98% galop, ~10% trot. Already read since `a23c0c4`. |
| Online `client/1` vs offline `client/61` parity (back-office brief) | **Identical** fields on 14 races. |
| What are the open-pmu `cotes`? | `[earlier snapshot, earlier snapshot, closing odds]`. Index 2 matches PMU direct odds in 82% of cases. |
| Which odds are the market benchmark? | `dernierRapportDirect` (closing). |
| Which odds can a prediction made 30 minutes out use? | `dernierRapportReference`, or our own snapshots. |
| Is "past-race going ≥ 95%" achievable? | Yes for galop. Not applicable to trot. |

## 6. Recommendations

1. **Rebuild the history from turfinfo, not open-pmu.**
   - **Labels and full field.** Walk the `programme` → `participants` endpoints day by day, for every French race since 2014. That gives every runner with its result and odds. About 46 races per day × ~4,300 days ≈ **200,000 races**, versus 6,000 biased ones today.
   - **Horse history.** Use the runner rows above, plus `performances-detaillees` where they extend the field.
   - **Rate.** At the current 1 request per second, a full backfill takes several days. It has to be throttled and resumable, and it raises the legal risk already documented in the parent brief.
2. **Stop using open-pmu for horse histories.** Its rows add only good runs. Remove or flag the rows already backfilled, then measure the engine again.
3. **Enforce a before/after split at the feature layer.** Write down the post-race list above and reject those fields in feature building, with a test.
4. **Snapshot odds ourselves.** Take snapshots at H-60, H-30, H-10 and H-2, and keep `dernierRapportDirect` after the start as the closing benchmark. Every logged prediction stores which snapshot it used.
5. **Make gap detection discipline-aware.** Going, weight, draw and handicap fields are empty by design in some disciplines (tables above). They are not gaps for the back-office.
6. **Fields that are available but unused, worth testing first:** `driverChange`, `avisEntraineur`, `deferre`, `handicapValeur`, `reductionKilometrique` (past races), past-race `participants[]` (opponent strength) and the odds movement between the reference and the snapshots.
