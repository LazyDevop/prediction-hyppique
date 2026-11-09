---
title: 'Show value and Kelly stakes as experimental in the app'
type: 'feature'
created: '2026-10-22'
status: 'done'
baseline_commit: '95ea6af90af138acb60b367e603861a551451ede'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/predictive-model-roadmap-2026-10-22.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Measured on 3,166 replayed races, the engine's probabilities are worse than a uniform guess, and the market beats them clearly. Yet the results screen presents value and Kelly stakes as reliable advice ("🔥 Value forte — jouable", green stakes in units). A user following them would lose money faster than by backing the favourite.

**Approach:** Keep the figures, but mark them as experimental until the combined model beats the market (roadmap stage 3):
- a banner pinned at the top of the results screen;
- an "experimental" mark on the value and stake figures;
- neutral wording instead of incentive verdicts.

There is no explanation and no measurement figure in the app (user decision). One switch lifts the whole treatment later.

## Boundaries & Constraints

**Always:**
- **The banner.** Exact text: `Value et mises expérimentales : le moteur ne bat pas encore le marché.` It is pinned above the scrolling list, like the stale banner, and shows whenever results are displayed. It coexists with the stale banner (stale first).
- **The figures.** Every value and stake figure on a horse card carries the mark `exp.` (for example `Value exp. +3,2 %`, `Mise exp. 1,2 u`). Stakes lose their green "positive" colour.
- **Verdict wording** (`_reco`):

  | Current | New |
  |---|---|
  | `🔥 Value forte — jouable` | `Écart positif marqué avec la cote` |
  | `Léger avantage` | `Écart positif avec la cote` |
  | `Avantage marginal` | `Écart faible avec la cote` |
  | `Favori du modèle, cote trop courte` | `Favori du modèle, cote plus courte que son estimation` |
  | `Pas d'avantage` | `Pas d'écart positif avec la cote` |

  `Données non saisies` and `Cote manquante` are unchanged.
- **The settings label.** It reads `Fraction de Kelly (expérimental)`.
- **The switch.** A single constant in one Dart file controls the banner, the marks and the settings label. Setting it to false restores the "validated" display, still with the neutral verdicts.
- **Accessibility.** The banner is a semantic container and reads as one sentence.

**Ask First:**
- Hiding any figure.
- Changing the engine, the combinations section or the backend.

**Never:**
- Explanatory text, links or measurement figures in the app.
- Changing value or Kelly computations.

</frozen-after-approval>

## Code Map

- `mobile/lib/screens/results_screen.dart:16-25` -- `_reco` verdict strings.
- `mobile/lib/screens/results_screen.dart:59-104` -- `Scaffold` → `Column`. The pinned stale banner (`stale-banner-semantics`) is the pattern to mirror; add the experimental banner after it, before `Expanded(ListView)`.
- `mobile/lib/screens/results_screen.dart:302-330` -- card row: cote, value (green/red), stake `'… u'` in `Colors.greenAccent`.
- `mobile/lib/screens/settings_screen.dart:115-122` -- `Fraction de Kelly` field label.
- `mobile/lib/screens/results_screen.dart:346` -- footer disclaimer; unchanged.
- `mobile/test/widgets/results_screen_test.dart` -- harness `_pumpWithHorses` and `_scrollToText` (cards are far down the ListView). Add tests here.
- Natural home for the switch: a small file such as `mobile/lib/widgets/experimental.dart` (const + banner widget), or a const near `results_screen.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `mobile/lib/widgets/experimental_banner.dart` (or equivalent) -- Define the switch const and the banner widget (keyed, `Semantics(container: true)`, neutral amber or info style). -- One place to lift the treatment.
- [x] `mobile/lib/screens/results_screen.dart` -- Pin the banner, mark the value and stake figures, neutralise the stake colour and replace the verdicts. -- The visible change.
- [x] `mobile/lib/screens/settings_screen.dart` -- Use the experimental label when the switch is on. -- Consistency.
- [x] `mobile/test/widgets/results_screen_test.dart` -- Tests:
  - the banner is present with its exact text, together with the stale banner;
  - a card shows `exp.` on value and stake;
  - no displayed verdict contains `jouable`;
  - each new verdict string maps from its value range. -- Coverage.

**Acceptance Criteria:**
- Given results are displayed, when the screen opens, then the experimental banner is visible without scrolling.
- Given the switch is false, when the screen renders, then no banner and no `exp.` mark appear, and the verdicts stay neutral.
- Given the mobile suite, when `flutter test` runs, then all tests pass, and `flutter analyze` reports no new issue.

## Verification

**Commands:**
- `cd mobile && C:/Users/lazyd/flutter/bin/flutter test` -- expected: all pass.
- `cd mobile && C:/Users/lazyd/flutter/bin/flutter analyze` -- expected: no new issues versus the baseline.

## Suggested Review Order

**The switch and the banner**

- Entry point: one constant lifts the whole treatment once stage 3 passes.
  [`experimental_banner.dart:8`](../../mobile/lib/widgets/experimental_banner.dart#L8)

- Banner pinned above the list, after the stale banner, one semantic sentence.
  [`results_screen.dart:119`](../../mobile/lib/screens/results_screen.dart#L119)

**Figures and wording**

- Neutral verdicts replace "jouable"-style incentives, kept neutral even after the switch.
  [`results_screen.dart:18`](../../mobile/lib/screens/results_screen.dart#L18)

- `exp.` marks, spelled out for screen readers; no positive green while experimental; Wrap avoids overflow.
  [`results_screen.dart:337`](../../mobile/lib/screens/results_screen.dart#L337)

- Settings label follows the same injectable switch.
  [`settings_screen.dart:122`](../../mobile/lib/screens/settings_screen.dart#L122)

**Tests**

- Experimental group pins `experimental: true`, asserts fixture preconditions and verdict boundaries.
  [`results_screen_test.dart:187`](../../mobile/test/widgets/results_screen_test.dart#L187)

- Settings label in both switch states.
  [`settings_screen_test.dart:1`](../../mobile/test/widgets/settings_screen_test.dart#L1)
