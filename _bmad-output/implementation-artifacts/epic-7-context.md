# Epic 7 Context: Fondations de sécurité de la plateforme

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the server safe to carry accounts and payments before any of them exist: close the deployed API until per-route account/tier checks exist, move schema changes to Alembic, replace the shared SQLite file with PostgreSQL split into schemas and per-writer roles, serve only HTTPS behind a TLS proxy with a strict origin allowlist and rate limits, prove no secret ships in the APK or web bundle, put the web companion in production, publish the Android app (internal/closed test), expose the current terms version, and provide the single audit-log writer that later account stories call. It is the first epic of the paid multi-user launch; Epics 5 and 6 may resume once story 7.1 is done.

## Stories

- Story 7.1: Mises à jour du serveur sans perte de données (Alembic)
- Story 7.2: Passer de SQLite à PostgreSQL
- Story 7.3: HTTPS et origines autorisées
- Story 7.4: Limitation du débit
- Story 7.5: Aucun secret dans les binaires
- Story 7.6: Web app compagnon en production
- Story 7.7: Publication sur le Play Store
- Story 7.8: Fermer l'API déployée en attendant les comptes
- Story 7.9: Exposer la version des conditions en vigueur (`CGU_VERSION`)
- Story 7.10: Écrivain du journal d'audit

## Requirements & Constraints

- HTTPS everywhere; CORS limited to origins that truly need it (never `*`; dev origins never in prod config); rate limits per IP, per phone number and per account.
- Data minimisation: no card number, PIN or OTP in clear server-side; accounts/payments separated from race data; backups encrypted.
- No provider secret (vision/Anthropic, payment aggregator, SMS provider, any prod `.env` value, any private key) in the APK or web bundle; only `.env.example` (no values) is tracked.
- Until accounts and tier checks land, nobody but the owner can read today's forecasts or write anonymously (`GET /dashboard/data`, `POST /pronostics` are currently open).
- Schema evolution must never lose production data: row counts per table must match after every migration/transfer.
- Legal texts (privacy policy, CGU, CGV) published on stable HTTPS URLs with version and date; may ship marked provisional pending legal review — sale stays blocked.
- Play Store listing for a betting-related app: no win promises, responsible-gambling reminder, suitable age rating; first release internal/closed test only.
- Error responses never expose technical traces (e.g. 429 returns code `trop_de_requetes` + `Retry-After`).

## Technical Decisions

