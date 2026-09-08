---
title: 'Story 4.1: vision_client.py — isolated, budget-guarded extraction adapter'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 1
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md']
baseline_commit: 'c39b44a435d9965a4c55494c54717e56775fb29d'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 4 (photo import fallback, FR-18/FR-19) needs a vision-extraction call to Anthropic Claude, but nothing in the backend talks to a third-party AI provider yet — this is the first paid external vendor integration (AD-3), and it must never leak an API key or a runaway budget outside one isolated module.

**Approach:** Create `backend/app/data/vision_client.py`, mirroring the adapter-isolation pattern already proven by `pmu_client.py`/`open_pmu_client.py`: two normalized functions (`extract_fiche_cheval`, `extract_programme`) that are the ONLY code in the repo that knows the Anthropic request/response shape, enforcing a daily call ceiling before any request is sent.

## Boundaries & Constraints

**Always:**
- Port the exact two prompts from `docs/analyse_hippique_ia.jsx:291-305` (`PROMPT`, fiche cheval) and `:307-319` (`RACE_PROMPT`, programme) verbatim — never rewritten, never "improved" (NFR-6).
- `extract_fiche_cheval(file_bytes: bytes, media_type: str) -> FicheChevalExtraite` and `extract_programme(file_bytes: bytes, media_type: str) -> ProgrammeExtrait` — typed dataclasses mirroring each prompt's JSON schema field-for-field (`name`/`num`/`age`/`poids`/`cote`/`perfs`/`rank`/`part`/`incident`/`niveau`/`dist`/`terr` for fiche; `hippo`/`dist`/`terr`/`niveau`/`partants`/`horses`/... for programme) — never a raw dict passed through untyped.
- `media_type == "application/pdf"` uses a `document` content block; any `image/*` uses an `image` content block — mirrors `docs/analyse_hippique_ia.jsx:322-325`.
- Anthropic API key read from `ANTHROPIC_API_KEY` env var only — never hardcoded, never included in a log line or exception message.
- Model name from `ANTHROPIC_VISION_MODEL` env var, default `"claude-sonnet-5"` — the prototype's `"claude-sonnet-4-6"` (`docs/analyse_hippique_ia.jsx:330`) is stale (AD-3 Provenance: re-verify, don't assume).
- Enforce `VISION_DAILY_CALL_LIMIT` (env var, int) via an in-memory counter keyed by the current UTC calendar date (AD-3 explicitly allows in-memory). A call at/past the ceiling raises `VisionBudgetExceeded` BEFORE any HTTP request is made (the blocked call must not itself consume budget) and logs loudly (`logger.error`).
- A non-2xx HTTP response, or model output that isn't valid JSON after stripping ` ```json`/` ``` ` fences (mirrors `docs/analyse_hippique_ia.jsx:339-341`), raises `VisionExtractionError` — never an unhandled `requests`/`json` exception leaking to the caller.

**Never:**
- Do not add the `/extraction/fiche`/`/extraction/programme` API routes — Story 4.2.
- Do not touch anything under `mobile/` — Story 4.3 (also actively worked on in a parallel session right now).
- Do not add the `anthropic` SDK as a new dependency — use `requests`, matching `pmu_client.py`/`open_pmu_client.py`'s existing raw-HTTP adapter pattern (see Design Notes).
- Do not persist extracted data anywhere — no `repository.py` dependency in this module.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fiche image, valid model JSON | `media_type="image/png"`, mocked 200 response with fiche-shaped JSON | `FicheChevalExtraite` populated from the JSON | N/A |
| Programme PDF | `media_type="application/pdf"` | Request body's content block has `type="document"`, not `"image"` | N/A |
| Daily limit already reached | `VISION_DAILY_CALL_LIMIT=5`, 5 calls already made today | `VisionBudgetExceeded` raised; the mocked HTTP call is NOT made (call count unchanged) | Logged loudly |
| Model wraps JSON in code fences | Response text is `` ```json\n{...}\n``` `` | Fences stripped, JSON parsed successfully | N/A |
| Non-2xx response or malformed JSON | Mocked 429/500, or unparseable text | `VisionExtractionError` raised | Logged, not swallowed |

