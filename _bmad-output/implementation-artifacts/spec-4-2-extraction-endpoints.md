---
title: 'Story 4.2: /extraction/fiche and /extraction/programme endpoints'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 1
context: ['{project-root}/_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md']
baseline_commit: '60e72574e06450d2ec6e7baf1472129a75e03628'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `routes_analyse.py` already has two stub endpoints, `POST /extraction/fiche` and `POST /extraction/programme`, both hardcoded to `raise HTTPException(501)` with a naive `image: bytes` signature that loses the upload's content-type — the vision-extraction adapter built in Story 4.1 (`vision_client.py`) has no caller yet.

**Approach:** Replace both stubs with real implementations: accept a multipart file upload, validate its content-type, call the matching `vision_client` function, and return a typed Pydantic response — never persisting anything, since the cahier requires extracted fields stay "à vérifier" until the user confirms them client-side.

## Boundaries & Constraints

**Always:**
- Accept the file via FastAPI `UploadFile = File(...)`, replacing the current `image: bytes` param — a raw body loses the original content-type header that `vision_client` needs to pick image vs. document content blocks.
- Validate `file.content_type` against an accepted set (`image/png`, `image/jpeg`, `image/webp`, `image/gif`, `application/pdf`) BEFORE calling `vision_client` — reject anything else with `HTTPException(400)`, so no vision budget unit is ever spent on an unsupported type (closes the "media_type never validated" item logged in `deferred-work.md` from Story 4.1's review).
- Build the response from a typed Pydantic schema via `.model_validate()` on the `vision_client` dataclass (`from_attributes=True`) — never a raw dict or dataclass passthrough (AD-4; mirrors `/analyse`'s existing `HorseOut.model_validate(horse)` pattern in this same file).
- Catch `vision_client.VisionBudgetExceeded` → `HTTPException(429, ...)`; catch `vision_client.VisionExtractionError` → `HTTPException(502, ...)`. Both `detail` strings must be generic/user-safe, never echoing the caught exception's raw message (which could carry upstream response fragments).
- Add `python-multipart` to `backend/requirements.txt` — required by FastAPI for `UploadFile`/`File(...)` parsing, not currently a dependency.

**Never:**
- Do not modify `vision_client.py` — read-only, already reviewed and committed in Story 4.1.
- Do not touch anything under `mobile/` — Story 4.3.
- Do not persist extracted data anywhere (no `repository.py` writes) — the endpoint's only job is to return JSON for client-side review.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Valid PNG to `/extraction/fiche` | Mocked `extract_fiche_cheval` returns populated data | `200`, JSON body matches the mocked `FicheChevalExtraite` field-for-field | N/A |
| Valid PDF to `/extraction/programme` | `content_type="application/pdf"` | `200`; `vision_client.extract_programme` called with the exact uploaded bytes and `"application/pdf"` | N/A |
| Unsupported content-type | e.g. `content_type="text/plain"` | `400`; `vision_client` function is NOT called | Rejected before any vision call |
| Daily budget exhausted | `vision_client` raises `VisionBudgetExceeded` | `429` | Generic detail message |
| Vision call/parse fails | `vision_client` raises `VisionExtractionError` | `502` | Generic detail message |

</frozen-after-approval>

## Code Map

- `backend/app/api/routes_analyse.py:62-68` -- MODIFY -- replace the two 501 stubs with real implementations
- `backend/app/schemas/extraction.py` -- TO CREATE -- `FicheExtraiteOut`/`ProgrammeExtraitOut` (+ nested perf/horse schemas), mirroring `vision_client.py`'s dataclasses field-for-field, `model_config = ConfigDict(from_attributes=True)`
- `backend/app/data/vision_client.py` -- READ-ONLY -- `extract_fiche_cheval`/`extract_programme`, `VisionBudgetExceeded`/`VisionExtractionError`, the dataclasses the new schemas mirror
- `backend/app/schemas/analyse.py:81-102` -- READ-ONLY -- precedent for the `from_attributes=True` + `.model_validate()` pattern (`HorseOut`)
- `backend/requirements.txt` -- MODIFY -- add `python-multipart`
- `backend/tests/test_routes_analyse.py` -- MODIFY -- add tests for both endpoints, mocking `vision_client`'s two functions at their import path in `routes_analyse.py`

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/schemas/extraction.py` -- create the typed response schemas
- [x] `backend/app/api/routes_analyse.py` -- implement both endpoints per Boundaries
- [x] `backend/requirements.txt` -- add `python-multipart`
- [x] `backend/tests/test_routes_analyse.py` -- tests covering the I/O matrix (multipart uploads via `TestClient`, `vision_client` mocked)
- [x] Run `pytest backend/tests/ -v` -- all pass, no regressions

**Acceptance Criteria:**
- Given the 5 I/O matrix scenarios, when each runs against a live `TestClient`, then it produces exactly the documented status code and body shape.
- Given the full backend test suite, when run after this story, then it passes with the new tests included and zero regressions.

## Verification

**Commands:**
- `cd backend && pytest tests/ -v` -- expected: 141 + (new extraction-route tests) passed, 0 regressions -- actual (implementation, pre-review): 149 passed (141 + 8 new), 0 regressions.
- Post-review (3-lens review: blind-hunter, edge-case-hunter, verification-gap), re-verified independently in a fresh throwaway `uv venv .verify-venv10` (Python 3.12) -- **actual: 158 passed** (149 + 9 new tests added during review triage), 0 regressions. Throwaway venv removed after the run.

## Review Findings & Resolution

Three parallel review lenses ran against the implementation. Triage:

**Fixed directly (4 source-code changes, consolidated into one shared helper, + 6 new tests):**
- Extracted `_run_extraction()` ([routes_analyse.py:47-71](backend/app/api/routes_analyse.py#L47-L71)) — both endpoints now share one code path instead of duplicating the try/except (blind-hunter). Consolidating it also fixed two other findings for free:
  - `.model_validate()` now runs INSIDE the try block, so a malformed `vision_client` response (a Pydantic `ValidationError`) degrades to the documented `502`, not an unhandled `500` (edge-case-hunter).
  - Added an explicit empty-file-body check (`400`) and a `MAX_EXTRACTION_FILE_SIZE_BYTES` (20 MiB) ceiling (`413`) — closes the "no upload size limit before memory is consumed" finding both blind-hunter and edge-case-hunter raised independently.
- `_validate_extraction_content_type` now normalizes (`.split(";")[0].strip().lower()`) before matching — a case-different or parameter-suffixed but otherwise-supported content-type (`IMAGE/PNG`, `image/png; charset=binary`) no longer gets wrongly rejected (blind-hunter finding #14, edge-case-hunter finding #2).
- New tests: 3 for the previously-unexercised `image/jpeg`/`image/webp`/`image/gif` types (**verification-gap's confirmed gap** — only 2 of 5 accepted types were ever tested, so a silently narrowed accepted-set would have passed every prior test), 3 for content-type normalization, 1 empty-body/400, 1 oversized/413, 1 malformed-response/502.

**Logged to `deferred-work.md`:**
- **Needs a human policy decision:** no cap on `perfs`/`horses` list length despite the ported prompts promising "maximum 6" (truncate vs. reject vs. leave as-is isn't obvious); `Content-Type` is trusted from the client header with no magic-byte sniffing (would need a new dependency to fix).
- Lower-priority: a filename-less multipart part bypasses the documented error taxonomy via FastAPI's own 422; `file.read()` isn't wrapped against a mid-upload client disconnect; harmless redundant double Pydantic validation from `response_model=` + explicit `.model_validate()`.

## Suggested Review Order

1. [backend/app/api/routes_analyse.py:47-71](backend/app/api/routes_analyse.py#L47-L71) — the new `_run_extraction` helper, all 4 code fixes in one place.
2. [backend/app/api/routes_analyse.py:124-130](backend/app/api/routes_analyse.py#L124-L130) — both route functions, now trivial one-liners delegating to the helper.
3. [backend/tests/test_routes_analyse.py:443-468](backend/tests/test_routes_analyse.py#L443-L468) — new `test_extraction_reponse_mal_formee_de_vision_client_renvoie_502_pas_500`, the most subtle new test (needed a nested-field-missing object, not just an empty one, to actually trigger `ValidationError` given every top-level field has a default).
4. [backend/tests/test_routes_analyse.py:390-412](backend/tests/test_routes_analyse.py#L390-L412) — the verification-gap-confirmed fix (3 previously-untested content types) + content-type normalization tests.
5. [_bmad-output/implementation-artifacts/deferred-work.md](_bmad-output/implementation-artifacts/deferred-work.md) — new entries, especially the `perfs`/`horses` list-length policy decision needed before this ships to real users.
