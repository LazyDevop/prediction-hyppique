# Review — Architecture spine update of 2026-11-15

- **Target:** `ARCHITECTURE-SPINE.md` (updated 2026-11-15: new AD-15..AD-21; amended AD-2, AD-3, AD-6, AD-7, AD-9, AD-10..AD-14).
- **Context read:** PRD §4.12–§4.15 (FR-31..FR-53, FR-39 matrix), `security-threat-matrix.md`, `sprint-status.yaml` (Epics 7–11 story list).
- **Code reality-checked:** `backend/app/main.py`, `docker-compose.yml`, `mobile/lib/data/local/database_helper.dart`, plus `backend/app/data/models.py`, `api/routes_pronostics.py`, `api/routes_dashboard.py`, `jobs/cotes_instantanees.py` (to confirm ownership claims).
- **Date:** 2026-11-15. Review only — the spine was not edited.

## Verdict

The update is directionally sound (server authority, dated entitlements, signed webhook, separate schemas, audit chain) and covers most of FR-31..FR-53, but it leaves two build-incompatibility traps that will split Epic 9/11 and Epic 5 stories — which probability set is "active" today, and whether Duo members own `droit` rows — plus ten high-severity holes around the offline entitlement token, offline sync, cache tiering, entity ownership and the edge. None requires a new paradigm; each is a one- or two-sentence tightening of an existing AD.

**Counts:** 2 critical, 10 high, 19 medium, 11 low.

---

## Critical

### C-1 — AD-14 status vs FR-53 / AD-6: "active probability set" is undefined today, and the recommendation identity cannot tell sets apart

- **ADs:** AD-14 (Status 2026-11-15, Display, Downstream), AD-6, AD-12, AD-10.
- **Pair that builds incompatibly:**
  - *Story 11.x (published forecast in the app)* reads FR-53 ("the published forecast is what the user sees by default") and the AD-14 status ("produced by `pronostics` as the reference set under evaluation") and makes the published ML set the default input of value, Kelly and the Multi on the phone.
  - *Story 5.x (Multi screen) / daily Multi log* reads AD-14's own condition clause ("until then AD-2 and AD-6 apply unchanged: both engines compute the same scoring, and the phone always computes locally") and feeds the Multi from the Dart scoring engine; the backend daily log (AD-10) feeds it from the Python scoring core.
  - Result: the user sees a Multi built on ML H-30 probabilities while `recommandation_multi` logs one built on the scoring engine; SM-4 measures something the user never saw. Neither story violates a word of the spine.
- **Second-order hole:** the AD-12 recommendation identity (race key, Multi engine version, catalogue version, rules hash, parameters hash, data timestamp) has no field for the probability source. A `recommandation_consultee` computed from the published H-30 set and one computed from the expert engine are indistinguishable, so the debrief and the evaluation cannot be joined correctly.
- **Fix:**
  1. Split AD-14 into two gates. **Gate A (active now):** the Display and Downstream bullets apply whenever a race has a published forecast — the published set (latest horizon allowed by the tier) is the default active set; the expert engine is the labelled alternative and the fallback. **Gate B (the benchmark condition):** only governs removing the « modèle en cours d'évaluation » label, calling it the "reference", and the Review trigger.
  2. Add `source_probabilites` to the AD-12 recommendation identity: `{"type": "publie", "modele_version", "horizon"}` or `{"type": "expert", "parametres_hash"}`; store it in `recommandation_multi` and `recommandation_consultee`.
  3. State in AD-10 which set the daily Multi log uses (recommended: the published forecast of the horizon closest to `MULTI_JOURNAL_AVANCE_MINUTES`, read from the forecast table, never recomputed), so the logged forecast is the one an Expert user was shown.

### C-2 — Duo: who owns a member's `droit` (AD-17 / AD-18 vs PRD FR-43 and SM-5)

