---
title: Brainstorm intent — Platform, accounts, auth & security (paid service)
date: 2026-11-15
source: _bmad-output/brainstorming/brainstorm-plateforme-auth-securite-2026-11-15/.memlog.md
status: final
---

# Brainstorm Intent: Platform, Accounts, Auth & Security

## 1. Context / Why

- **The service is paid.** It needs a usage licence, so it cannot run without user accounts. This **reverses PRD §9.1** (V1 single-user, free, no account; V2 gated on monetization and legal review).
- Current state that conflicts with this: the PRD and architecture assume a single user with no account. The backend has no auth (only the Anthropic key is protected, AD-3). Storage is SQLite (`hippique.db`). CORS is `allow_origins=['*']`. The back-office brief already implies data-entry agents, so multiple users with roles.
- Persona driver: the punter selects races when the programme loads, prepares in advance, re-runs predictions at each odds snapshot (H-60/H-30/H-15/H-10), then bets at the counter. They switch freely between phone and PC, so **cross-device continuity** is required.
- Required downstream: **bmad-correct-course**, then **bmad-prd update** and **bmad-architecture update**.

## 2. Market

Launch in **Cameroon**, then the rest of **Africa**, then the **rest of the world**. Cameroon sets the defaults:
- Android dominates. Mobile Money is the main payment method; cards and store in-app purchases are marginal.
- People are used to prepaid micro-payments.
- Mobile data is expensive and phones are low-end, so the app needs offline mode, a light footprint and compressed payloads.

## 3. Platforms

- One Flutter codebase.
- **Android app first.** It is the complete product: a punter with no computer prepares, re-runs predictions and decides entirely on the phone. It works offline, for use at the racecourse.
- **Flutter Web app** as an optional companion for punters who prefer to prepare on a PC. It must never hold a feature the mobile app lacks.
- iOS comes second (V1.1).
- **No desktop installers** (Windows/macOS/Linux).
- Out of scope: issuing or validating bets. The app helps the user decide, and the bet is placed at PMU or another operator.

## 4. Tiers

| Tier | Content |
|---|---|
| **Free** | Morning prediction only, read-only. Teaser: blurred "odds moved / ranking changed at H-10" (upgrade lever). |
| **Turfiste** | Snapshots H-60 / H-30 / H-15, value, Kelly, deep history, 2 devices, photo-import quota. |
| **Expert** | Everything in Turfiste, plus the **H-10 snapshot (Expert only)**, Multi and reduced systems, combinations for 10 bet types, expert engine with sliders, and a higher photo-import quota. |
| **Duo / Family** | 2–3 people, cheaper than separate subscriptions. Turns friendly account sharing into revenue. |
| **Club (B2B2C)** | Resale through clubs or PMU bars. Organization accounts with seats and roles (manager/members). Multi-tenant. |

- **Billing periods:** day pass (Expert access for 24 h, for big days such as Quinté or the Arc), **week pass**, and monthly subscription.
- **Entitlements are dated** (start/end, tier). There is no "subscribed" boolean.
- The data model must be **multi-tenant (organizations) from day one**.
- **Photo-import quota per tier.** Each call costs Anthropic API money, so the quota protects revenue and the API budget.

## 5. Payment

- **Cameroon:** Mobile Money (MTN MoMo, Orange Money) through **one aggregator** (candidates: CinetPay, Campay, Notch Pay, Flutterwave). Purchase starts in the app but **outside the store's payment system**. This **replaces** the earlier hybrid in-app plan for Cameroon.
- **International (later):** store in-app purchases may be offered. Stores take 15–30%, and rules on outbound links and betting-related apps vary by country.
- **Only the signed aggregator webhook activates an entitlement.** The server verifies the signature, then calls the status API back to confirm. Processing is idempotent on the transaction reference. The app never confirms a payment.
- **Daily reconciliation** of active licences against payments received.
- Known threat: chargeback/refund abuse (pay by MoMo, dispute the payment, keep access). No countermeasure was decided in the session (see open items).

## 6. Auth & Session

