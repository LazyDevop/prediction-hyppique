# Epic 3 Context: Consulter et analyser une course sur mobile, hors-ligne y compris

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

From their phone, the user browses the day's race programme, configures or adjusts a target course, sees the ranking/probabilities/value/stake/combinations, and can recalculate with zero network calls once the course is cached — including from the stands at a racetrack, on a degraded connection. This is the product's primary surface: the backend (Epic 1's engine, Epic 2's ingestion) only has value once someone can consult and act on it from a phone. The epic is scoped as one large unit rather than fragmented per screen, because config + engine + results + offline only deliver value together, and the UX (EXPERIENCE.md, and the two HTML/JSX prototypes it formalizes) has already validated this flow numerically — low direction-risk across whatever story split is chosen.

## Stories

- Story 3.1: Accueil — programme du jour (cache-first list, explicit pull-to-refresh, cold-start-empty state)
- Story 3.2: Configuration de la course cible (manual or prefilled, grouped Gazon/PSF terrain picker)
- Story 3.3: Liste des partants — transparency indicators, add/remove a horse (mandatory recalc on removal)
- Story 3.4: Fiche cheval éditable (editable performance history, explicit "terrain inconnu", per-performance edit sheet)
- Story 3.5: Dart port of the scoring engine (score, Plackett-Luce/Harville probabilities, value, Kelly stake, ordre/désordre and Monte-Carlo combinations)
- Story 3.6: Écran résultats (ranking cards, probability gauges, combination grid, stale-result banner)
- Story 3.7: Cache local SQLite + offline recalculation (no network call on parameter change)
- Story 3.8: Réglages du moteur (all engine coefficients exposed, persisted, one-gesture reset)
- Story 3.9: Export/partage du classement (text/JSON minimum, no network dependency)

## Requirements & Constraints

- Course list comes from cache first; refresh is always an explicit user action, never automatic in the background (applies to both the programme list and in-course odds refresh).
- Terrain and niveau scales (Gazon vs PSF) are never mixed in the picker; the target niveau actually feeds the engine's niveau coefficient.
- A course not yet in the local database triggers on-demand import (handled one screen earlier, at Accueil — not inside Configuration course).
- Transparency states on a horse ("Historique court (N)", "Données non saisies", "🐎 Inédit") are three distinct, fixed labels — never collapsed into one generic "insufficient data" state, and never silently absorbed into the calculation without being shown.
- Removing a horse invalidates any already-displayed result; the Résultats screen must show a "recalcul nécessaire" state rather than silently going stale.
- Once a course's data is cached, every parameter change recalculates (score → probabilities → combinations, including the 20,000-draw Monte-Carlo simulation) with zero HTTP calls — this includes airplane mode. Cached courses stay available until explicit deletion or manual refresh.
- The two network-dependent features (photo import, live-odds refresh) fail with a clear message and leave the rest of the screen usable; they never block the app.
- Suggested stake is hidden (not a misleading "0") when Kelly is negative or the odds are missing; engine settings persist across sessions with a one-gesture reset to defaults.
- Export is available at minimum as text or JSON with no network dependency; PDF is an optional bonus, never a requirement.
- Perceived-instant performance for a full local recalculation (engine + Monte-Carlo) is required, but no numeric threshold is fixed yet — open question, revisit once a target device is chosen.
- Offline availability of the calculation, once a course is cached, is non-negotiable — a cross-cutting constraint, not an optional feature.
- Mobile results must match the backend engine's output to within epsilon on identical input (cross-language parity), and both must reproduce the original prototype's ranking on the same input — except Monte-Carlo place-probability draws, which are compared only by statistical tolerance between languages, never exact equality.

## Technical Decisions

