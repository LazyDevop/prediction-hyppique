// Story 8.9 : cache `hippique_cache.db` en version 2 (table `course_suivie`).
// Fichiers SQLite temporaires réels (sqflite_common_ffi) : une montée de
// version exige de fermer puis rouvrir la même base, ce qu'une base
// `:memory:` ne permet pas.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:prediction_hippique/data/local/database_helper.dart';
import 'package:prediction_hippique/models/course_suivie.dart';
import 'package:prediction_hippique/models/course_summary.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/providers/courses_suivies_provider.dart';

Future<List<String>> _colonnes(Database db, String table) async =>
    (await db.rawQuery('PRAGMA table_info($table)')).map((r) => r['name'] as String).toList();

Future<List<String>> _tables(Database db) async =>
    (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'")).map((r) => r['name'] as String).toList();

/// Schéma figé de la version 1 (livrée avant la story 8.9).
Future<void> _creerV1(Database db, int version) async {
  await db.execute('''
    CREATE TABLE historique_performances (
      cheval_id INTEGER NOT NULL, date_course TEXT, hippodrome TEXT, discipline TEXT,
      allocation REAL, distance REAL, nb_participants INTEGER, rang INTEGER,
      terrain TEXT, incident TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE programme_courses (
      id INTEGER PRIMARY KEY, date TEXT NOT NULL, heure_depart TEXT,
      hippodrome TEXT NOT NULL, discipline TEXT NOT NULL, distance REAL,
      allocation REAL, nb_partants INTEGER, corde TEXT, terrain TEXT,
      niveau_estime TEXT, finalisee INTEGER NOT NULL, source TEXT NOT NULL
    )
  ''');
}

CourseSuivie _suivie(String cle, DateTime date, {bool suivie = true}) => CourseSuivie(
      cleCourse: cle,
      suivie: suivie,
      modifieeLe: DateTime.utc(2026, 11, 23, 9),
      date: date,
      heureDepart: DateTime.utc(2026, 11, 23, 14, 5),
      hippodrome: 'VINCENNES',
    );

/// Attend la fin de la lecture du cache : SQLite (ffi) répond depuis un
/// autre isolat, après un délai réel qu'aucun nombre fixe de tours de la
/// file d'événements ne garantit.
Future<void> _cacheLu(ProviderContainer container) async {
  final lu = Completer<void>();
  final abonnement = container.listen(coursesSuiviesProvider, (_, etat) {
    if (etat.charge && !lu.isCompleted) lu.complete();
  }, fireImmediately: true);
  await lu.future.timeout(const Duration(seconds: 20));
  abonnement.close();
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory dossier;
  late String chemin;

  setUp(() {
    dossier = Directory.systemTemp.createTempSync('cache_v2_');
    chemin = p.join(dossier.path, 'hippique_cache.db');
  });

  tearDown(() {
    try {
      dossier.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('onCreate v2 direct : toutes les tables, course_suivie et les colonnes PMU du programme', () async {
    final db = await databaseFactory.openDatabase(chemin, options: DatabaseHelper.optionsOuverture());
    addTearDown(db.close);

    expect(await db.getVersion(), 2);
    expect(await _tables(db), containsAll(['historique_performances', 'programme_courses', 'course_suivie']));
    expect(
      await _colonnes(db, 'course_suivie'),
      ['cle_course', 'suivie', 'modifiee_le', 'synchronise', 'date', 'heure_depart', 'hippodrome'],
    );
    expect(await _colonnes(db, 'programme_courses'), containsAll(['numero_reunion', 'numero_course', 'cle_course']));
  });

  test('onUpgrade 1 -> 2 : course_suivie ajoutée, données existantes intactes', () async {
    final v1 = await databaseFactory.openDatabase(
      chemin,
      options: OpenDatabaseOptions(version: 1, onCreate: _creerV1),
    );
    await v1.insert('historique_performances', {'cheval_id': 42, 'hippodrome': 'CABOURG', 'rang': 3});
    await v1.insert('programme_courses', {
      'id': 7,
      'date': '2026-11-23',
      'hippodrome': 'VINCENNES',
      'discipline': 'ATTELE',
      'finalisee': 0,
      'source': 'pmu',
    });
    await v1.close();

    final v2 = await databaseFactory.openDatabase(chemin, options: DatabaseHelper.optionsOuverture());
    addTearDown(v2.close);

    expect(await v2.getVersion(), 2);
    expect(await _tables(v2), contains('course_suivie'));
    final histo = await v2.query('historique_performances');
    expect(histo.single['cheval_id'], 42);
    expect(histo.single['rang'], 3);
    final programme = await v2.query('programme_courses');
    expect(programme.single['id'], 7);
    expect(programme.single['hippodrome'], 'VINCENNES');
    expect(programme.single['cle_course'], isNull);

    // Le programme v2 se relit (anciennes lignes : pas de clé PMU).
    DatabaseHelper.instance.setDatabaseForTesting(v2);
    final relu = await DatabaseHelper.instance.getProgramme(DateTime(2026, 11, 23));
    expect(relu.single.cleCourse, isNull);
    await DatabaseHelper.instance.enregistrerCourseSuivie(_suivie('20261123-R1-C4', DateTime(2026, 11, 23)));
    expect((await DatabaseHelper.instance.lireCoursesSuivies()).single.cleCourse, '20261123-R1-C4');
  });

  test('migration interrompue : rejouer la montée sur une base à moitié migrée', () async {
    final v1 = await databaseFactory.openDatabase(
      chemin,
      options: OpenDatabaseOptions(version: 1, onCreate: _creerV1),
    );
    await v1.insert('programme_courses', {
      'id': 3,
      'date': '2026-11-23',
      'hippodrome': 'CABOURG',
      'discipline': 'ATTELE',
      'finalisee': 0,
      'source': 'pmu',
    });
    // Première tentative arrêtée après une colonne et la table.
    await v1.execute('ALTER TABLE programme_courses ADD COLUMN numero_reunion INTEGER');
    await v1.execute(
      'CREATE TABLE course_suivie (cle_course TEXT PRIMARY KEY, suivie INTEGER NOT NULL, '
      'modifiee_le TEXT NOT NULL, synchronise INTEGER NOT NULL DEFAULT 0, date TEXT NOT NULL, '
      'heure_depart TEXT, hippodrome TEXT NOT NULL)',
    );
    await v1.close();

    final v2 = await databaseFactory.openDatabase(chemin, options: DatabaseHelper.optionsOuverture());
    addTearDown(v2.close);
    expect(await v2.getVersion(), 2);
    expect(await _colonnes(v2, 'programme_courses'), containsAll(['numero_reunion', 'numero_course', 'cle_course']));
    expect((await v2.query('programme_courses')).single['hippodrome'], 'CABOURG');

    // Rejouée sur une base déjà migrée : sans effet, sans erreur.
    await DatabaseHelper.migrerSchemaPourTests(v2, 1, 2);
    expect(await _tables(v2), contains('course_suivie'));
  });

  test('programme en cache : les champs PMU sont conservés', () async {
    final db = await databaseFactory.openDatabase(chemin, options: DatabaseHelper.optionsOuverture());
    addTearDown(db.close);
    DatabaseHelper.instance.setDatabaseForTesting(db);
    final jour = DateTime(2026, 11, 23);
    await DatabaseHelper.instance.saveProgramme(jour, [
      CourseSummary(
        id: 1,
        date: jour,
        hippodrome: 'VINCENNES',
        discipline: 'ATTELE',
        finalisee: false,
        source: 'pmu',
        numeroReunion: 1,
        numeroCourse: 4,
        cleCourse: '20261123-R1-C4',
      ),
    ]);
    final relu = (await DatabaseHelper.instance.getProgramme(jour)).single;
    expect(relu.numeroReunion, 1);
    expect(relu.numeroCourse, 4);
    expect(relu.cleCourse, '20261123-R1-C4');
  });

  test('suivre puis ne plus suivre : la ligne reste (suivie = 0, synchronise = 0), dates en UTC', () async {
    final db = await databaseFactory.openDatabase(chemin, options: DatabaseHelper.optionsOuverture());
    addTearDown(db.close);
    DatabaseHelper.instance.setDatabaseForTesting(db);

    final suivie = _suivie('20261123-R1-C4', DateTime(2026, 11, 23));
    await DatabaseHelper.instance.enregistrerCourseSuivie(suivie);
    await DatabaseHelper.instance
        .enregistrerCourseSuivie(suivie.basculee(suivie: false, maintenant: DateTime.utc(2026, 11, 23, 10)));

    final rows = await db.query('course_suivie');
    expect(rows, hasLength(1));
    expect(rows.single['suivie'], 0);
    expect(rows.single['synchronise'], 0);
    expect(rows.single['date'], '2026-11-23');
    expect(rows.single['modifiee_le'], '2026-11-23T10:00:00.000Z');
    expect(rows.single['heure_depart'], '2026-11-23T14:05:00.000Z');
  });

  test("purge à l'ouverture : plus de 90 jours supprimés, le reste gardé", () async {
    final maintenant = DateTime(2026, 11, 23, 12);
    final db = await databaseFactory.openDatabase(chemin, options: DatabaseHelper.optionsOuverture());
    for (final (cle, date) in [
      ('20260801-R1-C1', DateTime(2026, 8, 1)), // 114 jours
      ('20260825-R1-C1', DateTime(2026, 8, 25)), // exactement 90 jours
      ('20261120-R1-C1', DateTime(2026, 11, 20)),
    ]) {
      await db.insert('course_suivie', _suivie(cle, date).toCacheMap());
    }
    await db.close();

    final rouverte = await databaseFactory.openDatabase(
      chemin,
      options: DatabaseHelper.optionsOuverture(horloge: () => maintenant),
    );
    addTearDown(rouverte.close);
    final cles = (await rouverte.query('course_suivie')).map((r) => r['cle_course']).toList();
    expect(cles, unorderedEquals(['20260825-R1-C1', '20261120-R1-C1']));
  });

  test("une course suivie survit au redémarrage de l'app", () async {
    final course = CourseSummary(
      id: 9,
      date: DateTime(2026, 11, 23),
      heureDepart: DateTime.utc(2026, 11, 23, 14, 5),
      hippodrome: 'VINCENNES',
      discipline: 'ATTELE',
      finalisee: false,
      source: 'pmu',
      numeroReunion: 1,
      numeroCourse: 4,
      cleCourse: '20261123-R1-C4',
    );
    final overrides = [
      estWebProvider.overrideWithValue(false),
      horlogeMuraleProvider.overrideWithValue(() => DateTime(2026, 11, 23, 9)),
    ];

    final db = await databaseFactory.openDatabase(chemin, options: DatabaseHelper.optionsOuverture());
    DatabaseHelper.instance.setDatabaseForTesting(db);
    final avant = ProviderContainer(overrides: overrides);
    await _cacheLu(avant); // l'étoile est active
    avant.read(coursesSuiviesProvider.notifier).basculerCourse(course);
    await avant.read(coursesSuiviesProvider.notifier).ecrituresTerminees();
    avant.dispose();
    await db.close();

    final rouverte = await databaseFactory.openDatabase(chemin, options: DatabaseHelper.optionsOuverture());
    addTearDown(rouverte.close);
    DatabaseHelper.instance.setDatabaseForTesting(rouverte);
    final apres = ProviderContainer(overrides: overrides);
    addTearDown(apres.dispose);
    await _cacheLu(apres);

    final etat = apres.read(coursesSuiviesProvider);
    expect(etat['20261123-R1-C4']?.suivie, isTrue);
    expect(coursesSuiviesAVenir(etat.lignes.values, DateTime(2026, 11, 23, 9)).single.hippodrome, 'VINCENNES');
  });
}
