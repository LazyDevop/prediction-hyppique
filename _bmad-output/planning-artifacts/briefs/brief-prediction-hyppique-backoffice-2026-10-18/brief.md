---
title: "Product Brief: Data-Completion Back-Office"
status: final
created: 2026-10-18
updated: 2026-10-20
inputs:
  - "Cahier des charges back-office de complétion des données, v2 (18/10/2026)"
  - "Local database measurement, races of 18–19/10/2026 (113 races, 1,433 runners, 6,014 past performances)"
  - "Prediction-vs-result measurement, local database, 19/10/2026 (72 replayed races, 40 live races)"
  - "Empirical API field inventory, 20/10/2026 (29 dates 2014–2026, 1,898 runners): ../../research/api-field-inventory-2026-10-20/inventory.md"
parent_brief: "../brief-prediction-hyppique-2026-08-17/brief.md"
---

# Product Brief: Data-Completion Back-Office

## Executive Summary

The Analyseur Hippique turns PMU race data into win probabilities, value against the odds, and ranked bet combinations. Its predictions are only as good as the data fed into them, and today that data has holes. When the team fills those holes by hand, the predictions look markedly better.

This brief proposes a **data-completion system** to make that improvement systematic and provable. It has four parts: fix the gaps the system creates itself, including a historical dataset that only kept good runs; fill automatically what can be fetched; route the remaining gaps to human data-entry agents through a back-office; and **measure**, race by race, whether predictions beat the market.

Measurement shapes the whole design. The claim "more complete data gives better predictions" is the product's promise to users and to a future investor. Today it rests on an impression, and the first measurement is sobering. On 72 replayed races, the engine's log-loss equals that of a uniform guess. The market's closing odds do clearly better. The first deliverables are therefore the instrument that turns the claim into evidence and a clean historical dataset. The agent back-office is sized from what that evidence shows, not before.

## The Problem

Predictions are computed even when key inputs are missing. The engine then quietly treats the missing value as neutral or as zero, and nothing tells the user that the prediction rests on partial data.

A measurement on the local database (races of 18–19 October 2026), checked against an inventory of real API responses from 2014 to 2026, shows that the gaps have **different causes**. Most of them do not need human data entry:

| Gap | Rate | Real cause | Right fix | Status (20/10) |
|---|---|---|---|---|
| Going (terrain) of past races | 100% | The PMU API provides `etatTerrain` for **galop** races (86–100% filled). It is **absent by design for trot** (0–1%). Our ingestion did not read it. | **Code fix** (galop); trot: not a gap | Fixed (`1f27af3`) |
| Rank in past races | 22% | Finishers outside the displayed places (`NON_PLACE`) were scored **0**, the same as a last-place finish. | **Engine rule**, then agent review of ambiguous cases | Fixed (`0bf26f1`) |
| Going on race day | 100% | The API provides it in `penetrometre`: 98% for galop, about 10% for trot. | **Code fix** (galop); trot: not a gap | Fixed (`a23c0c4`) |
| Horse history | 332 of 1,339 horses had fewer than 5 races | `performances-detaillees` returns up to **10** past races (median 5). The deep backfill came from **open-pmu-api, which only covers the daily Quinté+ and its ~7 finishers**, so it added only a horse's good runs. | **Purge the open-pmu rows**; rebuild **5 years** of history from the PMU turfinfo API (every runner of every French race) | Purge job ready; rebuild to build |
| Weight | 69% | 97% of these are trotting races, where weight does not apply. Flat and jumps: 0% missing. | **None.** Detection must know the discipline. | — |
| Odds | 74% | Odds were captured in the morning. The API exposes reference odds about **30 minutes before** the start, and closing odds (`dernierRapportDirect`, timestamped 1–2 minutes after the start). | **Timed snapshots** before each race, never typed by hand | To build |

*Sample limits: two days of French meetings for the gap rates; one or two dates per year for the inventory. Full fill rates per discipline and period are in the inventory.*

