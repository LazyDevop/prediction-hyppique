---
title: 'Stories 8.1 + 8.3, app side — Login and PIN screens behind a fake AuthApi'
type: 'feature'
created: '2026-11-17'
status: 'done'
baseline_commit: '51977c0e4dfc29e2793eb76bc24a139b7dc838c5'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/mockups/connexion.html'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The owner wants to see the account flow decided in planning, but the server side of story 8.1 needs stories 7.2, 7.4, 7.9 and 7.10 first. The app today opens straight on Accueil with no account.

**Approach:** Build the app side of 8.1 (Connexion: number + terms, SMS code) and 8.3 (choose PIN, Déverrouillage) exactly per the UX spine and mockup, behind an `AuthApi` interface. A local `FauxAuthApi` (demo code `123456`) stands in for the server until the real client is written; screens depend only on the interface.

## Boundaries & Constraints

**Always:**
- Microcopy, states and component behaviour follow `epic-8-context.md` (taken from EXPERIENCE.md, DESIGN.md and `mockups/connexion.html`). Theme tokens come from the existing app theme in `main.dart`.
- Same response whatever the number: step 2 says « Si ce numéro peut recevoir un code, il vient d'être envoyé au … » (FR-31).
- Terms checkbox is required to request the code (mockup column 1); the accepted version is passed to `AuthApi` (constant `CGU_VERSION_PROVISOIRE = '2026-11-provisoire'` until story 7.9).
- PIN: 4 to 6 digits, entered only on `pin-pad` (never the system keyboard), confirmed once, stored only as an Argon2id hash in secure storage, never sent. 5 wrong PINs, or « Code oublié ? », wipe the local session and open Connexion.
- Gates render before the navigation stack: no session → Connexion; session + locked → Déverrouillage; otherwise Accueil. The app locks on return to foreground after `DELAI_VERROUILLAGE` (provisional 5 min, PRD OQ 14).
- Web (`kIsWeb`): no PIN, no Déverrouillage (EXPERIENCE: « pas de code PIN sur le web »); Connexion then Accueil.
- The fake is visibly a demo: step 2 shows « Mode démo : le code est 123456 » only when `FauxAuthApi` is active.
- Existing screens and tests keep working.

**Ask First:** Adding any dependency other than `flutter_secure_storage` and `cryptography`; changing Accueil or other existing screens beyond the gate.

**Never:** A real HTTP auth client, backend code, WhatsApp sending, Profil, Mes appareils, QR pairing, token refresh logic (story 8.2). Storing the PIN or code in clear, logging them, or putting them in shared_preferences.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First launch | no session | Connexion step 1 | N/A |
| Request code | valid number, terms ticked | step 2 with masked number | button disabled until both |
| Bad number | not a Cameroon mobile (E.164 +2376XXXXXXXX) | stays on step 1 | inline error text |
| Code ok | `123456` | step 3 (choose PIN) on device; Accueil on web | N/A |
| Code wrong | other code, attempts left | « Code incorrect » + attempts left | after 5 → back to step 1 with expiry text |
| PIN mismatch | confirmation differs | restart choice with message | N/A |
| Unlock ok | correct PIN | Accueil | N/A |
| Unlock wrong | wrong PIN, n < 5 | « Code incorrect — N essais restants » | 5th → session wiped → Connexion |
| Cold start | session + PIN set (device) | Déverrouillage | web: Accueil |
| Resume | foreground after ≥ 5 min | Déverrouillage | < 5 min: no lock |

</frozen-after-approval>

## Code Map

- `mobile/lib/main.dart` -- `MaterialApp(home: HomeScreen())` and theme colors (gold `0xFFE8B33C`, bg `0xFF0B1120`, surface `0xFF131C2E`); `ProviderScope` overrides `sharedPreferencesProvider`. Gate goes here as `home`.
- `mobile/lib/data/remote/api_client.dart` -- pattern for API interfaces (`CoursesApi`, `PronosticsApi` abstract classes, faked in tests; never mock Dio).
- `mobile/lib/providers/api_provider.dart` -- Riverpod provider pattern to copy for `authApiProvider`.
- `mobile/test/screens/import_photo_screen_test.dart` -- widget-test style with fake APIs.
- `mobile/test/widget_test.dart` -- may pump the app root; adjust to the gate (override providers with a signed-in fake).
- No auth code exists yet.

