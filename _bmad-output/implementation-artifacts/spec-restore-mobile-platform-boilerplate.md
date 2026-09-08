---
title: 'Reconstruct corrupted mobile platform boilerplate (Android/macOS/Web)'
type: 'bugfix'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
context: []
baseline_commit: 'e546c8f859fa26a454bf40e88434ba11e2c12a5d'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `flutter run -d chrome --debug` crashed immediately (`FileSystemException: Failed to decode data using encoding 'utf-8', path = '...mobile\web\index.html'`). A byte-level scan (`head -c 4 <file> | xxd -p`) found the same corrupted 4-byte header (`24 1a 9c 92`) already identified in `scoring.dart`/`scoring_test.dart`/`race_config_screen.dart`/`analysis_options.yaml` (see `spec-restore-mobile-engine-and-config-screen.md`) across 16 more files: `web/{index.html,manifest.json,favicon.png,icons/*.png}` (7), `android/app/src/main/res/{values,values-night}/styles.xml` + 3 `mipmap-*/ic_launcher.png` (5), `macos/Runner/{Info.plist,Base.lproj/MainMenu.xib,Configs/AppInfo.xcconfig}` + `Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` (4). Same single corruption event as the original files, just not caught by the earlier `.dart`-only scan.

**Approach:** All 16 files are unmodified default Flutter template boilerplate (no app-specific customization was ever made to launcher icons, `index.html` title/theme, or the macOS Xcode project) — `flutter create --overwrite .` regenerates them exactly. First attempt without `--overwrite` silently skipped existing (corrupted) files (`flutter create` only writes files that don't yet exist). Second attempt with `--overwrite` was too broad: it also overwrote `lib/main.dart`, `test/widget_test.dart`, and `pubspec.yaml` — genuinely custom files that happen to share a filename with the template — plus several never-corrupted platform config files (`.gitignore`, `.metadata`, Android Gradle files, `ios/Runner.xcodeproj/project.pbxproj`, `macos/Runner.xcodeproj/project.pbxproj`, `macos/Flutter/GeneratedPluginRegistrant.swift`) to their current-SDK-template defaults (harmless version-bump-style diffs, but out of scope). Both categories were restored via `git checkout HEAD -- <path>` and a stray new `macos/Runner/Assets.xcassets/` directory (macOS app icon assets that never existed in this repo, irrelevant since macOS isn't a build target here) was deleted — leaving only the 16 genuinely-corrupted files changed.

## Boundaries & Constraints

**Always:**
- Verify corruption byte-for-byte (`head -c 4` matching `24 1a 9c 92`) before treating a file as "in scope" — never assume based on `file`'s generic "data" classification alone (valid PNGs are also binary; a real corrupted file matches the exact known signature).
- After any `flutter create --overwrite .`, diff the full `mobile/` tree and restore (`git checkout HEAD --`) anything outside the confirmed-corrupted list, however benign-looking the change.

**Never:**
- Do not run `flutter create --overwrite .` again without immediately auditing `git status` for collateral changes to `lib/`, `test/`, or `pubspec.yaml` — confirmed to reset all three to template defaults.
- Do not touch anything under `backend/`.

## Code Map

- `mobile/web/{index.html,manifest.json,favicon.png,icons/Icon-{192,512,maskable-192,maskable-512}.png}` -- RESTORED via `flutter create --overwrite .`
- `mobile/android/app/src/main/res/{values,values-night}/styles.xml`, `mipmap-{xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` -- RESTORED
- `mobile/macos/Runner/{Info.plist,Base.lproj/MainMenu.xib,Configs/AppInfo.xcconfig}`, `Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` -- RESTORED
- `mobile/lib/main.dart`, `mobile/test/widget_test.dart`, `mobile/pubspec.yaml`, `mobile/pubspec.lock` -- collateral damage from `--overwrite`, reverted via `git checkout HEAD --`, byte-identical to the pre-existing committed version (confirmed no diff)
- `mobile/{.gitignore,.metadata}`, `mobile/android/{app/build.gradle.kts,gradle/wrapper/gradle-wrapper.properties,settings.gradle.kts}`, `mobile/ios/Runner.xcodeproj/project.pbxproj`, `mobile/macos/{Flutter/GeneratedPluginRegistrant.swift,Runner.xcodeproj/project.pbxproj}`, `mobile/analysis_options.yaml` -- collateral template-version churn, reverted via `git checkout HEAD --`
- `mobile/macos/Runner/Assets.xcassets/` -- new directory created by `--overwrite`, deleted (not a build target, not previously present)

## Tasks & Acceptance

**Execution:**
- [x] Scan all platform directories for the corrupted 4-byte signature -- found 16 files
- [x] `flutter create --overwrite .` -- regenerate boilerplate
- [x] Audit full diff, restore every file outside the 16 confirmed-corrupted -- `git checkout HEAD --` on 12 files, delete 1 stray directory
- [x] `flutter test` / `flutter analyze` -- confirm no regression after restoration

**Acceptance Criteria:**
- Given `flutter run -d chrome --debug`, when launched, then it no longer crashes on `web/index.html`.
- Given `git diff --stat -- mobile/`, when reviewed, then only the 16 originally-corrupted files (plus this spec) appear.
- Given `flutter test`, when run, then the full suite (45 tests) still passes unmodified.

## Verification

**Commands actually run:**
- Byte-signature scan across `android/ios/linux/macos/windows/web` (140 files) → 16 matches, 0 in `linux/`/`windows/`/`ios/` (already clean or previously fixed).
- `flutter create .` (no overwrite) → silently no-op on existing corrupted files (confirmed still corrupted after).
- `flutter create --overwrite .` → regenerated all 16 + unwanted collateral (see Intent).
- `git checkout HEAD -- <13 collateral paths>` + manual delete of `macos/Runner/Assets.xcassets/` → diff scoped to exactly 16 files.
- `flutter test` → **45/45 passed** (one transient `build/unit_test_assets` deletion failure on the first retry, a Windows/OneDrive file-handle blip unrelated to the code — resolved by removing the directory manually once, non-recurring).
- `flutter analyze` → **"No issues found!"**
- `flutter run -d chrome --debug` → launched successfully post-fix (see follow-up session activity).
