import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/course_summary.dart';
import '../../models/historique_performance.dart';

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
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  /// Injecte une base déjà ouverte (typiquement sqflite_common_ffi en
  /// mémoire) pour les tests — court-circuite la résolution de chemin
  /// normale de [_database]. Ne pas utiliser en dehors des tests.
  @visibleForTesting
  void setDatabaseForTesting(Database db) => _db = db;

  Future<Database?> _database() async {
    if (kIsWeb) return null;
    if (_db != null) return _db;
    try {
      final path = join(await getDatabasesPath(), 'hippique_cache.db');
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
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
            source TEXT NOT NULL
          )
        ''');
        },
      );
      return _db;
    } catch (e) {
      developer.log('Cache SQLite indisponible, dégradation sans cache : $e', name: 'DatabaseHelper');
      return null;
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
