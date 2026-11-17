---
title: 'Stories 9.4 + 9.5, app side — Offres and Paiement Mobile Money behind a fake OffresApi'
type: 'feature'
created: '2026-11-17'
status: 'done'
baseline_commit: '3cb6e0e6d89cd93770ac0abd5e0ce39c174cc2f2'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/mockups/offres-paiement.html'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/DESIGN.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-4-8-6-ecrans-profil-appareils.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The owner wants to keep seeing the planned interfaces. After Profil and Mes appareils, the next visible surfaces are Offres (story 9.4) and Paiement Mobile Money (story 9.5). Their server side is blocked (OQ 13 prices, OQ 15 aggregator, story 9.0 Google Play rules) and must not sell anything.

**Approach:** Build both screens in the app exactly per EXPERIENCE.md (surfaces Offres, Paiement; components `offer-card`, `payment-status`; states Paiement en attente / confirmé / échec), DESIGN.md (no gold, no green/red on these surfaces) and columns 2–4 of `mockups/offres-paiement.html`, behind an `OffresApi` port with a local `FauxOffresApi`, same demo rule as the account fakes (`demoAutoriseeProvider`). A confirmed demo payment changes the tier shown in Profil.

## Boundaries & Constraints

**Always:**
- Offres is opened from a new Profil row « Offres » (settings-row, in the tier section). It lists, grouped as in the mockup (Turfiste · instantanés H-60, H-30, H-15 / Expert · + instantané H-10 / Duo), the offers of PRD FR-41: pass semaine and mensuel Turfiste; pass journée, pass semaine and mensuel Expert; one Duo card per paid tier. Each `offer-card` shows name, tier, duration, price and what it unlocks (mockup texts); a Duo card says the number of people (provisional 2) and that each keeps their account.
- Prices are provisional configuration: shown as « … FCFA » exactly as the mockup (no invented figure), and a visible line « Mode démo : aucun paiement réel » whenever the fake is active.
- Selection is written (« Sélectionnée », border-strong), never gold. « Continuer vers le paiement » (cta-primary) is disabled until an offer is selected. Responsible-gaming reminder in the reading flow on both screens (mockup text). No « gagnez plus », « populaire », countdown or urgency (test on the texts).
- Paiement: summary (Offre, Durée, Prix), MTN MoMo / Orange Money choice (selection written), Mobile Money number prefilled from the account and editable (Cameroon mobile validation as Connexion), « Payer » (cta-primary). Then `payment-status` per EXPERIENCE: pending « Paiement en attente de confirmation — validez sur votre téléphone » with the operator/number instruction and « Le pass s'active dès que … confirme, même si vous quittez cet écran. »; confirmed « Pass semaine actif jusqu'au 22/11 » style (offer name + end date) with end-of-pass text; failed (strong variant) « Paiement non abouti » / « Aucun pass n'a été activé » + « Réessayer » and « Changer de moyen ». Texts only, live region polite, no colour for success/failure.
- The app polls the status without blocking; the user can leave Paiement; a later confirmation still changes the tier (Profil shows the new tier and end date on next load). The app never decides alone that a payment succeeded: only the `OffresApi` status does.
- Fake behaviour (demo): pending, then confirmed after a short delay (injectable clock/delay); Mobile Money number `690000000` → failed; Duo payments confirm like the others but no Duo management screen exists.
- Price appears only on Offres and Paiement. Screens depend only on `OffresApi`. Existing screens and tests keep working.

**Ask First:** Any new dependency; showing locked features or teaser banners in Résultats or other existing screens (story 9.8, next slice); opening Offres from Appareil bloqué (stays text only).

**Never:** Real payment or aggregator client, backend code, Duo invitation/management (9.6), locked-feature/teaser-banner (9.8), photo quota (9.9), FLAG_SECURE (9.10), real prices, any success/failure colour.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open Offres | Profil → « Offres » | grouped offer-cards, nothing selected, CTA disabled | load error: message + « Réessayer » |
| Select offer | tap a card | « Sélectionnée » on it only, CTA enabled | N/A |
| Pay ok | MTN MoMo, number ok, « Payer » | pending status, then confirmed « … actif jusqu'au … » | N/A |
| Pay failed | number `690000000` | failed status, « Réessayer » / « Changer de moyen » | no tier change |
| Bad number | not a Cameroon mobile | inline error, « Payer » disabled | N/A |
| Leave while pending | back during pending | Profil later shows the new tier and end date | N/A |
| Double tap Payer | two quick taps | one payment initiated | N/A |
| Copy check | all Offres/Paiement texts | no urgency or gain-promise words | test fails on any |

</frozen-after-approval>

## Code Map