- **ADs:** AD-17 (only two creation paths for `droit`), AD-18 ("holder's `droit` applies to every member"), AD-15 resolver, AD-17 reconciliation.
- **Pair that builds incompatibly:**
  - *Story 9.6 (Duo)* follows FR-43 literally ("chaque membre reçoit un droit du palier du titulaire, aux mêmes dates") and inserts one `droit` row per member. Those rows have no payment reference and no manual licence → *story 9.7 (reconciliation)* flags every Duo member as an orphan every day (SM-5 ≠ 0), and AD-17's "a `droit` is created only by (a) webhook or (b) manual licence" is broken.
  - *Story 9.1 (dated entitlements and organisations)* follows AD-18 and derives the member's tier from the organisation's holder `droit`. The two stories produce different tables and a different resolver.
- **Second hole:** an account "belongs to an organisation (a personal one by default)". A user who already holds a personal Turfiste month and joins an Expert Duo either leaves the personal organisation (losing a paid `droit`) or belongs to two organisations — AD-18 does not say which, nor how the active tier is chosen.
- **Fix (AD-18):** "`droit` rows exist only for the payer (holder or personal account) and are created only by AD-17's two paths. Membership is a `membre` row (organisation, compte, added_at, removed_at). Every account keeps its personal organisation and may be a member of at most one shared organisation. The active tier is the highest tier among the valid `droit` of its personal organisation and of the shared organisation it is a current member of. Removing a member or expiry of the holder's `droit` is a change to `membre`/`droit` only — no member `droit` row is ever written or deleted." Add to AD-17's reconciliation: Duo seats are checked as `membre` count ≤ the seat count of the holder's offer. Update the PRD FR-43 wording on the next PRD pass ("chaque membre bénéficie du droit du titulaire").

---

## High

### H-1 — AD-15 offline entitlement token: no revocation horizon, no clock defence, no shared signing algorithm

- **ADs:** AD-15, AD-16, AD-21.
- **Holes:**
  - "Trusted offline until its end date" — the end date is the `droit` end. A device removed from "Mes appareils" (FR-36), a removed Duo member (FR-43) or a future refund (PF-3) keeps offline paid features until the end of the month, because nothing shortens the token.
  - The offline check uses the device clock; setting the phone date back extends a lapsed token indefinitely on cached races (no APK patch needed, so not covered by D-5).
  - The token is verified in Dart offline and signed in Python. If story 8.2 reuses the access-token JWT with HS256, the verification secret ships in the APK — a direct AD-21 violation and a forgeable entitlement. No algorithm or key-handling rule exists.
  - Not bound to the `appareil`: a token copied from one phone unlocks another install.
- **Fix (AD-15):** "The entitlement token is an asymmetric signature (Ed25519 or ES256; only the public key ships in the app) over {compte, appareil, tier, droit end, issued_at, expires_at}, with `expires_at = min(droit end, issued_at + ENTITLEMENT_TOKEN_MAX_DAYS)` (default 7). The app stores the highest server time it has seen and treats the token as expired if the device clock is earlier than that time or later than `expires_at`. Any authenticated response carries the current entitlement version; on change the app fetches a new token (covers FR-42 'late confirmation shown without restart'). A token whose `appareil` differs from the local device id is ignored." Add the signing library on both sides to Stack as [TO VERIFY] at story 9.3.

### H-2 — AD-9 account sync refuses exactly the forecasts the offline journey creates

