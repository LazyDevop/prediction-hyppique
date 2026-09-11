# Rubric Walk — ARCHITECTURE-SPINE.md (prediction-hyppique, 2026-09-04)

Reviewer method: read the spine, read all three source documents in full
(PRD, cahier backend, cahier mobile), then cross-checked every factual claim
in the spine against the actual repository state (`backend/`, `mobile/`,
`docker-compose.yml`, `requirements.txt`, `pubspec.yaml`, git history,
`.memlog.md`) rather than taking the document's claims at face value.

Overall: the spine is well-grounded in the brownfield code — every
"[ADOPTED]" claim checked out against the actual files — and AD-1/AD-3 are
each enforceable and pointed at a real divergence risk. The one structural
weak point is AD-2, whose stated mechanism doesn't cover its own stated
scope, and there's one unverified/unsourced piece of named tech. Findings
below, most significant first.

---

## Finding 1 (High) — AD-2's shared fixture doesn't cover the constants tables it needs to, so the exact divergence it's designed to prevent isn't actually prevented

AD-2's Prevents clause is explicit: "the Python and Dart ports of the scoring
engine silently diverging when a story on one side adds a test case (or a
default parameter) that never gets mirrored to the other." Its Rule says the
shared `fixtures/engine_cases.json` holds test cases *and* "the canonical
default engine parameters (mirrors `DEFAULT_PARAMETERS` in `constants.py`)."

But `constants.py` (and its Dart mirror `constants.dart`) hold four things,
not one:
1. `DEFAULT_PARAMETERS` — covered by the rule.
2. `TERRAIN_COEFFICIENTS_GRASS` / `TERRAIN_COEFFICIENTS_PSF` — not covered.
3. `NIVEAU_COEFFICIENTS` — not covered.
4. `INCIDENTS` (malus per code) — not covered.
5. `RECENCE_STD` / `RECENCE_FORME` / `RECENCE_FLAT` — not covered either.

I read both files. `backend/app/engine/constants.py` and
`mobile/lib/engine/constants.dart` currently match exactly, but the Dart
file's own header comment says how that's being maintained: *"copiées à
l'identique... ne pas modifier ces valeurs ici sans les répercuter côté
Python"* — i.e., by the same "human discipline" AD-2 was written to replace.
The cahier mobile (§5, `constants.dart` entry) prescribes exactly this
by-hand-copy approach, and the PRD's cross-cutting NFR ("parité
fonctionnelle... vérifié par les mêmes cas de test") doesn't distinguish
constants tables from tunable parameters — both need to stay identical.

Concretely: a future story that changes a niveau coefficient (e.g. resolving
PRD Open Question 5, the allocation→niveau quantile calibration) or adds an
incident code has no shared-fixture mechanism forcing the Dart side to
follow, because AD-2's fixture, as scoped, has nothing to say about those
tables. That's the same silent-drift failure mode AD-2 exists to close, just
one layer down from where the rule currently reaches.

**Suggested fix**: either (a) broaden the fixture file's scope to also carry
the four constants tables (or reference/generate them from one canonical
source consumed by both languages), or (b) if the intent is genuinely to
leave constants-table sync to hand discipline, say so explicitly and narrow
AD-2's Prevents clause to match — as written, the Rule doesn't fully deliver
on the Prevents clause.

**Secondary, smaller point under the same AD**: `backend/tests/test_scoring.py`
and `backend/tests/test_combinatoire.py` already exist today (14KB / 10KB,
hand-encoded cases, no reference to `fixtures/engine_cases.json`, which
doesn't exist yet at repo root). AD-2 is written as a forward rule ("[decided
this run]"), which is fine, but the spine doesn't flag that adopting it
requires a retrofit story to extract the *existing* hand-encoded cases into
the new fixture — without that called out, the first team to touch either
test file has no signal that the file predates and violates the new
convention.

---

## Finding 2 (Medium) — "Anthropic" appears as settled fact in AD-3 but is untraceable to any source document and isn't in the Stack table

AD-3's Prevents clause states the rule protects against "an Anthropic API key
... leaking outside one module." I grepped all three source documents
(`prd.md`, both cahiers) and the brief for "Anthropic," "Claude," "GPT," and
"vision provider" — none of them name a vision provider. The cahiers only say
"un modèle de vision" / "fournisseur de vision IA," generically.

`.memlog.md` (this spine's own working log) confirms this is a real decision,
just not one drawn from the PRD: *"fournisseur vision (Anthropic Claude, déjà
choisi par l'utilisateur plus tôt dans la session)."* That's a legitimate way
to make the decision, but it isn't surfaced correctly in the finished
document:
- It's stated as established fact inside a "Prevents" bullet, not flagged
  `[decided this run]` the way AD-3's other net-new call (the budget-guard
  mechanism) explicitly is.
- It never appears in the **Stack** table, which is where a reader would
  otherwise expect to find "which vision API are we integrating" — the Stack
  table lists Python/FastAPI/SQLAlchemy/Flutter/Riverpod/sqflite/dio but has
  no row for the vision provider at all.
