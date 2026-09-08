import '../data/local/database_helper.dart';
import '../data/remote/api_client.dart';
import '../models/course_summary.dart';
import '../models/historique_performance.dart';
import '../models/horse.dart';

/// Résultat du programme du jour, distinct d'une simple `List<CourseSummary>`
/// pour porter la provenance (cache/réseau) et une éventuelle erreur de
/// rafraîchissement — EXPERIENCE.md exige que ces deux états restent
/// visibles simultanément (FR-1/FR-14 : "cache existant reste affiché" ET
/// "message clair" en cas d'échec de rafraîchissement).
class ProgrammeResult {
  final List<CourseSummary> courses;
  final bool fromCache;
  final String? refreshError;

  const ProgrammeResult({required this.courses, required this.fromCache, this.refreshError});
}

/// Point d'accès unique aux écrans, indépendant de la provenance de la
/// donnée (section 5 du document mobile). Le cache local (SQLite) s'y
/// intercale pour l'historique complet d'un cheval (section 7.4) et pour le
/// programme du jour (FR-1/FR-14) sans que les écrans aient à connaître sa
/// présence.
class CourseRepository {
  final ApiClient _api;
  final CoursesApi _programmeApi;
  final DatabaseHelper _db;

  /// [programmeApi] permet d'injecter un CoursesApi factice en test
  /// (spec-3-5) pour le programme du jour uniquement, sans mocker Dio ;
  /// par défaut, [_api] (implémente CoursesApi) sert aux deux usages.
  CourseRepository(this._api, [DatabaseHelper? db, CoursesApi? programmeApi])
      : _db = db ?? DatabaseHelper.instance,
        _programmeApi = programmeApi ?? _api;

  /// Cache-first, jamais de réseau silencieux (EXPERIENCE.md : "jamais de
  /// rafraîchissement automatique en arrière-plan"). Le réseau n'est
  /// interrogé que si le cache de ce jour est vide (premier chargement).
  Future<ProgrammeResult> programmeDuJour(DateTime date) async {
    final cached = await _db.getProgramme(date);
    if (cached.isNotEmpty) {
      return ProgrammeResult(courses: cached, fromCache: true);
    }
    final fresh = await _programmeApi.getCourses(date);
    await _db.saveProgramme(date, fresh);
    return ProgrammeResult(courses: fresh, fromCache: false);
  }

  /// Rafraîchissement explicite (bouton "Rafraîchir" uniquement, jamais
  /// automatique). Retombe sur le cache existant en cas d'échec réseau
  /// plutôt que de faire disparaître une liste déjà affichée ; ne relance
  /// l'exception que si aucun cache n'existe pour amortir l'échec.
  Future<ProgrammeResult> rafraichirProgramme(DateTime date) async {
    try {
      final fresh = await _programmeApi.getCourses(date);
      await _db.saveProgramme(date, fresh);
      return ProgrammeResult(courses: fresh, fromCache: false);
    } catch (e) {
      final cached = await _db.getProgramme(date);
      if (cached.isNotEmpty) {
        return ProgrammeResult(courses: cached, fromCache: true, refreshError: e.toString());
      }
      rethrow;
    }
  }

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
