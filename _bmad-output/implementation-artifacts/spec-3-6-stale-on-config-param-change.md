---
title: 'Mark results stale on race config / engine param changes too (FR-13/FR-6 follow-up)'
type: 'bugfix'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/implementation-artifacts/spec-3-3-mandatory-recalc-on-removal.md']
baseline_commit: '507536a'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 3.3 (`spec-3-3-mandatory-recalc-on-removal.md`) made `HorsesNotifier`'s three roster mutations mark `resultsProvider` stale, but explicitly deferred the same treatment for `raceConfigProvider`/`engineParamsProvider` (logged in `deferred-work.md`, "PRODUCT-RELEVANT" entry). Today, changing terrain/niveau/distance on `race_config_screen.dart`, or any engine parameter (bankroll, Kelly fraction, récence, k, sensibilité poids, âges, shrink, coef inédit, malus incident) on `settings_screen.dart`, after a calculation already ran, leaves `isStale` at `false` — the results screen keeps showing a ranking computed against inputs that no longer match, with zero visual signal. Same "silently obsolete" failure FR-6 exists to prevent, just a different trigger.

**Approach:** `RaceConfigNotifier.update()` and `EngineParamsNotifier.update()` each call `resultsProvider.notifier.markStale()`, mirroring `HorsesNotifier`'s three mutations exactly — single centralized call site per notifier, no screen wiring needed (both screens already funnel through these notifiers' `update()`).

## Boundaries & Constraints

**Always:**
- `RaceConfigNotifier.update()` and `EngineParamsNotifier.update()` call `ref.read(resultsProvider.notifier).markStale()` after setting state — same as `HorsesNotifier.add/replaceAt/removeAt`.
- `markStale()` itself is unchanged (already a no-op when `state == null` or already stale) — this story only adds call sites, never touches its logic.

**Never:**
- Do not touch `HorsesNotifier`, `ResultsNotifier`, or the stale banner UI (`results_screen.dart`) — all already correct from Story 3.3.
- Do not add a new "config changed" visual distinct from the existing stale banner — same banner, same message, any staleness cause.
- Do not touch anything under `backend/`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Edit config, no prior result | `resultsProvider.state == null`, `raceConfigProvider.update(...)` | `markStale()` no-ops, state stays `null` | N/A |
| Edit config, result exists | Result exists, `raceConfigProvider.update(...)` | `isStale: true` | N/A |
| Edit engine param, result exists | Result exists, `engineParamsProvider.update(...)` | `isStale: true` | N/A |
| New course loaded (`home_screen._selectCourse`) | `horsesProvider.clear()` (→ `resultsProvider.clear()`, state null) then `raceConfigProvider.update(...)` | `markStale()` no-ops (state already null) — no false-positive banner for a brand new course | N/A |

</frozen-after-approval>

## Code Map

- `mobile/lib/providers/race_provider.dart` -- MODIFY -- `update()` calls `markStale()`
- `mobile/lib/providers/params_provider.dart` -- MODIFY -- `update()` calls `markStale()`
- `mobile/test/providers/horses_provider_test.dart` -- pattern reference (not modified) for the new test file's style
- `mobile/test/providers/race_and_params_provider_test.dart` -- NEW -- I/O matrix coverage
- `mobile/test/widget_test.dart` -- READ-ONLY, must keep passing unmodified

## Tasks & Acceptance

**Execution:**
- [x] `race_provider.dart` -- `update()` marks stale
- [x] `params_provider.dart` -- `update()` marks stale
- [x] `race_and_params_provider_test.dart` -- covers the I/O matrix, including the new-course no-false-positive case

**Acceptance Criteria:**
- Given a computed result and a `raceConfigProvider.update(...)` call, when `ResultsScreen` rebuilds, then the stale banner shows.
- Given a computed result and an `engineParamsProvider.update(...)` call, then the stale banner shows.
- Given `home_screen._selectCourse`'s full sequence (clear → add horses → update config), then no stale banner appears (state is null throughout).
- Given `widget_test.dart`, when run unmodified, it still passes.

## Verification

**Commands actually run:**
- `cd mobile && flutter test` → **57/57 passed** (52 baseline + 5 new).
- `cd mobile && flutter analyze` → **"No issues found!"**
