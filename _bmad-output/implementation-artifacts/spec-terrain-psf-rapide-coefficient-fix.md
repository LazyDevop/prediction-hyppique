---
title: 'Fix: PSF "Rapide" terrain coefficient (1.00 -> 1.001), backend + mobile'
type: 'fix'
created: '2026-09-09'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/implementation-artifacts/deferred-work.md', '{project-root}/docs/analyse_hippique_ia.jsx']
baseline_commit: '28f5ab6'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `deferred-work.md` flagged (from Story 4.4's review) that the vision-extraction prompt's PSF "rapide"=1.001 has no match in `mobile/lib/engine/constants.dart`'s `terrainCoefficientsPsf` (`'Rapide': 1.00`), so an imported PSF "Rapide" terrain silently reverse-looks-up as "Non renseigné" on `RaceConfigScreen`. Investigation traced this to the ORIGINAL source: `docs/analyse_hippique_ia.jsx`'s own `TERRAINS` table (line 16) already uses `1.001` for "Rapide (PSF)" — a deliberate offset from grass "Bon" (1.00), the same anti-collision pattern already applied to niveau's `Handicap`/`Maiden`/`Inédits`. The vision prompt (verbatim per NFR-6) is correct; `backend/app/engine/constants.py` and its mobile mirror are the actual divergence from the documented source of truth. A second, independent instance of the same bug was found in the process: `mobile/lib/widgets/option_lists.dart`'s `terrainOptions` already had `1.001`, disagreeing with `constants.dart`'s `1.00` even for a manually-selected (non-imported) PSF "Rapide" race.

**Approach:** restore `"Rapide": 1.001` in the three places that must agree by contract (AD-2): `backend/app/engine/constants.py`, `fixtures/engine_constants.json`, `mobile/lib/engine/constants.dart`. This is a data-correction to already-established canonical tables, not a redesign — no prompt text touched (NFR-6), no reverse-lookup logic touched.

## Boundaries & Constraints

**Always:**
- Change exactly one value (`TERRAIN_COEFFICIENTS_PSF["Rapide"]` / `terrainCoefficientsPsf['Rapide']`) from `1.00`/`1.00` to `1.001` in all three mirrored locations.
- Verify the backend's mechanical mirror test (`test_fixture_constants_matches_constants_py`) and the mobile equivalent (`scoring_test.dart`'s `expectMapEquals`) both still pass — they must, since both sides get the identical new value.
- Run the full backend AND mobile test suites (not just the two mirror tests) before considering this done — a coefficient value feeds live scoring math (`compute_note`/`computeNote`), not just display.

**Never:**
- Do not touch `backend/app/data/vision_client.py`'s `PROMPT`/`RACE_PROMPT` strings — verbatim-ported from `docs/analyse_hippique_ia.jsx` per NFR-6, and already correct (they already say `rapide=1.001`).
- Do not attempt to resolve the separate, still-open Handicap/Catégorie-C niveau=2 collision — that's a genuine data-ambiguity in the source photos (the vision model cannot distinguish them), not a table-value bug like this one; needs a human product decision, logged separately in `deferred-work.md`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| Manual selection, mobile | User picks "Rapide (PSF)" in `RaceConfigScreen`'s dropdown | `RaceConfig.terrain == 1.001`; `results_screen.dart`'s display (via `option_lists.dart`, already `1.001`) now shows "Rapide (PSF)", not "Bon" |
| Vision-extracted programme import | `extrait.terr == 1.001` (per the correct, unmodified prompt) | `RaceConfigScreen`'s reverse-lookup finds `'Rapide'` in `terrainCoefficientsPsf`, displays it correctly instead of "Non renseigné" |
| Backend cross-language mirror | `fixtures/engine_constants.json` vs `constants.py` | `test_fixture_constants_matches_constants_py` still passes (both updated identically) |
| Scoring math | A `Performance.terrain == 1.001` (PSF Rapide) vs a `CourseTarget.terrain` of some other value | `compute_note`/`computeNote`'s `c_terr` computation shifts by ~0.1% for this one label only — no behavior change for any other label |

</frozen-after-approval>

## Code Map

- `backend/app/engine/constants.py` -- MODIFY -- `TERRAIN_COEFFICIENTS_PSF["Rapide"]`
- `fixtures/engine_constants.json` -- MODIFY -- `terrain_coefficients_psf.Rapide` (AD-2 mirror)
- `mobile/lib/engine/constants.dart` -- MODIFY -- `terrainCoefficientsPsf['Rapide']`
- `backend/tests/test_scoring.py`, `mobile/test/engine/scoring_test.dart` -- READ-ONLY -- mirror-check tests already cover this mechanically, no new test needed

## Tasks & Acceptance

**Execution:**
- [x] `constants.py` + `engine_constants.json` + `constants.dart` updated in lockstep
- [x] Backend full suite run (Docker, no local Python interpreter available) -- 158/158 passed
- [x] Mobile full suite run -- 97/97 passed, `flutter analyze` 0 issues
- [x] `deferred-work.md` updated: this item resolved, the separate Handicap/Catégorie-C ambiguity explicitly left open with rationale

**Acceptance Criteria:**
- Given the I/O matrix above, all four scenarios hold.
- Given the full backend + mobile test suites, both pass with zero regressions after the change.

## Verification

**Commands:**
- `docker run --rm -v <repo>:/work -w /work/backend python:3.12-slim bash -c "pip install -r requirements-dev.txt httpx2 httpx && python -m pytest -q"` -- 158 passed, 1 warning (unrelated deprecation notice).
- `cd mobile && flutter test` -- 97/97 passed.
- `cd mobile && flutter analyze` -- 0 issues.
