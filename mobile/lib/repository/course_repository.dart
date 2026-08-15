import '../data/local/database_helper.dart';
import '../data/remote/api_client.dart';
import '../models/course_summary.dart';
import '../models/historique_performance.dart';
import '../models/horse.dart';

/// Point d'accès unique aux écrans, indépendant de la provenance de la
/// donnée (section 5 du document mobile). Le cache local (SQLite) s'y
/// intercale pour l'historique complet d'un cheval (section 7.4) sans que
/// les écrans aient à connaître sa présence.
class CourseRepository {
  final ApiClient _api;
  final DatabaseHelper _db;

  CourseRepository(this._api, [DatabaseHelper? db]) : _db = db ?? DatabaseHelper.instance;

  Future<List<CourseSummary>> programmeDuJour(DateTime date) => _api.getCourses(date);

  Future<List<Horse>> partants(int courseId) => _api.getPartants(courseId);

  /// Historique complet d'un cheval (bouton "Voir tout l'historique",
  /// section 7.4). Cache-first : le cache local est renvoyé immédiatement
  /// s'il existe et que forceRefresh est faux, sinon on interroge le
  /// backend (qui déclenche lui-même le backfill via open-pmu-api) puis on
  /// rafraîchit le cache avec le résultat.
  Future<List<HistoriquePerformance>> historiqueComplet(int chevalId, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _db.getHistorique(chevalId);
      if (cached.isNotEmpty) return cached;
    }
    final perfs = await _api.backfillCheval(chevalId);
    await _db.saveHistorique(chevalId, perfs);
    return perfs;
  }
}