- No model/version is pinned (e.g. which Claude model, which API surface —
  Messages API vision blocks). Given `vision_client.py` doesn't exist yet,
  the story that creates it has no anchor for "verified-current" beyond a
  provider name in a prose sentence.

This doesn't block anything today (mechanism-wise AD-3 is still sound
regardless of which vision vendor is behind it), but it fails the "named tech
is verified-current" checklist bar as written, and a reader auditing the
spine against its sources would flag "Anthropic" as unsourced.

**Suggested fix**: add a Stack row for the vision provider (even if only
"Anthropic Claude (vision), model TBD — [decided this run, not sourced from
PRD/cahiers]"), or strip the vendor name from AD-3's prose and keep the rule
vendor-agnostic ("the vision provider's API key," matching how the cahiers
themselves stay generic) until it's formally decided with a version pinned.

---

## Finding 3 (Low) — `freezed`/`json_serializable` are load-bearing mobile stack already in use but absent from the Stack table

The Stack table lists Riverpod, sqflite, and dio for mobile (all correctly
verified present in `mobile/pubspec.yaml`), but omits `freezed` +
`json_serializable`, which the mobile cahier explicitly recommends (§9) for
"modèles immuables et sérialisation JSON cohérente avec les schémas du
backend" — i.e., exactly the kind of naming/shape parity concern this spine
otherwise cares about (see the Naming convention row). `pubspec.yaml`
confirms both are already dependencies (`freezed_annotation ^3.1.0`,
`json_annotation ^4.12.0`, plus the dev-dependency codegen packages). Since
JSON (de)serialization shape is precisely where a backend/mobile field-name
mismatch would surface, this is a minor completeness gap rather than a
contradiction — nothing in the spine conflicts with `freezed`, it's just
silently not ratified.

---

## Checklist items that came back clean

- **AD-1 (hexagonal boundary)**: verified directly — grepped imports in
  `backend/app/engine/scoring.py`, `combinatoire.py`, `constants.py`; none
  import from `data/`, `api/`, or any HTTP/I/O library. The rule is both
  enforceable (a lint/import-check could gate it) and currently true.
- **AD-3 mechanism** (budget-guard, isolation): sound independent of the
  vendor-naming issue in Finding 2. `vision_client.py` correctly doesn't
  exist yet, and the two `/extraction/*` routes in `routes_analyse.py` are
  present only as `501`-stub placeholders — consistent with "not yet
  created."
- **Deployment/environments deferred section**: checked against the actual
  `docker-compose.yml` — two services (`api`, `ingestion`) sharing a
  `hippique_data` SQLite volume, exactly as described. No `.github/`
  workflows, no `.env` files, no staging config anywhere in the repo — the
  "no CI/CD, no staging" claim is accurate, and deferring it is reasonable
  given the PRD's explicit bootstrap/no-fixed-timeline posture (§9.3/§10).
  This is the one place the checklist specifically calls out as a common
  blind spot, and here it's actually covered rather than silently missing.
- **Stack versions**: Python 3.12 confirmed in `backend/Dockerfile`;
  FastAPI/SQLAlchemy confirmed unpinned in `requirements.txt` (the
  `[ASSUMPTION]` tag is honest, not overclaiming). Flutter/Dart correctly
  deferred to `pubspec.yaml` ("not re-verified this run") rather than
  guessed.
- **Naming/vocabulary convention**: spot-checked `num_pmu`, `inedit`, `cote`,
  `age_a_la_course`, `poids` in `routes_courses.py` against the table's
  claimed vocabulary — matches.
- **PRD capability coverage**: all of FR-1 through FR-21 map onto something
  the spine either fixes (AD-1/2/3, naming/state conventions) or correctly
  leaves as ordinary structural detail owned by the code (export format,
  screen layout, specific combinatoire algorithm) rather than an invariant
  needing to be pinned at this altitude. The PRD's Open Questions are mostly
  picked up faithfully in Deferred (OQ4 vision budget, OQ5 niveau
  calibration, OQ7 homonyms); OQ1 (perf threshold "instantané"), OQ2
  (pricing format), OQ3 (Cameroon legal), and OQ6 (ingestion volume) are left
  out of Deferred, but correctly so — none of them create a cross-unit
  divergence risk between the Python and Dart engines, which is this
  document's stated job, and OQ6 in particular is already handled in code
  (`pmu_client.py` has `REQUEST_DELAY_SECONDS` and an honest `User-Agent`)
  without needing a spine-level rule.
- **Fixture directory name collision check**: `backend/tests/fixtures/`
  already exists in the repo (holds recorded PMU/open-pmu HTTP responses for
  `test_pmu_client.py`/`test_open_pmu_client.py`), which is a different thing
  from the new root-level `fixtures/engine_cases.json` AD-2 proposes. Worth
  being aware of only because of the name similarity; not an actual
  conflict — different directories, different purposes, no collision.

## Verdict

Solid spine for the paradigm and the two ports it names explicitly (PMU,
vision) — those rules are enforceable and match the code. The parity
mechanism (AD-2) is the one place where the rule as written doesn't fully
cover the failure mode it names, and one piece of named tech (Anthropic)
entered the document without a traceable source or a Stack-table home. Both
are fixable without restructuring the document.