- **Identity:** phone number plus OTP (SMS/WhatsApp). No email/password login. This matches how Mobile Money works.
- **Profile email (verified)** is used for account recovery and phone-number change.
- **Phone-number change by email:** 24–48 h security delay. An alert goes to the old number and to the email, and the change can be cancelled in one click.
- **Extra ownership proofs:** the reference of a past Mobile Money subscription transaction, plus one-time **backup codes** issued when a paid account is activated.
- **Local PIN (4–6 digits)**, with optional biometrics.
  - Auto-lock after X minutes of inactivity and every time the app goes to the background.
  - The PIN unlocks a session token stored in Android Keystore / iOS Keychain. **The PIN never reaches the server.**
  - After 5 wrong PINs, the local session is wiped and a new OTP login is required.
- **Tokens:**
  - Access token: short-lived (15 min).
  - Refresh token: **bound to the device** and rotated on every use.
  - A reused refresh token counts as theft and revokes the whole chain.
- **Devices:**
  - A **"My devices"** screen lists paired devices and allows remote revocation (lost or stolen phone).
  - **Every browser session counts as a device.**
  - A **new device** requires an OTP sent to the holder's phone, plus a notification.
  - **Over the device limit, the new device is blocked and the Duo offer is shown.** This replaces "disconnect the oldest session".
- **QR-code pairing** works like WhatsApp Web: the PC shows a QR code, the phone pairs to the account, and the device counts toward the licence limit.
- **Server-side sync** of race selections and kept predictions between devices.

## 7. Anti-Leak

The principle: a leak cannot be prevented, so the goal is to make the copy worth less than the original. Some leakage is accepted; the subscription just has to stay more convenient than a second-hand video.
- **Timing defence.** The value sits in H-10 to H-2. By the time a copy is written down and shared, the odds have moved. The app recalculates live, while the copy is frozen.
- **Personalisation defence.** Kelly stakes are computed on the user's own bankroll, Multi on their own selection, and the expert engine on their own settings. A generic copy is worth less.
- **Block screen capture and recording** on paid screens (`FLAG_SECURE` on Android, detection on iOS). This stops the easiest kind of sharing, though not filming with a second phone.
- **Semi-visible watermark** (logo plus a short account ID). It survives filming, traces the leaking subscriber, and turns the leak into advertising.
- **Invisible per-account watermark.** It identifies the source of a shared screenshot and gives evidence for a suspension.
- **Anomaly detection:** simultaneous use from distant cities or IPs, or frequent device rotation. The response is an alert, then a block.
- **Affiliate programme** for WhatsApp group admins (referral code plus commission), so the reseller becomes a distributor.

## 8. Technical Security

- **The server is the only authority.** Every paid route checks the token and the entitlement (tier and date) on the server. A modified APK unlocks nothing.
- **Tier-filtered responses.** The server never sends a field the tier does not allow, so there is no hidden H-10 data on the client.
- **Rate limiting** per account and per IP, to stop scraping.
- **Restrict CORS** (currently `*`).
- **HTTPS/TLS** everywhere, plus **certificate pinning** in the mobile app.
- **SQL injection:** the risk is low because the backend uses the SQLAlchemy ORM. The only f-strings are internal `ALTER TABLE` migrations. Keep it that way.
- **Data:**
  - **Migrate SQLite to PostgreSQL.**
  - Accounts and payments go in a separate database or schema with minimal access.
  - **Encrypted backups.**
  - Store only what is strictly needed: no card numbers, and no PIN on the server.
- **Secrets:** no keys in the APK. Extend AD-3 to the payment aggregator and SMS/OTP provider keys.

## 9. Back-Office / Insider Controls

- **The back-office is separate** from the user app: its own domain, restricted access, and **mandatory 2FA** for staff.
- **RBAC with least privilege:**
  - **Agent:** data entry only. Sees only their own entries and has no access to predictions or licences.
  - **Supervisor:** approves changes.
  - **Admin:** manages licences.
