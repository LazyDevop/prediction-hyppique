---
title: 'Reconstruct corrupted mobile scoring engine and race config screen'
type: 'bugfix'
created: '2026-09-07'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/docs/cahier_des_charges_app_mobile.md', '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md']
baseline_commit: '4889c5a1aa635d9dff53b6e2a7710ce6e8a7bca4'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `mobile/lib/engine/scoring.dart`, `mobile/test/engine/scoring_test.dart` and `mobile/lib/screens/race_config_screen.dart` contain only corrupted binary placeholder data (confirmed, one repeating block, zero recoverable information) since the repo's initial commit — the same failure shape already diagnosed and fixed on the backend (`spec-restore-backend-scoring-engine.md`). `scoring.dart` is the mobile port of the product's core differentiator; its absence blocks `mobile/test/engine/combinatoire_test.dart` (already intact, already calls `analyseCourse`) from compiling, and blocks the config→partants→résultats navigation chain.

**Approach:** Rebuild `scoring.dart` as a faithful Dart port of the already-validated Python engine (`backend/app/engine/scoring.py`, 53 tests passing), operating on the mobile's own intact model classes (`Horse`, `Performance`, `RaceConfig`, `EngineParams`) rather than re-declaring dataclasses, and reusing the intact `harville.dart` for Top1-4 instead of re-deriving that recursion. Rebuild `scoring_test.dart` on the shared AD-2 fixture (`fixtures/engine_cases.json`) plus hand-written structural tests mirroring the backend suite's edge-case coverage. Rebuild `race_config_screen.dart` per the UX spine (`EXPERIENCE.md` Information Architecture "Configuration course" + Component Patterns "Sélecteur de terrain groupé Gazon/PSF") and `mockups/configuration-course.html`, in the existing screen idiom (`ConsumerStatefulWidget` + `TextField`/`TextEditingController`, per `home_screen.dart`/`horse_edit_screen.dart`).

## Boundaries & Constraints

