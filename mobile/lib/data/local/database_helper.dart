import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/course_suivie.dart';
import '../../models/course_summary.dart';
import '../../models/historique_performance.dart';
import 'courses_suivies_store.dart';

/// Cache local de l'historique complet d'un cheval (section 7.4 du document
/// mobile : "Mets en cache localement (SQLite) l'historique complet une fois
/// chargé, pour ne pas le redemander à chaque ouverture de la fiche").
///
/// sqflite ne fonctionne pas sur Flutter Web (cible de dev de ce projet,
/// service docker mobile-web-dev) : toutes les méthodes se dégradent donc
/// gracieusement (jamais d'exception propagée) — sans cache disponible, on
/// se contente de redemander au backend à chaque fois, ce qui reste correct,
/// juste moins efficace. Le cache est un bonus, jamais une condition de
/// disponibilité de la fiche.
class DatabaseHelper implements CoursesSuiviesStore {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  /// Injecte une base déjà ouverte (typiquement sqflite_common_ffi en
  /// mémoire) pour les tests — court-circuite la résolution de chemin
  /// normale de [_database]. Ne pas utiliser en dehors des tests.
  @visibleForTesting
  void setDatabaseForTesting(Database db) => _db = db;

  /// Version du schéma du cache. Historique (AD-9, jamais renuméroter) :
  /// - 1 : `historique_performances`, `programme_courses`.
  /// - 2 (story 8.9) : table `course_suivie` ; colonnes `numero_reunion`,
  ///   `numero_course`, `cle_course` ajoutées à `programme_courses` (pour
  ///   retrouver une course par sa clé PMU dans le programme en cache).
  static const versionCache = 2;

  /// Une course suivie dont la date a plus de 90 jours est purgée à
  /// l'ouverture du cache.
  static const joursConservationSuivies = 90;

  /// Options d'ouverture réelles du cache, partagées avec les tests (pour
  /// qu'ils exercent exactement `onCreate`, `onUpgrade` et `onOpen`).
  @visibleForTesting
  static OpenDatabaseOptions optionsOuverture({DateTime Function() horloge = DateTime.now}) =>
      OpenDatabaseOptions(
        version: versionCache,
        onCreate: _creerSchema,
        onUpgrade: _migrerSchema,
        onOpen: (db) => purgerCoursesSuivies(db, horloge()),
      );

  Future<Database?> _database() async {
    if (kIsWeb) return null;
    if (_db != null) return _db;
    try {
      final path = join(await getDatabasesPath(), 'hippique_cache.db');
      _db = await databaseFactory.openDatabase(path, options: optionsOuverture());
      return _db;
    } catch (e) {
      developer.log('Cache SQLite indisponible, dégradation sans cache : $e', name: 'DatabaseHelper');
      return null;
    }
  }