- **ADs:** AD-9 (Account sync), AD-12, AD-15.
- **Hole:** the core offline journey (retain a forecast at the racecourse with no network) produces a local row that reaches the server only after the network returns — usually after departure. AD-9 refuses it, and "the device shows the frozen copy". Story 8.8 can read that as "replace the local row with the server's frozen version" (which is an older version from another device, or nothing), destroying the only debrief source (FR-30); story 5.x (debrief) keeps reading the local row. Two incompatible behaviours, both compliant.
- **Fix (AD-9):** "A version refused for arriving after departure is never deleted locally: it is kept with `synchronise = false, motif = 'recu_apres_depart'`. If the server holds a pre-departure version, the device displays the server version and keeps its own as a non-authoritative local note; if the server holds none, the local version stays the device's debrief source and is shown as 'not synced'. The server never accepts a device-supplied timestamp as proof of pre-departure retention." Also state that sync of Multi rows is accepted only while the account's tier allows the Multi, and that rows already on the server survive a downgrade (FR-39 "sans perte").

### H-3 — AD-9 race cache vs AD-15 / FR-44: cached payloads carry no tier

- **ADs:** AD-9 v2 (`partants_course`, `multi_contexte`), AD-15, AD-6, AD-14.
- **Hole:** the cache stores "the runners payload last received" and the Multi context. An Expert's cache contains H-10 forecasts and the Multi context; after expiry FR-44 requires hiding them, but the cache row does not say which fields were paid nor under which tier it was fetched. Conversely, a Turfiste who upgrades has cached payloads lacking H-10/Multi and will show "no Multi" offline. Story 9.3 (offline entitlements) and story 5.x (race cache) will each invent a different marker.
- **Fix (AD-9 + AD-15):** "Every cached race payload stores `palier_recu` (the tier under which the server built it). The app displays a cached field only if both the current token tier and `palier_recu` allow it (FR-39 matrix, mirrored as one Dart table generated from or validated against a shared `fixtures/acces_paliers.json`, AD-2 runtime-mirror pattern). A tier increase invalidates the cached payload for refetch at next network access." The shared matrix file also closes the risk of the server filter (9.2) and the app lock table (9.8) drifting.

### H-4 — AD-19 schema roles vs AD-17 reconciliation and AD-20 back-office

- **ADs:** AD-19, AD-17, AD-20, AD-10.
- **Hole:** "only `api` (and the back-office) can read the account schema", but `jobs/rapprochement.py` lives in `jobs/`, and every existing job runs in the `ingestion` container (scheduler). Story 9.7 placing it in the scheduler gets a role that cannot read `droit`/`paiement`. The back-office is "a separate surface" but neither a compose service nor a role is named: does it write the race schema (data entry, FR-49) and the account schema (manual licence) with one role? `journal_audit`'s "no update/delete grant" needs a named owning role and a separate migration role.
- **Fix (AD-19):** add a role table: `role_courses` (ingestion, cotes, pronostics, rebuild: race schema RW, no account access), `role_api` (race schema R + forecast tables R, account schema RW except `journal_audit` insert-only), `role_backoffice` (account schema as needed, race corrections table insert, `journal_audit` insert-only), `role_migration` (DDL, used only by the start-up migration step, AD-13). State that `rapprochement` runs under `role_api` in a scheduled process of its own (or inside `api`), never in `ingestion`. Name the back-office as a compose service.

### H-5 — AD-20 data entry vs AD-10 single writer: two writers of race data, and ingestion overwrites approved corrections

- **ADs:** AD-20, AD-10, AD-1, FR-49.
- **Hole:** an approved agent correction (rank, weight, ground — IN-3) must change race data. AD-10 makes ingestion/finalisation the sole writer of `participations`/`multi_course`; the 6 a.m. ingestion and `/rafraichir` re-read and overwrite. Story 10.3 writing corrections directly into `participations` breaks AD-10 and is silently undone the next morning; writing them elsewhere is undefined, so `pronostics`, the Multi log and the Dart engine do not see them.
- **Fix (AD-10/AD-20):** "Back-office corrections are rows in a race-schema table `correction_saisie` (target entity and field, old value, new value, agent, status `en_attente`/`validee`/`rejetee`, validator, timestamps), sole writer the back-office. `repository.py` applies validated corrections as an overlay on read; ingestion never reads or writes that table and never overwrites it. A pending correction enters no calculation (FR-49). Every state change appends a `journal_audit` row." Add the table to the AD-10 ownership table.

