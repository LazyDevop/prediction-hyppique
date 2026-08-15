import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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

  Future<Database?> _database() async {
    if (kIsWeb) return null;
    if (_db != null) return _db;
    try {
      final path = join(await getDatabasesPath(), 'hippique_cache.db');
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) => db.execute('''
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
        '''),
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
}