## Tasks & Acceptance

**Execution:**
- [x] `mobile/pubspec.yaml` -- add `flutter_secure_storage` and `cryptography` (latest stable compatible with the current SDK); run `flutter pub get`.
- [x] `mobile/lib/data/remote/auth_api.dart` -- create `AuthApi` (`demanderCode(numero, cguVersion)`, `verifierCode(numero, code)` → `SessionOuverte` with tokens and masked number, or a typed failure with attempts left / expired) and `FauxAuthApi` (code `123456`, 5 attempts, 5-min expiry, injectable clock).
- [x] `mobile/lib/data/local/session_store.dart` -- create: interface + secure-storage implementation + in-memory test implementation; holds tokens, masked number, PIN hash and salt, failed-unlock count; `effacer()`.
- [x] `mobile/lib/auth/pin_hash.dart` -- Argon2id hash/verify via `cryptography` (random salt), constant-time compare.
- [x] `mobile/lib/providers/auth_provider.dart` -- `authApiProvider` (FauxAuthApi for now), `sessionStoreProvider`, and a notifier exposing gate state (`aucuneSession`, `verrouillee`, `ouverte`) with the actions of the matrix.
- [x] `mobile/lib/widgets/pin_pad.dart`, `mobile/lib/widgets/otp_field.dart` -- create per the component specs (48dp keys, « Effacer », dots + text progress, TalkBack labels; single field, 6 digits, autofill hint `oneTimeCode`).
- [x] `mobile/lib/screens/connexion_screen.dart`, `mobile/lib/screens/deverrouillage_screen.dart` -- create the three Connexion steps and Déverrouillage with the exact microcopy.
- [x] `mobile/lib/screens/porte_screen.dart` + `mobile/lib/main.dart` -- gate widget as `home`, lifecycle lock after `DELAI_VERROUILLAGE`.
- [x] `mobile/test/auth/` -- unit tests (FauxAuthApi, pin_hash, notifier) and widget tests covering every matrix row with fakes and an in-memory store.

**Acceptance Criteria:**
- Given `flutter test`, when run, then all existing and new tests pass; given `flutter analyze`, then no new issues.
- Given `flutter run -d chrome`, when the app opens, then Connexion shows and code `123456` leads to Accueil.

## Verification

**Commands:**
- `cd mobile && flutter test` -- expected: all pass.
- `cd mobile && flutter analyze` -- expected: no new issues.

**Manual checks (if no CLI):**
- Chrome: Connexion → Accueil. Windows desktop (if the toolchain builds) or Android: Connexion → PIN → Accueil; relaunch → Déverrouillage.

## Suggested Review Order

**Gate and session state**

- Entry point: the gate wraps the Navigator so a lock also covers pushed routes.
  [`main.dart:54`](../../mobile/lib/main.dart#L54)

- Gate states, PIN failure counted before the check, wipe at 5.
  [`auth_provider.dart:150`](../../mobile/lib/providers/auth_provider.dart#L150)

- Fake API only in debug/profile or AUTH_DEMO; release throws.
  [`auth_provider.dart:24`](../../mobile/lib/providers/auth_provider.dart#L24)

- Home built only after first unlock, kept offstage on re-lock; back blocked.
  [`porte_screen.dart:35`](../../mobile/lib/screens/porte_screen.dart#L35)

**Port to replace later**

- The interface the real story 8.1 client will implement.
  [`auth_api.dart:64`](../../mobile/lib/data/remote/auth_api.dart#L64)

- Demo implementation: code 123456, 5 tries, 5-minute expiry.
  [`auth_api.dart:86`](../../mobile/lib/data/remote/auth_api.dart#L86)

**Storage and PIN**

- One JSON value per concept; corrupt data wipes and returns null.
  [`session_store.dart:60`](../../mobile/lib/data/local/session_store.dart#L60)

- Argon2id off the UI isolate, constant-time verify.
  [`pin_hash.dart:1`](../../mobile/lib/auth/pin_hash.dart#L1)

**Tests**

- Real app shell: no Home before login or unlock.
  [`app_porte_test.dart:1`](../../mobile/test/auth/app_porte_test.dart#L1)