### H-6 — Published forecasts and odds snapshots have no named table, writer or immutability rule

- **ADs:** AD-14 status, AD-10, AD-15, FR-51/FR-52.
- **Reality:** published forecasts are `prediction_runs` (variante `ml`, `horizon`) + `prediction_chevaux`; snapshots are `cotes_instantanees`. `prediction_runs` has **two writers today**: `jobs/pronostics_ml.py` and the public `POST /pronostics` (variante `app`, identified by `installation_id`), plus `predict.py`. `PredictionRun.chevaux` uses `cascade="all, delete-orphan"`. Immutability rests on a SQLite-only partial unique index (`sqlite_where`).
- **Hole:** FR-51/FR-52 "never rewritten" is a commercial and SM-1 measurement invariant, yet the spine only says "produced by the `pronostics` service". Story 11.x could add a recompute-on-correction path (H-5) that updates rows; story 9.2 needs to know which table to filter.
- **Fix:** add to AD-10's table (or a new AD-22): `prediction_runs`/`prediction_chevaux` variante `ml` — sole writer `pronostics`, insert-only, one row per (race, horizon), a late or corrected recompute is a new `modele_version`, never an update; `cotes_instantanees` — sole writer `cotes`, insert-only. The application role gets no UPDATE/DELETE on these tables in PostgreSQL. Port the partial index with `postgresql_where` in the Alembic baseline. Decide the fate of variante `app` (see H-7).

### H-7 — AD-15 does not classify the routes that exist today; one of them publishes the forecasts for free

- **ADs:** AD-15, AD-20, AD-21.
- **Reality:** `main.py` mounts `routes_dashboard` — `GET /dashboard/data` returns `pronostics_du_jour` and evaluation aggregates with no auth; `POST /pronostics` accepts anonymous writes keyed by `installation_id`; `POST /chevaux/{id}/backfill` and `POST /courses/{id}/importer` trigger source scraping. The threat matrix (open item 10) asks whether the current deployment must stay private until auth ships; the spine is silent. The `cotes` service also stores an **H-2** snapshot that is in no FR-39 row.
- **Hole:** "every route behind the entitlement dependency" is either applied literally (and then breaks the webhook, OTP, pairing and health routes) or story-by-story (and the dashboard stays public).
- **Fix (AD-15):** add an explicit route classification: *public* (OTP request/verify, pairing token, webhook — signature-verified, health), *account + tier* (all race and forecast routes, FR-39), *staff only, back-office host* (`/dashboard*`, evaluation, data entry), *internal only, never served* (H-2 snapshot, `probabilite_fondamentale`). `POST /pronostics` becomes account-bound (variante `app` keyed by `compte`, not `installation_id`) or is retired; `/backfill` and `/importer` follow FR-39 (Turfiste+) and AD-21 limits. Until story 9.2 ships, the deployed API is network-restricted (Deferred entry with an owner).

### H-8 — Web companion sessions: token storage, CSRF and browser `appareil` identity are undefined

- **ADs:** AD-16, AD-21, AD-9.
- **Hole:** AD-16 keeps tokens in Keystore/Keychain — the browser has neither. Story 7.6/8.2 may put the refresh token in `localStorage` (XSS-exfiltrable, defeats rotation-chain detection) or in an httpOnly cookie (then CORS needs `allow_credentials`, SameSite and CSRF protection that AD-21 does not mention). "Every browser session is an `appareil` row" + "over the limit the new device is refused" means a user clearing cookies or using private mode burns a device slot each time and gets locked out.
- **Fix (AD-16/AD-21):** "On the web, the refresh token lives in an httpOnly, Secure, SameSite=Strict cookie scoped to the API host; the access token lives in memory only; state-changing requests carry a CSRF header checked server-side; CORS sets `allow_credentials=True` with the explicit allowlist. A browser `appareil` that has not refreshed for `WEB_APPAREIL_INACTIF_JOURS` is retired automatically and frees its slot." Note that `flutter_secure_storage` on web is not Keystore-grade and must not hold the refresh token.