**What this means:**
- The back-office remains useful, but as a **residual** layer: ambiguous ranks, Multi-specific press content, and fields the inventory shows the API lacks. Building it before fixing the cheap causes would pay humans to re-type data the API already sends.
- Gap detection must treat a field that is empty by design for a discipline (going, weight, draw for trot) as **not applicable**, not as a gap.
- Several fields the API sends are not read today and should be tested before any manual entry: `driverChange` (late driver change), `avisEntraineur` (trainer's opinion, trot), `deferre` (unshod), `handicapValeur`, past-race `reductionKilometrique`.

## The Solution

Four layers, delivered in this order:

1. **Fix self-inflicted gaps.** Ingest the going and normalize it to the engine's scale (done). Separate "unplaced" from "unknown rank" in scoring (done). **Purge the open-pmu history rows**, which only keep good runs. Make gap detection aware of discipline and race timing.
2. **Complete automatically.**
   - **Rebuild 5 years of history** from the PMU turfinfo API: every runner of every French race (about 80,000 races) with result, reference and closing odds. Throttled and resumable.
   - **Snapshot odds** at fixed times before each start (H-60, H-30, H-10, H-2) and keep the closing odds after it.
   - Store each snapshot with its timestamp, never overwriting.
3. **Measure.** Build a **prediction-versus-result dashboard** (in place since 19/10). Every prediction is logged before the race with the data it used, then compared with the official result pulled from the API.
   - It shows hit/miss rates, calibration (Brier score / log-loss), and a split between complete and degraded data.
   - It must also show the **market benchmark**: log-loss and Brier of the closing odds on the same races. Each prediction records which odds snapshot it used.
   - It runs the "API only" vs "API + manual" comparison described in cahier §9.
4. **Complete by hand, for what remains.** The agent back-office:
   - an automatic gap queue, prioritized by time to start;
   - an entry screen with a mandatory source and a confidence level, and a "not found" answer;
   - reviewer validation and a time lock before the start.

   Manual data is stored separately and never overwrites official data. Every prediction states its completeness and is flagged *degraded* when a critical field is missing.

Detailed mechanics (field catalog, merge rules, roles, data model, endpoints) are in the cahier v2 and summarized in the [addendum](addendum.md).

## Who This Serves

- **End users (bettors).** They get predictions that say how complete their data is, instead of looking equally confident whether the data is full or partial. Today there is one test user. Usage cannot be measured yet because there are no user accounts.
- **Data-entry agents (to be recruited, 2 at start).** They need a queue that tells them what to fill and by when, clear source guidance, and the right to say "not found" without being penalized.
- **The founder (reviewer / admin at start).** Needs the dashboard to know whether the product works, to decide where agent effort pays off, and to show evidence to an investor.

## Success Criteria (3 months)

- **Dashboard live**: 100% of predictions on French races are logged before the start and matched with official results. Hit/miss rates, calibration and the **closing-odds benchmark** are visible per day and per race type.
- **Self-inflicted gaps closed**:
  - past-race going at least 95% filled for **galop** races, with trot treated as not applicable;
  - zero `NON_PLACE` ranks scored as last place;
  - zero open-pmu rows in horse histories.
- **Clean history**: 5 years of French races rebuilt from the PMU API, every runner included, with reference and closing odds.
- **Fresh odds**: at least 95% of live predictions use an odds snapshot taken within 30 minutes of the start.
- **Evidence for manual entry**: at least one month of paired "API only" vs "API + manual" predictions, with a confidence interval on the difference. `[ASSUMPTION]` The volume of races needed is set after a pilot that measures variance; no effect threshold is fixed in advance.
- **Agent pilot**: 2 agents operating on pre-race windows. Throughput, rejection rate and time per field are recorded, so the team size decision rests on data.

## Scope

**In V1:**
- ingestion fixes, including the open-pmu purge;
- the 5-year history rebuild from the PMU API;
- odds snapshots before each race;
- discipline-aware gap report and gap detection;
- prediction logging and the results dashboard with a market benchmark;
- completeness flags in the app;
- a minimal agent back-office (queue, entry, review, time lock, audit log).

**Out of V1:**
- foreign meetings (the product covers French races only, per the parent brief);
- agent pay and payroll;
- mobile app for agents;
- offline entry;
- automated scraping of third-party sites;
- machine-learned prioritization;
- vision-assisted entry (V1.1);
- replacing the scoring engine. A model trained on the rebuilt history is a separate decision, taken after the dashboard shows whether the current engine adds anything to the market.

**Staffing reality.** Two agents cannot cover 24/7, which takes about 4–5 full-time people. French races run roughly 11:00–22:00 Paris time, and useful entry happens **before** the start. Two agents on staggered shifts covering the evening before and the morning of race day (Cameroon time) likely cover the real need. `[ASSUMPTION]` To confirm with the gap report's volume.

## Risks and Open Questions

- **The core claim is unproven.** "Much more valid" comes from races the team filled by hand; the number of races and the fields involved were not recorded. On the first 72 replayed races, the engine did no better than a uniform guess, and the market did clearly better. The dashboard, with a market benchmark, settles whether completeness or the engine itself is the bottleneck.
- **Biased history.** The ~6,000 races backfilled from open-pmu-api are Quinté+ races with finishers only. They must be purged from the server database before any further measurement, and they must never be used to train a model. The mobile "full history" button still calls the open-pmu backfill. Until it is redirected or disabled, it adds biased rows again.
- **Data access and volume.** Everything rests on the PMU turfinfo API, which is not authorised (see the parent brief). Rebuilding 5 years of history means about 80,000 race calls plus their programmes. That volume makes the existing legal and blocking risk more concrete, so the rebuild must be throttled and resumable. The `online/client/1` and `offline/client/61` endpoints return identical fields (verified on 14 races), so this question is closed.
- **No user accounts.** Usage of the end-user app cannot be measured, which weakens any launch or investor story. This is a separate dependency, but a blocking one before launch.
- **Legal (Cameroon).** Agent contracts, personal data of agents, and the terms of use of every source agents consult. An approved list of sources is needed before training.
- **Agent cost.** No pay rate yet. The cost per field entered, compared with its measured gain, decides whether manual entry is worth it.

## Vision

If the measurement shows that completeness drives accuracy, the product gains something competitors' prose tips cannot offer: **published, auditable calibration**. Every prediction shows the data it used, how it turned out, and how it compared with the market. The agent team then becomes a targeted quality function focused on the fields proven to matter, and its track record becomes the core of the launch and investor story.
