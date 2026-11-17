---
title: 'Story 7.8 — Lock the deployed API until accounts exist'
type: 'feature'
created: '2026-11-16'
status: 'done'
baseline_commit: '3d6ba3005c58939d0248e5d3a5a2d5857eedec25'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The deployed API (host port 8000) is public: `GET /dashboard/data` serves today's forecasts to anyone and `POST /pronostics` accepts anonymous writes.

**Approach:** Two independent layers (AD-21): a host firewall allowlist on port 8000 in the iptables `DOCKER-USER` chain, and an `api` middleware that requires the shared secret `ACCES_RESTREINT_SECRET` (HTTP Basic or Bearer). The dev mobile build sends the secret from `--dart-define`.

## Boundaries & Constraints

**Always:**
- Compare the secret with `hmac.compare_digest`. A refusal is a bare 401 with `WWW-Authenticate: Basic realm="prediction-hyppique"` (so browsers prompt), no body detail.
- `GET /health` is exempt; CORS preflight (`OPTIONS`) passes so the Flutter web dev build still works.
- The middleware is active iff `ACCES_RESTREINT_SECRET` is non-empty. With `APP_ENV=production` and no secret, `app.main` raises at import (refuses to start).
- The secret never appears in logs, code, compose files or the repo.
- The allowlist IPs live in a versioned config file with no secret. The firewall script is idempotent and re-applied after reboot and Docker restart.

**Ask First:** Changing the default API base URL or the port; adding any route to the exemption list beyond `/health`.

**Never:** Store the secret in the mobile release build or web bundle. Remove or rewrite existing routes. Touch CORS policy beyond middleware ordering (story 7.3 owns CORS). Add the payment webhook exception (story 9.5).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Bearer ok | `Authorization: Bearer <secret>` | Route answers as before | N/A |
| Basic ok | Basic, any user, password = secret | Route answers as before | N/A |
| Missing / wrong | no header, wrong secret, malformed Basic base64 | 401 + `WWW-Authenticate` | never 500 |
| Health | `GET /health`, no header | 200 `{"status":"ok"}` | N/A |
| Preflight | `OPTIONS` with CORS headers | CORS answer, no 401 | N/A |
| No secret, dev | env unset, `APP_ENV` unset | middleware off, all open (local dev, tests) | N/A |
| No secret, prod | `APP_ENV=production`, secret unset | import of `app.main` raises `RuntimeError` | message names the variable, not a value |

</frozen-after-approval>

## Code Map

