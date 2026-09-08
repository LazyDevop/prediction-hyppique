---
title: 'Cache-first programme du jour with explicit-refresh fallback (FR-1/FR-14)'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
context: ['{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md']
baseline_commit: '8eb4367'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `CourseRepository.programmeDuJour` (`course_repository.dart:17`) calls the backend directly with zero caching — `DatabaseHelper` only has a table for per-cheval historique (`historique_performances`), nothing for the programme du jour itself. This violates FR-1 ("cache local prioritaire, rafraîchissement explicite") and FR-14, and every EXPERIENCE.md `State Patterns` row about the Accueil surface is currently unimplementable: "Cold start, programme en cache → affiche le cache immédiatement" (no cache exists to show), "Échec du rafraîchissement du programme → cache existant reste affiché" (there's nothing to fall back to — a failed fetch is just a hard error screen, cf. `home_screen.dart`'s `programmeAsync.when(..., error: ...)`).

**Approach:** New SQLite table `programme_courses`, mirroring the existing `toCacheMap`/`fromCacheMap` pattern already used for `HistoriquePerformance`. `CourseRepository` gains cache-first read (`programmeDuJour`: return cache immediately if non-empty, network only when cache is empty) and an explicit force-refresh path (`rafraichirProgramme`: always hits network, falls back to stale cache + a carried error message on failure) — two different methods rather than one flag-based method, because their failure semantics genuinely differ (one has no fallback, one does) and EXPERIENCE.md explicitly bans automatic background refresh (Interaction Primitives: "jamais de rafraîchissement automatique en arrière-plan").

## Boundaries & Constraints

**Always:**
- New table `programme_courses`, one row per `CourseSummary`, keyed by `id` (globally unique per backend) — no composite key needed.
- `programmeDuJour(date)`: if cache for that date is non-empty, return it immediately, no network call at all. Only fetch over the network when the cache is empty (first-ever load for that date).
- `rafraichirProgramme(date)`: always fetches over the network first. On success, overwrite the cache for that date and return the fresh data (`fromCache: false`). On failure, fall back to the existing cache for that date if non-empty (`fromCache: true`, `refreshError` carrying the error) — rethrow only if the cache is also empty (nothing to fall back to).
- Both methods return `ProgrammeResult { courses, fromCache, refreshError }`, never a bare `List<CourseSummary>` — the caller needs `fromCache`/`refreshError` to render EXPERIENCE.md's distinct states.
- `home_screen.dart`'s "Rafraîchir" button calls `rafraichirProgramme` imperatively and shows a `SnackBar` when `refreshError != null`, then `ref.invalidate(programmeProvider(date))` so the declarative provider re-reads the (now possibly updated) cache — keeps the transient error message and the persistent list state cleanly separated.
- Remove the manual "Charger le programme" gate (`_loaded`) — `programmeDuJour` is cheap and cache-first, so the screen can watch the provider from first build, matching "Affiche le cache immédiatement, pas d'écran de chargement bloquant."
- Empty-result message (no data available, whether cold-cache or a genuinely race-free date) is the exact EXPERIENCE.md string: `'Aucune course chargée — rafraîchissez ou ajoutez une course manuellement.'`, with a visible "Rafraîchir" CTA alongside it.

**Ask First:** None.

**Never:**
- Do not add a background/automatic refresh timer or lifecycle-triggered refetch — refresh is only ever a direct user tap.
- Do not touch `historique_performances`, `historiqueComplet()`, or the "Voir tout l'historique" feature — different cache, different table, out of scope.
- Do not touch anything under `backend/`.
- Do not change `ApiClient.getCourses`'s signature or JSON mapping.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Cold start, cache present | `programme_courses` has rows for `date` | `programmeDuJour` returns them immediately, `fromCache: true`, no network call | N/A |
| Cold start, no cache, network OK | Cache empty for `date` | `programmeDuJour` fetches, caches, returns `fromCache: false` | N/A |
| Cold start, no cache, network fails | Cache empty, `_api.getCourses` throws | `programmeDuJour` rethrows (nothing to fall back to) — UI shows existing error state | N/A |
| Explicit refresh, network OK | Any cache state | `rafraichirProgramme` overwrites cache, returns fresh data, `refreshError: null` | N/A |
| Explicit refresh, network fails, cache exists | Cache non-empty | Returns stale cache, `fromCache: true`, `refreshError` set — UI shows SnackBar + old list | N/A |
| Explicit refresh, network fails, cache empty | Cache empty | Rethrows | N/A |
| Backend returns zero courses for date | Fresh fetch succeeds, empty list | Cached as empty, UI shows the fixed "Aucune course chargée..." message | N/A |

