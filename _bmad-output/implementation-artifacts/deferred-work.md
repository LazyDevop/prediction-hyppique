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

- source_spec: `_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md`
  summary: Mobile side is missing a `niveauCoefficient()`-equivalent lookup (it has `terrainCoefficient()` but nothing for niveau labels), and both backend and mobile currently collapse "genuinely missing" and "unrecognized label" into the same neutral coefficient with no distinguishing log/signal (AD-5).
  evidence: Adversarial review of the architecture spine surfaced this — the two cases are indistinguishable today in logs or the UI's "terrain inconnu" counter (cahier backend §7.5, PRD FR-5), which could hide real data-quality problems (a typo'd label silently treated as "unknown, that's fine" instead of flagged).

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-engine-cases-fixture.md`
  summary: `fixtures/engine_cases.json`'s assertion DSL has no tolerance-based float equality type (`field_equals` is only ever used with an integer field today) and no formal JSON schema/README documenting the case format — both real gaps for a file explicitly meant to be a cross-language (Python + future Dart) contract, but not needed by any of the 6 current cases.
  evidence: Blind-hunter review of Story 1.1. Deliberately out of scope for a mechanical extraction of already-passing tests — revisit when a future fixture case actually needs float-tolerance equality, or when the Dart consumer (blocked — see the mobile Dart-port entry above) is finally built and a schema becomes worth enforcing mechanically.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-1-engine-cases-fixture.md`
  summary: The assertion DSL's `params`/`mode_recence` override plumbing in `_run_fixture_case` is unexercised — none of the 6 current fixture cases sets a non-default `params` or `mode_recence`, even though the schema supports both.
  evidence: Blind-hunter + edge-case-hunter review of Story 1.1. Not a bug (nothing currently relies on the untested path producing a specific result), just unused optional capability — worth a case exercising it once a future story's test actually needs a non-default parameter or récence mode.
