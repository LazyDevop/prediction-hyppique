- source_spec: none
  summary: Port the reconstructed scoring engine to Dart (mobile/lib/engine/scoring.dart, mobile/test/engine/scoring_test.dart) and rebuild mobile/lib/screens/race_config_screen.dart.
  evidence: Split from the corrupted-files reconstruction intent — backend (Python) and mobile (Dart) are independently shippable layers; the Dart port should follow once the Python engine is validated and stable, per cahier_des_charges_app_mobile.md section 5.2.

- source_spec: `_bmad-output/implementation-artifacts/spec-restore-backend-scoring-engine.md`
  summary: HIGH IMPACT — backend/app/api/routes_analyse.py line 49 (`resultats=[horse.__dict__ for horse in results]`) leaks virtual-outsider placeholders (`num_pmu=None`, `nom="Outsider virtuel"`) into the `/analyse` API response whenever `nb_partants_course` exceeds the number of horses submitted — the common case for that feature. It should filter to real horses only (e.g. `results[:len(horses)]` or `num_pmu is not None`), mirroring how the same file already slices correctly for `build_combinaisons` on the line just above.
  evidence: Verification-gap review of the scoring-engine restoration surfaced this. routes_analyse.py is intact/untouched by this story (pre-existing bug, not introduced by the reconstruction) but was unreachable while scoring.py was corrupted — now that scoring.py works, the bug is live and would show fabricated horses to real bettors via the mobile app.
  resolved: Fixed directly on user request (commit following spec-restore-backend-scoring-engine.md's completion) — routes_analyse.py now filters `resultats` to `horse.num_pmu is not None`, with a regression test in backend/tests/test_routes_analyse.py.

- source_spec: `_bmad-output/implementation-artifacts/spec-restore-backend-scoring-engine.md`
  summary: backend/app/engine/combinatoire.py has zero test coverage (no test file imports or calls it, directly or via the route).
  evidence: Verification-gap review noted this; combinatoire.py was intact before this story and untouched by it — pre-existing gap, not caused by the scoring-engine restoration.
  resolved: Fixed via spec-combinatoire-test-coverage.md — 17 tests added in backend/tests/test_combinatoire.py, reviewed and committed (a9a93c1), pushed.

- source_spec: `_bmad-output/implementation-artifacts/spec-restore-backend-scoring-engine.md`
  summary: `analyse_course`'s `params` dict is merged over `DEFAULT_PARAMETERS` with no key validation — a mistyped key is silently dropped, and hostile/malformed values (negative `shrink`, `age_min > age_max`) can crash the request or silently produce wrong scores.
  evidence: Blind-hunter and edge-case-hunter reviews both flagged this class of issue. Not in scope for a faithful port of the reference engine (neither the JS prototypes nor the cahier des charges validate params) — worth a dedicated input-validation pass (e.g. a Pydantic model for `params` at the API boundary) if it ever matters in practice.

- source_spec: `_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md`
  summary: HIGH IMPACT — backend/app/api/routes_analyse.py's `/analyse` endpoint ships `resultats=[horse.__dict__ for horse in results]` typed as a bare `List[Dict]`, bypassing the already-defined `HorseOut` Pydantic schema entirely (AnalyseOut.resultats never validates against it). Should construct `HorseOut(...)` (or `.model_validate()`) per horse instead of dumping the dataclass `__dict__` raw.
  evidence: Adversarial review of the architecture spine (AD-4) surfaced this as a live inconsistency, not hypothetical — two future spine-compliant stories could each "fix" this differently (one extends via `__dict__`, one enforces `HorseOut` strictly) and ship incompatible payloads. routes_analyse.py is intact/pre-existing, not touched by the scoring-engine restoration story.
  resolved: Fixed via spec-1-3-typed-analyse-response.md — AnalyseOut.resultats is now List[HorseOut], built via HorseOut.model_validate(horse) (from_attributes on the model itself per code review). Regression tests assert the exact field set, correct per-horse value mapping, the all-filtered-out edge case, and Optional-field-None propagation. 60/60 backend tests pass.

- source_spec: `_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md`
  summary: Mobile side is missing a `niveauCoefficient()`-equivalent lookup (it has `terrainCoefficient()` but nothing for niveau labels), and both backend and mobile currently collapse "genuinely missing" and "unrecognized label" into the same neutral coefficient with no distinguishing log/signal (AD-5).
  evidence: Adversarial review of the architecture spine surfaced this — the two cases are indistinguishable today in logs or the UI's "terrain inconnu" counter (cahier backend §7.5, PRD FR-5), which could hide real data-quality problems (a typo'd label silently treated as "unknown, that's fine" instead of flagged).

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-engine-cases-fixture.md`
  summary: `fixtures/engine_cases.json`'s assertion DSL has no tolerance-based float equality type (`field_equals` is only ever used with an integer field today) and no formal JSON schema/README documenting the case format — both real gaps for a file explicitly meant to be a cross-language (Python + future Dart) contract, but not needed by any of the 6 current cases.
  evidence: Blind-hunter review of Story 1.1. Deliberately out of scope for a mechanical extraction of already-passing tests — revisit when a future fixture case actually needs float-tolerance equality, or when the Dart consumer (blocked — see the mobile Dart-port entry above) is finally built and a schema becomes worth enforcing mechanically.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-engine-cases-fixture.md`
  summary: The assertion DSL's `params`/`mode_recence` override plumbing in `_run_fixture_case` is unexercised — none of the 6 current fixture cases sets a non-default `params` or `mode_recence`, even though the schema supports both.
  evidence: Blind-hunter + edge-case-hunter review of Story 1.1. Not a bug (nothing currently relies on the untested path producing a specific result), just unused optional capability — worth a case exercising it once a future story's test actually needs a non-default parameter or récence mode.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-engine-constants-fixture.md`
  summary: `fixtures/engine_cases.json`'s loader (Story 1.1) still raises a bare `KeyError`/crashes the whole test module on a missing/invalid fixture file or a fixture case missing a required key — the same class of fragility Story 1.2's review caught and fixed for `engine_constants.json`'s loader, but fixing it in `engine_cases.json`/its consuming tests would have meant touching Story 1.1's already-frozen code, out of bounds for this story.
  evidence: Blind-hunter + edge-case-hunter review of Story 1.2, generalized to the sibling fixture. Low real risk (a malformed fixture file is a local dev-time mistake, not a production path), but worth a small consistency pass once both fixtures are touched by the same future story.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-engine-constants-fixture.md`
  summary: The "mobile engine is corrupted/blocked" fact is now duplicated independently across 3 files (`fixtures/engine_cases.json`'s `$comment`, `fixtures/engine_constants.json`'s `$comment`, and this file) — each will need separate updating once the mobile engine is actually reconstructed, which is itself a drift risk despite AD-2 existing specifically to prevent drift elsewhere.
  evidence: Blind-hunter review of Story 1.2. Minor documentation hygiene, not a functional gap — worth centralizing (e.g. both fixture `$comment`s referencing this file by path instead of repeating the claim) whenever either fixture is next touched.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-engine-constants-fixture.md`
  summary: `constants.py`'s `terrain_coefficient(label)` function (the actual runtime consumer of `TERRAIN_COEFFICIENTS_GRASS`/`_PSF`) has no direct unit test anywhere in the backend suite — Story 1.2 only validates the raw tables match the fixture, never that the lookup function built on top of them still resolves a label correctly.
  evidence: Blind-hunter review of Story 1.2. Pre-existing gap (the function predates this story), not introduced by it — worth a small dedicated test once someone is next in this file.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-typed-analyse-response.md`
  summary: `/analyse`'s `course_id` branch (the `repository.get_horses_for_course` path) is untested — all of test_routes_analyse.py's tests post a manual `chevaux` list, so the `HorseOut.model_validate(horse)` fix (and the response typing generally) is unverified for the DB-backed code path, which shares the exact same construction line.
  evidence: Blind-hunter review of Story 1.3. Requires standing up a course + participations in the temp-db (pattern already established in test_main.py) — more setup than this bugfix story's scope; worth a dedicated test once a story next touches the course_id path.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-typed-analyse-response.md`
  summary: No mechanical test ties `HorseOut`'s field set to `HorseAnalysis`'s field set (e.g. `dataclasses.fields(HorseAnalysis)` minus known-internal names vs. `HorseOut.model_fields`) — the exact class of bug just fixed (a schema silently drifting from the dataclass it mirrors) could recur with nothing catching it mechanically, only another manual code review.
  evidence: Blind-hunter review of Story 1.3. A real hardening opportunity but adds meaningful complexity (deciding which HorseAnalysis fields are "intentionally internal" vs. "forgot to expose") — worth it once HorseAnalysis gains a field for the first time post-fix, as a concrete trigger to build the check against.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-3-typed-analyse-response.md`
  summary: `/analyse` has no error handling around `HorseOut.model_validate(horse)` — if a `HorseAnalysis` ever violated `HorseOut`'s types (a bug elsewhere), the route would now surface a raw, unhandled `pydantic.ValidationError` as a 500 rather than a controlled error response.
  evidence: Edge-case-hunter review of Story 1.3. A behavior change introduced by fixing AD-4 (the old `.__dict__` dump could never fail this way) — low likelihood since it requires an upstream engine bug, but worth a `try/except` -> clean `HTTPException(500, ...)` wrapper if `/analyse` ever gets broader hardening attention.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-validate-engine-params.md`
  summary: `EngineParamsIn`'s bounds have no upper ceiling on `coef_inedit`, `bankroll`, `malus_incident`, or `sensibilite_poids` — an absurd but technically-valid value (e.g. `coef_inedit=1000`, `bankroll=1e12`) is accepted and silently produces an equally absurd score/mise, no guardrail. Also: `Field`s lack `description=` metadata for the auto-generated OpenAPI docs, and `AnalyseIn`/`HorseIn`/`PerformanceIn` still don't set `extra="forbid"` — a typo'd top-level field (e.g. `distence`) is silently ignored while the identical mistake inside `params` is now caught, an inconsistency in the fix's reach.
  evidence: Blind-hunter + edge-case-hunter review of Story 1.4. `contraste`'s ceiling was fixed now (real overflow risk, cheap fix) — the others are "implausible input produces implausible output," not a crash or silent corruption of a different field, so left for a future dedicated hardening pass rather than expanding this story's scope further.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-4-validate-engine-params.md`
  summary: No test covers `params: {}` (explicit empty object) vs. omitting `params` entirely — both should behave identically (all defaults) but the equivalence isn't verified; no test covers a non-numeric value inside `params` (e.g. `{"shrink": "abc"}`) to lock in Pydantic's coercion/rejection behavior; no test asserts the actual error-message content of a 422 response (only the status code).
  evidence: Blind-hunter + verification-gap review of Story 1.4. None are false-pass risks (a real regression would still fail loudly, just without a test naming it precisely) — lower priority than the bound-coverage and partial-override gaps that were fixed directly.
