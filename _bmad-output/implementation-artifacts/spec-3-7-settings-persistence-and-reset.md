---
title: 'Persist engine params across app restarts + reset-to-defaults action (FR-20)'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md']
baseline_commit: 'f2ea8f3'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `EngineParamsNotifier` (`params_provider.dart`) is a plain in-memory `Notifier` seeded with `const EngineParams()` on every `build()` — any customization is lost the moment the app restarts. FR-20 requires "réglages du moteur exposés et persistés ... réinitialisation aux valeurs par défaut en un geste"; neither durable persistence nor a reset action exists anywhere in `settings_screen.dart` today.

**Approach:** `shared_preferences` (the standard, lightweight Flutter solution for scalar key-value settings — SQLite/`DatabaseHelper` would be overkill for ten numeric/string fields) stores the params as one JSON string under a single key. `main()` becomes async, resolves `SharedPreferences.getInstance()` before `runApp`, and overrides a `sharedPreferencesProvider` so `EngineParamsNotifier.build()` can synchronously load any persisted value. `update()` persists on every call (same cadence as the existing per-keystroke `onChanged` wiring — see Design Notes for why "persist on blur" from EXPERIENCE.md's prose is not followed literally here). A new `reset()` method restores + persists `const EngineParams()`. `settings_screen.dart` gains a "Réinitialiser" action gated by a confirmation dialog (EXPERIENCE.md Component Patterns: "irréversible pour la session"), and its `TextEditingController`s resync via `ref.listen` when state changes from outside the field's own `onChanged` (i.e., after a reset or an externally-loaded value).

## Boundaries & Constraints

**Always:**
- One SharedPreferences key (`engine_params`), JSON-encoded — never one key per field (avoids a 10-key migration surface for a value object that only ever changes as a whole).
- `EngineParamsNotifier.build()` reads the persisted value synchronously via the overridden `sharedPreferencesProvider` (no `FutureProvider`/`AsyncNotifier` — keeps this provider's shape consistent with every other sync `Notifier` in this app, e.g. `RaceConfigNotifier`, `HorsesNotifier`).
- A malformed/missing/corrupt stored JSON value never throws — falls back to `const EngineParams()` silently (a stale settings blob is not worth crashing the app over).
- `reset()` restores `const EngineParams()`, persists it, and calls `resultsProvider.notifier.markStale()` — same discipline as `update()` (spec-3-6).
- `settings_screen.dart`'s "Réinitialiser" shows a confirmation dialog (`AlertDialog`, "Annuler"/"Réinitialiser") before calling `reset()` — never a bare irreversible tap.
- After `reset()` (or any external state change), the screen's `TextEditingController`s reflect the new values — verified via `ref.listen`, not assumed.

**Ask First:** None.

**Never:**
- Do not add SharedPreferences-backed persistence to any other provider (`raceConfigProvider`, `horsesProvider`) — out of scope, FR-20 is engine params only.
- Do not restructure the 8 `TextField`s' `onChanged`-per-keystroke pattern into blur/submit-based commits — see Design Notes for why persisting on every `onChanged` is accepted here instead.
- Do not touch anything under `backend/`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First-ever launch, no stored value | `SharedPreferences` has no `engine_params` key | `EngineParamsNotifier.build()` returns `const EngineParams()` | N/A |
| Restart after customization | `engine_params` holds a valid JSON blob from a prior `update()` | `build()` restores those exact values | N/A |
| Corrupted stored value | `engine_params` holds invalid JSON / wrong shape | `build()` falls back to `const EngineParams()`, never throws | N/A |
| `update()` called | Any field change | New state persisted to `SharedPreferences` before the call returns | N/A |
| `reset()` called, no prior result | `resultsProvider.state == null` | State back to defaults, persisted, `markStale()` no-ops | N/A |
| `reset()` called, result exists | Result exists | State back to defaults, persisted, `isStale: true` | N/A |
| Reset tapped in UI | User taps "Réinitialiser" | Confirmation dialog shown first; `reset()` only runs on confirm | N/A |
| Controllers after reset | `engineParamsProvider` state changes externally | All 8 `TextField`s' displayed text updates to match | N/A |

</frozen-after-approval>

## Code Map

- `mobile/pubspec.yaml` -- MODIFY -- add `shared_preferences` dependency
- `mobile/lib/providers/params_provider.dart` -- MODIFY -- `sharedPreferencesProvider`, JSON load in `build()`, persist in `update()`, new `reset()`
- `mobile/lib/models/engine_params.dart` -- MODIFY -- `toJson()`/`fromJson()` for the SharedPreferences blob
- `mobile/lib/main.dart` -- MODIFY -- async `main()`, resolve `SharedPreferences.getInstance()`, override before `runApp`
- `mobile/lib/screens/settings_screen.dart` -- MODIFY -- "Réinitialiser" action + confirmation dialog, `ref.listen` to resync controllers
- `mobile/test/providers/params_provider_test.dart` -- NEW -- I/O matrix coverage (SharedPreferences has an official in-memory test implementation, `SharedPreferences.setMockInitialValues`, no ffi/mocking needed)
- `mobile/test/widget_test.dart` -- MODIFY -- the original assumption that this file stays unaffected was wrong: it builds `PredictionHippiqueApp()` directly via `ProviderScope(child: ...)`, bypassing `main()`'s bootstrap entirely, so `EngineParamsNotifier.build()` hit `sharedPreferencesProvider`'s unoverridden `throw` the moment the e2e test reached the "Calculer" step. Added the same `setMockInitialValues({})` + override pattern as `main.dart`.
- `mobile/test/providers/horses_provider_test.dart`, `mobile/test/providers/race_and_params_provider_test.dart`, `mobile/test/widgets/results_screen_test.dart` -- MODIFY -- same root cause as above: each builds a bare `ProviderContainer()` and then calls `resultsProvider.notifier.calculer()` (or, for race_and_params, `engineParamsProvider` directly), which reads `engineParamsProvider` → `sharedPreferencesProvider`. All three needed the same mock-and-override addition; `horse_edit_screen_test.dart` did not (its screen never touches `engineParamsProvider`).

## Tasks & Acceptance

**Execution:**
- [x] `engine_params.dart` -- `toJson()`/`fromJson()`
- [x] `pubspec.yaml` -- add `shared_preferences`
- [x] `params_provider.dart` -- persistence + `reset()`
- [x] `main.dart` -- async bootstrap
- [x] `settings_screen.dart` -- reset action + confirmation + controller resync
- [x] `params_provider_test.dart` -- I/O matrix coverage
- [x] `widget_test.dart`, `horses_provider_test.dart`, `race_and_params_provider_test.dart`, `results_screen_test.dart` -- fix `sharedPreferencesProvider` fallout (see Code Map)

**Acceptance Criteria:**
- Given a customized `bankroll` persisted via `update()`, when a fresh `ProviderContainer` reads `engineParamsProvider` with the same `SharedPreferences` backing, then it returns the customized value, not the default.
- Given a corrupted stored value, when `build()` runs, then it returns defaults without throwing.
- Given the settings screen and a tap on "Réinitialiser", when the confirmation dialog is dismissed via "Annuler", then no reset occurs.
- Given the confirmation is accepted, when `reset()` runs, then all 8 fields display default values.
- Given `widget_test.dart`, when run unmodified, it still passes.

## Verification

**Commands (run 2026-09-08):**
- `flutter analyze` -- No issues found! (ran in 5.2s)
- `flutter test` -- All tests passed! (64 tests, 0 failures)