### H-9 — AD-21 / AD-16 rate limits: layer unassigned, client IP lost behind the proxy, CGNAT ignored

- **ADs:** AD-21, AD-16 (OTP per number and per IP).
- **Hole:** story 7.3 (proxy) and 7.4 (rate limiting) can each implement limits. Behind the proxy, uvicorn sees the proxy's address unless `--proxy-headers`/`forwarded_allow_ips` is set; a per-IP OTP limit in the app then throttles every user together (or nobody). Cameroonian mobile carriers use carrier-grade NAT, so a strict per-IP OTP limit blocks many legitimate users behind one address.
- **Fix (AD-21):** "The proxy enforces coarse per-IP limits; the application enforces per-account and per-number limits (OTP, payment initiation, extraction) in one dependency. Uvicorn trusts `X-Forwarded-For` only from the proxy's address. Per-IP OTP limits are generous (CGNAT); per-number limits are the binding ones." Limit values stay configuration (Deferred).

### H-10 — SIM swap / OTP interception (threat AS-8, residual risk High) is silent

- **ADs:** AD-16, Deferred.
- **Hole:** AD-16 makes "an OTP to the account's number" sufficient to join a new device and the phone number the identity backbone. A SIM-swapped number therefore logs in as the holder on a new device; the SMS alert goes to the attacker's SIM. The threat matrix lists it Open/High; the spine neither mitigates nor defers it.
- **Fix:** either add to AD-16 "a new device joining a paid account by OTP alone (no approval from an existing device) also alerts the verified email, and for `NOUVEL_APPAREIL_DELAI_HEURES` cannot change email, number or Duo membership; WhatsApp OTP is preferred when the provider supports it", or record it explicitly in Deferred with the residual risk and an owner. Silence is the one option to avoid.

---

## Medium

