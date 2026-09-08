---
title: 'Invalidate displayed results when the horse roster changes (FR-6)'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md']
baseline_commit: '93df01069e0340325332708a52c59fb49775613a'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Adding, editing, or removing a horse never invalidates an already-computed `resultsProvider` state. `results_screen.dart` would keep showing stale numbers with no signal, silently obsolete — violating FR-6 ("retirer un cheval invalide tout résultat déjà affiché, recalcul obligatoire") and EXPERIENCE.md's explicit edge case: "Résultat périmé après édition d'un partant | Résultats | Le résultat affiché est invalidé visuellement (bandeau 'recalcul nécessaire') plutôt que silencieusement obsolète (PRD FR-6)."

**Approach:** Add `isStale` to `AnalyseResult` (results_provider.dart). `HorsesNotifier.add/replaceAt/removeAt` mark the current result stale (a no-op if none exists); `HorsesNotifier.clear()` (used when a whole new course is loaded, home_screen.dart) fully clears it instead, since that's a new context, not an edit. `results_screen.dart` renders a persistent banner when stale, with a "Recalculer" button.

## Boundaries & Constraints

**Always:**
- `AnalyseResult` gains `final bool isStale` (default `false`); `ResultsNotifier.calculer()` always produces a fresh instance with `isStale: false`.
- `ResultsNotifier.markStale()`: no-op if `state == null` or already stale (avoids pointless rebuilds); otherwise replaces state with a new `AnalyseResult` (same data, `isStale: true`) — mutating in place would not trigger Riverpod listeners.
- `HorsesNotifier.add/replaceAt/removeAt` call `ref.read(resultsProvider.notifier).markStale()` after updating horse state.
- `HorsesNotifier.clear()` calls `ref.read(resultsProvider.notifier).clear()` (full reset, not stale) — new-course loading (home_screen.dart `_selectCourse`) must not show a misleading "recalculate the same race" banner for a completely different one.
- Banner text: exactly `'Recalcul nécessaire — les partants ont changé depuis ce calcul.'`, with a `'Recalculer'` button calling `ref.read(resultsProvider.notifier).calculer()` in place (no navigation).
- Old (stale) ranking/combinations stay visible beneath the banner — invalidate visually, never blank the screen (EXPERIENCE.md: "invalidé visuellement... plutôt que silencieusement obsolète").

**Ask First:** None.

**Never:**
- Do not touch `horse_list_screen.dart` or `horse_edit_screen.dart` — invalidation is provider-level only, no screen wiring needed since both already funnel through `HorsesNotifier`.
- Do not change the "Calculer" FAB's existing always-recalculate behavior on `horse_list_screen.dart`.
- Do not touch anything under `backend/`.
- Do not implement in-place horse editing on `results_screen.dart` (accordion) — separate, larger story (3.6).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Add horse, no prior result | `resultsProvider.state == null`, `add(h)` | `markStale()` no-ops, state stays `null` | N/A |
| Remove horse, result exists | `resultsProvider.state != null`, `removeAt(i)` | state becomes same data + `isStale: true` | N/A |
| Edit horse via `replaceAt` | result exists, `replaceAt(i, h2)` | `isStale: true` | N/A |
| Recalculate after stale | `isStale == true`, `calculer()` called | new state, `isStale: false` | N/A |
| New course loaded | `clear()` called, prior result existed | `resultsProvider.state` becomes `null` (not stale) | N/A |
| Already stale, another edit | `isStale == true`, `add(h)` again | stays `isStale: true`, no redundant rebuild | N/A |

</frozen-after-approval>

## Code Map