- `mobile/lib/data/remote/compte_api.dart` -- `CompteApi`/`FauxCompteApi`, `Profil` with tier (`palier_actif`, end date); the fake payment must update the tier the account fake reports.
- `mobile/lib/providers/auth_provider.dart` -- `demoAutoriseeProvider`, `_fauxServeursProvider` (linked fakes built once): add the offers fake there so it shares the account state.
- `mobile/lib/screens/profil_screen.dart` -- tier section; add the « Offres » row; reload after return.
- `mobile/lib/widgets/{settings_row,auth_styles,cadre_auth}.dart` -- tokens and rows to reuse; cta-primary/cta-ghost styles.
- `mobile/lib/screens/connexion_screen.dart` -- Cameroon number validation and masking to reuse.
- `mobile/test/compte/compte_test_helpers.dart`, `mobile/test/auth/auth_test_helpers.dart` -- override pattern for tests.

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/data/remote/offres_api.dart` -- `OffresApi` (list offers, initiate payment, payment status) + typed results, `FauxOffresApi` (catalogue above with null prices shown « … FCFA », pending→confirmed after delay, `690000000` fails, injectable clock) that updates the linked `FauxCompteApi` tier on confirmation.
- [x] `mobile/lib/providers/auth_provider.dart` -- `offresApiProvider` from the shared fakes, same demo rule.
- [x] `mobile/lib/widgets/offer_card.dart`, `mobile/lib/widgets/payment_status.dart` -- per DESIGN components, grouped TalkBack nodes, live region.
- [x] `mobile/lib/screens/offres_screen.dart`, `mobile/lib/screens/paiement_screen.dart` -- mockup microcopy, polling with a timer cancelled on dispose, double-tap guard.
- [x] `mobile/lib/screens/profil_screen.dart` -- « Offres » row.
- [x] `mobile/test/offres/` -- unit tests for the fake; widget tests for every matrix row; one test pumping the real app: Profil → Offres → Paiement → confirmed → Profil shows the paid tier.

**Acceptance Criteria:**
- Given `flutter test` and `flutter analyze`, when run, then all pass with no new issues.
- Given `flutter run -d chrome`, when logged in with `677123456`, then Profil → Offres → Pass semaine Turfiste → Paiement → confirmed, and Profil shows « Turfiste » with an end date; with Mobile Money number `690000000`, the failure state shows.

## Verification

**Commands:**
- `cd mobile && flutter test` -- expected: all pass.
- `cd mobile && flutter analyze` -- expected: no issues.

**Manual checks (if no CLI):**
- Chrome: the two demo paths above.

## Notes

- 2026-11-17 (dev, after review patch): `flutter analyze` no issues; `flutter test` 267 passed (224 before the slice). Three review layers; 11 patch groups applied: failed state read-only, pending payment owned by a kept-alive provider that polls after Paiement closes and refreshes Profil/Offres, idempotency key, polling limits and unknown payment, entitlement rule in the fake (extend / upgrade / refuse lower tier, UTC), no-account error, back-while-locked, Duo invitation notice, empty catalogue, single live-region status slot, tests (release flags, error paths, double taps, wider forbidden-word list).
- Open owner decision: failure wording. EXPERIENCE.md says « Paiement non confirmé — aucun droit activé »; the mockup and this spec say « Paiement non abouti » / « Aucun pass n'a été activé » (kept for now).
- Demo limitations: Mobile Money number prefilled only after a login in the same launch; Duo duration 30 days is provisional; prices « … FCFA » until OQ 13.

## Suggested Review Order

**Payment state**

- Pending payment owned at app level; polls after Paiement closes, limits and idempotency.
  [`paiement_provider.dart:257`](../../mobile/lib/providers/paiement_provider.dart#L257)

- Signal that refreshes Profil and the Offres header on confirmation.
  [`paiement_provider.dart:33`](../../mobile/lib/providers/paiement_provider.dart#L33)

**Port to replace later**

- The interface the real 9.4/9.5 client will implement.
  [`offres_api.dart:148`](../../mobile/lib/data/remote/offres_api.dart#L148)

- Demo implementation: catalogue, delayed confirmation, 690000000 fails, entitlement rule.
  [`offres_api.dart:186`](../../mobile/lib/data/remote/offres_api.dart#L186)

- Extend / upgrade applied to the account fake.
  [`compte_api.dart:365`](../../mobile/lib/data/remote/compte_api.dart#L365)

**Screens**

- Back handling only when the route is current and the gate open.
  [`paiement_screen.dart:189`](../../mobile/lib/screens/paiement_screen.dart#L189)

- One status slot, live region, never coloured.
  [`payment_status.dart:12`](../../mobile/lib/widgets/payment_status.dart#L12)

- Profil entry to Offres.
  [`profil_screen.dart:194`](../../mobile/lib/screens/profil_screen.dart#L194)