</frozen-after-approval>

## Code Map

- `mobile/lib/data/local/database_helper.dart` -- MODIFY -- add `programme_courses` table (`onCreate`), `getProgramme(DateTime)`, `saveProgramme(DateTime, List<CourseSummary>)`, `@visibleForTesting setDatabaseForTesting(Database)` (test seam, not in the original plan — needed because the singleton has no other way to accept an in-memory test database)
- `mobile/lib/models/course_summary.dart` -- MODIFY -- add `toCacheMap()`/`fromCacheMap()` mirroring `HistoriquePerformance`
- `mobile/lib/data/remote/api_client.dart` -- MODIFY (not in the original plan) -- extract `abstract class CoursesApi { getCourses }`, `ApiClient implements CoursesApi` — needed to inject a fake network layer in tests without mocking Dio; `getCourses`'s signature is unchanged, satisfying the original "Never" boundary
- `mobile/lib/repository/course_repository.dart` -- MODIFY -- `ProgrammeResult`, cache-first `programmeDuJour`, `rafraichirProgramme`, constructor gains an optional `CoursesApi? programmeApi` (defaults to the real `ApiClient`)
- `mobile/lib/providers/programme_provider.dart` -- MODIFY -- `FutureProvider.family<ProgrammeResult, DateTime>` (was `List<CourseSummary>`)
- `mobile/lib/screens/home_screen.dart` -- MODIFY -- remove `_loaded` gate, wire `rafraichirProgramme` + SnackBar to the refresh button, align empty-state text
- `mobile/pubspec.yaml` -- MODIFY -- add `sqflite_common_ffi` dev dependency (real SQLite in the test VM, no platform channel)
- `mobile/test/repository/course_repository_test.dart` -- NEW -- 7 tests covering the full I/O matrix
- `mobile/test/widget_test.dart` -- READ-ONLY, unmodified, still passing

## Tasks & Acceptance

**Execution:**
- [x] `database_helper.dart` -- `programme_courses` table + get/save + test seam
- [x] `course_summary.dart` -- cache (de)serialization
- [x] `api_client.dart` -- `CoursesApi` interface extraction
- [x] `course_repository.dart` -- `ProgrammeResult`, cache-first `programmeDuJour`, `rafraichirProgramme`
- [x] `programme_provider.dart` -- return type update
- [x] `home_screen.dart` -- remove load gate, wire refresh + SnackBar, align empty-state text
- [x] `course_repository_test.dart` -- I/O matrix coverage (7 tests)

**Acceptance Criteria:**
- Given a cached programme for today, when the app cold-starts, then the list renders with no network call and no loading spinner.
- Given no cache and a reachable backend, when the app cold-starts, then the programme loads and is cached.
- Given a cached programme and a subsequent failed "Rafraîchir" tap, when the button is pressed, then the old list stays visible and a SnackBar reports the failure.
- Given the existing `widget_test.dart` end-to-end flow, when run unmodified, it still passes.

## Verification

**Commands actually run:**
- `cd mobile && flutter test` → **52/52 passed** (45 baseline + 7 new `course_repository_test.dart` cases), including the unmodified `widget_test.dart` e2e flow.
- `cd mobile && flutter analyze` → **"No issues found!"**
- No multi-lens review dispatched this run (solo/direct session, not the interactive spec→subagent→3-lens-review rhythm) — verified instead by direct implementation, full diff re-read, and real test/analyze execution at each step.

## Design Notes

`getProgramme`/cache-hit treats a cached-but-empty day (a genuine race-free date) the same as "never cached" (`cached.isNotEmpty` is the only signal) — such a day always re-hits the network on every visit rather than ever being served from cache. Deliberately accepted: distinguishing the two would need a sentinel row or separate "last fetched" metadata table, real complexity for a low-value edge case (a network call for a day with zero races is cheap and self-correcting, never wrong, just not maximally efficient).
