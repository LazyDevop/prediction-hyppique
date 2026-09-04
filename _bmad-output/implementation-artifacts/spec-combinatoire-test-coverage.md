---
title: 'Add test coverage for combinatoire.py'
type: 'chore'
created: '2026-08-22'
status: 'done'
route: 'one-shot'
---

# Add test coverage for combinatoire.py

## Intent

**Problem:** `backend/app/engine/combinatoire.py` — which computes every couplé/tiercé/quarté/quinté (ordre/désordre) and Monte-Carlo (couplé placé, 2 sur 4) combination shown to real users — had zero test coverage, despite being intact and already implemented.

**Approach:** Added 17 tests covering: exact permutation/aggregation correctness (désordre == sum of matching ordre permutations, cahier des charges §7.12), the ratio growth invariant from cahier des charges §9 case 8, Monte-Carlo determinism and seed sensitivity, `top_m` boundary handling, and end-to-end `build_combinaisons` behavior (structure, virtual-outsider filtering across all six combo families, depth-gating, the `[:3]` truncation, dossard/nom identity, and the empty-input case). Test-only change — no production code modified.

## Suggested Review Order

**Low-level correctness (cahier des charges §7.12, §9 case 8)**

- Entry point: proves désordre aggregation is exact, not approximate.
  [`test_combinatoire.py:13`](../../backend/tests/test_combinatoire.py#L13)

- The named cahier-des-charges test case: ratio grows with combination size.
  [`test_combinatoire.py:29`](../../backend/tests/test_combinatoire.py#L29)

- Coverage invariants when depth equals the full field (sums to exactly 1.0).
  [`test_combinatoire.py:56`](../../backend/tests/test_combinatoire.py#L56)

**Monte-Carlo behavior**

- Determinism and actual seed-sensitivity (catches a silently-ignored seed).
  [`test_combinatoire.py:72`](../../backend/tests/test_combinatoire.py#L72)

- `top_m` boundaries: clamped above the horse count, empty below 2.
  [`test_combinatoire.py:97`](../../backend/tests/test_combinatoire.py#L97)

**`build_combinaisons` — the real API surface**

- Virtual-outsider placeholders never leak into any of the 6 combo families.
  [`test_combinatoire.py:138`](../../backend/tests/test_combinatoire.py#L138)

- Depth-gating distinguishes real gating from "always empty" (strengthened per review).
  [`test_combinatoire.py:158`](../../backend/tests/test_combinatoire.py#L158)

- Dossard/nom identity survives non-sequential `num_pmu` values.
  [`test_combinatoire.py:209`](../../backend/tests/test_combinatoire.py#L209)

**Peripherals**

- Graceful degradation with zero horses.
  [`test_combinatoire.py:231`](../../backend/tests/test_combinatoire.py#L231)
