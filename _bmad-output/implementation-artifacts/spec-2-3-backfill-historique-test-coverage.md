---
title: 'Story 2.3: Test coverage for jobs/backfill_historique.py'
type: 'chore'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 1
context: ['{project-root}/docs/cahier_des_charges_backend_hippique.md']
baseline_commit: 'b5df0f73ac745c7a2e13232c4ce981aee66b71eb'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `backend/app/jobs/backfill_historique.py` — the manual deep-history backfill job (Epic 2, last of its 3 stories) — is intact and already used in production (also called from `POST /chevaux/{id}/backfill`, cahier mobile §7.4), but has zero test coverage. Its two functions have a subtle, deliberate divergence in which date they persist (`jour` requested vs. `arrivee.date` parsed from the response) that would regress silently.

**Approach:** Add `backend/tests/test_backfill_historique.py`, same convention as Stories 2.1/2.2: real `Repository` against temp-file SQLite, mock only `open_pmu_client.get_arrivees` (the network boundary, AD-1).

## Boundaries & Constraints

**Always:**
- Use the temp-file-SQLite `repo` fixture convention from `backend/tests/test_repository.py`.
- Mock `app.jobs.backfill_historique.open_pmu_client.get_arrivees` only — never real HTTP calls.
- Cover exactly these 8 behaviors (verified by reading `backfill_historique.py`, not guessed):
  1. `backfill_plage`: iterates every day from `date_debut` to `date_fin` INCLUSIVE, calling `get_arrivees(target_date=jour, hippodrome=hippodrome)` once per day.
  2. `backfill_plage` without a `cheval` filter: persists every `ArriveeCheval` found each day. With a `cheval` filter: persists only entries whose name matches after normalization (case/whitespace-insensitive), skipping others.
  3. `backfill_plage` persists `date_course=jour` (the requested day being iterated), NOT `arrivee.date`/`date_brute` from the response — deliberate, not incidental (open_pmu_client.py's own docstring: the response date field is reliable but the loop's own known-correct day is used here regardless).
  4. `backfill_plage` resilience: if `get_arrivees` raises for one day, it's logged/swallowed and the loop continues to the next day (verify a later day still gets processed).
  5. `backfill_plage`: `ajouter_performance_historique_backfill`'s return value drives ajoutee/doublon counting — verify via the repository's actual persisted state (row exists once, not duplicated) rather than the log output.
  6. `backfill_cheval_par_hippodromes_connus`: for each hippodrome in the given list, calls `get_arrivees(hippodrome=hippodrome)` (no date filter), filters chevaux by exact normalized-name match only, and persists matches with `date_course=arrivee.date` (the response's own parsed date — deliberately DIFFERENT from behavior #3, since there's no single requested day here).
  7. `backfill_cheval_par_hippodromes_connus` resilience: if `get_arrivees` raises for one hippodrome, it's logged/swallowed and the loop continues to the next hippodrome.
  8. `backfill_cheval_par_hippodromes_connus` returns the count of rows actually inserted (True from `ajouter_performance_historique_backfill`) — duplicates are not counted in the returned total.

**Never:**
- Do not modify `backfill_historique.py`, `open_pmu_client.py`, or `repository.py` — read-only this story.
- Do not test `open_pmu_client.py`'s own HTTP/parsing logic — out of scope, it's the mocked boundary here.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Single-day range | `date_debut == date_fin` | Exactly one `get_arrivees` call, for that one day | N/A |
| One day fails mid-range | `get_arrivees` raises for day 2 of 3 | Days 1 and 3 still processed; day 2's failure logged | Exception swallowed, not propagated |
| `cheval` filter excludes non-matching horses | Arrivee has 2 chevaux, `cheval="Bucephale"` matches only 1 | Only the matching one is persisted | N/A |
| Duplicate arrivee row across two backfill calls | Same (cheval, date, hippodrome) backfilled twice | Second call returns `False` from the repository, not double-counted as `ajoutee` | N/A |

</frozen-after-approval>

## Code Map

- `backend/tests/test_backfill_historique.py` -- TO CREATE
- `backend/app/jobs/backfill_historique.py` -- READ-ONLY -- `backfill_plage` (L24-77), `backfill_cheval_par_hippodromes_connus` (L80-120) — both under test
- `backend/app/data/open_pmu_client.py` -- READ-ONLY -- `get_arrivees` (L141-216) mocked; `Arrivee`/`ArriveeCheval` dataclasses (L110-138) mock return values must use; note `Arrivee.date` (parsed, reliable) vs. the loop's own `jour` — the two functions deliberately use different date sources (see Boundaries #3, #6)
- `backend/app/data/repository.py` -- READ-ONLY -- `ajouter_performance_historique_backfill` already covered by Story 2.1 (`test_repository.py`), reused here as the persistence side of these job tests
- `backend/tests/test_repository.py` / `backend/tests/test_ingest_daily.py` -- precedent -- `repo` fixture and dataclass-factory-helper pattern to reuse/adapt

## Tasks & Acceptance

