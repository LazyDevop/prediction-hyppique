---
title: "Addendum: Data-Completion Back-Office"
created: 2026-10-18
updated: 2026-10-20
---

# Addendum — detail for the PRD and architecture

Source of truth for mechanics: *Cahier des charges — Back-office de complétion des données, v2 (18/10/2026)*. This addendum keeps the parts the brief summarizes, plus the measurement detail.

## A. Measurement detail (local DB, races of 18–19/10/2026)

| Table | Rows | Field | Empty / 0 |
|---|---|---|---|
| courses | 113 | terrain, niveau_estime | 100% |
| courses | 113 | corde | 20% |
| participations | 1,433 | poids | 69% (987 of 1,020 trotting runners; 0 in flat / jumps) |
| participations | 1,433 | cote_direct / cote_reference | 74% (race day 379/876 present; D+1 0/557) |
| performances_historiques | 6,014 | terrain | 100% |
| performances_historiques | 6,014 | rang | 22% (1,353 rows, no incident recorded) |
| performances_historiques | 6,014 | allocation | 0.3% |

- History depth for non-maiden horses: 1,007 with 5 races, 332 with fewer (2 with none). 94 maidens (`inedit`).
- Code locations: `pmu_client.get_historique` never reads `etatTerrain`; `scoring.py` sets `sb = 0.0` when `rang` is None.

## B. Mechanics retained from the cahier v2

- **Field catalog** (admin-editable, versioned): entity, type, bounds, tier (critical / important / optional), `used_by`, `api_path`, `entry_mode` (surveillance / saisie / capture_horodatee / controle), normalizer, observed coverage, source hints.
- **Gap causes**: `key_absent`, `null_or_empty`, `suspect_zero`, `unrecognized_label`, `short_history`, `expected_later` (not counted before the start). Detection conditioned on country, discipline, race status.
- **Merge rule**: a single `effective_value(entity, field, as_of)` read layer. API > validated manual > (pending manual only if `use_unvalidated`) > NULL + degraded. Divergence opens a conflict when the field is API-authoritative. No silent resolution.
- **Roles**: `agent_saisie`, `relecteur`, `admin`; a reviewer can never validate their own entry (DB constraint). 2FA. Append-only audit log.
- **Task lifecycle**: open → claimed (TTL) → entered → resolved_manual / rejected (reason required). Optimistic locking.
- **Priority**: time to start, then Multi / Quinté+ races, then count of critical gaps, then age.
- **Time lock**: at `t_start − T_lock` no entry feeds that race's prediction; later entries kept for history with `effective_from`.
- **Prediction logging**: `data_version` hash, `as_of`, completeness per tier as explicit fractions, `degraded`, variant `api_only` / `api_plus_manual`.
- **Evaluation**: paired comparison per race (log-loss / Brier, calibration), bootstrap CI, per-field ablation, temporal split, Holm correction. No effect threshold fixed in advance.
- **Odds**: never typed by hand. Preference: official endpoint → timestamped capture (`snapshot`) → manual with explicit warning.

## B2. Corrections from the API field inventory (20/10/2026)

Source: [inventory](../../research/api-field-inventory-2026-10-20/inventory.md).

- **Going is galop-only.** Past-race `etatTerrain` is filled for HAIE, PLAT and STEEPLE races (86–100%) and for 0–1% of ATTELE and MONTE races. Race-day `penetrometre` is filled for 98% of galop races and about 10% of trot races. For trot, a missing going has the `not_applicable` status and creates no task.
- **History depth.** `performances-detaillees` returns up to 10 past races (median 5), not a hard cap of 5. It is not available for some 2014–2015 dates (HTTP 204).
- **open-pmu-api.** Returns one race per date (the Quinté+) and details only the ~7 finishers, about 46% of runners. `cotes[2]` matches the PMU closing odds in 82% of cases. Purge: `python -m app.jobs.purge_open_pmu` (dry run), then `--executer`.
- **Odds semantics.**
  - `dernierRapportReference`: reference odds, median 30 minutes before the start (59 minutes in 2014–17).
  - `dernierRapportDirect`: closing odds, timestamped 1–2 minutes after the start. This is the market benchmark.
  - The closing-odds favourite wins 27% of 154 sampled races.
- **Post-race fields** must never be features for the race itself: `ordreArrivee`, `incident`, `tempsObtenu`, `reductionKilometrique`, `distanceChevalPrecedent`, `commentaireApresCourse`, the closing odds, and race-level `ordreArrivee` and `dureeCourse`.
- **Endpoint parity.** The `online/client/1` and `offline/client/61` endpoints return identical participant fields on 14 races from 2025–26.

## C. Thresholds deliberately left open

`T_lock`, claim TTL, review sampling rate, alert sensitivity, team size, sample size for the evaluation — all calibrated during the pilot.
