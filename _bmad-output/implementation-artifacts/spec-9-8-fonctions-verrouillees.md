---
title: 'Story 9.8, app side — locked features by tier (demo tiers, no server filtering)'
type: 'feature'
created: '2026-11-24'
status: 'in-progress'
baseline_commit: '8aa49221133f454221085628c3de7606ec992356'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/DESIGN.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-9-4-9-5-ecrans-offres-paiement.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Offres and Paiement change the tier shown in Profil, but the tier unlocks nothing: every function is open to everyone. Story 9.8 shows, in place of a function above the tier, what it unlocks and how to get it.

**Approach:** An app-side copy of the PRD FR-39 matrix and one tier provider fed by `CompteApi` drive a `locked-feature` widget on the existing screens. Demo tiers: `677123456` is Expert (owner decision 2026-11-24), other numbers are Gratuit until they pay.

## Boundaries & Constraints

**Always:**
- Matrix, one Dart file (`acces_paliers.dart`), provisional until story 9.2 creates `fixtures/acces_paliers.json`:
  - Gratuit: programme, partants (read only), follow a race, account, Offres.
  - Turfiste adds: configure, manual entry, edit/add/delete runners, Fiche cheval, photo import, local calculation, value and suggested stake, bankroll and Kelly fraction.
  - Expert adds: the 10 combination types, the other engine coefficients.
- `locked-feature` per DESIGN.md (surface-2, border line-card, radius lg, decorative 🔒, never gold, never blur): « Combinaisons — palier Expert » style label, cta-ghost « Voir les offres » opening Offres with the unlocking offers first. One per section. One grouped TalkBack node (« Combinaisons, palier Expert, bouton Voir les offres »).
- Locked content is not computed: no combinations below Expert; a tier below Expert calculates with the default coefficients even if custom ones are stored (stored values are kept). Below Turfiste nothing is calculated.
- Gratuit path: a programme race opens Liste des partants directly (no Configuration). « Calculer » becomes « VOIR LE PRONOSTIC DU MATIN », which opens Résultats in read-only mode. The published forecast does not exist in the app yet (Epic 11): Résultats says « Pronostic du matin indisponible », with the locked sections below. No invented figures.
- Accueil « Saisie manuelle » and the photo import: below Turfiste they open a page holding one locked-feature. Réglages: locked sections in place.
- Tier provider: refreshed by `signalDroitProvider`, login, logout, app resume, and at the entitlement end date. Locks appear or disappear without restart. While loading: neither content nor lock. On error: last known tier of this session, otherwise Gratuit with « Réessayer ».
- Expired entitlement: Profil says « Droit Turfiste terminé le 22/11 » with « Voir les offres ».
- The pronostic sent to the backend by a Turfiste carries no combinations.

**Ask First:** Any new dependency; any backend change (if the backend rejects a pronostic without combinations, stop and ask); changing a matrix line.

**Never:** Server filtering (9.2), offline entitlement proof (9.3), published forecasts or teaser banners (Epic 11), Multi, export, photo quota (9.9), FLAG_SECURE (9.10).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Expert | `677123456` | no lock anywhere, app as today | N/A |
| Gratuit, race | `677000000`, open a race | Partants read-only, morning-forecast CTA | N/A |
| Gratuit, Résultats | tap that CTA | « Pronostic du matin indisponible » + locks | N/A |
| Turfiste | pays Pass semaine Turfiste | value and stake shown, combinations locked | N/A |
| Upgrade live | Résultats open, payment confirmed | lock replaced without restart | N/A |
| Expiry live | end date passes | locks return, Profil says ended | N/A |
| Stored coefficients | Turfiste with custom values | defaults used, stored values kept | N/A |
| See offers | tap on the Combinaisons lock | Offres, Expert offers first | N/A |
| Tier load fails | API error | last known tier, else Gratuit | « Réessayer » |
| Account switch | Expert logs out, Gratuit logs in | no Expert content or past result visible | N/A |

</frozen-after-approval>

## Code Map

- `mobile/lib/data/remote/compte_api.dart` -- fake tiers; seed `677123456` as Expert. Accounts are keyed by masked number.
- `mobile/lib/providers/paiement_provider.dart:33` -- `signalDroitProvider`.
- `mobile/lib/providers/results_provider.dart` -- `calculer`, `_envoyerPronostic`; clear results on account change.
- `mobile/lib/providers/params_provider.dart` -- engine parameters.
- `mobile/lib/screens/{results,settings,horse_list,horse_edit,race_config,import_photo,home,web_shell,offres,profil}_screen.dart` (web shell: `web_shell.dart`) and `ouverture_course.dart` -- places to lock; the web shell shares them.
- `backend/app/api/routes_pronostics.py` -- read only: does it accept empty combinations?

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/data/acces_paliers.dart`, `mobile/lib/providers/palier_provider.dart` -- matrix and tier state.
- [x] `mobile/lib/data/remote/compte_api.dart` -- demo tiers.
- [x] `mobile/lib/widgets/locked_feature.dart` -- widget.
- [x] Screens above -- locks, Gratuit path, Offres ordered by need.
- [x] `mobile/lib/providers/results_provider.dart` -- compute only what the tier allows.
- [x] `mobile/test/paliers/` -- every matrix row, phone and web shell; payment tests move to a Gratuit number.

**Acceptance Criteria:**
- Given `flutter test` and `flutter analyze`, when run, then all pass.
- Given Chrome and `677000000`, when buying Pass semaine Turfiste, then value and stake unlock without restart and combinations stay locked.

## Verification

**Commands:**
- `cd mobile && flutter test && flutter analyze` -- expected: all pass.