**Execution:**
- [x] `backend/tests/test_backfill_historique.py` -- 13 tests (10 from initial implementation, one per Boundaries behavior at minimum with #1/#2 split into 2 tests each for I/O-matrix sub-cases; 3 more added during review triage), reusing the `repo` fixture pattern and mocking `open_pmu_client.get_arrivees`
- [x] Run `pytest backend/tests/ -v` -- all pass, no regressions

**Acceptance Criteria:**
- Given the 8 behaviors listed in Boundaries, when their respective tests run, then each passes and would fail if the corresponding real behavior were broken (not a vacuous assertion).
- Given the full backend test suite, when run after this story, then it passes with the new tests included and zero regressions in existing tests.

## Verification

**Commands:**
- `cd backend && pytest tests/ -v` -- expected: 104 + (≥8 new) passed, 0 regressions -- actual (implementation, pre-review): 114 passed (104 pre-existing + 10 new in `test_backfill_historique.py`), 0 regressions. Run via `uv run` (no local Python interpreter available in this environment; only the Microsoft Store alias stub was present) with `requirements-dev.txt` plus pinned `fastapi==0.115.6 starlette==0.41.3 httpx==0.28.1` (newer unpinned `starlette`/`fastapi` resolve to versions requiring a nonexistent `httpx2` package for `TestClient` — pre-existing environment dependency, unrelated to this story, same finding as Stories 2.1/2.2) and `python -m pytest tests/ -v` run from `backend/` (`-m` form needed so `app` is importable — plain `pytest` does not add the cwd to `sys.path`).
- Post-review (3-lens review: blind-hunter, edge-case-hunter, verification-gap), re-verified independently in a fresh throwaway `uv venv .verify-venv6` (Python 3.12) + `uv pip install -r requirements-dev.txt httpx2` + `python -m pytest tests/ -v`, run from `backend/` -- **actual: 117 passed** (114 + 3 new tests added during review triage), 0 regressions. Throwaway venv removed after the run.

## Review Findings & Resolution

Three parallel review lenses ran against the implementation (blind-hunter, edge-case-hunter, verification-gap). Triage:

**Fixed directly (3 new tests):**
- `test_backfill_plage_transmet_tous_les_champs_de_larrivee_a_la_ligne_persistee` — **all 3 lenses independently converged on this gap**: every existing test asserted only `date_course` and/or the cheval's normalized name on the persisted `PerformanceHistorique` row; `hippodrome`, `discipline`, `allocation`, `distance`, `nb_participants`, `rang`, and `incident` were passed through by the job but never verified. Verification-gap confirmed a "right argument, wrong position" field-mapping bug (e.g. `distance`/`allocation` swapped) would pass every prior test. New test asserts all 7 fields.
- `test_backfill_plage_date_fin_avant_date_debut_ne_fait_rien` — `backfill_plage` is a public function callable directly, bypassing `main()`'s CLI guard (`--date-fin >= --date-debut`); the loop's own safe-no-op behavior for an inverted range was only inferred from reading the code, never asserted (edge-case-hunter).
- `test_backfill_cheval_par_hippodromes_liste_vide_ne_fait_rien` — the function's own docstring names this as the realistic entry state for `POST /chevaux/{id}/backfill` on a horse with no known history yet (`hippodromes=[]` from `get_hippodromes_connus`); untested (edge-case-hunter).

**Logged to `deferred-work.md`:**
- **PRODUCT-RELEVANT, not test-only (2 findings):** (1) same asymmetry pattern as Story 2.2's unguarded `get_programme` — in both `backfill_plage` and `backfill_cheval_par_hippodromes_connus`, only the `get_arrivees` fetch is guarded by try/except; the persistence loop after it is not, so one bad row can abort an entire multi-month backfill run. (2) `backfill_cheval_par_hippodromes_connus` persists `date_course=arrivee.date`, which can be `None` when `open_pmu_client._parse_date_brute` fails to parse the response — and a `None` `date_course` defeats the `(cheval_id, date_course, hippodrome)` unique-index deduplication (SQLite treats every `NULL` as distinct), risking duplicate rows on repeated calls. Neither fixed here — `backfill_historique.py` is read-only this story.
- Lower-priority: `main()`'s CLI argparse wiring untested (consistent with `ingest_daily.py`'s `main()` also untested in Story 2.2); no test for an `Arrivee` with an empty `chevaux` list; no test for a `cheval` filter matching zero horses across a full multi-day range; no test for an intra-response duplicate cheval entry (as opposed to the cross-call duplicate already covered); no `caplog` assertion on the swallowed-exception log calls.

## Suggested Review Order

1. [backend/tests/test_backfill_historique.py:185-211](backend/tests/test_backfill_historique.py#L185-L211) — new `test_backfill_plage_transmet_tous_les_champs_de_larrivee_a_la_ligne_persistee`, the highest-value fix (all 3 review lenses converged on this gap), against [backend/app/jobs/backfill_historique.py:50-60](backend/app/jobs/backfill_historique.py#L50-L60).
2. [backend/tests/test_backfill_historique.py:119-131](backend/tests/test_backfill_historique.py#L119-L131) and [:337-345](backend/tests/test_backfill_historique.py#L337-L345) — the two new safe-no-op edge case tests.
3. [_bmad-output/implementation-artifacts/deferred-work.md](_bmad-output/implementation-artifacts/deferred-work.md) — new entries, especially the two product-relevant findings (unguarded persistence loop; `None` `date_course` defeating deduplication).
