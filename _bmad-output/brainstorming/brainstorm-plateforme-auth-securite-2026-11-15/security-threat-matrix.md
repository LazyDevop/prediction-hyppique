# Security Threat Matrix — Paid Multi-User Launch (Cameroon)

- **Source:** brainstorming session `brainstorm-plateforme-auth-securite-2026-11-15` (`.memlog.md`, status complete). The current-state column was checked against `backend/app/main.py`, `backend/app/data/repository.py` and `backend/app/data/vision_client.py`.
- **Audience:** system architect updating the architecture spine (`bmad-architecture`).
- **Date:** 2026-11-15

## 1. Intro

The product moves from a single-user, account-less V1 (PRD §9.1) to a **paid, multi-user service**. It launches in Cameroon on Android and a Flutter web app, and payment runs through Mobile Money via an aggregator. This matrix lists the threats raised in the session's reverse-brainstorming step and maps each one to the mitigations and MoSCoW release scope decided in the session.

The session's main conclusion is that internal and external attacks have the same defence: **the server is the only authority**. Entitlements come from the signed payment webhook, responses are filtered by tier, and actions are audited.

**Release key** (session MoSCoW, with the user's final change applied):
- **Must** = launch. The user moved **QR pairing** and the **Duo/Family offer** from Should into Must.
- **Should** = V1.1.
- **Could** = later.
- **Open** = the session found no mitigation.
- Items marked *(proposed)* are not in the memlog. They are suggested here for the architect to decide.

## 2. Assumptions

**Actors**

| Actor | Description | Trust |
|---|---|---|
| Free user | Phone + OTP account. Sees the morning prediction only, plus a blurred teaser ("ranking changed at H-10"). | Untrusted |
| Subscriber | Turfiste tier (H-60/H-30/H-15, value, Kelly, deep history, 2 devices) or Expert tier (adds H-10, Multi/reduced systems, expert engine, photo import with quota). Buys a day pass, week pass or monthly plan. | Untrusted beyond own entitlements |
| Duo/Club member | Duo/Family is a 2–3 person shared plan (Must). Club is B2B2C with seats and roles (manager/members), which needs multi-tenant orgs (Could). | Untrusted. The org manager is trusted only within the org. |
| Data-entry agent | Back-office role. Enters race data and sees only their own entries. Every modification needs validation. Has no access to predictions or licences. | Low internal trust |
| Supervisor | Validates agents' modifications. | Medium internal trust |
| Admin | Manages licences. Can create a manual licence only with a mandatory reason and a second approver (four-eyes). | High trust, still audited |
| External attacker | Scraper, account thief, payment fraudster, network interceptor, or a reseller who republishes predictions (WhatsApp groups). | Hostile |

**Context assumptions**
- One Flutter codebase. The Android app supports offline use at the racetrack. The Flutter web app is used for preparation on a PC. iOS comes in V1.1. There are no desktop installers.
- The phone number is the identity backbone (identity, Mobile Money, OTP, new-device approval). This makes it a **single point of failure**, so email recovery is critical.
- Information leaks cannot be fully prevented. The goal is to make a copy worth less than the original, through **timing** (H-10 to H-2 odds move) and **personalisation** (Kelly stake on the user's bankroll, Multi on the user's own selection).
- A local legal consultation in Cameroon (betting/prediction regulation, PMUC, personal-data law) is a **prerequisite** to monetisation.

## 3. Threat matrix

### 3.1 Content leakage

| ID | Threat (attacker + action) | Asset at risk | Current state in code | Mitigation(s) | Release | Residual risk |
|---|---|---|---|---|---|---|
| CL-1 | An Expert subscriber takes H-10 screenshots and resells them in a WhatsApp group. | Paid predictions (H-10), revenue | No tiers, no paywall. All prediction routes are public. | Block screen capture/recording on paid screens (FLAG_SECURE on Android, detection on iOS). The value of H-10 decays fast (odds move, the app recalculates live, a copy is frozen). Personalised outputs (Kelly, Multi, expert settings). | Must | Medium. A second phone can still film the screen, and the user accepts some residual leakage. |
| CL-2 | A user films a friend's subscribed phone and shares the video. | Paid predictions | Same as CL-1. | Semi-visible watermark (logo + short account ID) that survives filming, traces the leaker and acts as advertising. | Should | Medium. Leakage persists, but the source becomes traceable. |
| CL-3 | A leaker copies predictions on paper and posts them. | Paid predictions | n/a | No technical defence possible. Rely on timing decay and personalisation. Turn the reseller into a distributor through an affiliate programme for WhatsApp group admins. | Could (affiliation) | Accepted. Goal: the subscription stays more convenient than a second-hand copy. |
| CL-4 | Leaked screenshots cannot be traced to an account. | Evidence for suspension | n/a | Invisible per-account watermark on prediction screens. | Could | Medium until shipped. The visible watermark (Should) covers part of this. |
| CL-5 | A client-side bypass reveals data that is only hidden in the UI (e.g. an H-10 field masked in Flutter). | Paid predictions | The API returns full payloads. There is no tier filtering. | The server returns only what the tier allows. Masked fields must not be present in the payload at all. | Must | Low |

### 3.2 Account sharing and takeover

| ID | Threat (attacker + action) | Asset at risk | Current state in code | Mitigation(s) | Release | Residual risk |
|---|---|---|---|---|---|---|
| AS-1 | A subscriber opens the web account on many browsers or devices at the same time. | Licence revenue | No accounts or sessions exist. | **Every browser session counts as a device.** The licence allows N devices (e.g. 1 PC + 1 phone). Over the limit, the **new device is blocked and the Duo offer is shown**. This replaces the earlier "disconnect the oldest session" idea. "My devices" screen with remote revocation. | Must | Low/medium. A holder can still collude manually (see AS-2). |
| AS-2 | Someone uses another subscriber's credentials. | Account, licence | No auth. | Phone + OTP login. A new device needs an OTP sent to the holder's phone, plus a notification. Borrowing therefore needs the holder's active help every time. Duo/Family plan turns friendly sharing into revenue. | Must | Low. Remaining abuse needs collusion. |
| AS-3 | Unusual use: the same account in two distant cities or IPs, or frequent device rotation. | Licence | n/a | Anomaly detection: alert, then block. | Should | Medium until shipped |
| AS-4 | Someone takes over a shared or stolen phone while the app is open. | Session, entitlements | No session. | Local PIN (4–6 digits) unlocks a session token kept in Android Keystore / iOS Keychain. **The PIN never leaves the device.** Auto-lock after X minutes of inactivity and whenever the app goes to the background. After 5 wrong PINs, the local session is wiped and a fresh OTP login is required. Biometrics are optional. | Must (biometrics: Should) | Low |
| AS-5 | An attacker steals or replays a token (refresh token exfiltrated). | Session | No tokens. | 15-minute access token. Refresh token bound to the device and rotated on every use. **Reuse of a refresh token counts as theft and revokes the whole token chain.** | Must | Low |
| AS-6 | A fraudster changes the account's phone number (social engineering, email recovery abuse). | Account, identity backbone | n/a | Verified email in the profile. A number change via email has a 24–48 h delay, sends an alert to the old number and to the email, and can be cancelled in one click. | Must | Medium. Depends on the security of the user's email. |
| AS-7 | A recovery attacker lacks ownership proof. A legitimate user loses both phone and email. | Account | n/a | Extra proof of ownership: reference of a past Mobile Money subscription transaction. One-time backup codes issued when a paid account is activated. | Should | Medium until shipped. Lockout and support load are possible. |
| AS-8 | An attacker performs a SIM swap or intercepts the SMS OTP, then logs in as the holder. | Account, identity | n/a | Not covered in the memlog. *(Proposed)* Treat a phone-number re-registration as a new device. Use the notification and delay from AS-6. Prefer WhatsApp OTP where possible. Rate-limit OTP sends and attempts. | Open | **High**. The phone number is the single point of failure. |
| AS-9 | QR pairing is abused: a phishing or relay QR pairs the attacker's device to the victim's account, or a QR is photographed and replayed. | Account, device slots | No pairing exists. | QR pairing (WhatsApp Web style) is in Must. Its security design is not in the memlog. *(Proposed)* Short-lived single-use pairing token. The already-authenticated device must confirm explicitly. The new device appears in "My devices" and counts against the limit. | Must | Medium until the pairing protocol is specified |

### 3.3 Payment fraud

| ID | Threat (attacker + action) | Asset at risk | Current state in code | Mitigation(s) | Release | Residual risk |
|---|---|---|---|---|---|---|
| PF-1 | A modified client forges a payment confirmation ("paid = true"). | Entitlements, revenue | No payments, no entitlements. | **The app never confirms a payment.** Only the aggregator's signed webhook activates an entitlement, after signature verification and a callback to the status API. | Must | Low |
| PF-2 | An attacker replays a webhook or the aggregator delivers it twice, granting duplicate entitlements. | Entitlements | n/a | Idempotency keyed on the transaction reference. | Must | Low |
| PF-3 | **MoMo chargeback:** a user pays a pass by Mobile Money, disputes or reverses it with the operator, and keeps access. | Revenue | n/a | **OPEN. The memlog lists this attack (line 68) but no mitigation.** *(Proposed for decision)* Subscribe to the aggregator's reversal/refund events and revoke dated entitlements when one arrives. Include reversals in the daily reconciliation. Keep a per-phone fraud flag that blocks future purchases. Check what the aggregator contract says about dispute handling. | Open | **High** until decided |
| PF-4 | Licences exist without a matching payment (bug, insider or forged grant). | Revenue | n/a | Daily reconciliation of active licences against payments received. Any licence without a payment stands out. | Must | Low |
| PF-5 | An attacker exhausts the photo-import budget (Anthropic API cost per call). | Operating cost | `/extraction/*` is public. There is no quota. The key is server-side only. | Monthly photo-import quota per tier. Rate limiting. | Must | Low |
| PF-6 | A pass is used beyond its validity window. | Revenue | n/a | Dated entitlements (start/end) instead of an "is subscriber" boolean. The server checks the date on every request. | Must | Low |

### 3.4 API abuse and scraping

| ID | Threat (attacker + action) | Asset at risk | Current state in code | Mitigation(s) | Release | Residual risk |
|---|---|---|---|---|---|---|
| AA-1 | An attacker calls the API directly to scrape predictions without paying. | Paid predictions, data | **No auth on any router** (courses, chevaux, analyse, dashboard, pronostics). | Every paid route checks the token **and** the entitlement (tier + date) on the server. A modified APK unlocks nothing. | Must | Low |
| AA-2 | Bulk scraping by a valid account or by IP. | Data, infrastructure | No rate limiting. | Rate limiting per account and per IP. | Must | Medium. Slow, distributed scraping by a paying account remains possible (see AS-3). |
| AA-3 | A malicious website calls the API from a victim's browser (cross-origin). | Sessions, data | `CORSMiddleware(allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])` | Restrict CORS to the web app origin. | Must | Low |
| AA-4 | Anonymous enumeration through the free tier. | Data | Free tier does not exist yet. | Free tier returns the morning prediction only, read-only. The teaser is computed on the server and contains no H-10 data. | Must | Low |

### 3.5 Injection and data theft

| ID | Threat (attacker + action) | Asset at risk | Current state in code | Mitigation(s) | Release | Residual risk |
|---|---|---|---|---|---|---|
| ID-1 | SQL injection through API parameters. | DB (accounts, payments, predictions) | SQLAlchemy ORM and parameterised `text()`. The only f-strings are migration `ALTER TABLE ... ADD COLUMN {nom}` statements on internal hard-coded names. | Keep ORM/bound parameters only. Never build SQL with f-strings from external input. | Must (continuing rule) | Low |
| ID-2 | An attacker accesses account, transaction and prediction data in one store. | PII, payments | A single SQLite file `sqlite:///./hippique.db` holds everything. | Migrate SQLite to PostgreSQL. Put accounts and payments in a separate database or schema with minimal-privilege access. Encrypted backups. Store only what is strictly needed: no card numbers, never a PIN on the server. | Must | Low/medium. Depends on host hardening. |
| ID-3 | An attacker breaches the back office and reaches user or licence data. | PII, licences | No back office or roles exist. | Back office on a separate domain with restricted access. Mandatory 2FA for agents, supervisors and admins. | Must | Low |

### 3.6 Transport interception

| ID | Threat (attacker + action) | Asset at risk | Current state in code | Mitigation(s) | Release | Residual risk |
|---|---|---|---|---|---|---|
| TI-1 | An attacker intercepts traffic or transactions on a network (racetrack Wi-Fi, ISP). | Tokens, OTPs, payment data | No TLS termination is configured in the app code (deployment concern). | HTTPS/TLS everywhere. | Must | Low |
| TI-2 | A user-installed CA or proxy lets someone inspect or modify mobile traffic (reverse-engineering the API, tampering with responses). | API contract, tokens | n/a | Certificate pinning in the mobile app. | Should | Medium until shipped. Server-side authority (AA-1) limits the impact. |

### 3.7 Secrets

| ID | Threat (attacker + action) | Asset at risk | Current state in code | Mitigation(s) | Release | Residual risk |
|---|---|---|---|---|---|---|
| SE-1 | An attacker extracts API keys from the APK or web bundle. | Anthropic, payment-aggregator and SMS/OTP keys | The Anthropic key is server-side only: `ANTHROPIC_API_KEY` is read from env in `vision_client.py` (rule AD-3). No other keys exist yet. | Extend AD-3: no secret in any client build. This covers the aggregator, SMS/WhatsApp OTP and webhook-signing keys. | Must | Low |
| SE-2 | Webhook signing secret is leaked or weak, allowing forged payment events. | Entitlements | n/a | Keep the secret server-side only. Combine signature verification with a callback to the status API, so a valid signature alone is not enough. | Must | Low |

### 3.8 Insider threats

| ID | Threat (attacker + action) | Asset at risk | Current state in code | Mitigation(s) | Release | Residual risk |
|---|---|---|---|---|---|---|
| IN-1 | A data-entry agent generates predictions to resell them. | Paid predictions | No roles. | RBAC with least privilege: an agent can only enter data, with no access to predictions or licences. An agent sees only their own entries. | Must | Low |
| IN-2 | An agent or admin creates licences and resells them. | Revenue | No roles. | Licences are created **only** by the payment webhook. A manual grant is admin-only, needs a mandatory reason and a second approver (four-eyes). Append-only audit log. Daily reconciliation against payments (PF-4). | Must | Low |
| IN-3 | An agent falsifies a data point (rank, weight, ground) to manipulate a horse's prediction and bet against the market. | Prediction integrity, reputation | No validation workflow. | Every modification needs supervisor validation before it applies. Traceability per agent through the audit log. Automatic comparison of entries against the PMU source data. | Must (validation, audit); Should (PMU comparison) | Medium until PMU comparison ships. A supervisor could collude. |
| IN-4 | Someone tampers with the audit trail. | Accountability | No audit log. | Append-only (tamper-evident) audit log of who created or changed what, and when. | Must | Low/medium. Depends on DB-admin separation. |

### 3.9 Data protection and legal

| ID | Threat (attacker + action) | Asset at risk | Current state in code | Mitigation(s) | Release | Residual risk |
|---|---|---|---|---|---|---|
| DP-1 | The paid service breaks Cameroonian betting or prediction regulation (PMUC). | Business continuity | n/a | Local legal consultation as a **prerequisite** to launch, then country by country (PRD §9.3/§10). | Must (prerequisite) | **High** until the consultation is done |
| DP-2 | Personal data (phone, email, payment references, device and IP data) is handled without the required declaration, consent or retention policy. | PII, legal exposure | No PII is stored today. | Check the applicable Cameroonian data-protection law (declaration, consent, retention) as part of the legal consultation. Data minimisation (ID-2). | Must | Medium until the legal review is done |
| DP-3 | App-store policy rejects a betting-related app, or store billing rules are breached. | Distribution | n/a | Mobile Money is sold outside the store. Check the store policies for betting-related apps. In-app store purchases only for international markets. | Must (verify); Could (in-app international) | Medium |

## 4. Architecture invariants implied

1. **The server is the sole authority for entitlements.** The client renders what the server sends. It never decides what is unlocked.
2. **Entitlements come only from a verified payment event**: signed aggregator webhook, plus a status-API callback, plus idempotency on the transaction reference. The one exception is an audited, four-eyes, admin-only manual grant with a mandatory reason.
3. **Entitlements are dated** (start/end, tier). They are checked on every request, not cached as a boolean on the client.
4. **Tier filtering happens on the server.** Payloads contain no fields above the caller's tier.
5. **The PIN never leaves the device.** It only unlocks a token kept in Keystore/Keychain.
6. **Every browser session counts as a device.** The device limit applies across mobile and web. Over the limit, the new device is blocked and the Duo offer is shown.
7. **Tokens:** 15-minute access token. Refresh token bound to the device and rotated on each use. Reuse revokes the whole token chain.
8. **No secrets in any client build** (APK, IPA, web bundle). This is AD-3 extended to the payment aggregator, SMS/OTP and webhook keys.
9. **Accounts and payments live in a separate database or schema with least-privilege access**, on PostgreSQL. No card data, no PIN, and minimal PII on the server.
10. **The back office is isolated** (separate domain, mandatory 2FA, RBAC agent/supervisor/admin). Every modification needs validation before it applies. Audit log is append-only.
11. **Multi-tenant-ready data model** (organisation, seats, roles) from day one, even though the Club tier is Could. Duo/Family (Must) needs shared entitlements.
12. **CORS is an explicit allowlist. TLS is used everywhere. All SQL uses bound parameters.**
13. **Reconciliation is a scheduled job:** active licences against payments received (and reversals, once PF-3 is decided).

## 5. Open items to verify

1. **MoMo chargeback/reversal (PF-3):** no mitigation was decided. Confirm the aggregator's reversal webhooks and dispute process, then define the revocation policy.
2. **SIM swap / OTP interception (AS-8):** not discussed. Decide what a number re-registration triggers and set OTP rate limits.
3. **QR pairing protocol (AS-9):** now Must, but its security design is unspecified (token lifetime, single use, confirmation on the authenticated device).
4. **Duo/Family entitlement model:** now Must. Define whether members have separate accounts sharing one entitlement or one account with more devices, and how the device limit applies per member.
5. **Choice of Mobile Money aggregator** (CinetPay / Campay / Notch Pay / Flutterwave): confirm that it signs webhooks, offers a status API and provides reversal events.
6. **Legal consultation in Cameroon:** prediction-service regulation and PMUC, data-protection law, consent and retention. It blocks launch.
7. **App-store policy** for a betting-related Android app distributed with payment outside the store.
8. **Screen-capture blocking on the Flutter web app:** FLAG_SECURE has no web equivalent. Decide what web protection is acceptable (watermark only?).
9. **Offline mode against server authority:** define what paid content may be cached on the device for racetrack use, how long it stays valid, and how it is protected at rest.
10. **The current API is fully open.** Until auth ships, decide whether the existing deployment must stay private (network-restricted) to avoid leaking paid content before launch.
11. **Migration SQLite to PostgreSQL:** the migrations in `repository.py` use SQLite-specific code (PRAGMA, `sqlite_insert`, table rebuilds) that must be ported.
