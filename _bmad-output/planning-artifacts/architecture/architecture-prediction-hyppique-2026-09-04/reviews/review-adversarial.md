---
name: 'review-adversarial-prediction-hyppique'
type: architecture-review
target: '_bmad-output/planning-artifacts/architecture/architecture-prediction-hyppique-2026-09-04/ARCHITECTURE-SPINE.md'
method: 'adversarial pair-construction — two spine-compliant future stories, built independently, that end up incompatible'
created: '2026-09-04'
---

# Adversarial Review — ARCHITECTURE-SPINE.md (prediction-hyppique)

## Method

For each finding below: two hypothetical future stories are constructed, each imagined as built by a
different agent session, at a different time, each obeying every Rule ("AD-N") in the spine to the
letter. Where possible the finding is grounded in code that **already exists** in `backend/app/` and
`mobile/lib/` today (not purely hypothetical) — this is noted per finding, since it means the divergence
risk isn't speculative, it's already latent in the shipped code and the spine doesn't close it.

Sources skimmed for domain grounding: `docs/cahier_des_charges_backend_hippique.md` §5, 6, 7, 8, 9;
`docs/cahier_des_charges_app_mobile.md` §5, 6, 7. Code inspected: `backend/app/schemas/analyse.py`,
`backend/app/schemas/course.py`, `backend/app/api/routes_analyse.py`, `backend/app/engine/{scoring,
combinatoire,constants}.py`, `mobile/lib/engine/{constants,combinatoire}.dart`,
`mobile/lib/models/{horse,performance,engine_params}.dart`, `mobile/lib/data/remote/api_client.dart`.

## Verdict

The spine is directionally sound (hexagonal boundary, French vocabulary, nullable-neutral semantics are
real and already-adopted conventions) but it stops one layer too early on the exact question it exists to
answer: **the wire shape and runtime defaults of the one thing built twice.** AD-2 guarantees the two
engines compute the *same number from the same input* in tests; it says nothing about what JSON shape
carries that input in, what shape carries the output out, or whether the two engines' *production*
defaults (as opposed to their test fixtures) stay equal. Three of the six findings below are not
speculative — they are gaps that already manifest as inconsistency in the code the spine is supposed to
be governing extensions of.

---

## Finding 1 — `/analyse` response has no single source of truth for its own shape (HIGH)

**Already manifesting in code.** `backend/app/schemas/analyse.py` defines a fully-typed `HorseOut` model
(`nom, num_pmu, age, poids, cote, inedit, score, probabilite, top1..top4, value, kelly, mise`). But
`backend/app/api/routes_analyse.py:54` builds the actual response as:

```python
resultats = [horse.__dict__ for horse in results if horse.num_pmu is not None]
return AnalyseOut(resultats=resultats, combinaisons=combinaisons)
```

and `AnalyseOut.resultats` is typed `List[Dict]` (`schemas/analyse.py:75`) — an untyped escape hatch, not
`List[HorseOut]`. `HorseAnalysis.__dict__` (`engine/scoring.py`) additionally carries `nb_perfs`, `forme`,
`c_poids`, `c_age`, and a nested `performances: List[Performance]` that `HorseOut` doesn't declare at all.
Today the two shapes happen to overlap on the named `HorseOut` fields, but nothing enforces that.

**Story pair.** Story A (backend) adds a new computed field to `HorseAnalysis` for an internal debug view
(e.g. `ecart_type_forme`) and never touches `HorseOut`, because nothing requires it — the field appears in
the wire response for free via `__dict__`, and every existing AD (AD-1, AD-2, the naming-convention row)
is still satisfied. Story B (mobile), built independently, parses `/analyse` against the documented
`HorseOut` contract and never sees the field — or, in the opposite order, Story B decides to "fix" the
schema by making `AnalyseOut.resultats: List[HorseOut]` (a strictly more correct, still spine-compliant
change), which silently drops `performances`/`c_poids`/`c_age`/`nb_perfs`/`forme` that some other feature
(e.g. a results-screen transparency indicator, cahier mobile §7.3) may already depend on reading off the
raw JSON. Both stories are individually correct; the pair is not.

