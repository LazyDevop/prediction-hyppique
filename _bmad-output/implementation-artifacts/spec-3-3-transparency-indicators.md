---
title: 'Complete FR-4 transparency indicators on partants list and results screen'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md', '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/DESIGN.md']
baseline_commit: 'c39b44a435d9965a4c55494c54717e56775fb29d'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-4's three fixed transparency labels ("🐎 Inédit" / "Données non saisies" / "Historique court (N)") are implemented twice, independently, and both copies are wrong. `mobile/lib/widgets/horse_card.dart` uses the wrong emoji ("🆕" instead of "🐎") and has no "Historique court" state at all. `mobile/lib/screens/results_screen.dart` has its own private `_regularite()` with a different, unjustified threshold (`nbPerfs < 3`) and fabricates a "Régulier" label for full-history horses — a régularité gradient whose formula is undefined in every available source (cahier, prototypes, backend). FR-4 and EXPERIENCE.md are explicit that these three labels are never confused, merged, or silently dropped.

**Approach:** Extract one shared pure function as the single source of truth for the three FR-4 labels, consumed by both `horse_card.dart` (pre-calculation, raw `performances.length`) and `results_screen.dart` (post-calculation, engine-computed `Horse.nbPerfs`). Full history (the engine's real recency window, `recenceStd.length` = 6) returns no label — "silence = signal" per EXPERIENCE.md — rather than inventing an unspecified régularité value.

## Boundaries & Constraints

**Always:**
- One shared function, `transparencyLabel(Horse horse, int nbPerfs)` in a new file, is the only place the three label strings and the threshold are written — both call sites delegate to it, never re-derive it.
- Exact fixed strings only: `'🐎 Inédit'`, `'Données non saisies'`, `'Historique court ($nbPerfs)'` — never reworded.
- `horse.inedit == true` always wins over performance count, even if stray performance rows exist.
- The "full history" threshold is `recenceStd.length` (from `mobile/lib/engine/constants.dart`, currently 6) — read from that constant, never a second hardcoded number, so the two can never drift apart again.
- `horse_card.dart` passes `horse.performances.length` (raw count, correct pre-calculation since `Horse.nbPerfs` is always 0 before `analyseCourse` runs); `results_screen.dart` passes `h.nbPerfs` (NR-filtered, set by the engine) — never swapped.
- When the function returns `null` (full history), the caller shows no transparency badge/text for that horse — never a fabricated régularité word.

**Ask First:** None — no decision here requires human gating beyond the standard checkpoint.

**Never:**
- Do not implement the régularité gradient ("Très régulier"/"Régulier"/"Moyen"/"Irrégulier", EXPERIENCE.md/DESIGN.md `regularity-indicator`) — its formula is not defined anywhere in the cahier, the two prototypes, or the backend; log it to `deferred-work.md` instead of guessing.
- Do not implement FR-5's "terrain inconnu counter" (fiche cheval) — separate story.
- Do not touch anything under `backend/`.
- Do not modify `horse.dart`, `performance.dart`, `race_config.dart`, `engine_params.dart`, `scoring.dart`, `harville.dart`, `combinatoire.dart`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Inédit flagged | `inedit=true`, `performances=[]` | `'🐎 Inédit'` | N/A |
| Inédit with stray perf rows | `inedit=true`, `nbPerfs=2` | `'🐎 Inédit'` (priority over count) | N/A |
| No data entered | `inedit=false`, `nbPerfs=0` | `'Données non saisies'` | N/A |
| Partial history, list screen | `inedit=false`, `performances.length=3` | `'Historique court (3)'` | N/A |
| Partial history, results screen | `inedit=false`, `h.nbPerfs=2` (post-engine) | `'Historique court (2)'` | N/A |
| Full history | `inedit=false`, `nbPerfs=6` | `null` → caller shows no badge | N/A |
| Over-full (defensive) | `inedit=false`, `nbPerfs=7` | `null` → no badge, never throws | N/A |

</frozen-after-approval>

## Code Map

- `mobile/lib/widgets/transparency_label.dart` -- NEW -- `String? transparencyLabel(Horse, int nbPerfs)`, single source of truth, reads `recenceStd.length` from `engine/constants.dart`
- `mobile/lib/widgets/horse_card.dart` -- MODIFY lines 14-18 (`sousTitre` ternary) -- delegate to `transparencyLabel(horse, horse.performances.length)`, fallback `'${horse.performances.length} perf(s)'` when null
- `mobile/lib/screens/results_screen.dart` -- MODIFY `_regularite()` (lines 14-19) and its call site (line 130) -- delegate to `transparencyLabel(h, h.nbPerfs)`, append `' · $label'` only when non-null, delete the dead private method
- `mobile/lib/engine/constants.dart` -- READ-ONLY -- `recenceStd` (length 6) is the engine's real recency window, reused as the single threshold source
- `mobile/lib/models/horse.dart` -- READ-ONLY -- `inedit`, `performances`, `nbPerfs` fields consumed, not modified
- `mobile/test/widget_test.dart` -- READ-ONLY, must keep passing unmodified -- existing e2e adds a 0-performance horse ("Foudre Noire")
- `mobile/test/widgets/transparency_label_test.dart` -- NEW -- unit coverage for the I/O matrix
- `mobile/test/widgets/horse_card_test.dart` -- NEW -- widget-level regression coverage (none existed before)
- `_bmad-output/implementation-artifacts/deferred-work.md` -- APPEND -- log the undefined régularité gradient formula as follow-up work

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/widgets/transparency_label.dart` -- create shared function -- closes the emoji/threshold divergence between the two call sites
- [x] `mobile/lib/widgets/horse_card.dart` -- delegate subtitle logic to it -- fixes wrong emoji, adds missing "Historique court" state
- [x] `mobile/lib/screens/results_screen.dart` -- delegate `_regularite` to it -- removes the fabricated "Régulier" label and the wrong `< 3` threshold
- [x] `mobile/test/widgets/transparency_label_test.dart` -- unit tests -- covers every I/O matrix row
- [x] `mobile/test/widgets/horse_card_test.dart` -- widget tests -- pumps `HorseCard` for the inédit/vide/court/complet states
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- append one entry -- régularité gradient formula, deferred

**Acceptance Criteria:**
- Given `Horse(inedit: true, performances: [p1, p2])`, when `HorseCard` renders, then its subtitle contains `'🐎 Inédit'`, not a performance count.
- Given `Horse(inedit: false)` with 3 raw performances entered, when `HorseCard` renders, then its subtitle contains `'Historique court (3)'`.
- Given a post-`analyseCourse` `Horse` with `nbPerfs == 6`, when `ResultsScreen` renders its card, then no transparency badge text is appended after the perf count.
- Given the existing `mobile/test/widget_test.dart` end-to-end flow, when run unmodified, it still passes.

## Design Notes

`docs/cahier_des_charges_app_mobile.md` §7.3 says "les 5 dernières performances", but the real engine window is 6 (`recenceStd`/`recenceForme`/`recenceFlat` in both `mobile/lib/engine/constants.dart` and `backend/app/engine/constants.py`, and `horse_edit_screen.dart` already loops 6 performance rows). Per AD-2, the backend/engine constants are the source of truth; the cahier's "5" is a stale doc inconsistency, not followed here.

`Horse.nbPerfs` is 0 for every horse until `analyseCourse` runs (it's a computed field, not raw input) — that's why `horse_card.dart` (rendered before any calculation) must count `performances.length` directly rather than `nbPerfs`, while `results_screen.dart` (rendered only after `resultsProvider.calculer()`) correctly uses the engine's NR-filtered `nbPerfs`.

## Verification

**Commands actually run:**
- `cd mobile && flutter test` → **28/28 passed**, including the new `transparency_label_test.dart`/`horse_card_test.dart` suites and the unmodified `widget_test.dart` e2e flow.
- `cd mobile && flutter analyze` → **"No issues found!"**
- The implementation agent's own multi-lens review (adversarial/edge-case/verification-gap, dispatched per `bmad-build`'s standard review step) was interrupted mid-run by an infrastructure error (API connection drop, unrelated to this code) before it could report back. Verification above was completed independently afterward by re-running the real test/analyze commands and reading the diff directly — not a substitute for the multi-lens review, but the diff is small (2 files modified, 3 new files, all shown in Suggested Review Order below) and was read in full.