**Always:**
- Import coefficient tables from `mobile/lib/engine/constants.dart` — never redefine `terrainCoefficientsGazon/Psf`, `niveauCoefficients`, `incidents`, `recenceStd/Forme/Flat` in `scoring.dart`.
- Match every formula in cahier des charges §7, cross-checked line-by-line against the already-validated `backend/app/engine/scoring.py` (`compute_note`, `compute_forme`, `analyse_course`): distance/terrain/niveau coefficients, incident malus, Bayesian shrinkage, virtual outsiders, Plackett-Luce, value/Kelly. `dart:math.sqrt(x)`, never `(x).sqrt()` (cahier mobile §8 pitfall 4).
- NR performances (`Performance.isNr`, already on the intact model) are filtered out before `nbPerfs`/`forme` aggregation — never counted, never influence the average.
- Where either side of a ratio is `null` (`Performance.terrain`/`niveau` or `RaceConfig.terrain`/`niveau`), the coefficient is neutral (`1.0`) — never throws, never guesses.
- `analyseCourse(horses, target, {EngineParams params = const EngineParams()})` — no-args-beyond-target call uses the real `EngineParams()` defaults (mirrors backend's `DEFAULT_PARAMETERS` merge); a partial override via `params.copyWith(...)` changes only that field.
- `analyseCourse` returns `[...analyses, ...virtuels]` with `analyses` sorted by score descending and exactly `horses.length` long — `combinatoire.dart`'s `buildCombinaisons(results, horses.length)` (already intact, already tested) depends on this contract.
- `race_config_screen.dart`'s terrain picker groups options under "Gazon" / "PSF" headers (two separate `Map`s from `constants.dart`), never a flat merged list (EXPERIENCE.md Component Patterns).
- `niveauCoefficient(String? label)` (new, additive, in `constants.dart`) mirrors `terrainCoefficient()`'s null-passthrough shape but logs a distinct, named signal (`dart:developer.log(name: 'niveau_label_unrecognized')`) when given a non-null label absent from `niveauCoefficients` — AD-5: an unrecognized label is never silently folded into the same "neutral" path as a genuinely-absent one.

**Never:**
- Do not modify `combinatoire.dart`, `harville.dart`, `horse.dart`, `performance.dart`, `race_config.dart`, `engine_params.dart`, or `combinatoire_test.dart`'s call shape.
- Do not touch anything under `backend/` (read-only reference only — parallel work may be in progress there).
- Do not retrofit `terrainCoefficient()` with the same unrecognized-label logging as `niveauCoefficient()` — out of scope for this ticket (existing intact function), noted as a follow-up in Design Notes.
- Do not implement FR-3 "import à la demande" (course not yet in DB) inside `race_config_screen.dart` — per `EXPERIENCE.md` UJ-1 that already happens one screen earlier (Accueil), before `RaceConfigScreen` is ever pushed.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Terrain unknown | `Performance.terrain=null` or `RaceConfig.terrain=null` | `cTerr == 1.0`, no exception | N/A |
| Niveau unknown | `RaceConfig.niveau=null` or `Performance.niveau=null` | `cNiv == 1.0`, no exception | N/A |
| NR performance | Horse has 1 NR-incident perf + 1 normal perf | `nbPerfs == 1`, NR excluded from `forme` | N/A |
| No params override | `analyseCourse(horses, target)` (2-arg call) | Identical scores to `analyseCourse(horses, target, params: const EngineParams())` | N/A |
| Partial params override | `params: const EngineParams().copyWith(shrink: 10)` | Only shrink-driven spread changes; `bankroll`/`fractionKelly` stay default | N/A |
| Niveau label unrecognized | `niveauCoefficient('Groupe Zzz')` | Returns `null`, logs `niveau_label_unrecognized` (distinct from the null-input silent path) | N/A |
| Terrain picker opened | Configuration course screen | Bottom sheet with two headed groups (Gazon 10 entries, PSF 3 entries), never merged | N/A |
| Partants left blank | Config screen "Partants" field cleared | `RaceConfig.nbPartantsCourse = null` ("auto", resolved later against the real horse count) | N/A |

</frozen-after-approval>

## Code Map

- `mobile/lib/engine/scoring.dart` -- TO CREATE (corrupted) -- `computeNote`/`computeForme`/`analyseCourse`, Dart port of `backend/app/engine/scoring.py`
- `mobile/test/engine/scoring_test.dart` -- TO CREATE (corrupted) -- fixture-driven (`fixtures/engine_cases.json`, AD-2) + hand-written edge-case tests
- `mobile/lib/screens/race_config_screen.dart` -- TO CREATE (corrupted) -- Configuration course screen
- `mobile/lib/engine/constants.dart` -- ADDITIVE ONLY -- add `niveauCoefficient(String?)`, mirroring intact `terrainCoefficient()`
- `mobile/lib/engine/harville.dart` -- READ-ONLY consumer -- `computeHarville(champ)` called by `analyseCourse` for top1-4 (do not re-derive the recursion inline)
- `mobile/lib/engine/combinatoire.dart`, `mobile/test/engine/combinatoire_test.dart` -- READ-ONLY consumers -- pin `analyseCourse`'s exact call shape and real-then-virtual return contract
- `mobile/lib/models/horse.dart`, `performance.dart`, `race_config.dart`, `engine_params.dart` -- READ-ONLY -- data shapes `analyseCourse` operates on and clones (mutable computed fields, immutable identity fields)
- `mobile/lib/providers/race_provider.dart`, `params_provider.dart` -- READ-ONLY -- `raceConfigProvider`/`engineParamsProvider` wired into the screen
- `mobile/lib/screens/home_screen.dart` -- READ-ONLY caller -- prefills `raceConfigProvider` then pushes `RaceConfigScreen()`
- `mobile/lib/screens/horse_list_screen.dart` -- READ-ONLY callee -- `RaceConfigScreen` pushes here on confirm
- `fixtures/engine_cases.json`, `fixtures/engine_constants.json` -- READ-ONLY -- AD-2 shared parity fixtures
- `backend/app/engine/scoring.py`, `constants.py` -- READ-ONLY reference (do not modify anything under `backend/`)
- `docs/cahier_des_charges_backend_hippique.md` §7 -- formula reference
- `docs/cahier_des_charges_app_mobile.md` §7.2, §8 -- screen spec + pitfalls to avoid
- `_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/{EXPERIENCE.md,DESIGN.md,mockups/configuration-course.html}` -- UX behavior/visual reference
- `mobile/analysis_options.yaml` -- found corrupted the same way as the three in-scope files (not originally in this Code Map); regenerated as standard `flutter_lints` config via `flutter pub get`/`flutter create` scaffolding repair
- `mobile/test/widget_test.dart` -- pre-existing, READ then MODIFIED (2 lines) -- expected stale placeholder strings from before `EXPERIENCE.md` existed; updated to match actual screen text, not part of the original Code Map either

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/engine/constants.dart` -- add `niveauCoefficient(String? label)` mirroring `terrainCoefficient()`, plus the distinct unrecognized-label log signal -- closes the AD-5 gap flagged in the Architecture Spine
- [x] `mobile/lib/engine/scoring.dart` -- implement `computeNote`/`computeForme`/`analyseCourse` per cahier §7 and `scoring.py`, operating on `Horse`/`Performance`/`RaceConfig`/`EngineParams`, delegating Top1-4 to `harville.dart` -- restores the core engine
- [x] `mobile/test/engine/scoring_test.dart` -- fixture-driven DSL subset (assertion types actually used by the 6 cases in `fixtures/engine_cases.json`) + hand-written tests for the I/O matrix rows -- durable regression coverage, AD-2 parity
- [x] `mobile/lib/screens/race_config_screen.dart` -- rebuild per `EXPERIENCE.md`/mockup, wired to `raceConfigProvider`, pushing `HorseListScreen` -- restores the config→partants navigation chain

**Acceptance Criteria:**
- Given the 6 fixture cases in `fixtures/engine_cases.json`, when traced by hand (or run via a standalone Dart harness) through `analyseCourse`, all assertions hold.
- Given `Performance(partants: 10, terrain: null, ...)` and a non-null target, `computeNote` returns without throwing, using `cTerr = 1.0`.
- Given a horse with one NR-incident performance and one normal one, `analyseCourse` produces `nbPerfs == 1` for that horse.
- Given `race_config_screen.dart`, tapping the Terrain field opens a picker with two headed groups (Gazon, PSF), never one flat list.

## Spec Change Log

## Design Notes

`analyseCourse` clones each input `Horse` via its constructor (all identity fields are constructor params) rather than mutating the caller's list — `performances` is `final` on `Horse`, so the NR-filtered list can only be attached to a new instance, mirroring Python's `dataclasses.replace`. Computed fields (`nbPerfs`, `forme`, `cPoids`, `cAge`, `score`, `probabilite`, `top1-4`, `value`, `kelly`, `mise`) are then set via cascade on the clone. `EngineParams` already carries `modeRecence`, so unlike the Python signature there is no separate `mode_recence` argument — it is read from `params.modeRecence`.

Deferred, not in this ticket's scope: retrofitting `terrainCoefficient()` with the same unrecognized-label logging as `niveauCoefficient()` (existing intact function, both sides of the France Galop/PSF split); the fixture-DSL self-tests (`test_dsl_selection_actually_filters_not_vacuous`-equivalent) that the backend suite grew in later hardening stories — the DSL ported here covers exactly the assertion types the current 6 fixture cases use, not a general-purpose engine.

## Verification

**Commands actually run:**
- Mid-implementation, before a Flutter SDK was available: installed the standalone `Google.DartSDK` (winget — `Dart SDK version: 3.13.2`) and verified the engine files with `dart analyze` plus a temporary standalone harness (`_verify_manual.dart`, deleted before commit) driving all 6 `fixtures/engine_cases.json` cases through the real `analyseCourse`: **44/44 checks passed**, including cross-language parity against the same fixture that drives `backend/tests/test_scoring.py` (53 tests passing).
- A full Flutter SDK was subsequently installed (`git clone` to `C:\Users\lazyd\flutter`, channel stable 3.47.1) so `race_config_screen.dart` and `scoring_test.dart` (both depend on `package:flutter_test`/`flutter_riverpod`, unlike the pure-Dart engine files) could be verified for real rather than by manual reading alone.
- `cd mobile && flutter pub get` → succeeded (regenerated `pubspec.lock` and platform plugin-registrant scaffolding for linux/macos/windows; `analysis_options.yaml` was found to be corrupted the same way as the three files in scope and was regenerated as a standard `flutter_lints` config — noted here since it wasn't in the original Code Map).
- `flutter test` → **17/17 passed**, including all 13 tests in `scoring_test.dart` (fixture-driven + hand-written edge cases) and the pre-existing end-to-end `widget_test.dart`. One fix was needed after the first real run: `widget_test.dart` (pre-existing, not touched by this ticket's Code Map) expected placeholder strings `"Course cible"` / `"Suivant : les partants"` that predate the actual `EXPERIENCE.md`-driven copy; updated to the real screen text (`"Configuration course"` / `"Voir les partants"`, matching `mockups/configuration-course.html` and the AppBar/button as implemented) rather than changing the reviewed UX spine's wording to fit a stale placeholder.
- `flutter analyze` → 2 `unnecessary_late` info-level lints on top-level `late final` fixture loaders in `scoring_test.dart` (top-level finals are already lazily initialized in Dart); removed the redundant `late`. Re-ran: **"No issues found!"**
- This closes out the verification this spec's own Acceptance Criteria call for by actual compilation and test execution, not manual reading — stronger evidence than the engine-only Dart-SDK pass above.

## Suggested Review Order

**Core engine — per-performance formula (cahier des charges §7.5-7.6)**

- Entry point: the note formula for one past performance — distance/terrain/niveau coefficients, all three nullable-safe.
  [`scoring.dart`](../../mobile/lib/engine/scoring.dart)

- Recency-weighted average across a horse's last 6 performances; assumes NR already filtered by the caller.
  [`scoring.dart`](../../mobile/lib/engine/scoring.dart)

**Core engine — course-level orchestration (cahier des charges §7.7-7.11)**

- Full pipeline: NR filtering, Bayesian shrinkage, virtual outsiders, Plackett-Luce probabilities, delegation to `harville.dart`, value/Kelly.
  [`scoring.dart`](../../mobile/lib/engine/scoring.dart)

**AD-5 gap closure**

- `niveauCoefficient()` — new function, distinct unrecognized-label log signal.
  [`constants.dart`](../../mobile/lib/engine/constants.dart)

**Screen**

- Configuration course screen, grouped terrain picker, `raceConfigProvider` wiring.
  [`race_config_screen.dart`](../../mobile/lib/screens/race_config_screen.dart)

**Tests**

- Fixture-driven DSL + hand-written edge cases.
  [`scoring_test.dart`](../../mobile/test/engine/scoring_test.dart)