- **Migrations (Alembic 1.20.0):** only the `api` start-up script (`backend/scripts/demarrer_api.py`) migrates — backup first (SQLite file copy, later `pg_dump`; keep last 3), stamp baseline on legacy DBs, `upgrade head`, then uvicorn; failure exits non-zero. Every other service/job checks revision == `head` and refuses to write otherwise. `Repository` no longer calls `create_all`/`_migrate` on a real DB. A model/migration concordance test must stay empty. Partial unique indexes declare both `sqlite_where` and `postgresql_where`.
- **VPS is SSE2-only:** PostgreSQL major version, Python driver (psycopg 3 or psycopg2), Traefik v3 and `age` must be verified on it first (story 7.1 task 1) and then pinned in the architecture Stack. Backend image locked to Python 3.12 / NumPy 1.26.4.
- **PostgreSQL layout:** schemas `courses`, `comptes`, `audit`; each model declares its schema; Alembic `include_schemas=True`; SQLite tests use `schema_translate_map` → `None` so one suite runs on both. One role per writer: `role_ingestion` (ingestion, rebuild), `role_cotes` (INSERT `cotes_instantanees` only), `role_pronostics` (INSERT `ml` runs only via RLS), `role_api` (course reads + ingestion-table writes for import/backfill/Multi refresh, `variante='app'` runs via RLS, per-table `comptes` grants, `droit` SELECT+INSERT only, EXECUTE on `audit.inscrire()`), `role_backoffice` (courses SELECT for now), `role_migration` (DDL, start-up only). No app role has UPDATE/DELETE on published forecasts, snapshots or the audit log. Grant tests run on real PostgreSQL, skipped on SQLite with an explicit message.
- **Time:** all instants `timestamptz`; naive UTC values read as UTC; fix remaining naive writers.
- **Backups:** daily `pg_dump` encrypted with `age` (public key on host, private key offline), stored outside the `postgres` container; local host volume until the owner picks an off-host destination.
- **Edge:** Traefik v3 is the only internet-facing service; ACME certs, HTTP→HTTPS redirect, HSTS, coarse per-IP limits. Hosts from env (`DOMAINE_API`, `DOMAINE_WEB`, `DOMAINE_BACKOFFICE`), never hard-coded: `api.<d>` → api; `app.<d>` → web build + `/api/*` → api (same origin); `admin.<d>` → back-office. Dev uses `*.localhost`. Proxy has a fixed Docker IP; uvicorn `--forwarded-allow-ips` set to it only. `allow_origins` read from `ORIGINES_AUTORISEES` (may be empty in prod).
- **App rate limiting:** one FastAPI dependency (`backend/app/api/deps_limites.py`) keyed by `ip`/`numero`/`compte`, thresholds from config; counters shared in `comptes.limite_debit` (never per-process). OTP routes: per-number limit binding, per-IP generous (CGNAT). Stricter on OTP, payment initiation, photo extraction, Multi refresh.
- **Access restriction (7.8):** layer 1 = host firewall allowlist on port 8000 in iptables `DOCKER-USER` (Docker bypasses ufw), idempotent, reboot-proof script; layer 2 = middleware `backend/app/api/acces_restreint.py` requiring `ACCES_RESTREINT_SECRET` (Basic or Bearer, `hmac.compare_digest`, 401 without detail, `/health` exempt, refuses prod start if missing, never logged). Dev mobile build gets the secret via `--dart-define` only. Lifted only after stories 9.2 and 10.7, by recorded decision.
- **Secrets scan:** `scripts/verifier_secrets_binaires.py` scans APK, web bundle and `git ls-files`; run before every production publish (documented in `docs/`).
- **Terms:** config carries `CGU_VERSION`, date and three URLs (missing → api won't start); public typed `GET /conditions` returns `{version, date, url_cgu, url_cgv, url_confidentialite}` plus `provisoire`.
- **Audit log:** `audit.journal_audit` (increasing id, `timestamptz`, actor type `compte|personnel|systeme` + id, event type, target, JSON detail, `empreinte_precedente`, `empreinte`). Only write path: SQL function `audit.inscrire(...)` (`SECURITY DEFINER`, non-login owner, pinned `search_path`, transaction advisory lock, sha256 chaining). Python entry point `inscrire_audit(...)` in `backend/app/data/audit.py`, same transaction as the action; event types from a single registry `backend/app/data/audit_evenements.py`; detail never holds OTP, tokens, passwords, TOTP secrets or card numbers. SQLite path runs without advisory lock.
- Bound SQL parameters only; French domain naming for account/payment entities.

## UX & Interaction Patterns

- Web companion: two-column layout (race list, detail) per `mockups/web-compagnon.html`, same components as mobile; permanent notice exactly « Web : connexion requise ; l'app Android fonctionne hors ligne »; local cache stays disabled on web (`kIsWeb`); API base URL relative (`/api`). No web-only feature; mobile-only features absent on web (camera capture, screen protection, PIN) listed with reasons.
- `GET /conditions` feeds the Connexion screen's terms checkbox and links (story 8.1).

## Cross-Story Dependencies

- Order: 7.8 and 7.1's VPS verification start immediately in parallel (7.8 depends on neither 7.1 nor 7.3); then rest of 7.1, 7.2 → 7.7 in order; 7.9 any time after 7.1; 7.10 after 7.2.
- 7.2/7.3 production cutover blocked by VPS verification; 7.3/7.6 production blocked by domain purchase + DNS (owner task) — deliverable locally on `*.localhost` meanwhile. 7.2 off-host backup destination is an owner choice. 7.7 blocked by Google Play developer account, legal review and story 9.0 (payment rules).
- 7.4 relies on 7.3 for trusted client IP; `compte` key tested with simulated identity until Epic 8. 7.7 depends on 7.5 and 7.9. 7.8 dev-secret must pass the 7.5 scan.
- Downstream: Epic 8 story 8.1 needs 7.2, 7.4, 7.9, 7.10; Epic 10 needs 7.10; story 9.5 adds an IP-filtered webhook exception to 7.8; story 11.1 needs 7.2; story 11.2 decides the fate of `POST /pronostics` (RLS-confined to `app` meanwhile).
