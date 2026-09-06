---
title: 'Story 1.2: Shared fixture for engine coefficient tables'
type: 'chore'
created: '2026-09-06'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md', '{project-root}/_bmad-output/implementation-artifacts/spec-1-1-engine-cases-fixture.md']
baseline_commit: 'bc1d9425f20fc425e03ba1b5a740c49997dfb941'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `backend/app/engine/constants.py`'s four coefficient tables (terrain, niveau, incidents, récence) are hand-defined Python literals. Architecture AD-2 requires these in a shared, language-neutral fixture too — same rationale as Story 1.1's test cases, different content (production constants, not test cases).

**Approach:** Create `fixtures/engine_constants.json` mirroring `TERRAIN_COEFFICIENTS_GRASS`, `TERRAIN_COEFFICIENTS_PSF`, `NIVEAU_COEFFICIENTS`, `INCIDENTS`, `RECENCE_STD`/`FORME`/`FLAT` exactly. Add one mechanical validation test (following Story 1.1's `test_fixture_default_parameters_matches_constants` precedent) proving `constants.py`'s actual tables equal the fixture's, so the two can never silently drift.

## Boundaries & Constraints

**Always:**
- Same file-location convention as Story 1.1: `fixtures/engine_constants.json` at the repository root.
- The fixture is read-only reference data validated *against* `constants.py` by a test — this story does not make `constants.py` load from the fixture at runtime (that would be a behavior change to production code, out of scope for a "shared reference data" story; `constants.py` stays the runtime source of truth, the fixture is the cross-language mirror).
- `INCIDENTS` in the fixture must preserve all three fields per code (`malus`, `chute`, `ignore`) — not just the malus number.
- The validation test must fail if a single value anywhere in any of the 4 tables differs (exact equality, these are all exact literals in Python — no floating-point tolerance concerns here beyond what `==` already handles for these specific values).

**Never:**
- Do not modify `constants.py`'s values or make it import from the JSON file — read-only reference relationship this story, not a runtime dependency change.
- Do not touch `fixtures/engine_cases.json` (Story 1.1) or `test_scoring.py`'s existing content beyond appending one new test (or a new file, implementer's choice).
- Do not start the Dart-side consumer (still blocked — mobile engine is corrupted, tracked in `deferred-work.md`).

</frozen-after-approval>

## Code Map

- `fixtures/engine_constants.json` -- TO CREATE -- mirrors the 4 tables below
- `backend/app/engine/constants.py` -- READ-ONLY -- `TERRAIN_COEFFICIENTS_GRASS`, `TERRAIN_COEFFICIENTS_PSF`, `NIVEAU_COEFFICIENTS`, `INCIDENTS` (dict of `IncidentDefinition(malus, chute, ignore=False)`), `RECENCE_STD`/`FORME`/`FLAT` -- the validation target
- `backend/tests/test_scoring.py` -- precedent -- `test_fixture_default_parameters_matches_constants` (near end of file) is the pattern to follow for the new validation test
- `fixtures/engine_cases.json` -- precedent -- file-location/`$comment` convention to match

## Tasks & Acceptance

**Execution:**
- [x] `fixtures/engine_constants.json` -- create with all 4 tables, `INCIDENTS` preserving malus/chute/ignore per entry -- the shared reference AD-2 requires
- [x] `backend/tests/` -- add one test validating each table in `constants.py` equals its fixture counterpart exactly -- closes the drift loop
- [x] Run `pytest backend/tests/ -v` -- 57 passed (56 existing + 1 new), verified independently

**Acceptance Criteria:**
- Given `fixtures/engine_constants.json`, when compared field-by-field to `constants.py`, then every terrain/niveau/incident/récence value matches exactly, including `INCIDENTS`' `chute` and `ignore` booleans (not just `malus`).
- Given a deliberately-wrong value hand-edited into the fixture (manual check, not automated), when the new validation test runs, then it fails.

## Verification

**Commands:**
- `cd backend && pytest tests/ -v` -- expected: 57 passed

## Suggested Review Order

**The shared fixture**

- Entry point: what's mirrored, its scope boundary, and the read-only relationship to `constants.py`.
  [`engine_constants.json:2`](../../fixtures/engine_constants.json#L2)

- `INCIDENTS` — the one table with structure beyond a flat number (malus/chute/ignore per code).
  [`engine_constants.json:37`](../../fixtures/engine_constants.json#L37)

**Loader hardening (added during review)**

- Duplicate-key detection during JSON parsing — closes a silent last-key-wins risk `engine_cases.json`'s loader didn't need to guard against the same way.
  [`test_scoring.py:58`](../../backend/tests/test_scoring.py#L58)

- The validation test itself, now with named assertion messages instead of bare `KeyError` on a malformed fixture.
  [`test_scoring.py:294`](../../backend/tests/test_scoring.py#L294)

**Peripherals**

- One-line pointer added to the runtime source of truth, so a future editor of these tables sees the fixture exists.
  [`constants.py:1`](../../backend/app/engine/constants.py#L1)
