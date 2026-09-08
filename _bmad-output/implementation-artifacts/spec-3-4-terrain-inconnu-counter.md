---
title: 'Fiche cheval: visible "X/6 performances avec terrain inconnu" counter (FR-5)'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md']
baseline_commit: '60e72579e0d0a6c0e0e2d1f7f1e0c1f6b1f7a1e1'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `horse_edit_screen.dart` lets a user leave a performance row's terrain unset (the engine correctly treats it as neutral, `computeNote`), but nothing on screen tells the user how many of the six rows are missing terrain — the uncertainty is silently absorbed rather than surfaced, contradicting FR-5 and EXPERIENCE.md's transparency discipline (already applied to FR-4's labels via `transparency_label.dart`).

**Approach:** A small computed counter on `_HorseEditScreenState`, `X/6 performances avec terrain inconnu`, always visible under the performance list (not conditional on being > 0 — "silence = signal" only applies to the FR-4 badges, this counter is a permanent fixture per EXPERIENCE.md line 93). A row only counts as "entered" (and thus eligible to be missing terrain) if it has a rang, partants, or incident — a genuinely blank/untouched row is not a "terrain inconnu" case, it's simply not data yet.

## Boundaries & Constraints

**Always:**
- Counter text is exactly `'$n/6 performances avec terrain inconnu'`, always rendered (never hidden at 0).
- A row counts as "entered" via `_isEntered(p)`: `rang != null || partants > 0 || incident != null`. Only entered rows with `terrain == null` count toward the numerator.
- Denominator is always literally 6 (the fixed number of performance rows on this screen), not `_perfs.length`.

**Never:**
- Do not touch `transparency_label.dart`, `horse_card.dart`, or `results_screen.dart` — this is a `horse_edit_screen.dart`-only counter, unrelated to the FR-4 labels.
- Do not touch anything under `backend/`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| New horse, nothing entered | All 6 rows blank | `0/6 performances avec terrain inconnu` | N/A |
| Blank row (never touched) | `rang=null, partants=0, incident=null, terrain=null` | Does not count (not "entered") | N/A |
| Entered row, terrain set | `rang=3, terrain=1.0` | Does not count | N/A |
| Entered row, terrain unset | `rang=3, terrain=null` | Counts toward numerator | N/A |
| Entered via incident only | `incident='NR', rang=null, partants=0, terrain=null` | Counts as entered + terrain inconnu | N/A |

</frozen-after-approval>

## Code Map

- `mobile/lib/screens/horse_edit_screen.dart` -- MODIFY -- `_isEntered(Performance)`, `_terrainInconnuCount` getter, one `Text` widget under the performance list
- `mobile/test/screens/horse_edit_screen_test.dart` -- NEW -- widget-level coverage of the I/O matrix

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/screens/horse_edit_screen.dart` -- add counter -- closes the FR-5 transparency gap
- [x] `mobile/test/screens/horse_edit_screen_test.dart` -- widget tests -- covers the I/O matrix

**Acceptance Criteria:**
- Given a new horse with all rows blank, when `HorseEditScreen` renders, then it shows `0/6 performances avec terrain inconnu`.
- Given a row with a rang entered but no terrain, when the screen renders, then the counter includes that row.
- Given a fully blank row (never touched), when the screen renders, then it is never counted.

## Verification

**Commands actually run:**
- `cd mobile && flutter test` → **45/45 passed** (previous 41 + 4 new `horse_edit_screen_test.dart` cases), independently re-run and confirmed after the implementing agent's own run was interrupted (600s stall on the review-dispatch step, unrelated infrastructure issue — the code itself was already complete and untouched since).
- `cd mobile && flutter analyze` → **"No issues found!"**, independently re-run and confirmed.
- The implementing agent's own multi-lens review (blind-hunter dispatch) did not complete before the stall; given the change's small size (11 lines in one file + one focused test file), it was verified directly here by reading the full diff and running the real test/analyze commands rather than re-dispatching review subagents.
