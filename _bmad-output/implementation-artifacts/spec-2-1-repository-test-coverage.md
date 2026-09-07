---
title: 'Story 2.1: Test coverage for repository.py'
type: 'chore'
created: '2026-09-07'
status: 'done'
review_loop_iteration: 1
context: ['{project-root}/docs/cahier_des_charges_backend_hippique.md']
baseline_commit: '06b3a7326e7f2b31769dd3218d06e04d74d61562'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `backend/app/data/repository.py` — the sole persistence layer, already intact and used in production paths (`/courses`, `/analyse` via `course_id`, the daily ingestion job) — has zero test coverage. Its two documented "pièges" (cahier backend §6.2: `num_pmu` instability, source-priority conflict rules between the daily PMU feed and the backfill) are exactly the kind of subtle behavior that regresses silently without a test pinning it down.

**Approach:** Add `backend/tests/test_repository.py` using the temp-file-SQLite convention already established in `test_main.py`. Cover the 9 behaviors listed in Boundaries — each traced to either a code comment/docstring in `repository.py` itself or the cahier des charges, not invented.

## Boundaries & Constraints

**Always:**
- Use a real temp SQLite file (`tempfile.mkstemp` + `atexit` cleanup), never `:memory:` — same reasoning as `test_main.py` (Repository's own session pattern needs the DB visible regardless of which thread touches it).
- Each test constructs its own `Repository(database_url=...)` against a fresh temp file (or a shared one within one test function) — never reuse a DB file across test functions, to keep tests independent and order-proof.
- Cover exactly these 9 behaviors, each already true of the existing code (verify by reading it, do not guess):
  1. `upsert_course` creates a new `Course`; called again with the same `(date, numero_reunion, numero_course)` updates the existing row (no duplicate).
  2. `upsert_cheval` creates a new `Cheval` matched by `nom_normalise`; called again with the same (or differently-cased/spaced) name reuses the existing row.
  3. `save_partants` creates `Participation` rows; called again for the same `(course_id, cheval_id)` updates rather than duplicates.
  4. `save_historique`: a conflicting row on `(cheval_id, date_course, hippodrome)` is always overwritten (`source="pmu"` wins unconditionally, per the method's own docstring).
  5. `ajouter_performance_historique_backfill`: the opposite conflict rule — `on_conflict_do_nothing`, an existing row is never overwritten; returns `True` when it actually inserted, `False` when skipped as a duplicate.
  6. `get_horses_for_course`: performances come back sorted most-recent-first (`date_course` descending); `terrain` is resolved through `constants.terrain_coefficient()` (a stored label maps to its float, an unrecognized/`NULL` label yields `None`); `niveau` is always `None` (the method does not attempt a niveau lookup — this is the current real behavior, not a gap to silently "fix").
  7. `get_unfinalized_courses_before(target_date)` returns only courses with `date < target_date` AND `finalisee is False`.
  8. `update_resultats` updates `rang_arrivee`/`incident` per participation matched by `num_pmu`, and sets the course's `finalisee` flag.
  9. `get_hippodromes_connus` returns the distinct set of hippodromes already present in a cheval's `performances_historiques`.

**Never:**
- Do not test `Repository._migrate()`'s defensive ALTER-TABLE paths (would require crafting a synthetic pre-migration database file) — meaningfully harder to set up than the value it adds here; note as deferred, not silently skipped.
- Do not modify `repository.py`, `models.py`, `pmu_client.py`, or `open_pmu_client.py` — read-only this story.
- Do not add coverage for `import_course` (currently a no-op `pass` — nothing to test) or `list_courses_for_date`/`get_course_by_id` beyond what's incidentally exercised by the 9 behaviors above (they're simple queries, not separately called out because nothing subtle is documented about them).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Course upsert, same key twice | `upsert_course(info)` called twice with identical `date/numero_reunion/numero_course`, differing `allocation` | One `Course` row; second call's fields win | N/A |
| Historique conflict, pmu wins | A row exists from backfill (`source="open_pmu_api"`), then `save_historique` writes a conflicting `(cheval_id, date_course, hippodrome)` | Row's `source` becomes `"pmu"`, other fields overwritten | N/A |
| Backfill never overwrites | A row exists (any source), then `ajouter_performance_historique_backfill` targets the same key | Row unchanged, method returns `False` | N/A |
| Terrain label unresolved | `PerformanceHistorique.terrain` is a label `terrain_coefficient()` doesn't recognize (or `NULL`) | Resulting `Performance.terrain is None`, no exception | N/A |

</frozen-after-approval>

## Code Map

- `backend/tests/test_repository.py` -- TO CREATE
- `backend/app/data/repository.py` -- READ-ONLY -- the 9 methods under test
- `backend/app/data/models.py` -- READ-ONLY -- ORM schema (`Course`, `Cheval`, `Participation`, `PerformanceHistorique`)
- `backend/app/data/pmu_client.py` -- READ-ONLY -- `CourseInfo`/`PartantInfo`/`PerformancePassee` dataclasses these methods accept
- `backend/app/engine/constants.py` -- READ-ONLY -- `terrain_coefficient()`, consumed by `get_horses_for_course`
- `backend/tests/test_main.py` -- precedent -- temp-file-SQLite convention to follow exactly

## Tasks & Acceptance

**Execution:**
- [x] `backend/tests/test_repository.py` -- 9 tests (one per Boundaries behavior, at minimum) using the temp-file convention
- [x] Run `pytest backend/tests/ -v` -- all pass, no regressions

**Acceptance Criteria:**
- Given the 9 behaviors listed in Boundaries, when their respective tests run, then each passes and would fail if the corresponding real behavior were broken (not a vacuous assertion).
- Given the full backend test suite, when run after this story, then it passes with the new tests included and zero regressions in existing tests.

## Verification

**Commands:**
- `cd backend && pytest tests/ -v` -- expected: 78 + (≥9 new) passed -- actual (implementation, pre-review): 87 passed (78 pre-existing + 9 new in `test_repository.py`), 0 regressions. Run via a `python:3.12-slim` Docker container (no local Python interpreter available in this environment; only the Microsoft Store alias stub was present) with `pip install -r requirements-dev.txt httpx2` (newer `starlette` versions require `httpx2` for `TestClient` — pre-existing environment dependency, unrelated to this story) and `python -m pytest tests/ -v` run from `backend/` with the repo root mounted (needed for `test_scoring.py`'s `../../fixtures/*.json` fixtures).
- Post-review (3-lens review: blind-hunter, edge-case-hunter, verification-gap), re-verified independently in a fresh throwaway `uv venv .verify-venv2` (Python 3.12) + `uv pip install -r requirements-dev.txt httpx2` + `python -m pytest tests/ -v`, run from `backend/` -- **actual: 92 passed** (87 + 5 new tests added during review triage), 0 regressions. Both throwaway venvs removed after the run.

## Review Findings & Resolution

Three parallel review lenses ran against the implementation (blind-hunter, edge-case-hunter, verification-gap). Triage:

**Fixed directly (5 new tests + 1 fixture hardening + 1 docstring update):**
- `test_get_horses_for_course_tri_terrain_et_niveau` strengthened to assert `nom`/`num_pmu`/`age`/`poids`/`cote`/`inedit` on the returned `HorseAnalysis`, not just its performances — a field-mapping regression in `get_horses_for_course` (repository.py:133-141) would previously have passed unnoticed.
- New `test_get_horses_for_course_cote_repli_sur_cote_direct_si_reference_absente` — the `cote_reference or cote_direct` fallback (repository.py:138) had no test exercising the `cote_reference=None` branch.
- New `test_save_partants_meme_cheval_deux_courses_identite_partagee_participations_distinctes` — proves cross-course horse identity (cahier §6.2): same `nom_normalise` across two courses shares one `Cheval.id` but produces two independent `Participation` rows.
- `test_get_hippodromes_connus_retourne_ensemble_distinct` strengthened with a second, unrelated `Cheval` and its own hippodrome, asserting the first cheval's result excludes it — proves the query is scoped by `cheval_id`, not table-wide (verification-gap finding: the prior version would have passed even if `get_hippodromes_connus` ignored its `cheval_id` argument entirely).
- New `test_save_historique_num_pmu_sans_participation_correspondante_est_ignore` — covers the `if participation is None: continue` skip branch (repository.py:232-234) for an orphaned `num_pmu`.
- `test_get_unfinalized_courses_before` split into 3: the original mixed case, plus new `test_get_unfinalized_courses_before_aucune_qualifiante_retourne_vide` (empty result) and `test_get_unfinalized_courses_before_plusieurs_qualifiantes` (multiple qualifying courses returned together).
- `test_upsert_course_meme_cle_met_a_jour_sans_dupliquer` strengthened to assert all 7 fields `upsert_course` rewrites on every call (repository.py:155-162: `libelle`, `hippodrome`, `discipline`, `distance`, `corde`, `nb_partants`), not just `allocation`.
- `repo` fixture: added `atexit.unregister(_cleanup)` after the explicit per-test `_cleanup()`, preventing atexit handler accumulation across a full test run (minor, no functional impact).
- Module docstring extended to document `get_cheval_by_id` and `import_course` as out of scope and point to `deferred-work.md` for narrower deferred branches.

**Logged to `deferred-work.md` (lower value relative to cost, or genuinely out of this story's scope):**
- `get_cheval_by_id` itself untested (only documented as out of scope).
- `update_resultats`'s `arrivee_definitive=False` path and its own "participation not found" skip branch.
- `save_historique` / `ajouter_performance_historique_backfill` called with multiple performances in one call.
- Further under-asserted fields on `save_partants` / `ajouter_performance_historique_backfill`.
- Calling repository methods against a nonexistent `course_id`.
- **Product-relevant, not test-only:** `get_horses_for_course`'s `niveau` is always `None` in production (repository.py:128 hardcodes it) — flagged for attention in a future Epic 2 ingestion story, not a test gap.

**Explicitly skipped (judged over-engineering for test helpers):** edge-case-hunter's 3 findings about validating unknown override keys in `make_course_info`/`make_partant_info`/`make_performance_passee` — these are test-only factory helpers, not production code; adding key-validation to them was judged to add cost without proportionate value.

## Suggested Review Order

1. [backend/app/data/repository.py:107-142](backend/app/data/repository.py#L107-L142) — `get_horses_for_course`, the mapping under test in the strengthened test #6 and the new cote-fallback test.
2. [backend/tests/test_repository.py:291-358](backend/tests/test_repository.py#L291-L358) — strengthened `test_get_horses_for_course_tri_terrain_et_niveau` + new `test_get_horses_for_course_cote_repli_sur_cote_direct_si_reference_absente`.
3. [backend/tests/test_repository.py:174-199](backend/tests/test_repository.py#L174-L199) — new cross-course identity test, `test_save_partants_meme_cheval_deux_courses_identite_partagee_participations_distinctes`.
4. [backend/tests/test_repository.py:426-446](backend/tests/test_repository.py#L426-L446) — `get_hippodromes_connus` scoping test with the second cheval.
5. [backend/app/data/repository.py:222-260](backend/app/data/repository.py#L222-L260) — `save_historique`, against the new orphaned-`num_pmu` skip-branch test at [backend/tests/test_repository.py:242-256](backend/tests/test_repository.py#L242-L256).
6. [_bmad-output/implementation-artifacts/deferred-work.md](_bmad-output/implementation-artifacts/deferred-work.md) — new entries, especially the product-relevant `niveau` finding.
