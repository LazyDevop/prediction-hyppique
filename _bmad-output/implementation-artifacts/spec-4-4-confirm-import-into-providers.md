---
title: 'Story 4.4: wire import_photo_screen confirm action into raceConfigProvider/horsesProvider'
type: 'feature'
created: '2026-09-09'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/docs/cahier_des_charges_app_mobile.md']
baseline_commit: 'e29a4565e8a12a746a6d42b0a88ed9f1d1c83a69'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 4.3 deliberately shipped `import_photo_screen.dart` as display-only (deferred in `deferred-work.md`) because `race_provider.dart`/`horses_provider.dart` were mid-development in a concurrent session at the time. That session's work landed and stabilized (`41c0a38`, `f2ea8f3`) — the split is no longer necessary. A user can extract a programme but has no way to actually use it.

**Approach:** Add a "Confirmer et configurer" button to the extraction result view. On tap, map the extracted data into a `RaceConfig` and a `List<Horse>`, write them into the existing providers via one new bulk-replace method, and navigate to `RaceConfigScreen` (the same screen `home_screen.dart` already pushes after loading a backend-sourced course) so the user reviews/adjusts the prefilled, "à vérifier" fields before proceeding — never applying them silently.

## Boundaries & Constraints

**Always:**
- Add `HorsesNotifier.setAll(List<Horse> horses)` to `horses_provider.dart` — bulk-replaces the horse list in one state update (not N sequential `add()` calls) and resets `resultsProvider` via `.clear()`, matching `clear()`'s own "nouvelle course chargée, pas une édition" semantics (a whole imported programme is a new context, not an edit to the current one).
- Map `ProgrammeExtrait` → `RaceConfig` verbatim: `hippodrome: extrait.hippo ?? ''`, `distance: extrait.dist`, `terrain: extrait.terr`, `niveau: extrait.niveau`, `nbPartantsCourse: extrait.partants`. These are already-resolved coefficients (Story 4.1), not labels — `RaceConfigScreen`'s existing reverse-lookup (`_reverseLookupTerrain`/`_reverseLookup`) handles turning them back into a selectable label exactly as it already does for backend-sourced courses; do not change that screen's lookup logic.
- Map each `HorseProgrammeExtrait` → `Horse`: `nom: horse.name ?? 'Cheval inconnu'`, `numPmu: horse.num`, `age: horse.age`, `poids: horse.poids`, `cote: horse.cote`, `inedit: false`, `performances: const []` — the programme-level extraction's `perfs` (rank/incident only, no partants/distance/terrain/niveau) aren't rich enough to become valid `Performance` records; leave each horse's performance history empty for the user to fill in manually or via a future per-horse import, exactly as a manually-added horse starts today.
- After the two provider updates, navigate with `Navigator.pushReplacement` to `RaceConfigScreen` — replaces the import screen in the stack (matches `home_screen.dart`'s existing push-after-load pattern; the user shouldn't navigate "back" into the now-stale extraction view).
- The confirm button is visible only when `_result != null` (the existing success state).

**Never:**
- Do not change `RaceConfigScreen`'s reverse-lookup logic, `RaceConfig`, or `Performance` models.
- Do not implement `/extraction/fiche`'s single-horse import — separate story.
- Do not add per-horse editing/selection UI to the confirm step (e.g. "only import these 3 of 8 horses") — confirm applies the full extracted set; trimming happens afterward on the normal horse-list screen, same as any other import.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Confirm a populated result | `_result` has 2 horses, full course fields | `raceConfigProvider` and `horsesProvider` updated with the mapped values; navigates to `RaceConfigScreen` | N/A |
| Confirm with a null `name` on one horse | `HorseProgrammeExtrait.name == null` | That horse's `Horse.nom == 'Cheval inconnu'`, not a crash | N/A |
| Confirm with zero extracted horses | `extrait.horses` is empty | `horsesProvider` becomes `[]`; navigation still proceeds (user can add horses manually on the next screen) | N/A |
| `resultsProvider` had a prior calculated result | Any state before confirm | Cleared (not marked stale) after confirm — matches `horsesProvider.clear()`'s existing "new course" semantics | N/A |

</frozen-after-approval>

## Code Map

- `mobile/lib/providers/horses_provider.dart` -- MODIFY -- add `setAll`
- `mobile/lib/screens/import_photo_screen.dart` -- MODIFY -- confirm button + mapping + navigation, in `_buildResult`
- `mobile/lib/providers/race_provider.dart` -- READ-ONLY -- `RaceConfigNotifier.update` already does what's needed
- `mobile/lib/screens/race_config_screen.dart` -- READ-ONLY -- navigation target; its reverse-lookup already handles resolved-coefficient `RaceConfig` values (see its own docstring, confirmed by reading `initState`)
- `mobile/lib/models/race_config.dart`, `mobile/lib/models/horse.dart` -- READ-ONLY -- target model shapes
- `mobile/lib/screens/home_screen.dart` -- READ-ONLY -- precedent for the update-then-`pushReplacement`-to-`RaceConfigScreen` pattern
- `mobile/test/screens/import_photo_screen_test.dart`, `mobile/test/providers/` -- MODIFY/TO CREATE -- tests for the mapping and the new provider method

## Tasks & Acceptance

**Execution:**
- [x] `horses_provider.dart` -- `setAll`
- [x] `import_photo_screen.dart` -- confirm button, mapping functions, navigation
- [x] Tests per the I/O matrix
- [x] Run `flutter test` -- all pass, no regressions; `flutter analyze` -- 0 issues

**Acceptance Criteria:**
- Given the 4 I/O matrix scenarios, when confirm is tapped, then `raceConfigProvider`/`horsesProvider` end in exactly the documented state and navigation occurs.
- Given the full mobile test suite, when run after this story, then it passes with the new tests included and zero regressions.

## Verification

**Commands:**
- `cd mobile && flutter test` -- expected: existing suite + new tests, 0 regressions.
- `cd mobile && flutter analyze` -- expected: 0 issues.