1. **AD-10 vs AD-14 — two H-30 readings of the odds.** The daily Multi log re-reads odds from the source at `MULTI_JOURNAL_AVANCE_MINUTES` (30) while `cotes` stores the H-30 snapshot that `pronostics` uses. Two different "H-30" odds sets per race. *Fix:* the Multi log reads the `cotes_instantanees` H-30 row (and the published forecast, C-1) instead of re-reading the source.
2. **AD-14 / AD-15 — published forecast payload shape is unspecified.** FR-52 says "the latest snapshot allowed by the tier"; AD-14 says "served with the race's runners". *Fix:* one typed `pronostic_publie` object on the race (`horizon`, `modele_version`, `donnees_le`, `en_evaluation`, `chevaux[{num_pmu, probabilite, rang}]`) plus an optional `apercu` (FR-40: `chevaux_changes`, `horizon`, `palier_requis`) — never an array of all horizons filtered client-side.
3. **AD-6 / AD-14 — non-runners with a published set.** AD-6 says the scoring core recomputes after a non-runner; the ML model runs only on the backend. A user-marked non-runner on the phone has no defined rule for the published probabilities. *Fix:* "the phone renormalises the published win probabilities over the remaining field (Plackett-Luce consistent) and labels the result 'ajusté'; the server recomputes only at the next snapshot".
4. **AD-14 / FR-39 — what a Turfiste runs.** FR-7/FR-8 local calculation is Turfiste+, FR-53 expert mode is Expert-only, and AD-14 calls the Dart engine "the expert engine". *Fix:* state that the Dart engine at default parameters is the fallback for every paid tier (photo/manual races), and adjustable coefficients are the Expert-only expert mode.
5. **AD-14 — downstream single implementation vs server columns.** `prediction_chevaux` has `value` and `mise`. If `pronostics` fills them, value/Kelly exist twice. *Fix:* published forecasts carry probabilities and rank only; value/Kelly stay on the phone.
6. **AD-9 — conflict rule for followed races and engine settings is missing,** and the web (no local copy) writes straight to the server — a second mutation path. *Fix:* last-write-wins on server receive time per key for settings and followed races; the web uses the same sync endpoint as the phone; expert coefficients are stored but not returned to a tier that cannot use them.
7. **AD-16 — device-limit race.** Two concurrent logins can both pass the "under limit" check. *Fix:* the limit check and the `appareil` insert run in one transaction with a row lock on the account (or a per-account advisory lock).
8. **AD-18 / AD-17 — `droit` cannot be revoked without rewriting history.** PF-3 is deferred, but the shape is fixed now: tier, start, end, origin. A chargeback would mutate `end`. *Fix:* `droit` is insert-only with nullable `revoque_le`/`motif_revocation`; the resolver ignores revoked rows; revocation appends a `journal_audit` row.
9. **AD-20 — hash chain under concurrency and against a DB superuser.** Two concurrent appends read the same previous hash and fork the chain; an operator with DDL can rewrite the whole chain consistently (IN-4 residual "depends on DB-admin separation"). *Fix:* serialise appends (advisory lock or a single sequence-ordered writer) and periodically export the head hash outside the database (e.g. daily to the encrypted backup and an off-host log).
10. **AD-20 / FR-48 / FR-50 — audit scope.** Which events are journaled is partial: refused agent access attempts (FR-48), webhook-created `droit` (AD-17 "insiders unseen"), device additions and number changes are not listed. *Fix:* enumerate the event types in AD-20.
11. **AD-20 — staff identity and tables are unnamed.** The `comptes` schema list has no staff account, TOTP secret or pending-change table. *Fix:* name `personnel` (separate from `compte`, TOTP secret encrypted at rest) and `correction_saisie` (H-5), and their schema.
12. **FR-46 / threat CL-1 (Must) — screen protection is absent from the spine.** *Fix:* one line in AD-15 or the conventions: "paid screens set `FLAG_SECURE` through one wrapper widget driven by the FR-39 table; the web is unprotected by decision"; plugin version [TO VERIFY] at story 9.10.
13. **FR-34 / FR-35 — no email port.** Verification links and number-change alerts need an email provider, but only `otp_client.py` (SMS/WhatsApp) is a named port. *Fix:* add `data/email_client.py` (AD-1 pattern) or widen `otp_client.py` to "notifications" explicitly.
14. **Threat matrix open item 9 — paid content at rest.** `hippique_cache.db` will hold H-10 forecasts and Multi contexts unencrypted. *Fix:* decide (sqlcipher / encrypted columns, or accept) and record it in AD-9 or Deferred.
15. **AD-13 reality — every service migrates today.** `Repository()` runs `create_all()` + `_migrate()` and is instantiated by every route module and by `ingestion`, `cotes`, `pronostics`, `rebuild`, `build_features`, `purge_open_pmu`. AD-13 names only `api` and `ingestion`. *Fix:* "no process other than the `api` start-up step migrates" and list the services; the migration step uses `role_migration` (H-4), so `role_api` has no DDL.
16. **AD-19 / Deferred reality — the `rebuild` service is missing.** `docker-compose.yml` runs five services (`api`, `ingestion`, `cotes`, `pronostics`, `rebuild`); the spine lists four. `rebuild` writes the race schema. *Fix:* add it to AD-19's binds and race-role list, and to the Deferred deployment line.
17. **AD-12 reality — more naive timestamps than the one logged.** `cotes_instantanees.pris_le`/`cote_direct_le` are "UTC naïf"; `routes_pronostics.maintenant()` uses `datetime.now()` (container local) and compares it with `heure_depart`. *Fix:* extend the `deferred-work.md` entry and make the PostgreSQL migration (AD-13) convert to `timestamptz`.
18. **Stack — bind PostgreSQL and its driver before Epic 7 splits.** The NumPy pin already showed the SSE2-only VPS breaks assumptions. The PostgreSQL image, the Python driver (psycopg 3 binary wheels vs psycopg2) and the proxy must be verified on that CPU, and the driver fixes `DATABASE_URL` for every service and Alembic's env. *Fix:* move PostgreSQL major + driver from "story 7.2 [TO VERIFY]" to a verified pin now (or make story 7.1's first task the on-VPS check). The other [TO VERIFY] items (proxy, `flutter_secure_storage`, QR scanner) can stay deferred to their stories.
19. **AD-6 / AD-15 — `/multi/courses/{cle}/rafraichir` triggers a source re-read** limited per race only. Any account can drive scraping. *Fix:* Expert-only (FR-39 Multi) and counted in AD-21's per-account limits.

