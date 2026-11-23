---
title: 'Story 8.9 — Suivre une course (device side, before sync 8.8)'
type: 'feature'
created: '2026-11-23'
status: 'done'
baseline_commit: '41cd6f80e267511ee83ac5326a3a230c9256e643'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/planning-artifacts/epics.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/EXPERIENCE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-prediction-hyppique-2026-08-22/DESIGN.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 8.9 (epics.md « Story 8.9: Suivre une course ») lets the turfiste mark races and find them at the top of Accueil. The app cannot name a race across systems yet: `GET /courses` exposes only the autoincrement `id`, while AD-12 requires the PMU key `cle_course` = `AAAAMMJJ-Rn-Cn` (the database already has `numero_reunion` and `numero_course`).

**Approach:** Expose `cle_course`, `numero_reunion` and `numero_course` on `CourseOut` (additive). In the app, add a `followed-race` star toggle in the race screens' header and a « Courses suivies » section at the top of Accueil, stored in the local cache `hippique_cache.db` (new version), offline, `synchronise = false` until story 8.8.

## Boundaries & Constraints

**Always:**
- Backend: `CourseOut` gains `numero_reunion: int | None`, `numero_course: int | None`, `cle_course: str | None` (`AAAAMMJJ-Rn-Cn` from date and both numbers; null when a number is missing). Existing fields and routes unchanged. App `CourseSummary` parses them (absent → null, so an older backend still works).
- Star (`followed-race` toggle): in the AppBar of Liste des partants and Résultats when the current race has a `cle_course` (a manual or photo race has none → no star). Glyph ★ filled when followed / outline when not, colours `text` / `muted`, never gold; label written next to it « Suivre » / « Suivie »; one 48dp target; switch semantics « Suivre la course, {heure}, {hippodrome}, course {n} », state « suivie » / « non suivie »; tap toggles at once, no confirmation, works offline.
- Storage: cache version bumped from 1 to 2 with a table `course_suivie` (`cle_course` primary key, `suivie` int, `modifiee_le` UTC ISO text, `synchronise` int default 0) plus display snapshot columns `date`, `heure_depart`, `hippodrome` (needed to render the row without the programme in cache). Unfollow keeps the row with `suivie = 0` (sync needs it). `onCreate` v2 direct and `onUpgrade` 1→2 both tested; existing tables and data survive the upgrade.
- Accueil: section « Courses suivies » above the programme, rows for followed races dated today or later, sorted by departure time: local time (`numeric`), « R{n} C{n} · {hippodrome} » (`muted`), star at the right that unfollows. Hidden when empty. Tap → opens the race the same way as a programme row (find the race by `cle_course` in that date's programme; not found → snackbar « Course introuvable dans le programme »). A followed race leaves the section the day after its date; rows older than 90 days are purged at cache open.
- Wording: « Suivre la course » / « Course suivie » / « Courses suivies »; never « Favoris », « Mes paris », « Courses jouées ».
- Web (`kIsWeb`, no local cache): no star and no section until story 8.8 (never an empty section by mistake).
- Existing screens and tests keep working; the race-opening path from the programme is unchanged.

**Ask First:** Any new dependency; any change to backend routes beyond the three additive `CourseOut` fields; changing how a programme race is opened.

**Never:** Server sync or any account route (8.8), web section, Multi badge on the row (Epic 5 not built), renaming or renumbering existing cache tables, identifying a followed race by the autoincrement id.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Follow | race from programme, tap star | star filled, « Suivie », row in Accueil section | cache unavailable: star stays usable for the session, no crash |
| Unfollow from race | tap filled star | « Suivre », row gone from section | N/A |
| Unfollow from Accueil | tap row star | row disappears, section hidden if last | N/A |
| Manual / photo race | no `cle_course` | no star | N/A |
| Open from section | tap row | race opens like a programme row | not in programme → snackbar |
| Next day | followed race dated yesterday | not in section | N/A |
| Upgrade | existing v1 cache with data | v2 with `course_suivie`, old data intact | N/A |
| Old backend | `/courses` without new fields | no star, app works | N/A |
| Web | kIsWeb | no star, no section | N/A |

</frozen-after-approval>

## Code Map

- `backend/app/schemas/course.py` -- `CourseOut`; add the three fields and a computed `cle_course`.
- `backend/app/data/models.py:19-20` -- `numero_reunion`, `numero_course` already stored.
- `backend/app/api/routes_courses.py:17` -- `GET /courses` (unchanged; only the schema grows).
- `mobile/lib/models/course_summary.dart` -- `fromJson` and cache serialisation; add the fields.
- `mobile/lib/data/local/database_helper.dart:38-76` -- `openDatabase(version: 1)`, `onCreate`; add v2 + `onUpgrade`; `setDatabaseForTesting`.
- `mobile/lib/screens/home_screen.dart:68-95, 170-215` -- `_selectCourse` and the programme list; add the section on top and reuse `_selectCourse`.
- `mobile/lib/screens/horse_list_screen.dart:18`, `mobile/lib/screens/results_screen.dart:34,60` -- AppBars where the star goes.
- `mobile/lib/providers/pronostic_provider.dart` -- `PronosticContext.courseId`; the current race summary must be reachable by the race screens (e.g. a current-race provider set in `_selectCourse`).

## Tasks & Acceptance

**Execution:**
- [x] `backend/app/schemas/course.py` + `backend/tests/` -- three fields, `cle_course` format test (incl. missing numbers → null).
- [x] `mobile/lib/models/course_summary.dart` -- parse/serialise the fields.
- [x] `mobile/lib/data/local/database_helper.dart` (or a new `courses_suivies_store.dart` on the same database) -- v2, `course_suivie`, follow/unfollow/list/purge.
- [x] `mobile/lib/providers/courses_suivies_provider.dart` -- state of followed races, current race provider.
- [x] `mobile/lib/widgets/followed_race.dart` -- star toggle and section row.
- [x] `mobile/lib/screens/{horse_list_screen,results_screen,home_screen}.dart` -- star in AppBars, section on Accueil.
- [x] `mobile/test/` -- `onCreate` v2 and `onUpgrade` 1→2 with sqflite_common_ffi; widget tests for every matrix row; wording test (no forbidden words).

**Acceptance Criteria:**
- Given the backend suite, `flutter test` and `flutter analyze`, when run, then all pass with no new issues.
- Given Android (or the test harness), when a race is followed from Liste des partants, then it appears in « Courses suivies » on Accueil and survives an app restart.

## Verification

**Commands:**
- `cd backend && PYTHONPATH=. .venv/Scripts/python.exe -m pytest -q` -- expected: all pass.
- `cd mobile && flutter test` -- expected: all pass.
- `cd mobile && flutter analyze` -- expected: no issues.

**Manual checks (if no CLI):**
- Chrome shows no star and no section (by design before 8.8); the device check needs Android or Windows desktop.

## Notes

- 2026-11-23 (dev, after review patch): backend 449 passed / 38 skipped; `flutter analyze` no issues; `flutter test` 309 passed (267 before). Two review layers (blind + edge/verification); 11 patches applied: keyless cached day refetched once, manual entry clears the current race, Accueil date at midnight and one refresh before « introuvable », snapshot (time, hippodrome) kept current, section kept while the race has not started and recomputed at midnight/resume, sort by (date, time), `cle_course` null for numbers < 1, single TalkBack state wording + spoken-time row label, defensive migration, star disabled until the cache is read, tests.
- TalkBack speaks the state through the switch (« activé / non activé », per epics.md); « Suivie / Suivre » stays on screen.
- Not checked on a device yet: Chrome has no local cache (no star by design before 8.8); Windows desktop build needs a complete Visual Studio, Android needs the SDK.

## Suggested Review Order

**Storage**

- Cache v2: defensive migration and `course_suivie` table.
  [`database_helper.dart:114`](../../mobile/lib/data/local/database_helper.dart#L114)

- Keyless cached day counted as a cache miss once.
  [`course_repository.dart:40`](../../mobile/lib/repository/course_repository.dart#L40)

**State and rules**

- Section rows: still to come, sorted by date then time.
  [`course_suivie.dart:126`](../../mobile/lib/models/course_suivie.dart#L126)

- Race key on the wire (AD-12), null for missing or invalid numbers.
  [`course.py:30`](../../backend/app/schemas/course.py#L30)

**Screens**

- Star toggle (disabled until loaded, never gold) and section row.
  [`followed_race.dart:88`](../../mobile/lib/widgets/followed_race.dart#L88)

- Opening a followed race: cache, one refresh, then snackbar.
  [`home_screen.dart:151`](../../mobile/lib/screens/home_screen.dart#L151)