</frozen-after-approval>

## Code Map

- `backend/app/data/vision_client.py` -- TO CREATE
- `docs/analyse_hippique_ia.jsx:291-342` -- READ-ONLY -- source of `PROMPT`/`RACE_PROMPT` (verbatim) and the reference `extractFromImage` call shape (model, content blocks, fence-stripping) to port to Python
- `backend/app/data/pmu_client.py` -- READ-ONLY -- precedent for adapter isolation: module docstring pattern, raw `requests` usage, normalized dataclass returns, `_normalize_name`-style small helpers
- `backend/app/data/open_pmu_client.py` -- READ-ONLY -- precedent for defensive parsing of untrusted external JSON (`_to_float`/`_to_int` style helpers) — vision model output, like PMU JSON, cannot be fully trusted
- `backend/tests/test_vision_client.py` -- TO CREATE

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/data/vision_client.py` -- implement `extract_fiche_cheval`/`extract_programme`, `VisionBudgetExceeded`/`VisionExtractionError`, the in-memory daily counter, and the two ported prompts
- [x] `backend/tests/test_vision_client.py` -- tests covering the I/O matrix, mocking `requests.post` (never a real HTTP call)
- [x] Run `pytest backend/tests/ -v` -- all pass, no regressions

**Acceptance Criteria:**
- Given a mocked successful Anthropic response for a fiche image, when `extract_fiche_cheval` is called, then it returns a `FicheChevalExtraite` whose fields match the mocked JSON.
- Given `VISION_DAILY_CALL_LIMIT` calls already made today, when either extraction function is called again, then `VisionBudgetExceeded` is raised and the mocked HTTP call count does not increase.
- Given a non-2xx response or malformed model output, when either extraction function is called, then `VisionExtractionError` is raised, not a raw `requests`/`json` exception.

## Design Notes

`requests` over the `anthropic` SDK: `pmu_client.py`/`open_pmu_client.py` both talk to their respective REST APIs with raw `requests`, no vendor SDK — staying consistent avoids introducing a second HTTP-calling convention into the codebase for one module, and the Messages API surface this job needs (one POST, one response) is small enough that the SDK buys little here.

Daily counter reset: compare `date.today()` (or `datetime.now(timezone.utc).date()`) against a stored "last reset date" module-level variable; if different, reset the counter to 0 before checking the ceiling — simplest correct approach for a single-process bootstrap deployment (AD-3 explicitly permits in-memory).

## Verification

**Commands:**
- `cd backend && pytest tests/ -v` -- expected: 117 + (new vision_client tests) passed, 0 regressions -- actual (implementation, pre-review): 133 passed (117 pre-existing + 16 new in `test_vision_client.py`), 0 regressions. Independently re-verified in a fresh throwaway `uv venv .verify-venv7` (Python 3.12), same result, 0 regressions; throwaway venv removed after the run. Both `PROMPT` and `RACE_PROMPT` diffed byte-for-byte against `docs/analyse_hippique_ia.jsx` and confirmed identical (NFR-6).
- Post-review (3-lens review: blind-hunter, edge-case-hunter, verification-gap), re-verified independently in a fresh throwaway `uv venv .verify-venv8` (Python 3.12) -- **actual: 141 passed** (117 + 24 new tests, 16 from implementation + 8 added during review triage), 0 regressions. Throwaway venv removed after the run.

## Review Findings & Resolution

Three parallel review lenses ran against the implementation (blind-hunter, edge-case-hunter, verification-gap) — the first review of a story that ships new production code (not test-coverage-only, unlike Epic 2), so 2 real source-code fixes were made alongside 8 new tests.

**Fixed directly (2 code changes + 8 new tests):**
- **Code fix 1** ([vision_client.py:233-239](backend/app/data/vision_client.py#L233-L239)): moved the `ANTHROPIC_API_KEY` presence check to run BEFORE `_enforce_budget()`, not after. A missing key guarantees no HTTP request will ever be attempted, so it must not consume a unit of the daily budget — only a real attempt (even one that fails) should (blind-hunter finding #3).
- **Code fix 2** ([vision_client.py:144-179](backend/app/data/vision_client.py#L144-L179)): added a `threading.Lock()` around `_enforce_budget`'s read-compare-increment sequence. FastAPI runs sync handlers in a threadpool, so two concurrent requests could both observe the counter under the limit before either increments it, defeating the exact guarantee AD-3 exists to provide — "mono-process" (which AD-3 permits) does not mean "mono-thread" (blind-hunter finding #2).
- `test_missing_api_key_checked_before_budget_is_consumed` / strengthened `test_missing_api_key_raises_extraction_error_without_http_call` — lock in fix 1.
- `test_budget_consumed_even_on_http_failure` — documents the deliberate contrast: a real (failed) network attempt DOES consume budget, unlike a blocked missing-key call.
- `test_daily_limit_enforced_across_real_sequential_calls` / `test_daily_limit_zero_blocks_every_call` — the existing limit tests only ever pre-set the internal counter directly; these drive the boundary via real successive calls instead (edge-case-hunter).
- `test_request_headers_use_x_api_key_not_authorization` — **verification-gap's cleanest-confirmed miss**: no test inspected outgoing request headers at all; a wrong/renamed auth header would fail every real call with a 401 while passing 100% of the prior suite.
- `test_top_level_json_array_raises_extraction_error_not_attribute_error` / `test_non_dict_entry_in_perfs_is_dropped_not_crashed` — a JSON array response or a malformed `perfs` entry are both valid-but-unexpected model outputs; proven to degrade to `VisionExtractionError`/a silent drop rather than an unhandled `AttributeError` (edge-case-hunter).
- `test_prompts_match_prototype_source_exactly` — replaces spot-check-only NFR-6 verification with a full-string diff against `docs/analyse_hippique_ia.jsx` itself, mechanically locking in "never reworded" going forward.

**Logged to `deferred-work.md`:**
- **Needs human verification before production use:** shared `max_tokens: 2000` risks truncating large programme extractions; an unverified claim that Claude Sonnet 5 may consume that same budget via default extended thinking (not independently confirmed against current Anthropic docs — flagged, not treated as fact).
- Lower-priority: `media_type` not validated against a known-supported list before budget is spent; multi-text-block joining (inherited from the prototype, not a regression); narrow fence-stripping/date-reset edge cases; no INFO-level cost/audit logging (deliberate, leak-avoidance tradeoff); `VISION_DAILY_CALL_LIMIT` re-read uncached (log-spam risk under sustained misconfiguration); empty `file_bytes` not locally rejected before a network round-trip.

## Suggested Review Order

1. [backend/app/data/vision_client.py:141-179](backend/app/data/vision_client.py#L141-L179) — `_enforce_budget`, the two code fixes (API-key-before-budget ordering, the new `threading.Lock`).
2. [backend/tests/test_vision_client.py:289-343](backend/tests/test_vision_client.py#L289-L343) — the four new budget-semantics tests proving both fixes.
3. [backend/tests/test_vision_client.py:345-359](backend/tests/test_vision_client.py#L345-L359) — new `test_request_headers_use_x_api_key_not_authorization`, the verification-gap-confirmed fix.
4. [backend/tests/test_vision_client.py:268-287](backend/tests/test_vision_client.py#L268-L287) — new `test_prompts_match_prototype_source_exactly`, mechanically locking NFR-6.
5. [_bmad-output/implementation-artifacts/deferred-work.md](_bmad-output/implementation-artifacts/deferred-work.md) — new entries, especially the `max_tokens`/extended-thinking item needing human verification before Story 4.2 wires real traffic through this module.

## Note on this file's history

This spec file was found missing from disk mid-review (never committed — the implementation files `vision_client.py`/`test_vision_client.py` were unaffected and remained intact). It was recreated verbatim from conversation history before continuing the review. Likely cause: a concurrent peer session sharing this same working directory (actively doing Epic 3 mobile work) performed a file operation that removed untracked files outside its own scope. Separately, the original implementation subagent (`a5f4f7397de08890c`) reported "completed" via task notification but was later found still `running` in `ListAgents` and was explicitly stopped (`TaskStop`) before any review-driven edits — files were re-read from disk afterward and confirmed intact. Worth keeping both hazards in mind for any future work done in parallel sessions against this same repo path.