- `backend/app/main.py` -- app assembly; CORS added with `allow_origins=["*"]`. Starlette: last added middleware is outermost, so add the access middleware first, then CORS (CORS answers preflight before the lock).
- `backend/app/api/routes_dashboard.py:24,50` -- `GET /dashboard/data`, `GET /dashboard` (HTML page that fetches `/dashboard/data`; browser reuses Basic credentials on same origin).
- `backend/app/api/routes_pronostics.py` -- anonymous `POST /pronostics` (stays, just locked).
- `backend/tests/test_main.py` -- imports `app.main` with a temp SQLite; no secret set, so the middleware stays off there. Do not break it.
- No `/health` route exists yet; no environment flag exists yet (`APP_ENV` is new).
- `docker-compose.yml` `api` service -- publishes `8000:8000`, reads `.env`.
- `mobile/lib/data/remote/api_client.dart:44-55` -- `ApiClient` builds `Dio(BaseOptions(...))`; `API_BASE_URL` already via `String.fromEnvironment`. Tests use fakes, never mock Dio.
- `docs/` -- existing docs folder (French specs); add the runbook here.

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/api/acces_restreint.py` -- create: pure `secret_valide(header, secret) -> bool` (Bearer and Basic), an ASGI/Starlette middleware class, and `installer(app, secret, app_env)` that adds the middleware when `secret` is set and raises `RuntimeError` when `app_env == "production"` and it is not -- single place for the rule.
- [x] `backend/app/main.py` -- add `GET /health`; call `installer(app, os.environ.get("ACCES_RESTREINT_SECRET", ""), os.environ.get("APP_ENV", ""))` before adding CORS.
- [x] `backend/tests/test_acces_restreint.py` -- create: every matrix row on a small FastAPI app built with `installer` (plus one check that the real `app.main` exposes `/health`), and a check that no log record contains the secret.
- [x] `docker-compose.yml` -- `api`: add `APP_ENV=production`; the secret comes from `.env` only (comment says so).
- [x] `deploy/firewall/ips_autorisees.conf` -- create: one IPv4/CIDR per line, comments allowed, placeholder `# 203.0.113.10  # exemple` only (owner fills real IPs).
- [x] `deploy/firewall/acces_restreint.sh` -- create: idempotent and fail-closed; validates the whole list first (octets 0-255, prefix /1-/32), builds a fresh chain `ACCES_RESTREINT_NEW`, inserts its jump, removes the old jump and chain, renames the new one to `ACCES_RESTREINT`; jumped from `DOCKER-USER` only for published inbound TCP (`--ctstate DNAT --ctorigdstport 8000 --ctdir ORIGINAL`); RETURN for established, RETURN for listed sources (Docker's own rules continue), DROP the rest; refuses to run with an empty list (would lock the owner out); reads the untracked `ips_autorisees.local.conf` instead of the versioned file when present; `--retirer` removes jump and chains.
- [x] `deploy/firewall/acces-restreint.service` -- create: systemd oneshot `Requires=docker.service`, `After=docker.service`, `PartOf=docker.service`, `WantedBy=multi-user.target`, runs the script; `ExecStop` runs it with `--retirer`.
- [x] `docs/acces-restreint.md` -- create (French): install, edit IPs, set the secret in `.env`, dev mobile build command, browser use, smoke test (6 refused calls + `/health`), and lift conditions (after 9.2 and 10.7, recorded decision).
- [x] `mobile/lib/data/remote/api_client.dart` -- read `String.fromEnvironment('ACCES_RESTREINT_SECRET')`; when non-empty, set `Authorization: Bearer` on the Dio base headers; constructor parameter for tests.
- [x] `mobile/test/data/api_client_test.dart` -- create: header present with a secret, absent without.

**Acceptance Criteria:**
- Given the backend suite, when run, then all existing tests still pass with no secret configured.
- Given `bash -n deploy/firewall/acces_restreint.sh`, when run, then it passes; running the script twice leaves one jump rule only (documented, checked on the VPS by the owner).
- Given the smoke procedure in `docs/acces-restreint.md`, when the owner runs it on the VPS, then the outcome is recorded in this spec's notes.

## Design Notes

Docker DNATs published ports before `DOCKER-USER`, so match on the original port of DNATed traffic only: `-m conntrack --ctstate DNAT --ctorigdstport 8000 --ctdir ORIGINAL` (container outbound connections to a remote :8000 are untouched). Basic auth: accept any username; compare only the password, so `curl -u x:$SECRET` and a browser prompt both work.

## Verification

**Commands:**
- `cd backend && PYTHONPATH=. .venv/Scripts/python.exe -m pytest -q` -- expected: all pass.
- `cd mobile && flutter test` -- expected: all pass.
- `bash -n deploy/firewall/acces_restreint.sh` -- expected: no output.

**Manual checks (if no CLI):**
- On the VPS (owner): install the service, run the smoke test, reboot, re-check `iptables -S DOCKER-USER`.

## Notes

- 2026-11-16 (dev, after review patch): backend suite 443 passed / 38 skipped with no secret (includes real `app.main` wiring in a subprocess and the firewall script against a stateful fake `iptables`: empty/invalid list -> exit 1 with no iptables call, two runs -> one `DOCKER-USER` jump, new jump inserted before the old one is removed, `--retirer`); `flutter test` 107 passed; `bash -n` clean.
- VPS smoke test (owner): _pending_ -- record outcome of `docs/acces-restreint.md` section 6 and the post-reboot `iptables -S DOCKER-USER` here.

## Local Run (2026-11-17)

Local uvicorn with the secret and APP_ENV=production: /health 200; /dashboard/data, /courses, POST /pronostics without or with a wrong secret 401; Bearer and Basic with the secret 200; CORS preflight 200; production without a secret refuses to start. Flutter web (Chrome) with --dart-define secret: OPTIONS then GET /courses 200. VPS firewall and smoke test still pending (owner).

## Suggested Review Order

**Application lock (layer 2)**

- Entry point: the rule — lock on iff secret set, refuse production start without one.
  [`acces_restreint.py:117`](../../backend/app/api/acces_restreint.py#L117)

- ASGI middleware: locks http and websocket, only lifespan passes.
  [`acces_restreint.py:91`](../../backend/app/api/acces_restreint.py#L91)

- Exemptions limited to real CORS preflight and GET/HEAD /health.
  [`acces_restreint.py:70`](../../backend/app/api/acces_restreint.py#L70)

- Bearer or Basic password, constant-time comparison.
  [`acces_restreint.py:39`](../../backend/app/api/acces_restreint.py#L39)

- Installed before CORS so CORS stays outermost and answers preflight.
  [`main.py:25`](../../backend/app/main.py#L25)

**Host firewall (layer 1)**

- Jump matches only published DNATed traffic on original port 8000.
  [`acces_restreint.sh:35`](../../deploy/firewall/acces_restreint.sh#L35)

- Removal path used by systemd ExecStop and for lifting the lock.
  [`acces_restreint.sh:54`](../../deploy/firewall/acces_restreint.sh#L54)

- IPv4-only publication because ip6tables is not filtered.
  [`docker-compose.yml:8`](../../docker-compose.yml#L8)

**Mobile dev build**

- Secret from --dart-define, never sent in release builds.
  [`api_client.dart:54`](../../mobile/lib/data/remote/api_client.dart#L54)

**Tests**

- Real app.main wiring checked in a fresh interpreter.
  [`test_acces_restreint.py:261`](../../backend/tests/test_acces_restreint.py#L261)
