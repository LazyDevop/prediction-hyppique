// Couverture de la matrice I/O de spec-3-5-programme-cache-local.md
// (FR-1/FR-14). sqflite_common_ffi fournit un vrai SQLite en mémoire sous
// `flutter test` (le canal de plateforme sqflite n'existe pas dans ce
// contexte) — injecté dans le singleton DatabaseHelper via
// setDatabaseForTesting. Un CoursesApi factice (voir CourseRepository,
// paramètre programmeApi) remplace le réseau réel.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:prediction_hippique/data/local/database_helper.dart';
import 'package:prediction_hippique/data/remote/api_client.dart';
import 'package:prediction_hippique/models/course_summary.dart';
import 'package:prediction_hippique/repository/course_repository.dart';

class _FakeCoursesApi implements CoursesApi {
  List<CourseSummary> Function(DateTime date)? onCall;
  Object? throwOnce;
  int callCount = 0;

  @override
  Future<List<CourseSummary>> getCourses(DateTime date) async {
    callCount++;
    if (throwOnce != null) {
      final e = throwOnce!;
      throwOnce = null;
      throw e;
    }
    return onCall?.call(date) ?? [];
  }
}

CourseSummary _course(int id, {String hippodrome = 'Vincennes'}) => CourseSummary(
      id: id,
      date: DateTime(2026, 9, 8),
      hippodrome: hippodrome,
      discipline: 'ATTELE',
      finalisee: false,
      source: 'pmu',
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late _FakeCoursesApi api;
  late CourseRepository repo;
  final date = DateTime(2026, 9, 8);

  setUp(() async {
    // sqflite_common_ffi partage la même base ":memory:" entre ouvertures
    // successives dans le même process (pas une base fraîche par appel) —
    // CREATE TABLE IF NOT EXISTS + purge explicite pour un état propre à
    // chaque test plutôt qu'un "table already exists".
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS programme_courses (
        id INTEGER PRIMARY KEY, date TEXT NOT NULL, heure_depart TEXT,
        hippodrome TEXT NOT NULL, discipline TEXT NOT NULL, distance REAL,
        allocation REAL, nb_partants INTEGER, corde TEXT, terrain TEXT,
        niveau_estime TEXT, finalisee INTEGER NOT NULL, source TEXT NOT NULL
      )
    ''');
    await db.delete('programme_courses');
    DatabaseHelper.instance.setDatabaseForTesting(db);

    api = _FakeCoursesApi();
    repo = CourseRepository(ApiClient(), DatabaseHelper.instance, api);
  });

  group('programmeDuJour (cache-first)', () {
    test('cache présent -> retourné immédiatement, aucun appel réseau', () async {
      api.onCall = (d) => [_course(1)];
      await repo.rafraichirProgramme(date); // peuple le cache via un 1er appel
      api.callCount = 0;

      final result = await repo.programmeDuJour(date);

      expect(result.fromCache, isTrue);
      expect(api.callCount, 0);
    });

    test('cache vide, réseau OK -> récupère et met en cache', () async {
      api.onCall = (d) => [_course(1)];

      final result = await repo.programmeDuJour(date);

      expect(result.fromCache, isFalse);
      expect(result.courses, hasLength(1));
      expect(api.callCount, 1);

      // Deuxième appel : doit maintenant venir du cache.
      api.callCount = 0;
      final second = await repo.programmeDuJour(date);
      expect(second.fromCache, isTrue);
      expect(api.callCount, 0);
    });

    test("cache vide, réseau échoue -> relance l'exception (rien à quoi se replier)", () async {
      api.throwOnce = Exception('offline');

      expect(() => repo.programmeDuJour(date), throwsException);
    });
  });

  group('rafraichirProgramme (explicite)', () {
    test('réseau OK -> écrase le cache, fromCache=false', () async {
      api.onCall = (d) => [_course(1)];
      await repo.rafraichirProgramme(date);

      api.onCall = (d) => [_course(1), _course(2)];
      final result = await repo.rafraichirProgramme(date);

      expect(result.fromCache, isFalse);
      expect(result.courses, hasLength(2));
    });

    test('réseau échoue, cache existant -> retombe sur le cache avec refreshError', () async {
      api.onCall = (d) => [_course(1)];
      await repo.rafraichirProgramme(date);

      api.throwOnce = Exception('offline');
      final result = await repo.rafraichirProgramme(date);

      expect(result.fromCache, isTrue);
      expect(result.refreshError, contains('offline'));
      expect(result.courses, hasLength(1));
    });

    test('réseau échoue, aucun cache -> relance l\'exception', () async {
      api.throwOnce = Exception('offline');

      expect(() => repo.rafraichirProgramme(date), throwsException);
    });
  });

  test("backend renvoie zéro course pour la date -> mis en cache vide, pas d'erreur", () async {
    api.onCall = (d) => [];

    final result = await repo.programmeDuJour(date);

    expect(result.fromCache, isFalse);
    expect(result.courses, isEmpty);
  });
}
