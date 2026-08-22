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

- source_spec: `_bmad-output/implementation-artifacts/spec-restore-backend-scoring-engine.md`
  summary: `analyse_course`'s `params` dict is merged over `DEFAULT_PARAMETERS` with no key validation — a mistyped key is silently dropped, and hostile/malformed values (negative `shrink`, `age_min > age_max`) can crash the request or silently produce wrong scores.
  evidence: Blind-hunter and edge-case-hunter reviews both flagged this class of issue. Not in scope for a faithful port of the reference engine (neither the JS prototypes nor the cahier des charges validate params) — worth a dedicated input-validation pass (e.g. a Pydantic model for `params` at the API boundary) if it ever matters in practice.
