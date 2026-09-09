---
title: 'Story 3.8: stale result — live partant count in header + accessibility live-region'
type: 'fix'
created: '2026-09-09'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/implementation-artifacts/deferred-work.md']
baseline_commit: '0597831'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** two gaps logged against `spec-3-3-mandatory-recalc-on-removal.md` in `deferred-work.md`:
1. The stale-result banner (`results_screen.dart`) is purely visual (color + icon + text), no `Semantics(liveRegion: true, ...)` — a screen-reader user isn't proactively notified a displayed ranking just became stale.
2. While a result is stale, the race-info summary card's partant count still reports the frozen `result.resultats.length` from calculation time, not the live `horsesProvider` roster — only the banner signals staleness; the rest of the header looks normal/trustworthy.

**Approach:** wrap the existing stale banner in `Semantics(liveRegion: true, ...)` so assistive tech announces it when it appears. When `result.isStale`, replace the header's partant-count line with the live `horsesProvider` count styled to match the banner's amber treatment (color + text, not color alone), instead of the frozen count.

## Boundaries & Constraints

**Always:**
- `Semantics(liveRegion: true, child: <existing stale Container>)` — wrap, don't restructure the banner's existing content/layout.
- When `result.isStale`: header partant-count line becomes `'${horses.length} partants actuellement — recalcul nécessaire'` (live count, amber-styled, no virtuels annotation — the frozen `nVirtuels` figure is meaningless once the roster has changed).
- When `!result.isStale` (default/current behavior): keep the existing `'${result.resultats.length} partants${nVirtuels > 0 ? ' (dont $nVirtuels non analysés)' : ''}'` line unchanged.

**Never:**
- Do not change `resultsProvider`/`horsesProvider` staleness logic itself (Story 3.3/3.6 territory, already correct).
- Do not touch the banner's existing text, icon, or "Recalculer" button.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior |
|----------|--------------|---------------------------|
| Not stale | `result.isStale == false` | Header shows frozen `result.resultats.length` (+ virtuels note if any) — unchanged from today |
| Stale, horse removed | `result.isStale == true`, `horses.length` less than the frozen count | Header shows the smaller live `horses.length`, amber-styled, "recalcul nécessaire" suffix |
| Stale, horse added | `result.isStale == true`, `horses.length` greater than the frozen count | Header shows the larger live `horses.length` |
| Banner appears | Any stale transition | `Semantics(liveRegion: true)` ancestor present on the banner container, so a screen reader announces it |

</frozen-after-approval>

## Code Map

- `mobile/lib/screens/results_screen.dart` -- MODIFY -- wrap stale banner in `Semantics(liveRegion: true)`; header partant-count line branches on `result.isStale`
- `mobile/test/widgets/results_screen_test.dart` -- MODIFY -- add coverage for the live count and the liveRegion semantics flag

## Tasks & Acceptance

**Execution:**
- [x] `results_screen.dart` -- Semantics wrap
- [x] `results_screen.dart` -- live partant count when stale
- [x] Tests per the I/O matrix
- [x] Run `flutter test` -- all pass, no regressions; `flutter analyze` -- 0 issues

**Acceptance Criteria:**
- Given the 4 I/O matrix scenarios, the header and the banner's accessibility behavior match exactly.
- Given the full mobile test suite, when run after this story, then it passes with the new tests included and zero regressions.

## Verification

**Commands:**
- `cd mobile && flutter test` -- ran: 97/97 pass (93 baseline + 4 new), 0 regressions.
- `cd mobile && flutter analyze` -- ran: 0 issues.
