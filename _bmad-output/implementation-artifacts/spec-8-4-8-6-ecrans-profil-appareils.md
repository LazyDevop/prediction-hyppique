---
title: 'Stories 8.4 + 8.6, app side — Profil, Mes appareils and Appareil bloqué behind a fake CompteApi'
type: 'feature'
created: '2026-11-17'
status: 'done'
baseline_commit: '0c2a28a16bfd0d6c359385a9ce68d3c508d5b6db'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/mockups/mes-appareils.html'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-1-8-3-ecrans-connexion.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** After the login screens, the owner wants to see the next account screens decided in planning: Profil (story 8.4), Mes appareils and the device limit (story 8.6). Their server side does not exist yet.

**Approach:** Build them in the app exactly per the UX spine and `mockups/mes-appareils.html` (columns Profil, Mes appareils, Appareil bloqué), behind a `CompteApi` interface with a local `FauxCompteApi`, following the pattern of the login slice (`AuthApi` / `FauxAuthApi`, demo only in debug/profile or `AUTH_DEMO`).

## Boundaries & Constraints

**Always:**
- Microcopy, layout (settings-row, device-row, status-banner, cta-primary, cta-ghost), states and TalkBack labels follow `epic-8-context.md` and the mockup. No green/red for « vérifié »/« non vérifié »: the state is written.
- Profil is opened from an account icon on Accueil (only change allowed on Accueil). It shows: number (masked as in the session), backup email and its state, tier and end date (`palier_actif` provisional: « Gratuit », no end date), accepted terms version and date (`CGU_VERSION_PROVISOIRE`, date of the login), entry « Mes appareils ». Offers, Duo and « Scanner un QR code » are absent (their stories are not built), never shown disabled.
- Backup email: add or change → a 6-digit code sent to the email (demo code `123456`, reusing `otp-field`) → « vérifié ». Paid-tier reminder banner is implemented but only shown when the tier is not Gratuit.
- Mes appareils: list with type, last activity, « Cet appareil » and « Nouveau » markers; « Retirer » on other devices with a confirmation dialog; the current device cannot be removed here.
- Device limit (provisional 2, PRD OQ 14): the fake has a demo number `699999999` whose account already has 2 devices. Logging in with it shows Appareil bloqué (« Aucun appareil n'a été déconnecté. »), whose « Retirer un appareil » opens Mes appareils in restricted mode (list + remove one, 10-minute limit, nothing else); after the removal → back to Connexion. « Découvrir l'offre Duo » shows the offer as text only, no payment.
- « Se déconnecter » (owner request 2026-11-17): last row of Profil, cta-ghost, confirmation dialog « Se déconnecter de cet appareil ? Vous devrez recevoir un nouveau code pour vous reconnecter. » [Annuler] [Se déconnecter]; on confirm the local session (tokens, PIN hash) is wiped and the gate shows Connexion. The fake has no server call (server revoke is story 8.2, already in deferred-work).
- Screens depend only on `CompteApi`; the real client replaces the fake without touching them.
- Existing screens and the login slice keep working; its tests stay green.

**Ask First:** Any new dependency; any change to the login screens beyond routing a blocked login to Appareil bloqué.

**Never:** Real HTTP client, backend code, QR pairing (8.7), offers/payment (Epic 9), Duo management, account recovery or number change (8.5), sync (8.8).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open Profil | session open, tap account icon | Profil with number, email « non renseigné », Gratuit, terms | N/A |
| Add email | valid email → code `123456` | email shown « vérifié » | invalid email: inline error |
| Wrong email code | other code | « Code incorrect » + attempts left | 5 → back to email entry |
| Devices list | open Mes appareils | current device first « Cet appareil », others with last activity | load error: message + retry |
| Remove device | « Retirer » → confirm | row disappears | cancel: nothing changes |
| Blocked login | number `699999999`, code ok | Appareil bloqué, no session opened | N/A |
| Restricted remove | from Appareil bloqué, remove one | back to Connexion with a message to log in again | after 10 min: « Délai dépassé » → Connexion |
| Log out | Profil → « Se déconnecter » → confirm | session wiped, Connexion step 1 (pushed routes gone) | cancel: stays on Profil |

</frozen-after-approval>

## Code Map

- `mobile/lib/data/remote/auth_api.dart` -- `AuthApi`/`FauxAuthApi`, result types, OTP constants; add a blocked-device result for the demo number.
- `mobile/lib/providers/auth_provider.dart` -- gate notifier (`Porte` states), demo-mode rule (`kDebugMode || kProfileMode || AUTH_DEMO`) to reuse for `compteApiProvider`.
- `mobile/lib/screens/porte_screen.dart` -- gate above the Navigator; Appareil bloqué is a gate state (no session).
- `mobile/lib/screens/connexion_screen.dart`, `mobile/lib/widgets/{otp_field,pin_pad,cadre_auth,auth_styles}.dart` -- reuse `otp-field`, `CadreAuth`, `JetonsAuth`, `EnTeteAuth`, `LienAuth`.
- `mobile/lib/data/local/session_store.dart` -- session holds the masked number; extend only if Profil needs the login date.
- `mobile/lib/screens/home_screen.dart` -- add the account icon in the app bar.
- `mobile/test/auth/auth_test_helpers.dart` -- `overridesAuth` pattern for tests.

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/data/remote/compte_api.dart` -- create `CompteApi` (profile read, email set + verify, devices list, remove device, restricted remove) and `FauxCompteApi` (in-memory, demo codes, injectable clock).
- [x] `mobile/lib/data/remote/auth_api.dart` + `mobile/lib/providers/auth_provider.dart` -- blocked-login result and a `Porte.appareilBloque` state carrying the restricted token; `compteApiProvider` with the same demo rule; a `seDeconnecter()` action (wipe store → `aucuneSession`).
- [x] `mobile/lib/widgets/settings_row.dart`, `mobile/lib/widgets/device_row.dart` -- create per DESIGN components.
- [x] `mobile/lib/screens/profil_screen.dart`, `mobile/lib/screens/email_secours_screen.dart`, `mobile/lib/screens/mes_appareils_screen.dart`, `mobile/lib/screens/appareil_bloque_screen.dart` -- create with the mockup microcopy.
- [x] `mobile/lib/screens/home_screen.dart` -- account icon → Profil.
- [x] `mobile/test/compte/` -- unit tests for `FauxCompteApi` and widget tests for every matrix row; one test pumping the real `PredictionHippiqueApp` for the blocked login.

**Acceptance Criteria:**
- Given `flutter test` and `flutter analyze`, when run, then all pass with no new issues.
- Given `flutter run -d chrome`, when logging in with `677123456`, then Accueil → account icon → Profil → Mes appareils works; with `699999999`, Appareil bloqué shows.

## Verification

**Commands:**
- `cd mobile && flutter test` -- expected: all pass.
- `cd mobile && flutter analyze` -- expected: no issues.

**Manual checks (if no CLI):**
- Chrome: both demo numbers as above.

## Notes

- 2026-11-17 (dev, after review patch): `flutter analyze` no issues; `flutter test` 224 passed (201 before review). Three review layers; 12 patch groups applied (release demo flags, Profil icon hidden without a CompteApi, restricted removal outcome applied by the notifier, double-tap guards, token expiry timer, shared kept-alive fakes, fake reset on logout, email back/normalisation, local dates with year, Profil reload notice, tests). « Se connecter avec un autre numéro » and « Sans date de fin » were added by the dev, not in the mockup; shown to the owner, not explicitly confirmed.
- Demo limitation: the CGU acceptance date shown after a cold start is the fake's start time (real server will return it).

## Suggested Review Order

**Gate and demo wiring**

- Demo rule as a plain boolean; no exception-as-flag.
  [`auth_provider.dart:27`](../../mobile/lib/providers/auth_provider.dart#L27)

- Both fakes built once and linked, so 699999999 blocks through real wiring.
  [`auth_provider.dart:35`](../../mobile/lib/providers/auth_provider.dart#L35)

- Leaving Appareil bloqué, and logout wiping the session.
  [`auth_provider.dart:225`](../../mobile/lib/providers/auth_provider.dart#L225)

- Appareil bloqué is a gate state; Home is never built for it.
  [`porte_screen.dart:95`](../../mobile/lib/screens/porte_screen.dart#L95)

**Port to replace later**

- The interface the real 8.4/8.6 client will implement.
  [`compte_api.dart:139`](../../mobile/lib/data/remote/compte_api.dart#L139)

- Demo implementation: limit 2, code 123456, single-use 10-min token.
  [`compte_api.dart:197`](../../mobile/lib/data/remote/compte_api.dart#L197)

**Screens**

- Restricted mode: expiry timer, back blocked during removal.
  [`mes_appareils_screen.dart:61`](../../mobile/lib/screens/mes_appareils_screen.dart#L61)

- Removal: guard before confirm; remove and reload handled separately.
  [`mes_appareils_screen.dart:90`](../../mobile/lib/screens/mes_appareils_screen.dart#L90)

- Profil icon only when a CompteApi exists.
  [`home_screen.dart:121`](../../mobile/lib/screens/home_screen.dart#L121)

**Tests**

- Review regressions: back during/after removal, double tap, expiry, wiring.
  [`compte_revue_test.dart:1`](../../mobile/test/compte/compte_revue_test.dart#L1)