**Hole to close.** New AD: the `/analyse` HTTP response body is defined **exclusively** by the Pydantic
`AnalyseOut`/`HorseOut` models — `routes_analyse.py` must construct `HorseOut` instances explicitly
(field-by-field or via an explicit adapter function), never pass a domain dataclass's `__dict__` through
an untyped `Dict`. Any field the engine needs to expose must be added to `HorseOut` in the same change
that adds it to `HorseAnalysis`.

---

## Finding 2 — Monte-Carlo combo probabilities cannot be cross-language reproducible under AD-2 as written (HIGH)

**Already manifesting in code.** Backend `combinatoire.py` seeds `numpy.random.default_rng(seed)` (PCG64)
for `couple_place`/`deux_sur_quatre`. Mobile `combinatoire.dart` seeds `dart:math`'s `Random(seed)` for the
same computation. These are different, non-interoperable PRNG algorithms: identical `seed=0` does **not**
produce identical draw sequences across the two runtimes, even though both correctly implement "~20,000
weighted draws without replacement" per cahier §7.12.

**Story pair.** AD-2 says the shared fixture holds "every test case expressible as fixed-input →
fixed-or-tolerance-checked-output," explicitly listing "probability-sum invariants, Bayesian-shrinkage
bounds... terrain/niveau=None neutrality" as examples, and says both `test_scoring.py` and `scoring_test.dart`
must load it and iterate it rather than hand-encode cases. Story A (backend), reading AD-2 as written,
adds `couple_place`/`deux_sur_quatre` golden values to `fixtures/engine_cases.json` — a reasonable reading
since §7.12's Monte-Carlo section is squarely part of "the engine." Story B (mobile), built independently,
loads the same fixture per AD-2's letter and gets numbers that differ from the golden value by an amount
far outside any sane float epsilon — because the underlying random draws are simply different in Python
vs. Dart. The mobile test now either (a) fails permanently on a fixture both sides dutifully load, or (b)
gets "fixed" by loosening the tolerance so much it stops catching real regressions — a decision some future
session will make locally, differently on each side, since the spine gives no guidance.

**Hole to close.** New AD, one of:
- (a) explicitly exclude Monte-Carlo-derived combo outputs (`couple_place`, `deux_sur_quatre`) from the
  exact-value fixture; specify instead a statistical-tolerance test methodology (e.g. assert convergence
  toward the Harville-derived theoretical bound within N% at 20,000 trials) — i.e. treat these as the
  "comparative/structural, hand-written per language" category AD-2 already carves out for ordering
  properties, not as fixed-value cases; or
- (b) mandate a single, explicitly-ported PRNG (e.g. hand-rolled xorshift/PCG core implemented identically
  in both `combinatoire.py` and `combinatoire.dart`) so that `seed=0` is bit-reproducible cross-language,
  and bind that requirement to AD-2.
Either is fine; leaving it unstated guarantees the two sides pick differently.

---

## Finding 3 — No canonical wire format for label-valued domain scales (terrain, niveau) (MEDIUM-HIGH)

**Already manifesting in code.** `backend/app/schemas/course.py` sends `terrain: Optional[str]` and
`niveau_estime: Optional[str]` (label strings, e.g. `"Bon souple"`, `"Catégorie C"`) on
`CourseOut`/`PerformanceHistoriqueOut`. Mobile's `api_client.dart:53` correctly converts the terrain label
via `terrainCoefficient(perf['terrain'] as String?)`. But there is **no `niveauCoefficient()` counterpart**
in `mobile/lib/engine/constants.dart` despite `NIVEAU_COEFFICIENTS` existing on both sides, and
`api_client.dart:54` hardcodes `niveau: null` with a comment "pas encore dérivé côté backend" — i.e. the
mobile side currently assumes niveau will *not* arrive pre-labelled, unlike terrain. Additionally, both
`terrain_coefficient()` (Python) and `terrainCoefficient()` (Dart) return `None`/`null` **silently** on an
unrecognized label — no log, no error — which is indistinguishable from "field genuinely absent" given the
spine's own "nullable means neutral coefficient" rule (Consistency Conventions row 2).

