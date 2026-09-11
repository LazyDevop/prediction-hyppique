# Tech-Currency Review — ARCHITECTURE-SPINE.md (prediction-hyppique, 2026-09-04)

**Reviewer posture:** verify every committed technology/version claim in the "Stack" table against actual current status (web-researched, not asserted from training data), and treat every "unpinned"/"[ASSUMPTION]" marker as a real gap rather than an accepted note. This is a solo/bootstrap project, not a starter-template selection, so the bar is "still exists, still maintained, still fit" — not "is this the trendiest pick."

## Overall verdict

No claim in the Stack table is factually wrong or points at a deprecated/superseded technology. Every named technology (Python 3.12, FastAPI, SQLAlchemy, Flutter/Dart, Riverpod, sqflite, dio) is confirmed current and actively maintained as of September 2026, and the two version-management gaps the spine itself flagged (FastAPI unpinned, Flutter/Dart "not re-verified") are real and correctly called out. However, the table has an **inconsistency**: SQLAlchemy is just as unpinned as FastAPI in the actual `requirements.txt` but is not marked `[ASSUMPTION]`, which understates the risk. One additional soft finding: Python 3.12 is now in security-fix-only maintenance (no more bugfix releases), which doesn't invalidate the pin but is worth one sentence of awareness.

## Per-technology findings

### Python 3.12 — CURRENT, appropriate, but note lifecycle stage
- Verified via web search: Python 3.14 (released Oct 2025) is the current latest; Python 3.13 is also stable. Python 3.12 (released Oct 2023) is **not EOL** — full support continues to **October 2028** — but it has already exited its 2-year bugfix-release phase and is now in **security-fix-only** maintenance (no more regular bugfix releases, only security patches until EOL).
- `backend/Dockerfile` confirms the pin: `FROM python:3.12-slim`. This claim in the spine is accurate and reality-checked against the actual file, not asserted.
- **Verdict: fine for this use case.** 3.12 remains a safe, well-supported choice for a solo bootstrap backend; nothing here should be revisited. Optionally note in a future pass that 3.13/3.14 exist if a Dockerfile bump is ever considered, but this is not an architectural gap.

### FastAPI — CURRENT, correctly flagged as unpinned
- Verified: latest stable is in the 0.12x line (0.124.4 as of Dec 2025), actively maintained, no successor/fork has superseded it. Framework choice remains sound and idiomatic for this stack.
- Verified against the actual file: `backend/requirements.txt` contains a bare `fastapi` line with no version pin — confirming the spine's "unpinned" claim is accurate, not a guess.
- **This is a real gap, not just a note**, exactly as the spine already tags it `[ASSUMPTION]`. An unpinned dependency in `requirements.txt` means every fresh `pip install` can silently pull a different FastAPI minor/patch version, with no reproducibility across dev/prod or across time. For a solo bootstrap project this is a defensible short-term tradeoff, but it should stay visible as technical debt (e.g., pin once the API surface stabilizes, or move to a lockfile-based tool).

### SQLAlchemy — CURRENT, but **inconsistently flagged**
- Verified: current stable is the 2.0.x line (2.0.52 as of Aug 2026), with 2.1.0rc1 already in release-candidate stage. The `sqlalchemy.org` blog and PyPI confirm active, frequent maintenance. No deprecation concern.
- Verified against the actual file: `backend/requirements.txt` contains a bare `SQLAlchemy` line — **exactly as unpinned as FastAPI's line above it.**
- **Finding: the Stack table's "latest at requirements.txt resolution" wording for SQLAlchemy omits the `[ASSUMPTION]`/gap marker that the FastAPI row carries, despite the underlying risk being identical (same file, same lack of a version pin).** This is an inconsistency in the spine's own risk-flagging, not a technology problem — SQLAlchemy itself is fine. Recommend the spine either (a) fold SQLAlchemy into the same `[ASSUMPTION: unpinned, acceptable for solo bootstrap]` treatment as FastAPI, or (b) explain why it's treated differently (it isn't — both are one unversioned line in the same file).