- Hexagonal boundary applies to mobile too: `lib/engine/` never imports from `lib/data/` or any HTTP/network library; `lib/data/` (remote client, local SQLite) are the only modules that know their external format; `lib/screens/`+`lib/providers/` are the driving adapters that call into engine/data, never the reverse.
- Engine parity with the backend is enforced via two shared, repo-root fixture files consumed by both languages — never hand-duplicated test cases or hand-copied coefficient tables: one holds test cases plus the canonical default engine parameters, the other holds the terrain/niveau/incident/récence coefficient tables.
- `terrain`/`niveau` travel end-to-end as canonical French label strings, never pre-resolved floats; coefficient resolution happens only at point of use via a mirrored lookup table on the Dart side. An unrecognized label must be a distinct, logged condition — never silently folded into the same neutral-coefficient path used for a genuinely-absent (`null`) value.
- API responses consumed by mobile are the typed backend schema, not a raw dict dump — mobile models should mirror the declared response shape, not an ad hoc map.
- Domain vocabulary (field names) stays French end-to-end across Python dataclasses, JSON payloads, and Dart models for the engine-facing shape — never translated to English.
- Stack: Flutter/Dart current stable; Riverpod for state management; `sqflite` for the local cache; `dio` (not `http`) for the HTTP client, chosen for timeout/retry handling on unreliable trackside connections; `freezed` + `json_serializable` for immutable models with JSON parity to backend schemas.
- Android only in V1 (iOS deferred); dark theme only, no light mode; fully custom Material 3 token theme, never default Material colors.

## UX & Interaction Patterns

- Navigation is a simple linear stack — Accueil → Configuration course → Liste des partants → Résultats — no tabs, with a direct shortcut from Accueil into an already-cached course. Import photo is a single-level bottom sheet only, never stacked on another full screen.
- A horse's expanded detail on Résultats (full probabilities, history) is an in-place accordion on the result card, not a separate navigable screen.
- Fixed microcopy vocabulary must be reused verbatim (not reworded): transparency badges, value badges ("🔥 Value forte — jouable", "📈 Léger avantage", "— Pas d'avantage"), the responsible-gaming reminder shown on every results screen, "Mise suggérée" (never "Mise recommandée"/"à jouer").
- Per-performance editing happens in a dedicated full-width edit sheet, not inline in the compact performance row — keeps touch targets ≥48dp.
- Accessibility floor: cards (`horse-card`, `results-card`) announce as one grouped semantic node (identity → status → score → value → stake → odds → detail-on-demand), never as 10+ flat fields; no signal is carried by color alone (value sign, badges are always text too); visible focus indicator for keyboard/external-accessory input.
- Settings changes apply immediately in memory, persist on blur/confirm; reset requires a lightweight confirmation (irreversible for the session).
- A screen-specific mockup exists for each surface in this epic (`accueil.html`, `configuration-course.html`, `liste-partants.html`, `fiche-cheval.html`, `resultats.html`, under `ux-designs/ux-prediction-hyppique-2026-08-22/mockups/`) — consult the relevant one for layout, but the spine (`EXPERIENCE.md`) wins on any conflict. `DESIGN.md` carries the visual token/style reference (colors, elevation, components) referenced by name above.

## Cross-Story Dependencies

- The Dart engine port (Story 3.5) is the load-bearing dependency for Résultats (3.6), Réglages' demonstrable effect (3.8), and Export (3.9) — none of those can show real output without it. It depends on Epic 1's shared parity fixtures, not on any other Epic 3 story.
- Liste des partants (3.3) and Fiche cheval (3.4) both surface an "importer une photo/PDF" entry point that hands off to Epic 4's vision-extraction capability — that capability itself is out of this epic's scope, but the entry point and the resulting "à vérifier" field state are not.
- Accueil (3.1) owns on-demand course import (FR-3, backed by Epic 2's ingestion); Configuration course (3.2) assumes the course already exists locally by the time it's pushed and must not re-implement that import.
- The whole epic must remain usable with 100% manual data entry, without Epic 2's ingestion or a network connection — cached/offline operation (3.7) is not an enhancement layered on top, it's a baseline every other story must not violate.