- **Every change needs approval** before it is applied.
- **Licences are created only by the payment webhook.** A manual licence (commercial gesture) is admin-only, needs a mandatory reason, and needs approval by a second person (**four-eyes**).
- **Append-only, tamper-evident audit log** (who, what, when). Combined with the daily reconciliation, any licence without a payment stands out.
- **Data-tampering defence:** an agent could falsify rank, weight or going to manipulate a horse's prediction and bet against the market. Defences are traceability per agent, mandatory approval, and **checking entries against the PMU source**.

## 10. Legal Prerequisites (blocking for monetization)

- **Local legal consultation in Cameroon** before any paid model (PRD §9.3/§10). Topics:
  - rules on gambling and horse-racing tips, including the PMUC position;
  - **personal-data law** (filing with the authority, consent, retention).
- Run it **in parallel** with the accounts work, then repeat it country by country for each expansion.

## 11. Launch Scope (MoSCoW)

**MUST: paid launch in Cameroon**
- Prerequisite: Cameroon legal consultation.
- Android app plus web app.
- Phone + OTP account, PIN with auto-lock, secure tokens (short access token, rotating refresh token bound to the device, reuse means revocation).
- Verified email, and recovery with delay and alert.
- "My devices", with the new device blocked over the limit.
- **QR-code pairing.**
- **Duo offer.**
- Server-side sync of selections and kept predictions.
- Free / Turfiste / Expert tiers, plus the H-10 teaser.
- Day pass, week pass and monthly subscription.
- Dated entitlements and photo quota per tier.
- Mobile Money through one aggregator: signed webhook, status callback, idempotency, daily reconciliation.
- Server-side access control, tier filtering, rate limiting, restricted CORS, HTTPS.
- PostgreSQL, secrets kept out of the APK, encrypted backups.
- Screen-capture blocking.
- Back-office:
  - agent/supervisor/admin roles, with agents seeing only their own entries;
  - approval before changes;
  - audit log;
  - staff 2FA;
  - manual licence with reason and four-eyes.

**SHOULD (V1.1)**
- iOS.
- Biometrics.
- Visible watermark.
- Anomaly detection.
- Mobile Money proof plus backup codes.
- Certificate pinning.
- Entries compared against the PMU source.

**COULD (later)**
- Club tier (B2B2C).
- WhatsApp-admin affiliate programme.
- Invisible watermark.
- Store in-app payments for international markets.
- Expansion to the rest of Africa.

**WON'T (this time)**
- Desktop apps (Windows/macOS/Linux).
- Bet ticket issuing or validation.

Note: the data model must still be multi-tenant and support dated entitlements at launch, even though Club is COULD.

## 12. Open Items to Verify

1. Results of the Cameroon legal consultation (tipping rules, PMUC, data protection). These block monetization.
2. Choice of Mobile Money aggregator (CinetPay / Campay / Notch Pay / Flutterwave): webhook signatures, status API, how refunds and chargebacks are reported.
3. Google Play and Apple policies on betting-related apps and on Mobile Money payments outside the store.
4. SMS vs WhatsApp OTP provider (cost and deliverability in Cameroon).
5. Prices for each tier and pass, and Duo pricing and seat count (2 or 3).
6. Device limit per tier, inactivity lock delay (X), and photo quota values.
7. How well screen-capture detection works on iOS.

## 13. Key Synthesis Insights

1. **The account does three jobs at once:** licensing, PC↔phone continuity, and fraud prevention.
2. **The phone number is the backbone.** It carries identity, Mobile Money, OTP and new-device approval, which also makes it a single point of failure. Email recovery, the delay with alert, and backup codes are therefore critical.
3. **The anti-leak strategy is the product strategy.** Timing (H-10 for Expert only) and personalisation are both the paywall and the defence against copying.
4. **Insider and outsider attacks share one defence:** the server is the only authority (webhook-only entitlements, tier filtering, audit, approvals).
5. **Big gap with what exists today:** the PRD and architecture are single-user with no account, the backend has no auth, and storage is SQLite. This needs correct-course, then updates to the PRD (§9.1 reversed, tiers, payment, legal) and the architecture (auth, entitlements, multi-tenancy, PostgreSQL, back-office RBAC).