### Flutter/Dart — CURRENT, but "not re-verified this run" is a real gap given the task
- Verified: current Flutter stable is 3.47.1 (Aug 2026), shipping Dart 3.13.1. The project's `mobile/pubspec.yaml` pins `environment: sdk: ^3.12.0` (Dart 3.12, caret-constrained so newer Dart 3.x SDKs are compatible) — not stale or abandoned; Dart 3.12/3.13 are both actively supported points on the same major line.
- The spine's own text — "per `mobile/pubspec.yaml` (not re-verified this run — owned by the code)" — is itself the kind of hedge this review was asked to flag: a committed Stack-table row that defers verification rather than checking it. Having now checked it directly against `mobile/pubspec.yaml`, the pin is fine (Dart `^3.12.0`, compatible with current stable Flutter/Dart), so there is no substantive problem — but the spine should either state the verified constraint plainly or keep the hedge and treat it as open debt the way FastAPI's is treated. Right now it reads as a plain note rather than a flagged gap, which understates it.

### Riverpod — CURRENT and well-chosen
- Verified: Riverpod 3.0 is the current major line in 2026, described across multiple sources as the modern default for new Flutter state management, with compile-time safety and built-in offline persistence.
- `mobile/pubspec.yaml` pins `flutter_riverpod: ^3.4.2` — matches the current 3.x generation exactly, not a stale major version. No concern.

### sqflite — CURRENT, not deprecated
- Verified: sqflite is not deprecated; it remains a maintained, stable SQLite binding for Flutter. Drift exists as a higher-level, more modern alternative for new projects wanting a reactive ORM layer, but sqflite itself has no deprecation notice and is a legitimate direct-SQL choice, which matches this project's "local cache" use case (cahier mobile §9, [ADOPTED]).
- `mobile/pubspec.yaml` pins `sqflite: ^2.4.3` — current major line. No concern. (Optional forward-looking note, not a gap: if the mobile engine later wants reactive queries/migrations, Drift is the thing to evaluate — but nothing here requires revisiting sqflite now.)

### dio — CURRENT and well-chosen
- Verified: dio remains the dominant, actively maintained HTTP client for Flutter in 2026, specifically recommended over the bare `http` package when interceptors, timeouts, retries, and cancellation are needed — which is exactly the stated rationale in the spine ("chosen over `http` for timeout/retry handling on unreliable trackside connections").
- `mobile/pubspec.yaml` pins `dio: ^5.11.0` — current major line. No concern.

## Summary table

| Stack entry | Currently maintained/fit? | Version claim verified against actual file? | Unpinned/assumption correctly flagged? |
| --- | --- | --- | --- |
| Python 3.12 | Yes (security-fix-only phase, EOL Oct 2028) | Yes — `backend/Dockerfile` | N/A (pinned) |
| FastAPI | Yes (0.124.x current) | Yes — bare `fastapi` in `requirements.txt` | Yes, correctly `[ASSUMPTION]` |
| SQLAlchemy | Yes (2.0.52 stable, 2.1 in RC) | Yes — bare `SQLAlchemy` in `requirements.txt`, same as FastAPI | **No — same risk as FastAPI but not flagged** |
| Flutter/Dart | Yes (Dart `^3.12.0` compatible with current stable) | Yes — `mobile/pubspec.yaml` | **No — hedged as "not re-verified" rather than flagged as a gap** |
| Riverpod | Yes (3.x is current default) | Yes — `^3.4.2` | N/A (pinned, current) |
| sqflite | Yes (not deprecated) | Yes — `^2.4.3` | N/A (pinned, current) |
| dio | Yes (actively maintained, right tool for the stated need) | Yes — `^5.11.0` | N/A (pinned, current) |

## Recommended actions

1. Apply the same `[ASSUMPTION: unpinned, acceptable for solo bootstrap]` tag to the SQLAlchemy row that FastAPI already carries — the underlying file-level risk is identical.
2. Either replace "(not re-verified this run — owned by the code)" on the Flutter/Dart row with the verified constraint (Dart `^3.12.0`, current stable Flutter 3.47.1/Dart 3.13.1, compatible), or keep it as a hedge but tag it `[ASSUMPTION]` like the other unverified rows so it's tracked as debt rather than read as a settled fact.
3. No technology in the table needs to be swapped, upgraded, or reconsidered — all seven are current, maintained, and fit for a solo hexagonal FastAPI + Flutter/Riverpod bootstrap project as of September 2026.
