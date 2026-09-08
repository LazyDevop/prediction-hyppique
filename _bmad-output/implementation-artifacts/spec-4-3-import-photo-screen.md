---
title: 'Story 4.3: import_photo_screen.dart — programme photo/PDF import'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 1
context: ['{project-root}/docs/cahier_des_charges_app_mobile.md']
baseline_commit: '41c0a380ec315b10721429dce4536c6a4c2e407f'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The backend's `/extraction/programme` endpoint (Story 4.2) has no mobile caller yet — cahier mobile §7.5/§9 names `import_photo_screen.dart` as the screen that captures/picks a photo or PDF and calls it, but the file doesn't exist and no HTTP/multipart plumbing for it exists on the mobile side either.

**Approach:** Add the screen, its API-client method, and a Dart model mirroring the backend's `ProgrammeExtraitOut` schema. Scope this story to picking a file, calling the endpoint, and DISPLAYING the extracted data marked "à vérifier" (cahier's own required treatment) — applying confirmed data into `raceConfigProvider`/`horsesProvider` is explicitly out of scope this story (see Never) and logged to `deferred-work.md`, since those providers are mid-development in a concurrent session right now and this story must not touch them.

## Boundaries & Constraints

**Always:**
- Add `image_picker` (gallery + camera) and `file_picker` (PDF) to `pubspec.yaml`, matching cahier mobile §9's recommended stack.
- New model `mobile/lib/models/programme_extrait.dart` — plain class + `fromJson`, mirroring `backend/app/schemas/extraction.py`'s `ProgrammeExtraitOut` field-for-field (same convention as `CourseSummary`, not `freezed` — that's listed in `pubspec.yaml` but unused by existing models).
- Define a small `ExtractionApi` abstract interface (mirrors the existing `CoursesApi` pattern in `api_client.dart` — "sans mocker Dio" is the established testing convention here) with one method, implemented by `ApiClient` via a multipart `POST /extraction/programme` using `dio`'s `FormData`/`MultipartFile`.
- Map the four documented backend error codes to distinct, clear French messages on the screen: `400` (type/fichier invalide), `413` (fichier trop volumineux), `429` (budget épuisé, réessayer plus tard), `502` (échec d'extraction, réessayer).
- Successful extraction renders the "✨ Rempli par l'IA — vérifiez les champs" banner (cahier §7.5, reused from the React prototype) above a read-only display of every extracted field (hippodrome, distance, terrain, niveau, partants, and each horse's num/name/age/poids/cote).
- Add exactly one navigation entry point into this screen from `home_screen.dart` (a single button/icon + `Navigator.push`) — the smallest possible touch to that file.

**Never:**
- Do not modify `race_provider.dart`, `params_provider.dart`, `horses_provider.dart`, or any other existing provider file — this screen is display-only this story; wiring "confirm" into those providers is deferred (logged to `deferred-work.md` as a split goal, not silently dropped).
- Do not implement `/extraction/fiche`'s single-horse import (the "Importer une photo ou un PDF" button on `horse_edit_screen.dart`, cahier §7.4) — different screen, different story.
- Do not modify `main.dart`, `engine_params.dart`, or any file touched by the concurrent mobile session's recent commits (`41c0a38` and earlier) beyond the single `home_screen.dart` navigation entry.
- Do not attempt to test actual `image_picker`/`file_picker` platform-channel behavior — inject the picked file (bytes + filename + content-type) so the screen's logic is testable without mocking native plugins.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Successful extraction | Fake `ExtractionApi` returns a populated `ProgrammeExtrait` | "✨ Rempli par l'IA" banner + all fields rendered read-only | N/A |
| Backend rejects unsupported type | `ExtractionApi` throws for a 400 | Clear French message, no banner | User can retry with a different file |
| Budget exhausted | 429 | "Budget quotidien épuisé, réessayez plus tard" | N/A |
| Extraction failure | 502 | "Échec de l'extraction, réessayez" | N/A |
| User cancels the picker | Picker returns null/no file | Screen stays on its idle state, no request made | N/A |

</frozen-after-approval>

## Code Map

- `mobile/lib/screens/import_photo_screen.dart` -- TO CREATE
- `mobile/lib/models/programme_extrait.dart` -- TO CREATE -- mirrors `backend/app/schemas/extraction.py`'s `ProgrammeExtraitOut`/`HorseProgrammeOut`/`PerfProgrammeOut`
- `mobile/lib/data/remote/api_client.dart` -- MODIFY -- add `ExtractionApi` interface + `ApiClient.extractProgramme`, following the existing `CoursesApi` pattern in this same file
- `mobile/lib/screens/home_screen.dart` -- MODIFY (minimal) -- one navigation entry to the new screen
- `mobile/pubspec.yaml` -- MODIFY -- add `image_picker`, `file_picker`
- `backend/app/schemas/extraction.py` -- READ-ONLY -- the exact response shape to mirror
- `mobile/lib/models/course_summary.dart` -- READ-ONLY -- precedent for the plain-class model convention to follow
- `mobile/test/models/programme_extrait_test.dart`, `mobile/test/screens/import_photo_screen_test.dart` -- TO CREATE

## Tasks & Acceptance

**Execution:**
- [x] `pubspec.yaml` -- add `image_picker`/`file_picker`
- [x] `models/programme_extrait.dart` -- model + `fromJson`
- [x] `data/remote/api_client.dart` -- `ExtractionApi` interface + implementation
- [x] `screens/import_photo_screen.dart` -- picker UI, loading/error/success states, "à vérifier" display
- [x] `screens/home_screen.dart` -- one navigation entry
- [x] Tests per the I/O matrix, using a fake `ExtractionApi` (never real Dio/platform channels)
- [x] Run `flutter test` -- all pass, no regressions; `flutter analyze` -- 0 issues

**Acceptance Criteria:**
- Given the 5 I/O matrix scenarios, when driven through a fake `ExtractionApi`, then the screen renders exactly the documented state.
- Given the full mobile test suite, when run after this story, then it passes with the new tests included and zero regressions.

## Suggested Review Order

1. [mobile/ios/Runner/Info.plist](mobile/ios/Runner/Info.plist) and [mobile/android/app/src/main/AndroidManifest.xml](mobile/android/app/src/main/AndroidManifest.xml) — the two platform-config fixes; without these, the camera button crashes/is denied on a real device.
2. [mobile/lib/screens/import_photo_screen.dart:91-155](mobile/lib/screens/import_photo_screen.dart#L91-L155) — `_pickAndExtract`/`_handlePicked`, all 4 source-code fixes in one place (loading-before-pick, picker-exception handling, the missing `mounted` guard).
3. [mobile/test/screens/import_photo_screen_test.dart:155-186](mobile/test/screens/import_photo_screen_test.dart#L155-L186) — the Completer-gated "buttons stay disabled for the whole picker phase" test, the most structurally interesting new test.
4. [mobile/test/screens/import_photo_screen_test.dart:187-244](mobile/test/screens/import_photo_screen_test.dart#L187-L244) — the two state-clearing transition tests (verification-gap-confirmed gap).
5. [mobile/lib/screens/import_photo_screen.dart:232-240](mobile/lib/screens/import_photo_screen.dart#L232-L240) and [:266-280](mobile/lib/screens/import_photo_screen.dart#L266-L280) — the new `_describePerf`/musique rendering.
6. [_bmad-output/implementation-artifacts/deferred-work.md](_bmad-output/implementation-artifacts/deferred-work.md) — new entries, especially the HEIC/mimeType policy decision.

## Design Notes

Testability for the picker: structure the screen so the actual `image_picker`/`file_picker` calls happen in one small, separately-injectable function/callback — the widget tests exercise the loading/error/success states by supplying a fake `ExtractionApi` and directly invoking the screen's post-pick handler, never the real plugin call.

## Verification

**Commands:**
- `cd mobile && flutter test` -- expected: existing suite + new tests, 0 regressions -- actual (implementation, pre-review): 74/74 passed, 0 regressions. `flutter analyze` -- 0 issues.
- Post-review (3-lens review: blind-hunter, edge-case-hunter, verification-gap), re-verified independently -- **actual: 81/81 tests passed** (74 + 7 new), 0 regressions. `flutter analyze` -- 0 issues.

## Review Findings & Resolution

Three parallel review lenses ran against the implementation. This story shipped new production code (not test-coverage-only), and review surfaced real bugs — including two platform-config omissions that would have crashed the app on first real-device use — so fixes went beyond tests into source and platform config.

**Fixed directly (2 platform-config files + 4 source-code changes + 7 new tests):**
- **`mobile/ios/Runner/Info.plist`**: added `NSCameraUsageDescription`/`NSPhotoLibraryUsageDescription` — iOS terminates an app that calls a privacy-sensitive API (camera) without the matching usage-description key present. Tapping "Appareil photo" on a real device would have hard-crashed the app (blind-hunter finding #1).
- **`mobile/android/app/src/main/AndroidManifest.xml`**: added `<uses-permission android:name="android.permission.CAMERA"/>` (blind-hunter finding #2).
- **`_pickAndExtract`** ([import_photo_screen.dart:91-127](mobile/lib/screens/import_photo_screen.dart#L91-L127)): `_loading` now flips to `true` before opening the native picker, not only once a file is returned — previously all 3 buttons stayed enabled for the entire picker-open window, so a second tap during that window raced a concurrent extraction against the first (blind-hunter #4, edge-case-hunter #2).
- Same function: the picker call is now wrapped in try/catch — a `PlatformException` (denied permission, plugin failure) previously left the button looking like it silently did nothing; now shows a clear French message (blind-hunter #3).
- **`_handlePicked`**: added the `mounted` guard it was missing on its very first `setState` (every other `setState` in the same function already had one) — calling `setState` after the widget is disposed (e.g. user navigates back while a slow real picker/upload is in flight) throws in production (edge-case-hunter #1, verification-gap #5).
- **`_buildResult`**: added a `_describePerf`/"Musique" line per horse — extracted performance history (`perfs`) was parsed correctly by the model but never rendered anywhere, so "vérifiez les champs" didn't actually let the user verify it (edge-case-hunter finding #6).
- New tests: `backend 413 (file too large)` (the 4th documented error code, previously untested), `buttons stay disabled for the whole picker phase` (Completer-gated), `un échec du picker natif affiche un message clair`, `une extraction réussie efface un message d'erreur précédent` / `une nouvelle extraction en échec efface le résultat précédent` (the success↔error state-clearing transitions, verification-gap finding #3), `les performances extraites (musique) sont affichées`, and a model-level test locking in that a missing required `incident` key throws (the backend already guarantees this field's presence via its own Pydantic validation, so the Dart mirror stays intentionally strict rather than silently tolerant — verification-gap #6, blind-hunter #5).

**Logged to `deferred-work.md`:**
- **Needs a human policy decision:** `image_picker`'s `XFile.mimeType` is often `null` on iOS and falls back to `'image/jpeg'`, which can mislabel an actual HEIC capture — fixing it means either adding HEIC support to the backend's accepted types or forcing JPEG output client-side, neither decided here.
- Lower-priority: no client-side pre-upload size/type validation (would duplicate the backend's 20 MiB constant cross-language); the empty-file case shows a slightly imprecise message on mobile vs. the backend's own "Fichier vide" detail; `int`-typed fields use a stricter cast than `double`-typed ones (asymmetric but low-risk given the backend's schema guarantees); `ApiClient.extractProgramme`'s multipart field name is never exercised by a Dart-side test (same class of gap as the rest of `ApiClient`, consistent with this codebase's "never mock Dio" testing convention); no accessibility live-region on the loading spinner (same recurring gap already logged from Story 3.3); large PDFs fully materialize in memory before any size check.
