---
title: "Sprint Change Proposal — Paid multi-user service: accounts, licences, Mobile Money, security"
date: 2026-11-15
workflow: bmad-correct-course (batch mode)
trigger: _bmad-output/brainstorming/brainstorm-plateforme-auth-securite-2026-11-15/brainstorm-intent.md
supporting:
  - _bmad-output/brainstorming/brainstorm-plateforme-auth-securite-2026-11-15/security-threat-matrix.md
  - _bmad-output/brainstorming/brainstorm-plateforme-auth-securite-2026-11-15/.memlog.md
approach: Hybrid — PRD MVP redefinition + new epics (direct adjustment)
scope: Major
status: approved by the project owner on 2026-11-15 (D-1 to D-7 accepted; D-5 accepted on a low-risk condition, see §5.3) — only sprint-status.yaml applied; PRD, spine, UX and epics are applied by the handoff (§5.2)
---

# Sprint Change Proposal — Paid multi-user service

> This document **modifies no artifact**. It describes, artifact by artifact, the changes to apply once approved. Design choices that no session recorded are marked **[TO CONFIRM]**: each is the most cautious option compatible with the 2026-11-15 decisions and the existing code. Section 5.3 lists them all.
>
> **Language.** The proposal is in English. Replacement text for documents written in French (PRD, epics, UX spine) is given in French, so it can be pasted as is. Replacement text for the architecture spine (English) is in English.

## 1. Issue Summary

### 1.1 Trigger

A brainstorming session with the project owner on 2026-11-15 (`brainstorm-intent.md`) settled the user platform, multi-user model, authentication and security. Its central decision: **the service is paid**, so it needs a usage licence and user accounts.

### 1.2 Category

**Strategic pivot.** This is not a defect found during implementation. The product moves from "free, single user, no account" to "paid, multi-user, launched in Cameroon".

### 1.3 Problem statement

Every planning artifact assumes the opposite:

- **PRD §9.1:** "V1 est mono-utilisateur, sans compte, sans authentification et sans paiement."
- **PRD §6.2:** accounts, authentication, multi-device, cloud sync and billing are out of scope, deferred to a V2 gated by §10.
- **PRD §2.2:** "Les équipes multi-utilisateurs partageant un compte" are non-users.
- **PRD FR-30:** the retained forecast stays "sur l'appareil … sans compte ni envoi au serveur".
- **Architecture spine, Deferred:** "Payment/account/multi-user architecture. Explicitly out of MVP scope — revisit only once the V2 monetization gate (PRD §10) is met."
- **Architecture AD-9:** the retained forecast lives on the device only.

The current code matches those assumptions. A paid service cannot launch on it.

### 1.4 Evidence