## Low

1. **First Mermaid diagram is stale** — no `otp_client`, `paiement_client`, back-office or `cotes`/`pronostics`. Update or point to the third diagram.
2. **Structural seed indentation** — `alembic/` sits under `backoffice/` (AD-13 says `backend/alembic/`), and `data/otp_client.py`/`api/routes_auth.py` are listed beside `jobs/` instead of inside `data/`/`api/`.
3. **`docker-compose.yml` comment** for `cotes` says "H-60, H-30, H-10 et H-2"; commit `0e84e04` added H-15. Cosmetic, but the spine's H-2 question (H-7) starts there.
4. **CORS dev origins** — `main.py` opened `*` for `flutter run -d chrome`; the allowlist should come from configuration so dev origins never reach production.
5. **§6.1 terms acceptance** — "registration requires acceptance of the terms in force": add `cgu_version_acceptee`/`cgu_acceptee_le` on `compte`.
6. **FR-45 counter** — where the per-tier extraction counter lives (account schema, per period) and its concurrency is unstated; one line in AD-3.
7. **FR-46 short account id** — "identifiant court du compte" on exports needs one fixed derivation (not the phone number); name it in AD-16.
8. **FR-41 offer catalogue** — "prices and durations are configuration": name its home (a table in the account schema, edited by admin and journaled) so 9.5 and 10.x agree.
9. **Threat ID-1 (Must, continuing rule)** — "bound parameters only, never f-string SQL from external input" is not stated; add to AD-1 or the conventions (the f-string `ALTER TABLE` in `_migrate()` disappears with Alembic).
10. **DP-2 retention** — `appareil` (IP, user agent), `session` and `journal_audit` retention is undefined; record as Deferred pending the legal review.
11. **AD-17 webhook origin** — optionally restrict the webhook route to the aggregator's published IP ranges at the proxy, in addition to signature + status re-check.

---

## Lens 2 — Reality/currency summary

| Claim in spine | Code / fact | Status |
| --- | --- | --- |
| Services `api`, `ingestion`, `cotes`, `pronostics` | compose also has `rebuild` | Incomplete (M-16) |
| `allow_origins=["*"]` live defect | confirmed in `main.py` | Correct |
| Only `api` migrates; `ingestion` never | every `Repository()` migrates (all services) | Contradicted (M-15) |
| Published forecasts produced by `pronostics` | yes, but `prediction_runs` also written by `POST /pronostics` and `predict.py` | Incomplete (H-6) |
| Snapshots H-60/30/15/10 | `cotes` also stores H-2 | Unclassified (H-7) |
| `hippique_cache.db`, schema v1→2→3 | file name and `getDatabasesPath()` confirmed; current version 1 | Correct |
| Web companion has no local cache | `DatabaseHelper` returns null on web; `shared_preferences` still holds settings and `installation_id` | Correct for the DB; settings live in browser storage |
| AD-12 naive-time defect limited to `pmu_client` | also `cotes_instantanees`, `routes_pronostics` | Incomplete (M-17) |
| `/dashboard` | public, exposes daily forecasts | Unaddressed (H-7) |
| [TO VERIFY] PostgreSQL, proxy, secure storage, QR | — | Acceptable except PostgreSQL + driver: bind now (M-18); add token-signing library (H-1) |