  /// Installation neuve : schéma de la dernière version directement.
  static Future<void> _creerSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE historique_performances (
        cheval_id INTEGER NOT NULL,
        date_course TEXT,
        hippodrome TEXT,
        discipline TEXT,
        allocation REAL,
        distance REAL,
        nb_participants INTEGER,
        rang INTEGER,
        terrain TEXT,
        incident TEXT
      )
    ''');
    // Cache du programme du jour (FR-1/FR-14) : une ligne par course,
    // 'date' au format ISO (YYYY-MM-DD) pour filtrer par jour.
    await db.execute('''
      CREATE TABLE programme_courses (
        id INTEGER PRIMARY KEY,
        date TEXT NOT NULL,
        heure_depart TEXT,
        hippodrome TEXT NOT NULL,
        discipline TEXT NOT NULL,
        distance REAL,
        allocation REAL,
        nb_partants INTEGER,
        corde TEXT,
        terrain TEXT,
        niveau_estime TEXT,
        finalisee INTEGER NOT NULL,
        source TEXT NOT NULL,
        numero_reunion INTEGER,
        numero_course INTEGER,
        cle_course TEXT
      )
    ''');
    await _creerCourseSuivie(db);
  }

  /// Montée de version : chaque palier est additif, les données existantes
  /// sont conservées. Défensive : rejouable sur une base à moitié migrée
  /// (colonne déjà présente, table déjà créée).
  static Future<void> _migrerSchema(Database db, int ancienne, int nouvelle) async {
    if (ancienne < 2) {
      final colonnes =
          (await db.rawQuery('PRAGMA table_info(programme_courses)')).map((r) => r['name'] as String).toSet();
      for (final (nom, type) in const [
        ('numero_reunion', 'INTEGER'),
        ('numero_course', 'INTEGER'),
        ('cle_course', 'TEXT'),
      ]) {
        if (!colonnes.contains(nom)) {
          await db.execute('ALTER TABLE programme_courses ADD COLUMN $nom $type');
        }
      }
      await _creerCourseSuivie(db);
    }
  }

  /// Rejoue la montée de version (tests de migration interrompue).
  @visibleForTesting
  static Future<void> migrerSchemaPourTests(Database db, int ancienne, int nouvelle) =>
      _migrerSchema(db, ancienne, nouvelle);

  /// Courses suivies (story 8.9). `modifiee_le` en ISO UTC ; `date`,
  /// `heure_depart`, `hippodrome` : instantané d'affichage.
  static Future<void> _creerCourseSuivie(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS course_suivie (
        cle_course TEXT PRIMARY KEY,
        suivie INTEGER NOT NULL,
        modifiee_le TEXT NOT NULL,
        synchronise INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        heure_depart TEXT,
        hippodrome TEXT NOT NULL
      )
    ''');

  /// Supprime les courses suivies dont la date a plus de 90 jours. Ne lève
  /// jamais (un échec de purge n'empêche pas d'ouvrir le cache).
  @visibleForTesting
  static Future<void> purgerCoursesSuivies(Database db, DateTime maintenant) async {
    try {
      final local = maintenant.toLocal();
      final limite = DateTime(local.year, local.month, local.day - joursConservationSuivies);
      await db.delete('course_suivie', where: 'date < ?', whereArgs: [CourseSuivie.isoDate(limite)]);
    } catch (e) {
      developer.log('Purge des courses suivies échouée, ignorée : $e', name: 'DatabaseHelper');
    }
  }

  @override
  Future<List<CourseSuivie>> lireCoursesSuivies() async {
    try {
      final db = await _database();
      if (db == null) return [];
      final rows = await db.query('course_suivie');
      return rows.map(CourseSuivie.fromCacheMap).toList();
    } catch (e) {
      developer.log('Lecture des courses suivies échouée, dégradation sans cache : $e', name: 'DatabaseHelper');
      return [];
    }
  }

  @override
  Future<void> enregistrerCourseSuivie(CourseSuivie course) async {
    try {
      final db = await _database();
      if (db == null) return;
      await db.insert('course_suivie', course.toCacheMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      developer.log("Écriture d'une course suivie échouée, ignorée : $e", name: 'DatabaseHelper');
    }
  }

  /// Renvoie [] si aucun cache n'existe ou n'est disponible sur cette
  /// plateforme (jamais d'exception : l'appelant retombe alors sur le
  /// réseau).
  Future<List<HistoriquePerformance>> getHistorique(int chevalId) async {
    try {
      final db = await _database();
      if (db == null) return [];
      final rows = await db.query(
        'historique_performances',
        where: 'cheval_id = ?',
        whereArgs: [chevalId],
      );
      final perfs = rows.map(HistoriquePerformance.fromCacheMap).toList();
      perfs.sort((a, b) {
        if (a.dateCourse == null || b.dateCourse == null) return 0;
        return b.dateCourse!.compareTo(a.dateCourse!);
      });
      return perfs;
    } catch (e) {
      developer.log('Lecture du cache échouée, dégradation sans cache : $e', name: 'DatabaseHelper');
      return [];
    }
  }

  /// Remplace intégralement le cache de ce cheval. Échec silencieux côté
  /// cache (loggé, jamais propagé) : ne doit jamais faire échouer l'action
  /// "Voir tout l'historique", qui a déjà réussi côté réseau à ce stade.
  Future<void> saveHistorique(int chevalId, List<HistoriquePerformance> perfs) async {
    try {
      final db = await _database();
      if (db == null) return;
      await db.transaction((txn) async {
        await txn.delete('historique_performances', where: 'cheval_id = ?', whereArgs: [chevalId]);
        for (final perf in perfs) {
          await txn.insert('historique_performances', perf.toCacheMap(chevalId));
        }
      });
    } catch (e) {
      developer.log('Écriture du cache échouée, ignorée : $e', name: 'DatabaseHelper');
    }
  }

  /// Cache du programme du jour (FR-1/FR-14). [] si aucun cache n'existe ou
  /// n'est disponible sur cette plateforme — jamais d'exception, l'appelant
  /// (CourseRepository) retombe alors sur le réseau.
  Future<List<CourseSummary>> getProgramme(DateTime date) async {
    try {
      final db = await _database();
      if (db == null) return [];
      final iso = _isoDate(date);
      final rows = await db.query('programme_courses', where: 'date = ?', whereArgs: [iso]);
      return rows.map(CourseSummary.fromCacheMap).toList();
    } catch (e) {
      developer.log('Lecture du cache programme échouée, dégradation sans cache : $e', name: 'DatabaseHelper');
      return [];
    }
  }

  /// Remplace intégralement le cache du programme pour ce jour. Échec
  /// silencieux côté cache (loggé, jamais propagé) : ne doit jamais faire
  /// échouer un chargement qui a déjà réussi côté réseau.
  Future<void> saveProgramme(DateTime date, List<CourseSummary> courses) async {
    try {
      final db = await _database();
      if (db == null) return;
      final iso = _isoDate(date);
      await db.transaction((txn) async {
        await txn.delete('programme_courses', where: 'date = ?', whereArgs: [iso]);
        for (final course in courses) {
          // 'date' est la clé de bucket de la requête (jour demandé), pas le
          // champ date brut de la course (qui peut porter une heure) — sinon
          // getProgramme(date) ne retrouverait jamais ces lignes.
          await txn.insert('programme_courses', {...course.toCacheMap(), 'date': iso});
        }
      });
    } catch (e) {
      developer.log('Écriture du cache programme échouée, ignorée : $e', name: 'DatabaseHelper');
    }
  }

  String _isoDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