**Story pair.** Story A (backend) implements the deferred "niveau-from-allocation" derivation (spine's own
Deferred §3) and, following the terrain precedent already in the codebase, emits it as one of the
`NIVEAU_COEFFICIENTS` label strings on `/courses/{id}/partants`. Story B (mobile), built earlier or in
parallel without visibility into Story A's exact choice, either (i) still assumes — per the existing
"not yet derived" comment it inherited — that niveau must be derived client-side from `allocation`, and
never wires up a `niveauCoefficient()` conversion at all, or (ii) assumes the field is pre-resolved to a
float (since `Performance.niveau` is typed `float` in *both* engines' internal dataclasses/classes) and
writes `json['niveau_estime'] as double?`, which is `null`-safe but silently wrong on a string payload, or
crashes if written as `as double`. Neither story violates any AD. Compounding this: if the backend's
allocation-quantile derivation (still uncalibrated per Deferred §3) ever emits a label with a spelling
that doesn't exactly match a `NIVEAU_COEFFICIENTS` key (accent, capitalization, a synonym), the mismatch
degrades silently to "neutral" on whichever side sees it, with no signal that anything is wrong.

**Hole to close.** New AD: label-valued domain-scale fields (`terrain`, `niveau`) always travel over the
wire as the exact canonical French label string that is a key in `constants.py`'s / `constants.dart`'s
lookup tables — never pre-resolved to a float, on either request or response payloads. Each side owns
coefficient resolution locally via its own lookup (mirroring the already-adopted terrain pattern). An
unrecognized label must be a loud, logged/countable event, not a silent fallback to the same "neutral"
value used for genuinely-missing data — the two cases need to stay distinguishable, which they aren't
today.

---

## Finding 4 — AD-2's fixture binds test code, not the production default-parameter objects (MEDIUM)

**Already manifesting in code.** `backend/app/engine/constants.py`'s `DEFAULT_PARAMETERS` dict and
`mobile/lib/models/engine_params.dart`'s `EngineParams()` const constructor are two independent literal
definitions of the same nine default values (`malus_incident=1.0`, `shrink=2`, `coef_inedit=0.75`, ...).
They agree today, by manual diligence — not by any mechanism AD-2 establishes. AD-2's binding list is
explicitly `backend/app/engine/`, `test_scoring.py`, `mobile/lib/engine/`, `scoring_test.dart` — it never
mentions `constants.py`'s `DEFAULT_PARAMETERS` object or `engine_params.dart`'s `EngineParams` class as
themselves needing to be *derived from* or *checked against* `fixtures/engine_cases.json`; it only requires
the *test files* to load the fixture.

**Story pair.** Story A (backend), after real ingested-volume calibration work (the kind the spine's
Deferred §3 anticipates), tunes `shrink` from `2` to `3` in `constants.py` and mirrors the change into
`fixtures/engine_cases.json` — fully AD-2 compliant, since that's the exact file the rule requires both
test suites to load, and `test_scoring.py` continues to pass. Story B, a mobile-only session shipping an
unrelated UI feature around the same time, never touches `engine_params.dart` — nothing requires it to,
and `scoring_test.dart` still passes because it independently loads the (now-updated) fixture and computes
correctly with `shrink=3` supplied explicitly in each test case. Production code on mobile, however, still
constructs `EngineParams()` with `shrink=2` for any screen that doesn't override it. Both test suites are
green; local (Dart) recomputation now silently disagrees with the backend on every calculation that relies
on the default, undetected by anything in the spine's own consistency mechanism.

**Hole to close.** New AD (or tighten AD-2): add a test on each side — not exercised via the fixture's
per-case values, but asserting the *production default-parameter object itself* (`DEFAULT_PARAMETERS` in
Python, `const EngineParams()` in Dart) equals the fixture's canonical-defaults block value-for-value. This
closes the gap between "tests load the fixture" and "the shipped default actually is the fixture."

---

## Finding 5 — Two live, non-overlapping field vocabularies for "a horse in a race," and no rule for which wins on extension (MEDIUM)

**Already manifesting in code.** `backend/app/schemas/course.py`'s `ParticipationOut` (served by
`/courses/{id}/partants`) uses `nb_participants`/`age_a_la_course`/`cote_reference`/`cote_direct`. But
`backend/app/schemas/analyse.py`'s `HorseIn`/`HorseOut` (served by `/analyse`) uses
`partants`/`age`/`cote` for what is conceptually the same information about the same horse. The spine's
Consistency Conventions table asserts "Identical spelling... in Python dataclasses, JSON API payloads, and
Dart models — never translated to English on either side" — true in the sense that both vocabularies are
French, but the table's implied claim (one vocabulary, end-to-end) is already false in the shipped code,
and mobile already carries two separate adapters as a result (`api_client.dart`'s `_horseFromJson` for the
DB vocabulary; the engine's own `HorseIn`-shaped construction wherever `/analyse` is actually called).

**Story pair.** Story A extends `/analyse`'s output with a new per-horse field using the engine vocabulary
(e.g. `ecart_recence`, sitting naturally next to `age`/`poids`/`cote`). Story B, working independently on
`/courses/{id}/partants` to add the transparency indicators the cahier mobile §7.3 explicitly asks for
("historique court" / "terrain inconnu sur N performances" / "inédit" labels), extends `ParticipationOut`
using the DB vocabulary (`age_a_la_course`, etc.), reasonably, since that's the file's existing convention.
Both changes are individually "French, identical spelling" per the letter of the rule. The result: mobile's
`Horse` model (`mobile/lib/models/horse.dart`, which frames itself as mirroring both dataclasses at once —
see its own docstring) now needs two field-mapping tables with no shared rule connecting them, and every
future field addition repeats the same fork decision independently.

**Hole to close.** New AD: pick one of — (a) collapse to one vocabulary (rename `ParticipationOut`'s DB
fields to match the engine's, or vice versa, accepting a migration cost now while the schema is still
young), or (b) formally document the two DTOs as intentionally distinct bounded contexts with a single
named mapping table (Python and Dart both reference it) that every future field addition on either side
must update. Leaving it as an implicit "both happen to be French" convention is exactly the vague rule
that admits two contradictory-but-compliant extensions.

---

## Finding 6 — Vision-extraction response shape is unscoped, and has at least three plausible precedents to fork from (MEDIUM, compounds Findings 1 and 5)

**Partially hypothetical — the endpoints are explicitly `[not yet created]` per AD-3's own binds list**, but
the risk is concrete given Findings 1 and 5. AD-3 fixes the *mechanism* around
`extract_fiche_cheval`/`extract_programme` (budget ceiling, isolation of the Anthropic call shape) but says
nothing about the shape of `FicheChevalExtraite`/`ProgrammeExtrait` themselves. Given the codebase already
has two divergent vocabularies for "a horse" (Finding 5) and an untyped escape hatch for engine output
(Finding 1), a future backend story building `vision_client.py` has at least three precedents to
independently pick from: the DB/`ParticipationOut` vocabulary, the engine/`HorseIn` vocabulary, or a fresh
vision-specific one. Separately, cahier mobile §7.5 requires a per-field "à vérifier" / "✨ Rempli par l'IA"
UX affordance — i.e. some per-field confidence or provenance flag — that exists in **no** current schema on
either side, meaning a backend session and a mobile session, built independently, will each invent their
own shape for it (e.g. `{"champs_incertains": [...]}` vs. `{"age": {"valeur": 5, "confiance": 0.8}}`) with
nothing in the spine to arbitrate.

**Hole to close.** When AD-3's deferred module is actually scoped (likely its own story), pin
`FicheChevalExtraite`/`ProgrammeExtrait` explicitly against the vocabulary chosen by whichever AD closes
Finding 5, and add an explicit shape for the per-field "AI-filled, needs verification" flag the mobile UX
already commits to (cahier mobile §7.5) before both sides are built — this is cheap to fix now, expensive
to reconcile once both a backend and a mobile story have shipped independent guesses.

---

## Note on the Deferred section

The spine's Deferred section is reasonable on deployment/CI, the vision budget *value*, niveau-quantile
*calibration*, and homonym disambiguation — those are genuinely not structural decisions. It does **not**
mention any of Findings 1–6, all of which *are* structural (wire shape, PRNG determinism, default-value
sourcing) rather than tuning/calibration work, and none of which can be safely deferred to "whichever story
gets there first" without landing on two incompatible implementations, per the pairs constructed above.