## Lens 3 — Coverage

**PRD FR-31..FR-53**

| FR | Lands in | Gap |
| --- | --- | --- |
| FR-31 | AD-16, AD-21 | Non-enumeration ("same message either way") silent — add one clause to AD-16 |
| FR-32 | AD-16 | Inactivity lock and 5-PIN wipe are client rules — story level, fine |
| FR-33 | AD-16 | — |
| FR-34 | — | Email verification port missing (M-13) |
| FR-35 | AD-16 | Email port (M-13) |
| FR-36 | AD-16 | Concurrency (M-7), browser slots (H-8), offline revocation (H-1) |
| FR-37 | AD-16 | — |
| FR-38 | AD-9 | Offline-then-late refusal (H-2), conflict rule (M-6) |
| FR-39 | AD-15 | Route classification (H-7), shared matrix (H-3) |
| FR-40 | AD-15 | Payload shape (M-2) |
| FR-41 | Deferred (values) | Catalogue home (L-8) |
| FR-42 | AD-17 | Late confirmation → token refresh (H-1) |
| FR-43 | AD-18 | Contradiction (C-2) |
| FR-44 | AD-15 | Cache tier tag (H-3), clock (H-1) |
| FR-45 | AD-3 | Counter home (L-6) |
| FR-46 | — | **Silent** (M-12) |
| FR-47 | AD-20 | — |
| FR-48 | AD-20 | Refused-access logging (M-10) |
| FR-49 | AD-20 | Overlay vs single writer (H-5) |
| FR-50 | AD-17, AD-20 | Chain concurrency/anchoring (M-9) |
| FR-51 | AD-14 status | Table/writer/immutability (H-6) |
| FR-52 | AD-14 status, AD-10 | Payload (M-2), immutability (H-6), H-2 tier (H-7) |
| FR-53 | AD-14 | Active-set ambiguity (C-1), Turfiste engine (M-4) |

**Threat matrix Must mitigations**

| Threat | Lands in | Gap |
| --- | --- | --- |
| CL-1 screen capture | — | **Silent** (M-12) |
| CL-5, AA-1, AA-4 | AD-15 | Existing routes (H-7) |
| AS-1, AS-2, AS-5, AS-6, AS-9 | AD-16 | Web sessions (H-8) |
| AS-4 PIN | AD-16 | — |
| AS-8 SIM swap (Open, High) | — | **Silent** (H-10) |
| PF-1, PF-2, PF-4, SE-2 | AD-17 | — |
| PF-3 chargeback (Open, High) | Deferred | Acceptable, but `droit` shape must allow revocation (M-8) |
| PF-5 | AD-3, AD-21 | — |
| PF-6 | AD-18 | — |
| AA-2 | AD-21 | Layer/proxy IP (H-9) |
| AA-3, TI-1, SE-1 | AD-21 | Credentials mode (H-8) |
| ID-1 bound parameters | — | Silent (L-9) |
| ID-2 | AD-19 | Role matrix (H-4) |
| ID-3, IN-1, IN-2 | AD-20 | — |
| IN-3 (validation, audit) | AD-20 | Overlay (H-5) |
| IN-4 | AD-20 | Anchoring (M-9) |
| DP-1, DP-3 | PRD §6.1/§9.2 | Not architecture — fine |
| DP-2 | — | Retention (L-10) |
| Open item 9 (offline cache at rest) | — | Silent (M-14) |
| Open item 10 (open API before auth) | — | Silent (H-7) |
| Open item 11 (SQLite-specific code port) | AD-13 | Partial-index port (H-6) |