| Fact | Source |
|---|---|
| Owner decision: paid service, licence required, accounts mandatory | memlog, 2026-11-15 |
| No authentication on any API route | `backend/app/main.py`: routers included with no dependency |
| CORS open to every origin | `backend/app/main.py:23`, `allow_origins=["*"]` |
| Single SQLite file shared by 4 services | `docker-compose.yml`: `api`, `ingestion`, `cotes` and `pronostics` services, all on `sqlite:////app/data/hippique.db` |
| Only secret protected: the Anthropic key | `backend/app/data/vision_client.py:233`, AD-3 |
| No local cache on the web build | `mobile/lib/data/local/database_helper.dart:34`, `if (kIsWeb) return null;` |
| Monetization gate (PRD §10), condition 1 (model beats the market) | Partly met: the combined model beats the H-30 market out of sample (log-loss difference −0.016, 95% CI [−0.020, −0.012], `ml/runs/2026-11-10-combine-r1/report.md`; corrected 2026-11-15, an earlier draft quoted 2.009, which is the roadmap's gate figure). Live confirmation is still pending (AD-14). |
| Monetization gate (PRD §10), condition 2 (legitimate data source) | **Not met** (PRD §9.3) |

## 2. Impact Analysis

### 2.1 Change navigation checklist

| # | Item | Status | Finding |
|---|---|---|---|
| 1.1 | Triggering story | [N/A] | Strategic decision, no story involved |
| 1.2 | Core problem | [x] | Strategic pivot (§1.2) |
| 1.3 | Evidence | [x] | §1.4 |
| 2.1 | Current epic | [x] | Epics 1–4 are done and stay valid. Epics 5–6 (Multi) are untouched in substance: the Multi becomes Expert-tier content. |
| 2.2 | Epic-level changes | [!] | Add **Epics 7–10** (launch) and **Epic 11** (V1.1). Move story 5.4 (Alembic) to Epic 7. |
| 2.3 | Remaining epics | [!] | Epic 5: AD-9 changes (the retained forecast is synced to the account), which affects story 5.15. Epic 6: no impact. |
| 2.4 | Obsolete or new epics | [x] | Nothing becomes obsolete. Four launch epics are new. |
| 2.5 | Order and priority | [!] | Epic 7 (security foundations) comes first. Epics 8–10 come before the paid launch. Epics 5–6 can run in parallel after story 7.1. |
| 3.1 | PRD conflicts | [!] | §1, §2.2, §2.3, §3, §4 (new sections), FR-30, §5, §6, §7, §8, §9.1, §9.2, §9.3, §10, §11, §12 |
| 3.2 | Architecture conflicts | [!] | Deferred item removed. **AD-15 to AD-21** added. AD-3, AD-9 and AD-13 amended. Stack and Structural Seed updated. |
| 3.3 | UX conflicts | [!] | New surfaces: sign-in, PIN, profile, My devices, offers, payment, QR pairing. New component `locked-feature`. Voice rules for the paywall. Web companion layout. |
| 3.4 | Other artifacts | [!] | `docker-compose.yml` (PostgreSQL, TLS reverse proxy), `.env`, Play Store release, legal texts (terms of sale and use, privacy policy), monitoring of payment webhooks, security tests |
| 4.1 | Option 1, direct adjustment | Viable in part | The new epics fit the plan, but the PRD's goals change, so adjustment alone is not enough. |
| 4.2 | Option 2, rollback | Not viable | Nothing built conflicts, and AD-9's device-only store is not built yet (story 5.15 is in backlog). |
| 4.3 | Option 3, PRD MVP review | Viable, required | The MVP is redefined as a paid launch in Cameroon. |
| 4.4 | Recommended path | [x] | **Hybrid: Option 3 + Option 1** (§3) |
| 5.x | Proposal components | [x] | This document |
| 6.1–6.2 | Checklist review, proposal accuracy | [x] | Done while drafting |
| 6.3 | User approval | [ ] | Pending |
| 6.4 | `sprint-status.yaml` | [ ] | Applied only after approval (§4.5) |
| 6.5 | Handoff | [ ] | §5 |

### 2.2 Epic impact

| Epic | Status | Impact |
|---|---|---|
| 1. Engine and API | done | None. `/analyse` becomes a protected route (Epic 9). |
| 2. PMU ingestion | done | None in substance. The storage moves to PostgreSQL (Epic 7). |
| 3. Mobile, offline included | done | Screens get an authentication gate and tier locks (Epics 8–9). Offline computation stays non-negotiable. |
| 4. Photo import | done | Per-account quota per tier, on top of the global daily limit (story 9.8). |
| 5. Multi forecast | backlog | Story **5.4 → 7.1**. Story 5.15 follows amended AD-9 (sync to the account). The Multi is reserved for the Expert tier. |
| 6. Multi evaluation | backlog | None |
| **7. Platform security foundations** | new | Alembic, PostgreSQL, TLS, CORS, rate limiting, secrets, web build |
| **8. Accounts, sign-in and devices** | new | Phone + OTP, tokens, PIN, profile and email, recovery, My devices, QR pairing, sync |
| **9. Licences, tiers and Mobile Money** | new | Dated entitlements, tier filtering, offline entitlement, payment, offers, reconciliation, paywall, quota, screen-capture blocking |
| **10. Back-office: roles and internal controls** | new | Separate surface, 2FA, RBAC, approvals, audit, four-eyes manual licence |
| **11. Hardening (V1.1)** | new | iOS, biometrics, watermark, anomaly detection, recovery proofs, certificate pinning, check against the PMU source |

### 2.3 Artifact conflicts

| Artifact | Section | Conflict | Resolution |
|---|---|---|---|
| PRD | §9.1 | Single user, no account, no payment | Rewritten: paid V1 with accounts (§4.1, P-12) |
| PRD | §6.1 / §6.2 | Accounts and billing out of scope; Android only | MVP redefined (P-9, P-10) |
| PRD | §2.2 | Multi-user teams and Cameroon users excluded | Rewritten (P-3) |
| PRD | FR-30 | Retained forecast without account or server | Synced to the account (P-7) |
| PRD | §10 | Monetization as a V2 roadmap item | Becomes the decided model, with the gate revisited (P-15) |
| PRD | §9.3 | Unauthorized data source | Risk increased by monetization, owner decision required (P-14, D-1) |
| Spine | Deferred | Account and payment architecture deferred | Removed; AD-15 to AD-21 added (§4.2) |
| Spine | AD-9 | Retained forecast on the device only | Device plus account sync (A-3) |
| Spine | AD-13 | Alembic on SQLite | Alembic on PostgreSQL (A-4) |
| Spine | AD-3 | Global daily vision limit | Plus a per-account quota per tier (A-2) |
| UX | Information Architecture | No account surfaces | New surfaces (§4.3) |
| UX | Responsive & Platform | Phone only | Web companion (§4.3) |
| Compose | all services | Shared SQLite, no TLS | PostgreSQL, reverse proxy (story 7.2, story 7.3) |

### 2.4 Technical impact

- **Storage.** SQLite becomes PostgreSQL. Four services write to the same file today; with paying users that becomes a concurrency and backup risk. Accounts and payments go in a separate schema with their own database role.
- **Edge.** A TLS reverse proxy is added in front of `api`, CORS is limited to the web app's domain, and calls are rate-limited.
- **New driven ports (AD-1 pattern):**
  - `data/otp_client.py`, for the SMS or WhatsApp provider;
  - `data/paiement_client.py`, for the Mobile Money aggregator.
- **Mobile:**
  - secure storage (Android Keystore) for the tokens;
  - PIN screen;
  - QR scanner;
  - tier locks;
  - `FLAG_SECURE` on paid screens.
- **Web.** No local cache, which is accepted because the web app is a companion (D-7). It needs a production build and a domain of its own.
- **Distribution.** Release on the Play Store, which requires a privacy policy, a review of the store's policy on betting-related apps, and a review of the rules on Mobile Money payments made outside Google Play billing.
- **Legal and operations:**
  - terms of use and terms of sale;
  - a privacy policy;
  - responsible-gambling notices on the paywall;
  - alerts on failed payment webhooks.

## 3. Recommended Approach

**Hybrid: PRD MVP review (Option 3) + direct adjustment (Option 1).**

- **The PRD is rewritten where the pivot contradicts it.** The new MVP is a **paid launch in Cameroon**.
- **Four launch epics (7–10) and one V1.1 epic (11) are added.** Epics 1–6 keep their content.
- **Rollback: none.** Nothing built conflicts with the change.

**Rationale.**
- The decision comes from the owner and has clear business value.
- The finished epics (engine, ingestion, mobile, photo import) are kept whole, so momentum is preserved.
- The security work goes first (Epic 7), so that no account or payment is built on an open API and a shared SQLite file.

**Effort.**
- **High:** 4 launch epics, about 33 stories, plus V1.1.
- Payment, OTP and security are new domains for the project.

**Risk.**
- **Medium to high:**
  - legal, in Cameroon (§9.2) and on data rights (§9.3);
  - integration with a third-party aggregator;
  - security of a system that handles money.

**Timeline impact.**
- The Multi (Epics 5–6) is no longer the only next step.
- **[TO CONFIRM] D-2:** the paid launch does not wait for the Multi. At launch, the Expert tier holds H-10, combinations, the expert engine and the larger photo quota. The Multi joins it when Epic 5 is done.

**Gate for the paid launch (not for development).** All of the following:
1. the Cameroon legal consultation has a favourable outcome;
2. the Must stories of Epics 7–10 are done;
3. the Play Store review is passed;
4. the terms and the privacy policy are published.

## 4. Detailed Change Proposals

### 4.1 PRD — `prds/prd-prediction-hyppique-2026-08-22/prd.md`

**P-1. Frontmatter and §0.** Set `updated: 2026-11-15`. Add this source to the list in §0:

> - `brainstorm-intent.md` (2026-11-15, `_bmad-output/brainstorming/brainstorm-plateforme-auth-securite-2026-11-15/`) — passage à un service payant : plateformes, comptes, licences, paiement Mobile Money, sécurité. Fait foi sur ces sujets en cas d'écart avec les cahiers techniques, qui excluaient comptes et facturation.

**P-2. §1 Vision.** Add after the "Limite assumée" paragraph:

> **Modèle de service** : le produit est un **service payant**, lancé au **Cameroun** puis étendu au reste de l'Afrique et au monde. Il est utilisé sur téléphone Android en priorité — l'application mobile est le produit complet —, avec une web app compagnon pour préparer sur ordinateur. Un compte et une licence par paliers donnent accès aux fonctionnalités ; le paiement se fait par Mobile Money. Le produit ne collecte jamais de mise : on paie l'outil, jamais un pari.

**P-3. §2.2 Non-Users.**

OLD:
> - Les parieurs sur courses hors France (pas de PMUC camerounais, pas de courses internationales) — les échelles terrain/niveau et la source de données sont calibrées sur la France uniquement.
> […]
> - Les équipes multi-utilisateurs partageant un compte — V1 est mono-utilisateur, sans notion de compte (§9 Constraints, décision de périmètre).

NEW:
> - Les parieurs sur des courses hors France (courses camerounaises du PMUC, courses internationales) — les échelles terrain/niveau et la source de données sont calibrées sur la France. Les **parieurs résidant au Cameroun qui jouent les courses françaises** (via le PMUC ou un autre opérateur) sont, eux, la cible du lancement.
> - Le partage d'un compte entre plusieurs personnes — un compte est personnel ; le partage se fait par l'offre Duo (§10), et l'offre Club (revente par un tiers) vient plus tard.

**P-4. §2.3 UJ-1, "État d'entrée".**

OLD: `app ouverte, pas de compte à créer (V1 mono-utilisateur). Programme du jour pas encore chargé.`
NEW: `app ouverte, compte connecté et déverrouillé par son code PIN, palier Turfiste. Programme du jour pas encore chargé.`

Add these two journeys after UJ-4:

> - **UJ-5. Paul s'abonne par Mobile Money depuis son téléphone.**
>   - **Persona + contexte :** Paul, Douala, turfiste du week-end, un seul appareil : un Android d'entrée de gamme. Pas d'ordinateur, pas de carte bancaire, un compte MTN MoMo.
>   - **État d'entrée :** app installée depuis le Play Store, aucun compte.
>   - **Parcours :** il saisit son numéro → reçoit un code par SMS → choisit un code PIN → voit le pronostic du matin (palier Gratuit) → sur la course de 15 h, un aperçu indique « Le classement a changé à H-10 pour 3 chevaux » → il ouvre les offres → choisit le pass semaine Turfiste → paie par MTN MoMo et valide sur son téléphone → l'app affiche « Paiement en attente de confirmation » puis « Pass semaine actif jusqu'au … ».
>   - **Climax :** les instantanés H-60, H-30 et H-15 se débloquent sur la course en cours, sans redémarrer l'app.
>   - **Résolution :** il prépare ses courses du dimanche sur son téléphone, hors ligne compris une fois les courses chargées.
>   - **Edge case :** le paiement échoue ou n'est pas confirmé par l'agrégateur → aucun droit n'est activé, l'écran le dit et propose de réessayer ; un paiement confirmé plus tard active le droit sans action de Paul.
>
> - **UJ-6. Marc prépare sur son ordinateur et décide sur son téléphone.**
>   - **Persona + contexte :** Marc, palier Expert, prépare le Quinté+ sur son PC le samedi soir.
>   - **État d'entrée :** compte Expert actif sur le téléphone ; aucune session sur le PC.
>   - **Parcours :** il ouvre la web app → elle affiche un QR code → il le scanne avec l'app de son téléphone, déjà connectée, et approuve → le PC rejoint son compte et apparaît dans « Mes appareils » → il prépare ses sélections et retient un pronostic Multi.
>   - **Climax :** le dimanche, au guichet, il ouvre l'app de son téléphone : sa sélection et son pronostic retenu y sont, et l'instantané H-10 recalcule le classement.
>   - **Edge case :** un troisième appareil tente de se connecter alors que la limite est atteinte → il est bloqué, l'écran propose l'offre Duo ou de retirer un appareil depuis « Mes appareils ».

**P-5. §3 Glossary.** Add:

> - **Compte** — Identité d'un utilisateur, rattachée à un numéro de téléphone vérifié par code (OTP). Personnel, jamais partagé.
> - **Palier** — Niveau d'accès aux fonctionnalités : Gratuit, Turfiste, Expert (§10). Duo et Club sont des formules de partage, pas des paliers.
> - **Droit (d'accès)** — Autorisation datée d'utiliser un palier : palier, date de début, date de fin, origine (paiement ou geste commercial). Il n'existe pas de simple statut « abonné ».
> - **Pass** — Droit de courte durée acheté d'avance : pass journée (Expert pendant 24 h), pass semaine.
> - **Appareil** — Téléphone ou navigateur rattaché à un compte. Chaque session de navigateur compte comme un appareil.
> - **Agrégateur Mobile Money** — Prestataire qui encaisse les paiements MTN MoMo et Orange Money et confirme chaque transaction au serveur.
> - **Code PIN** — Code local de 4 à 6 chiffres qui déverrouille l'app sur l'appareil ; il n'est jamais envoyé au serveur.
> - **Instantané de cotes** — Cotes relevées à H-60, H-30, H-15 ou H-10 avant le départ, et pronostic recalculé sur ces cotes.

**P-6. §4: three new feature sections.** Add to the §4 index: *FR-31 à FR-38 (§4.12 Comptes et appareils), FR-39 à FR-46 (§4.13 Licences et paiement), FR-47 à FR-50 (§4.14 Back-office).*

> ### 4.12 Comptes, connexion et appareils
>
> **Description :** Chaque utilisateur a un compte personnel, rattaché à son numéro de téléphone, utilisable sur son téléphone et, s'il le veut, sur un ordinateur. Réalise UJ-5, UJ-6.
>
> #### FR-31: Inscription et connexion par numéro de téléphone
> L'utilisateur crée son compte ou se connecte avec son numéro de téléphone et un code à usage unique reçu par SMS (ou WhatsApp), sans mot de passe.
>
> **Consequences (testable):**
> - Le code expire après 5 minutes et accepte au plus 5 essais ; les demandes de code sont limitées par numéro et par adresse IP.
> - Aucune information ne permet de savoir si un numéro a déjà un compte (même message dans les deux cas).
>
> #### FR-32: Code PIN et verrouillage
> Après la première connexion, l'utilisateur choisit un code PIN de 4 à 6 chiffres qui déverrouille l'app sur cet appareil.
>
> **Consequences (testable):**
> - L'app se verrouille quand elle passe en arrière-plan et après une durée d'inactivité réglable (valeur par défaut : Open Question 14).
> - Le code PIN n'est jamais transmis au serveur ; il déverrouille une session gardée dans le stockage sécurisé de l'appareil.
> - Après 5 codes PIN faux, la session est effacée de l'appareil et une nouvelle connexion par code SMS est exigée.
>
> #### FR-33: Session sécurisée
> Une session reste ouverte sur un appareil sans reconnexion, tant qu'elle n'est pas révoquée.
>
> **Consequences (testable):**
> - Un jeton d'accès vit 15 minutes ; un jeton de renouvellement, lié à l'appareil, est remplacé à chaque usage.
> - La réutilisation d'un jeton de renouvellement déjà remplacé révoque toutes les sessions de cet appareil.
>
> #### FR-34: Profil et email de secours
> L'utilisateur renseigne une adresse email, vérifiée par un lien, qui sert à récupérer son compte.
>
> **Consequences (testable):**
> - Un compte payant sans email vérifié voit un rappel non bloquant à chaque ouverture de « Profil ».
>
> #### FR-35: Récupération du compte et changement de numéro
> L'utilisateur qui a perdu son numéro récupère son compte par son email vérifié et le rattache à un nouveau numéro.
>
> **Consequences (testable):**
> - Le changement de numéro prend effet après un délai de sécurité de 24 à 48 heures (valeur : Open Question 14) ; pendant ce délai, une alerte part vers l'ancien numéro et vers l'email, avec un lien d'annulation en un geste.
> - Les droits actifs et les données synchronisées suivent le compte, pas le numéro.
>
> #### FR-36: Mes appareils et limite d'appareils
> L'utilisateur voit la liste des appareils rattachés à son compte et peut en retirer un à distance.
>
> **Consequences (testable):**
> - Chaque session de navigateur compte comme un appareil.
> - Le rattachement d'un nouvel appareil exige un code envoyé au numéro du compte et déclenche une notification sur les autres appareils.
> - Au-delà de la limite du palier (Open Question 14), le nouvel appareil est **bloqué** — aucun appareil existant n'est déconnecté — et l'écran propose l'offre Duo ou de retirer un appareil.
>
> #### FR-37: Appairage par QR code
> Depuis la web app, l'utilisateur rattache son ordinateur à son compte en scannant un QR code avec l'app de son téléphone, déjà connectée.
>
> **Consequences (testable):**
> - Le QR code expire après 2 minutes et ne sert qu'une fois ; le téléphone affiche le navigateur concerné et demande une approbation explicite.
> - L'appareil rattaché compte dans la limite d'appareils (FR-36).
>
> #### FR-38: Synchronisation entre appareils
> Les sélections de courses, les réglages du moteur et les pronostics retenus d'un utilisateur se retrouvent sur tous ses appareils.
>
> **Consequences (testable):**
> - L'application mobile reste utilisable hors ligne (FR-13) ; les changements faits hors ligne sont envoyés au retour du réseau.
> - Un pronostic retenu figé au départ (FR-28) n'est plus modifiable sur aucun appareil ; avant le départ, la dernière version enregistrée l'emporte.
> - Aucune fonctionnalité n'existe seulement dans la web app.
>
> ### 4.13 Licences, paliers et paiement
>
> **Description :** Le palier de l'utilisateur détermine ce qu'il voit ; il l'achète par Mobile Money, en pass ou en abonnement. Réalise UJ-5.
>
> #### FR-39: Paliers et contenu
> Le contenu accessible dépend du palier actif (§10) : Gratuit, Turfiste, Expert.
>
> **Consequences (testable):**
> - Le serveur ne renvoie jamais une donnée que le palier n'autorise pas (ex. instantané H-10 pour un compte Turfiste) : un champ interdit est absent de la réponse, pas masqué par l'app.
> - Un droit expiré ramène le compte au palier Gratuit sans perte de ses données synchronisées.
>
> #### FR-40: Aperçu pour le palier Gratuit
> Un compte Gratuit voit, sur une course, qu'un instantané plus récent a changé le classement, sans voir le classement lui-même.
>
> **Consequences (testable):**
> - L'aperçu dit seulement combien de chevaux ont changé de rang et à quel instantané ; aucun nom, dossard ni probabilité de l'instantané n'est transmis.
>
> #### FR-41: Offres
> L'utilisateur choisit une offre : pass journée (Expert pendant 24 h), pass semaine, abonnement mensuel (Turfiste ou Expert), offre Duo.
>
> **Consequences (testable):**
> - Les prix et durées sont des données de configuration, modifiables sans nouvelle version de l'app.
> - L'écran des offres porte le rappel de jeu responsable et ne promet aucun gain.
>
> #### FR-42: Paiement par Mobile Money
> L'utilisateur paie par MTN MoMo ou Orange Money depuis l'app, via un agrégateur.
>
> **Consequences (testable):**
> - Un droit n'est activé que par la notification signée de l'agrégateur, vérifiée par le serveur puis confirmée par une requête de statut ; jamais par l'app.
> - Une même transaction n'active jamais deux droits (traitement idempotent sur sa référence).
> - Tant que le paiement n'est pas confirmé, l'écran affiche « Paiement en attente de confirmation » ; un échec n'active rien et le dit.
>
> #### FR-43: Offre Duo
> Le titulaire d'une offre Duo invite 1 ou 2 personnes (nombre : Open Question 13), qui ont chacune leur propre compte et leurs propres appareils.
>
> **Consequences (testable):**
> - Le titulaire peut retirer un membre ; le membre retiré revient au palier Gratuit.
>
> #### FR-44: Droits disponibles hors ligne
> Sur l'application mobile, les fonctionnalités calculées sur l'appareil restent accessibles hors ligne pendant la durée du droit déjà acquis.
>
> **Consequences (testable):**
> - L'app conserve une preuve de droit signée par le serveur, avec sa date de fin ; hors ligne, elle s'y fie jusqu'à cette date, jamais au-delà.
>
> #### FR-45: Quota d'import photo par palier
> Chaque palier dispose d'un quota d'imports photo par période (valeurs : Open Question 14), en plus de la limite journalière globale (§9.4).
>
> **Consequences (testable):**
> - Le compteur restant est visible avant l'import ; un quota épuisé est dit clairement, sans appel au fournisseur de vision.
>
> #### FR-46: Protection des écrans payants
> Les captures et enregistrements d'écran sont bloqués sur les écrans qui affichent un contenu payant (Android).
>
> ### 4.14 Back-office — contrôle des accès internes
>
> **Description :** Les agents de saisie, superviseurs et administrateurs travaillent dans un back-office séparé de l'application, avec des droits limités et tracés. Les fonctionnalités de saisie elles-mêmes relèvent du brief back-office du 2026-10-18 ; cette section fixe le cadre d'accès.
>
> #### FR-47: Accès séparé et double authentification
> Le back-office est servi sur une adresse distincte de l'application ; chaque membre du personnel s'y connecte avec une double authentification obligatoire.
>
> #### FR-48: Rôles
> Trois rôles : **agent** (saisie, ne voit que ses propres saisies, aucun accès aux pronostics ni aux licences), **superviseur** (valide les modifications), **administrateur** (gère les licences).
>
> #### FR-49: Validation avant application
> Toute modification saisie par un agent reste en attente jusqu'à la validation d'un superviseur ; elle n'entre dans aucun calcul avant.
>
> #### FR-50: Licence manuelle et journal d'audit
> Seul un administrateur crée une licence hors paiement (geste commercial), avec un motif obligatoire et la validation d'une seconde personne. Chaque création, modification, validation et licence est inscrite dans un journal en ajout seul.
>
> **Consequences (testable):**
> - Chaque jour, un rapprochement liste tout droit actif sans paiement confirmé ni licence manuelle validée ; l'objectif est zéro (SM-5).

**P-7. FR-30, 4th consequence.**

OLD: `- Le pronostic retenu par l'utilisateur (FR-28) est conservé sur l'appareil avec l'heure des données utilisées, pendant 90 jours, sans compte ni envoi au serveur (V1 mono-utilisateur).`
NEW: `- Le pronostic retenu par l'utilisateur (FR-28) est conservé sur l'appareil avec l'heure des données utilisées, pendant 90 jours, et synchronisé avec son compte (FR-38) ; il reste consultable hors ligne.`

**P-8. §5 Non-Goals.** Add:

> - L'application n'encaisse, ne transmet ni ne conserve aucune mise. Le paiement porte uniquement sur l'accès à l'outil (§10).
> - Aucune fonctionnalité réservée à la web app : l'application mobile est le produit complet.

**P-9. §6.1 In Scope.**

OLD: `- App mobile Flutter, Android uniquement : …`
NEW: `- App mobile Flutter, Android : … (inchangé). Web app Flutter compagnon, sans cache hors ligne, sans fonctionnalité propre.`

OLD: `- Usage mono-utilisateur, sans compte ni authentification.`
NEW:
> - Lancement payant au Cameroun : comptes et appareils (§4.12), licences, paliers et paiement Mobile Money (§4.13), contrôle d'accès du back-office (§4.14), fondations de sécurité (§8). Prérequis de mise en vente : §9.2.

**P-10. §6.2 Out of Scope.**

OLD:
> - Compte utilisateur, authentification, multi-appareil, synchronisation cloud — différé, condition : introduction d'un modèle payant (§10).
> - Paywall / facturation / gestion d'abonnement ou de crédits — différé à V2, cette PRD documente l'intention (§10) sans la construire.
> - Version iOS — différée à V2, une fois Android validé en usage réel. `[NOTE FOR PM]` …

NEW:
> - **V1.1** : version iOS ; contrôle d'intégrité de l'app (Play Integrity : le serveur refuse les sessions d'une app modifiée) ; déverrouillage biométrique ; filigrane visible portant l'identifiant du compte ; détection d'usages anormaux (même compte simultanément dans deux villes, rotation d'appareils) ; preuves de récupération complémentaires (référence d'un paiement Mobile Money passé, codes de secours) ; épinglage du certificat dans l'app ; contrôle des saisies du back-office contre la source PMU.
> - **Plus tard** : offre Club (revente par un tiers, comptes organisation à sièges) ; programme d'affiliation pour les administrateurs de groupes WhatsApp ; filigrane invisible ; paiement intégré aux stores pour l'international ; ouverture à d'autres pays d'Afrique.
> - **Exclu** : applications de bureau (Windows, macOS, Linux) ; édition ou validation de tickets de pari.

**P-11. §7 Success Metrics.** Add:

> **Garde-fou d'exploitation**
> - **SM-5** : Droits actifs sans paiement confirmé ni licence manuelle validée, mesurés chaque jour par le rapprochement (FR-50) — cible : zéro. Tout écart est une anomalie à expliquer.
>
> **Secondary**
> - **SM-6** : Conversion du palier Gratuit vers un palier payant, par offre — directionnel. Contrepartie : SM-C4.
>
> **Counter-metrics**
> - **SM-C4** : Agressivité de l'aperçu et des relances — ne jamais augmenter la conversion par une promesse de gain, une urgence artificielle ou un message contraire au rappel de jeu responsable (§5).

**P-12. §8 Cross-Cutting NFRs.** Add:

> - **Le serveur seul décide des droits** : chaque route vérifie la session et le droit actif ; une application modifiée ne débloque aucune donnée réservée.
> - **Transport chiffré** : HTTPS partout ; CORS limité au domaine de la web app ; débit limité par compte et par adresse IP.
> - **Minimisation des données** : aucun numéro de carte ni code PIN côté serveur ; comptes et paiements séparés des données de courses ; sauvegardes chiffrées.
> - **Aucun secret dans les binaires** : la règle « aucune clé API tierce côté client » couvre aussi l'agrégateur de paiement et le fournisseur de codes SMS.
> - **Données personnelles** : conformité à la loi camerounaise applicable (périmètre exact : §9.2).

**P-13. §9.1 rewritten.**

> ### 9.1 Périmètre V1 — décision de cadrage (révisée le 2026-11-15)
>
> **V1 est un service payant, avec comptes, authentification et paiement.** Décision du porteur de projet du 2026-11-15 (`brainstorm-intent.md`) : le service n'est pas gratuit, il faut une licence d'utilisation, donc des comptes. Elle remplace la décision précédente (« mono-utilisateur, sans compte, sans authentification et sans paiement »), qui avait tranché en faveur des cahiers techniques contre le modèle freemium du brief ; le brief l'emporte désormais sur ce point. Les cahiers techniques restent la référence pour le moteur, l'ingestion et l'application, hors comptes et facturation. `[ASSUMPTION: confirmé explicitement par le porteur de projet le 2026-11-15.]`

**P-14. §9.2 and §9.3.**
- §9.2, replace the last paragraph with:

> **Prérequis bloquant pour la mise en vente** (pas pour le développement) : une consultation juridique locale doit confirmer, avant toute vente, (1) si un outil d'analyse payant qui ne collecte aucune mise entre dans le champ de la loi n°2015/012, et la position du PMUC ; (2) les obligations de la loi camerounaise sur les données personnelles (déclaration, consentement, conservation) ; (3) le risque lié à la revente d'un service fondé sur des données PMU non autorisées (§9.3). Elle est à refaire pour chaque nouveau pays.

- §9.3, add at the end:

> **Effet de la monétisation (2026-11-15)** : vendre un service construit sur une source non autorisée aggrave le risque décrit ici — un usage commercial est plus visible et plus difficile à défendre qu'un usage personnel. Le jalon §10 (« source légitime sécurisée ou plan crédible ») n'est pas atteint. La décision de lancer quand même relève du porteur de projet (voir §10). `[TO CONFIRM — D-1]`

**P-15. §10 rewritten.**

> ## 10. Monétisation (décidée le 2026-11-15)
>
> | Palier | Contenu |
> |---|---|
> | **Gratuit** | Pronostic du matin, consultation seule ; aperçu « le classement a changé à H-10 » (FR-40) |
> | **Turfiste** | + instantanés H-60, H-30 et H-15, value, mise Kelly, historique complet, quota d'import photo |
> | **Expert** | + instantané H-10, combinaisons sur les 10 types de paris, moteur expert réglable, Multi, quota d'import photo plus élevé |
>
> - **Formules** : pass journée (Expert pendant 24 h), pass semaine, abonnement mensuel, offre Duo (2 ou 3 personnes). Offre Club : plus tard (§6.2).
> - **Paiement** : Mobile Money (MTN MoMo, Orange Money) via un seul agrégateur, en dehors du système de paiement des stores. Paiement intégré aux stores : plus tard, pour l'international.
> - **Principe conservé** : la coupure porte sur l'actionnable et sur la fraîcheur des cotes ; l'instantané H-10, le plus proche du départ, est réservé à l'Expert. C'est aussi la défense contre la revente : une copie du pronostic perd sa valeur quand les cotes bougent.
> - **Jalon de bascule revu** : (1) la calibration — le modèle combiné bat le marché (cotes H-30) hors échantillon (écart de log-loss −0,016, IC 95 % [−0,020 ; −0,012]), confirmation sur pronostics en direct en cours (AD-14) ; (2) la source de données légitime — **non atteinte** ; le porteur de projet décide de lancer en assumant ce risque, après la consultation juridique (§9.2). `[TO CONFIRM — D-1]`
> - Le paragraphe « Structuration » est conservé tel quel : son raisonnement (la dépendance à la source grandit avec la traction) s'applique désormais au lancement payant.

**P-16. §11 Open Questions.**
- Close OQ 2: "Format tarifaire : structure décidée (§10) ; prix ouverts (OQ 13)."
- Rewrite OQ 3 as: "Consultation juridique camerounaise : §9.2, trois volets, prérequis de mise en vente."
- Add:

> 13. Prix de chaque offre et du Duo ; nombre de places du Duo (2 ou 3).
> 14. Limite d'appareils par palier, délai d'inactivité avant verrouillage, délai de sécurité du changement de numéro (24 ou 48 h), quotas d'import photo par palier.
> 15. Choix de l'agrégateur Mobile Money (CinetPay, Campay, Notch Pay, Flutterwave…) : signature des notifications, requête de statut, remontée des remboursements et contestations.
> 16. Contestation d'un paiement Mobile Money après activation du droit (rétrofacturation) : parade à définir avec l'agrégateur retenu.
> 17. Fournisseur des codes de connexion (SMS ou WhatsApp) : coût et délivrabilité au Cameroun.
> 18. Règles du Google Play pour une app liée aux paris hippiques et pour un paiement Mobile Money hors de la facturation Google Play.

**P-17. §12 Assumptions Index.** Add:

> - §9.1, §10 — Service payant, comptes obligatoires, paliers, formules et paiement Mobile Money : décisions du porteur de projet le 2026-11-15 (`brainstorm-intent.md`).
> - §4.12 — Numéro de téléphone + code comme identité, code PIN local, email de secours, appareil bloqué au-delà de la limite avec proposition Duo : décisions du porteur de projet le 2026-11-15.
> - §1, §6.1 — Application mobile = produit complet, web app compagnon sans fonctionnalité propre : décision du porteur de projet le 2026-11-15.

### 4.2 Architecture spine — `architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md`

**A-1. Remove** this line from Deferred:

> - **Payment/account/multi-user architecture.** Explicitly out of MVP scope (PRD §6.2, §9.1) — revisit only once the V2 monetization gate (PRD §10) is met.

Amend the Deferred line on deployment: "no mobile store distribution exist yet" becomes "Play Store distribution is required for the paid launch (Epic 7); CI/CD and a staging environment stay deferred."

Set the frontmatter to `updated: 2026-11-15` and add `brainstorm-intent.md` and `security-threat-matrix.md` to `sources`.

**A-2. Amend AD-3.** Add to its Rule:

> On top of the global `VISION_DAILY_CALL_LIMIT`, each account has a per-tier quota per period, checked by the extraction route before `vision_client` is called; an exhausted quota never reaches the provider. [amended 2026-11-15]

**A-3. Amend AD-9.** New Rule:

> The retained forecast is written to the device's SQLite cache first, so it works offline, then synced to the user's account (AD-16, story 8.8). The server copy is the cross-device source of truth; the device copy is the offline source. After the departure freeze (UTC, AD-12), neither copy changes. Purge after 90 days applies to both. [amended 2026-11-15; was "device only"]

**A-4. Amend AD-13.** Replace "production SQLite file" with "production database (PostgreSQL from story 7.2)". Add:

> The SQLite → PostgreSQL move is itself a one-off migration job with a row-count check per table, run once; after it, SQLite remains only as the test database and the mobile cache. [amended 2026-11-15]

**A-5. New invariants.**

> ### AD-15 — The server is the sole authority for entitlements; gate by data, not by code
>
> - **Binds:** every `api/routes_*.py`, the race payloads, `mobile/lib/providers/`, the entitlement token.
> - **Prevents:** a patched APK or a hand-crafted request reading H-10 snapshots or reference probabilities without paying; a tier check duplicated in several places that drifts.
> - **Rule:** one FastAPI dependency resolves the caller's active entitlement (tier, start, end) on every route; responses are built per tier, so a field the tier does not allow is absent, never hidden by the client. Data that is server-produced (odds snapshots, reference probabilities, history depth) is gated on the server. Features computed on the phone (Kelly, combinations, expert sliders, Multi) are gated on the phone from a **server-signed entitlement token** (tier, end date), trusted offline until its end date, never after. The residual risk — a patched APK unlocking local computations on data it was allowed to receive — is accepted. [TO CONFIRM — D-5] [decided 2026-11-15]
>
> ### AD-16 — Identity, sessions and devices have one fixed shape
>
> - **Binds:** `data/otp_client.py` (new driven port), the auth routes, the `appareil` and `session` tables, mobile secure storage, the web app.
> - **Prevents:** a PIN or OTP stored server-side; sessions that cannot be revoked; the web becoming an unlimited side door.
> - **Rule:** identity = verified phone number via OTP through `otp_client.py` (only module knowing the provider). Access token 15 min; refresh token bound to one device record, rotated on each use, reuse = revoke the device's chain. The PIN exists only on the device and unlocks tokens held in Android Keystore / iOS Keychain. Every browser session is a device record. A new device needs an OTP to the account's number; over the tier's device limit it is refused (never evicting another). QR pairing creates a one-time, 2-minute pairing token approved from an already signed-in phone. [decided 2026-11-15]
>
> ### AD-17 — Payments enter only through a signed, verified, idempotent webhook
>
> - **Binds:** `data/paiement_client.py` (new driven port), the webhook route, the `paiement` and `droit` tables, the daily reconciliation job.
> - **Prevents:** an app-side "payment OK" unlocking access; a replayed notification creating two entitlements; an insider creating licences unseen.
> - **Rule:** `paiement_client.py` is the only module knowing the aggregator's format (AD-1 pattern). An entitlement (`droit`) is created only (a) by a webhook whose signature is verified and whose status is re-confirmed by a call to the aggregator, idempotent on the transaction reference, or (b) by an admin manual licence with a reason and a second approver (AD-20). A daily job in `jobs/` reconciles active entitlements against confirmed payments and manual licences and reports any orphan (PRD SM-5). [decided 2026-11-15]
>
> ### AD-18 — Accounts belong to organizations; entitlements are dated
>
> - **Binds:** `models.py` (`organisation`, `compte`, `membre`, `droit`), Alembic revisions, AD-15's resolver.
> - **Prevents:** a schema rewrite when Duo and later Club arrive; a boolean "subscribed" flag that cannot express a day pass.
> - **Rule:** every account belongs to an organization (a personal one by default); Duo is an organization with 2–3 seats; Club later reuses the same shape. An entitlement carries tier, start, end (UTC, AD-12), origin (payment reference or manual licence id) and applies to an organization's members. No boolean subscription field exists. [decided 2026-11-15]
>
> ### AD-19 — PostgreSQL is the server store; accounts and payments live apart
>
> - **Binds:** `docker-compose.yml`, `DATABASE_URL` of every service, `repository.py`, backups.
> - **Prevents:** four services writing one SQLite file once money is involved; a race-data bug or query exposing phone numbers and payments.
> - **Rule:** PostgreSQL replaces SQLite on the server. Race data and account/payment data are in separate schemas with separate database roles: race services (`ingestion`, `cotes`, `pronostics`) cannot read the account schema. Backups are encrypted. The server never stores a card number or a PIN. [decided 2026-11-15]
>
> ### AD-20 — The back-office is a separate surface with RBAC, approvals and an append-only audit log
>
> - **Binds:** the back-office routes and app, staff accounts, the `journal_audit` table.
> - **Prevents:** an agent reselling predictions or minting licences; a falsified data entry silently changing a forecast; untraceable changes.
> - **Rule:** the back-office is served on its own host with mandatory TOTP 2FA for staff. Roles agent / supervisor / admin, least privilege: agents see only their own entries and no predictions or licences. An agent's change is a pending request applied only after a supervisor's approval. Manual licences need admin + second approver. Every create, change, approval and licence writes an append-only `journal_audit` row (no update or delete grant on that table). [decided 2026-11-15]
>
> ### AD-21 — The edge is TLS, an origin allowlist and rate limits
>
> - **Binds:** `docker-compose.yml` (reverse proxy), `backend/app/main.py`.
> - **Prevents:** interception on public Wi-Fi; any website calling the API from a browser; scraping by loop.
> - **Rule:** a TLS reverse proxy fronts `api`; `allow_origins` lists only the web app's and back-office's origins; rate limits apply per account and per IP, stricter on OTP and payment routes. Certificate pinning in the mobile app is V1.1. [decided 2026-11-15]

**A-6. Consistency Conventions.** Add a row:

> | Accounts & payments naming | French domain vocabulary as well: `compte`, `appareil`, `session`, `droit`, `palier`, `paiement`, `organisation`, `membre`, `journal_audit`. |

Extend the "State & cross-cutting" row: "No third-party key ever ships in the mobile binary or the web bundle — vision, payment aggregator and OTP provider alike."

**A-7. Stack.** Add these rows. Versions are verified at story time, as was done for the existing stack.

| Name | Version |
|---|---|
| PostgreSQL | current stable major at story 7.2 [TO VERIFY] |
| Reverse proxy (TLS) | Caddy or Traefik, decided in story 7.3 [TO VERIFY] |
| `flutter_secure_storage` | current [TO VERIFY], tokens in Keystore/Keychain |
| QR scanning (e.g. `mobile_scanner`) | current [TO VERIFY] |
| Mobile Money aggregator | PRD OQ 15 |
| OTP provider | PRD OQ 17 |

**A-8. Structural Seed.** Add:

```text
backend/app/data/otp_client.py        # AD-16
backend/app/data/paiement_client.py   # AD-17
backend/app/api/routes_auth.py        # AD-16
backend/app/api/routes_paiement.py    # AD-17 (webhook + offers)
backend/app/api/deps_droits.py        # AD-15 entitlement dependency
backend/app/jobs/rapprochement.py     # AD-17 daily reconciliation
backoffice/                           # AD-20 (separate surface)
```

### 4.3 UX — `ux-designs/ux-prediction-hyppique-2026-08-22/`

**U-1. EXPERIENCE.md, Information Architecture.** Add these surfaces:

| Surface | Accès | Contenu |
|---|---|---|
| Connexion | Premier lancement, session expirée | Numéro de téléphone → code reçu → choix du code PIN |
| Déverrouillage | Retour au premier plan, inactivité | Pavé de code PIN, 5 essais, « Code oublié ? » → reconnexion par code SMS |
| Profil | Icône compte (Accueil) | Numéro, email de secours (vérifié ou non), palier et date de fin du droit, « Mes appareils », offres |
| Mes appareils | Profil, écran de blocage | Liste des appareils (type, dernière activité), retirer un appareil |
| Offres | Profil, `locked-feature`, aperçu H-10 | Paliers, pass journée, pass semaine, mensuel, Duo ; rappel de jeu responsable |
| Paiement | Offres | Choix MTN MoMo / Orange Money, numéro, états « en attente de confirmation », « actif jusqu'au … », « échec » |
| Appairage | Web app (QR) ; téléphone (scanner, Profil) | QR code côté web ; côté téléphone, scan puis approbation nommant le navigateur |
| Appareil bloqué | Connexion au-delà de la limite | Explication, « Retirer un appareil », « Découvrir l'offre Duo » |

Navigation: the stack stays as it is. A compte icon is added on the Accueil. Sign-in and unlock are gates placed before the stack, not stacked screens.

**U-2. Component Patterns.** Add:
- **`locked-feature`.** Replaces locked content in place, with a short label of what it unlocks and a "Voir les offres" button. It never blurs content that has actually been received, because the server does not send it (AD-15).
- **`teaser-banner`.** The free-tier preview: « Le classement a changé à H-10 pour 3 chevaux ».
- **`pin-pad`** and **`otp-field`.** Large targets (48 dp or more), each digit announced by TalkBack, autofill of the SMS code where Android allows it.

**U-3. Voice and Tone.** Add a paywall row. Allowed: « Débloquer les instantanés », « Pass semaine Turfiste ». Forbidden: « gagnez plus », « pronostics gagnants », countdowns, any promise of a win. The responsible-gambling reminder appears on Offres and Paiement.

**U-4. Responsive & Platform.** Add the web companion:
- A wide-screen layout (two columns: race list and detail) with the same components.
- No offline mode, and the page says so.
- No feature found only on the web.

**U-5. State Patterns.** Add these states:
- payment pending, confirmed, failed;
- entitlement expired (back to Free, data kept);
- device blocked;
- photo quota used up;
- offline with a valid entitlement (local features stay open until the end date).

**U-6. Mockups to produce.**
- `mockups/connexion.html`;
- `mockups/offres-paiement.html`;
- `mockups/mes-appareils.html`;
- the web companion layout.

The spine wins over the mockups, as before.

### 4.4 Epics and stories — `epics.md`

**E-1. Requirements Inventory.**
- Add FR-31 to FR-50 (P-6).
- Add NFR-12 to NFR-16 (P-12).
- In "Additional Requirements", replace "toute architecture compte/paiement/multi-utilisateur" (in the "Différé explicitement" line) with "— (levé le 2026-11-15 : voir AD-15 à AD-21)".
- Update the FR Coverage Map.

**E-2. Story 5.4 moves to Epic 7 as story 7.1.** Its content is unchanged, except that "base de production SQLite" becomes "base de production (SQLite, puis PostgreSQL à la story 7.2)". Epic 5 keeps a reference: "Alembic : voir story 7.1 (prérequis)".

> Note: the 2026-10-18 proposal (still pending) renumbers Epic 5. Decide it before applying this one. If it is approved, its Alembic story moves to 7.1 under its new number.

**E-3. Story 5.15 (retained forecast).** Add this acceptance criterion:

> **Given** un utilisateur connecté qui retient un pronostic
> **When** le réseau est disponible
> **Then** le pronostic est aussi envoyé à son compte (story 8.8, AD-9 amendé), et le gel au départ s'applique aux deux copies.

**E-4. Epic List.** Add these entries:

> ### Epic 7: Fondations de sécurité de la plateforme
> Le serveur est prêt à porter des comptes et des paiements : schéma migré par Alembic, PostgreSQL à la place de SQLite, accès en HTTPS seulement, CORS restreint, débit limité, aucun secret dans les binaires, web app de production.
> **FRs couvertes :** NFR-12 à NFR-16 ; prépare FR-31 à FR-50.
> **Notes :** AD-13 (amendé), AD-19, AD-21, AD-3 étendu. Premier epic à réaliser ; les Epics 5-6 peuvent reprendre après la story 7.1.
>
> ### Epic 8: Comptes, connexion et appareils
> L'utilisateur crée son compte par son numéro, protège l'app par un code PIN, retrouve son compte s'il change de numéro, gère ses appareils, rattache son ordinateur par QR code et retrouve ses sélections partout.
> **FRs couvertes :** FR-31 à FR-38. **Notes :** AD-16, AD-9 amendé.
>
> ### Epic 9: Licences, paliers et paiement Mobile Money
> L'utilisateur voit ce que son palier autorise, découvre ce qu'il manque, paie par Mobile Money un pass ou un abonnement, et garde ses fonctionnalités hors ligne pendant son droit.
> **FRs couvertes :** FR-39 à FR-46. **Notes :** AD-15, AD-17, AD-18. Mise en vente conditionnée à la consultation juridique (PRD §9.2).
>
> ### Epic 10: Back-office — rôles et contrôles internes
> Le personnel travaille dans un back-office séparé, avec double authentification, des rôles limités, une validation avant toute modification et un journal d'audit ; une licence hors paiement exige deux personnes.
> **FRs couvertes :** FR-47 à FR-50. **Notes :** AD-20. Les écrans de saisie eux-mêmes viennent du brief back-office du 2026-10-18 et seront découpés à part.
>
> ### Epic 11: Renforcement (V1.1)
> iOS, contrôle d'intégrité de l'app (Play Integrity, parade du risque accepté en D-5), déverrouillage biométrique, filigrane visible, détection d'usages anormaux, preuves de récupération complémentaires, épinglage du certificat, contrôle des saisies contre la source PMU.
> **FRs couvertes :** PRD §6.2 « V1.1 ». Découpage détaillé après le lancement.

**E-5. Stories for Epics 7–10.** These are summaries with their key criteria. Each full story file is written when it starts, as for the earlier epics.

> ## Epic 7: Fondations de sécurité de la plateforme
>
> ### Story 7.1: Mises à jour du serveur sans perte de données (Alembic) — *ex-story 5.4, contenu inchangé*
>
> ### Story 7.2: Passer de SQLite à PostgreSQL
> En tant que porteur de projet, je veux que le serveur stocke ses données dans PostgreSQL, afin que plusieurs services et des données de paiement cohabitent sans risque.
> **Given** la base SQLite de production **When** le job de migration unique tourne **Then** chaque table est copiée et un contrôle compare le nombre de lignes par table **And** les services `api`, `ingestion`, `cotes` et `pronostics` pointent sur PostgreSQL par `DATABASE_URL`.
> **Given** le schéma `comptes` **When** un service de courses s'y connecte **Then** l'accès est refusé (rôles séparés, AD-19).
> **Given** une sauvegarde planifiée **Then** elle est chiffrée, et une restauration de test est documentée dans les notes de la story.
>
> ### Story 7.3: HTTPS et origines autorisées
> **Given** l'API exposée **When** un client l'appelle en HTTP **Then** il est redirigé vers HTTPS (proxy TLS devant `api`).
> **Given** une requête de navigateur depuis une origine non listée **Then** CORS la refuse ; seules la web app et le back-office sont autorisés (`main.py` n'a plus `allow_origins=["*"]`).
>
> ### Story 7.4: Limitation du débit
> **Given** un même compte ou une même adresse IP **When** il dépasse le seuil configuré **Then** l'API répond 429 **And** les routes de code SMS et de paiement ont des seuils plus stricts.
>
> ### Story 7.5: Aucun secret dans les binaires
> **Given** l'APK et le bundle web de production **When** un test cherche les motifs de clés connus (Anthropic, agrégateur, fournisseur SMS) **Then** il n'en trouve aucun **And** les clés ne vivent que dans l'environnement du serveur (`.env`, jamais commité).
>
> ### Story 7.6: Web app compagnon en production
> **Given** la build Flutter Web **When** elle est servie sur son domaine **Then** toutes les routes passent par HTTPS **And** l'absence de cache hors ligne est dite à l'écran **And** une liste de contrôle confirme qu'aucune fonctionnalité n'est propre au web.
>
> ### Story 7.7: Publication sur le Play Store
> **Given** l'app Android signée **When** elle est soumise **Then** la politique de confidentialité est publiée, la fiche respecte les règles Google Play sur les apps liées aux paris (OQ 18), et la décision sur le paiement hors facturation Google Play est consignée.
>
> ## Epic 8: Comptes, connexion et appareils
>
> ### Story 8.1: Créer son compte et se connecter par son numéro
> En tant que turfiste, je veux me connecter avec mon numéro et un code reçu par SMS, afin de ne retenir aucun mot de passe.
> **Given** un numéro valide **When** je demande un code **Then** je le reçois via `otp_client.py` **And** il expire en 5 minutes, 5 essais au plus **And** le message est le même que le numéro ait un compte ou non.
>
> ### Story 8.2: Session sécurisée et renouvellement des jetons
> **Given** une connexion réussie **Then** l'appareil reçoit un jeton d'accès de 15 minutes et un jeton de renouvellement lié à l'appareil, rangé dans le stockage sécurisé.
> **Given** un jeton de renouvellement déjà remplacé **When** il est réutilisé **Then** toutes les sessions de cet appareil sont révoquées (test).
>
> ### Story 8.3: Code PIN et verrouillage
> **Given** une première connexion **Then** je choisis un code PIN de 4 à 6 chiffres **And** il n'est jamais envoyé au serveur (test réseau).
> **Given** l'app passe en arrière-plan ou reste inactive au-delà du délai **Then** elle se verrouille.
> **Given** 5 codes PIN faux **Then** la session locale est effacée et la connexion par code SMS est exigée.
>
> ### Story 8.4: Profil et email de secours
> **Given** mon profil **When** je saisis un email **Then** il reste « non vérifié » jusqu'au clic sur le lien reçu.
>
> ### Story 8.5: Récupérer son compte et changer de numéro
> **Given** un email vérifié **When** je demande un changement de numéro **Then** il prend effet après le délai de sécurité **And** une alerte part vers l'ancien numéro et l'email, avec annulation en un geste **And** mes droits et mes données suivent le compte.
>
> ### Story 8.6: Mes appareils et limite d'appareils
> **Given** mon compte **Then** « Mes appareils » liste chaque téléphone et navigateur, et je peux en retirer un.
> **Given** la limite du palier atteinte **When** un nouvel appareil se connecte **Then** il est bloqué, aucun autre appareil n'est déconnecté, et l'écran propose l'offre Duo ou de retirer un appareil.
>
> ### Story 8.7: Rattacher son ordinateur par QR code
> **Given** la web app non connectée **Then** elle affiche un QR code valable 2 minutes et une seule fois.
> **Given** mon téléphone connecté **When** je le scanne **Then** il affiche le navigateur concerné et demande mon approbation **And** le navigateur rejoint mon compte et compte dans la limite d'appareils.
>
> ### Story 8.8: Retrouver ses sélections et pronostics sur tous ses appareils
> **Given** une sélection, un réglage ou un pronostic retenu créé sur un appareil **When** le réseau est disponible **Then** il apparaît sur mes autres appareils.
> **Given** des changements faits hors ligne **When** le réseau revient **Then** ils sont envoyés ; avant le départ, la dernière version enregistrée l'emporte ; après le gel, rien ne change.
>
> ## Epic 9: Licences, paliers et paiement Mobile Money
>
> ### Story 9.1: Droits datés et organisations
> **Given** un compte **Then** il appartient à une organisation (personnelle par défaut) **And** un droit porte palier, début, fin (UTC) et origine **And** aucun champ booléen « abonné » n'existe (AD-18).
>
> ### Story 9.2: Le serveur filtre selon le palier
> **Given** un compte Turfiste **When** il demande une course **Then** la réponse contient H-60, H-30 et H-15, et **aucun** champ H-10 (test sur la réponse brute).
> **Given** un compte Gratuit **Then** seule la prédiction du matin est renvoyée, avec l'aperçu de FR-40 (nombre de chevaux qui changent, instantané), sans nom, dossard ni probabilité.
> **Given** toute route **Then** une dépendance unique résout le droit actif (AD-15).
>
> ### Story 9.3: Droits disponibles hors ligne
> **Given** un droit actif **Then** l'app conserve une preuve signée (palier, date de fin) **And** hors ligne, les fonctionnalités locales du palier restent ouvertes jusqu'à cette date, jamais au-delà (test d'horloge).
>
> ### Story 9.4: Payer par Mobile Money
> **Given** une offre choisie **When** je paie par MTN MoMo ou Orange Money **Then** `paiement_client.py` initie la transaction et l'écran affiche « en attente de confirmation ».
> **Given** une notification de l'agrégateur **When** sa signature est valide **And** la requête de statut confirme le paiement **Then** un droit est créé une seule fois pour cette référence (test de rejeu).
> **Given** une signature invalide ou un statut non confirmé **Then** aucun droit n'est créé et l'événement est journalisé.
>
> ### Story 9.5: Catalogue des offres
> **Given** les offres (pass journée, pass semaine, mensuel Turfiste et Expert, Duo) **Then** prix et durées viennent de la configuration du serveur, modifiables sans nouvelle version de l'app.
>
> ### Story 9.6: Offre Duo
> **Given** un titulaire Duo **When** il invite un numéro **Then** la personne invitée garde son propre compte et rejoint l'organisation, dans la limite des places **And** le titulaire peut la retirer.
>
> ### Story 9.7: Rapprochement quotidien
> **Given** le job `rapprochement.py` **When** il tourne chaque jour **Then** il liste tout droit actif sans paiement confirmé ni licence manuelle validée (SM-5) **And** un écart déclenche une alerte.
>
> ### Story 9.8: Offres, aperçu et fonctionnalités verrouillées dans l'app
> **Given** un compte Gratuit sur une course **Then** `teaser-banner` montre le changement à H-10 **And** les fonctionnalités payantes affichent `locked-feature` **And** l'écran Offres porte le rappel de jeu responsable, sans promesse de gain.
>
> ### Story 9.9: Quota d'import photo par palier
> **Given** un compte dont le quota est épuisé **When** il lance un import **Then** l'API refuse avant tout appel à `vision_client` **And** le compteur restant est visible avant l'import.
>
> ### Story 9.10: Écrans payants protégés
> **Given** un écran affichant un contenu payant sur Android **Then** capture et enregistrement d'écran sont bloqués (`FLAG_SECURE`).
>
> ## Epic 10: Back-office — rôles et contrôles internes
>
> ### Story 10.1: Accès séparé et double authentification
> **Given** le back-office **Then** il est servi sur son propre domaine **And** chaque compte du personnel exige un second facteur (TOTP).
>
> ### Story 10.2: Rôles agent, superviseur, administrateur
> **Given** un agent **Then** il ne voit que ses propres saisies, aucun pronostic ni aucune licence (test d'accès par route).
>
> ### Story 10.3: Modifications soumises à validation
> **Given** une modification saisie par un agent **Then** elle reste en attente **And** n'entre dans aucun calcul avant la validation d'un superviseur.
>
> ### Story 10.4: Journal d'audit en ajout seul
> **Given** toute création, modification, validation ou licence **Then** une ligne est ajoutée à `journal_audit` **And** le rôle applicatif n'a aucun droit de modification ni de suppression sur cette table (test).
>
> ### Story 10.5: Licence manuelle à quatre yeux
> **Given** un administrateur qui crée une licence hors paiement **Then** un motif est obligatoire **And** la licence n'est active qu'après l'approbation d'une seconde personne.

### 4.5 Sprint tracking — `implementation-artifacts/sprint-status.yaml`

Apply only after approval:
- Move `5-4-mises-à-jour-du-serveur-sans-perte-de-données-alembic` to Epic 7 as `7-1-…`.
- Add `epic-7` to `epic-10` and their stories with status `backlog`. Add `epic-11: backlog`, with no stories yet.
- Add these `action_items` (owner Lazyd, `open`):
  1. « Décider la proposition de changement du 2026-10-18 (Multi) avant d'appliquer celle du 2026-11-15. »
  2. « Lancer la consultation juridique au Cameroun (PRD §9.2, trois volets) — prérequis de mise en vente. »
  3. « Choisir l'agrégateur Mobile Money et le fournisseur de codes SMS (OQ 15, 17). »
  4. « Fixer prix, places Duo, limites d'appareils, délais et quotas (OQ 13, 14). »
  5. « Trancher D-1 : lancer malgré le jalon §10 (source légitime) non atteint. »

## 5. Implementation Handoff

### 5.1 Scope classification: Major

The product's goals, its business model and its security posture change together. A fundamental replan is required before any implementation.

### 5.2 Handoff and sequence

| Step | Who | What |
|---|---|---|
| 0 | Lazyd | Decide the 2026-10-18 proposal; decide D-1 to D-7; start the legal consultation; choose the aggregator and the OTP provider |
| 1 | PM (John), `bmad-prd` | Apply §4.1 to the PRD |
| 2 | Architect (Winston), `bmad-architecture` | Apply §4.2 to the spine, using `security-threat-matrix.md` |
| 3 | UX (Sally), `bmad-ux` | Apply §4.3 and produce the 4 mockups |
| 4 | `bmad-create-epics-and-stories` | Apply §4.4 to `epics.md`; update `sprint-status.yaml` (§4.5) |
| 5 | `bmad-sprint-planning` | Readiness check on Epics 7–10 |
| 6 | Developer, `bmad-build` | Epic 7 → 8 → 9 → 10; Epics 5–6 can restart after story 7.1 |

**Success criteria:**
- the PRD, spine, UX and epics no longer contradict a paid multi-user service;
- the readiness check on Epics 7–10 passes without a high finding;
- **at the paid launch:** the gate in §3 is met, and SM-5 is at zero over the first reconciliations.

### 5.3 Decisions to confirm

| ID | Decision | Cautious default proposed |
|---|---|---|
| **D-1** | Launch paid even though the §10 gate "legitimate data source" is not met (PRD §9.3) | Add the question to the legal consultation; launch only after a favourable outcome; keep the PMU adapter isolated (FR-16) |
| **D-2** | The paid launch does not wait for the Multi (Epics 5–6) | Expert at launch = H-10, combinations, expert engine, larger photo quota; the Multi joins it when ready |
| **D-3** | Day pass = Expert for 24 h; week pass and monthly exist for Turfiste and Expert | As stated |
| **D-4** | Offline entitlement valid until its end date, with no grace period | As stated (FR-44) |
| **D-5** | Features computed on the phone are gated on the phone; a patched APK risk is accepted | As stated (AD-15); the server-gated data remains protected |
| **D-6** | QR pairing direction: the web shows the QR, the signed-in phone scans and approves | As stated (FR-37), like WhatsApp Web |
| **D-7** | The web app has no offline cache (current code) | Accepted: the web app is a companion; the mobile app holds offline mode |

**Outcome (2026-11-15).** The owner accepted D-1 to D-4, D-6 and D-7 as proposed "for now". The owner accepted D-5 on the condition that the risk is not high.

**D-5 risk assessment: low.**
- **Exploiting it is hard.** A Flutter release build compiles Dart to native code, so it cannot be patched like a Java APK. The attacker must reverse the native code, patch it, re-sign it and sideload it. A Play Store install never receives the patched build.
- **What is gained is limited.** A patched app still needs a real account, and it receives only the data the tier allows (AD-15). It unlocks only computations on the data it already holds. The scarce asset, the H-10 snapshot and the snapshots of the paid tiers, never reaches it.
- **It does not scale.** Each patched build must be redistributed by hand, and it breaks at every app update.
- **Added mitigation (V1.1, Epic 11).** **Play Integrity API** attestation: the server refuses to issue or refresh tokens for an app that is not genuine. If abuse is observed before V1.1, this story moves up.