- `mobile/lib/providers/results_provider.dart` -- MODIFY -- add `isStale` field to `AnalyseResult`, add `ResultsNotifier.markStale()`, `calculer()` always sets `isStale: false`
- `mobile/lib/providers/horses_provider.dart` -- MODIFY -- `add`/`replaceAt`/`removeAt` call `ref.read(resultsProvider.notifier).markStale()`; `clear()` calls `.clear()` instead
- `mobile/lib/screens/results_screen.dart` -- MODIFY -- render banner (`Container` + icon + text + `TextButton`) above the race-info card when `result.isStale`
- `mobile/test/providers/horses_provider_test.dart` -- NEW -- covers the I/O matrix at the `ProviderContainer` level
- `mobile/test/widgets/results_screen_test.dart` -- NEW -- pumps `ResultsScreen` with `resultsProvider` pre-seeded (stale and non-stale) via `ProviderScope` overrides
- `mobile/test/widget_test.dart` -- READ-ONLY, must keep passing unmodified -- first-ever calc, never stale

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/providers/results_provider.dart` -- add `isStale`, `markStale()` -- single source of truth for the flag
- [x] `mobile/lib/providers/horses_provider.dart` -- wire mutations to `resultsProvider.notifier` -- closes the FR-6 gap
- [x] `mobile/lib/screens/results_screen.dart` -- add banner -- satisfies EXPERIENCE.md's "bandeau" requirement
- [x] `mobile/test/providers/horses_provider_test.dart` -- unit tests -- covers I/O matrix
- [x] `mobile/test/widgets/results_screen_test.dart` -- widget tests -- banner shown/hidden correctly

**Acceptance Criteria:**
- Given a computed result and a horse removed via `HorsesNotifier.removeAt`, when `ResultsScreen` rebuilds, then it shows the "Recalcul nécessaire" banner and the previous ranking is still visible beneath it.
- Given a stale result, when the user taps "Recalculer", then the banner disappears and the ranking reflects the current roster.
- Given `HorsesNotifier.clear()` is called (new course loaded), then `resultsProvider.state` is `null`, not stale.
- Given the existing `mobile/test/widget_test.dart` end-to-end flow, when run unmodified, it still passes.

## Verification

**Commands:**
- `cd mobile && flutter test` -- expected: all tests pass, including new suites
- `cd mobile && flutter analyze` -- expected: "No issues found!"

**Commands actually run:**
- `cd mobile && flutter test` → **41/41 passed** (38 baseline + 3 new: `add()`-triggers-`markStale()` provider test, plus its two widget-level mirrors), independently re-run and confirmed.
- `cd mobile && flutter analyze` → **"No issues found!"**, independently re-run and confirmed.
- Multi-lens review (blind-hunter, edge-case-hunter, verification-gap) ran on the initial diff; 5 findings were classified `patch` and applied (banner recolored amber not red, banner pinned outside the scrolling `ListView` via `Column`/`Expanded`, `Recalculer` disabled when the roster is empty, the `add()`-after-calc mutation-testing gap closed with a new test, a cross-reference doc comment on `ResultsNotifier.clear()`); 4 findings were `defer`red to `deferred-work.md` (race-config/engine-param changes don't yet mark results stale; no `copyWith` on `AnalyseResult`; no `Semantics(liveRegion: true)` on the banner; the stale race-info summary card still shows the pre-edit partant count); the rest were `reject`ed as subjective style opinions or already covered by frozen spec copy.

## Suggested Review Order

**Staleness state machine**

- Entry point: the `isStale` flag and its two transitions (`calculer()` always clears it, `markStale()` sets it once).
  [`results_provider.dart:14`](../../mobile/lib/providers/results_provider.dart#L14)

- `markStale()` is a no-op with no prior result or already-stale — avoids a redundant Riverpod rebuild.
  [`results_provider.dart:38`](../../mobile/lib/providers/results_provider.dart#L38)

- `clear()` is the full-reset counterpart used for a genuinely new course, not an edit.
  [`results_provider.dart:48`](../../mobile/lib/providers/results_provider.dart#L48)

**Wiring roster mutations to invalidation**

- All three roster mutations funnel through the same `markStale()` call — single source of truth, no screen wiring needed.
  [`horses_provider.dart:10`](../../mobile/lib/providers/horses_provider.dart#L10)

- `clear()` deliberately resets rather than marks stale — a new course is a different context, not an edit of the current one.
  [`horses_provider.dart:32`](../../mobile/lib/providers/horses_provider.dart#L32)

**Stale banner UI**

- Banner sits outside the scrolling `ListView` (`Column` + `Expanded`) so it stays visible while reviewing the stale ranking beneath it.
  [`results_screen.dart:61`](../../mobile/lib/screens/results_screen.dart#L61)

- Amber, not red — staleness is an expected, benign state, never an app error.
  [`results_screen.dart:66`](../../mobile/lib/screens/results_screen.dart#L66)

- `Recalculer` is disabled on an emptied roster, mirroring the existing Calculer FAB guard elsewhere in the app.
  [`results_screen.dart:89`](../../mobile/lib/screens/results_screen.dart#L89)

**Tests**

- Provider-level coverage of the full I/O matrix, including the add()-specific mutation-testing gap closed during review.
  [`horses_provider_test.dart:35`](../../mobile/test/providers/horses_provider_test.dart#L35)

- Widget-level coverage: banner visibility, old ranking still rendered, disabled button on empty roster, recalculation in place.
  [`results_screen_test.dart:75`](../../mobile/test/widgets/results_screen_test.dart#L75)

