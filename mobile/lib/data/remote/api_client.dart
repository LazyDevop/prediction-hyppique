import 'package:dio/dio.dart';

import '../../engine/constants.dart';
import '../../models/course_summary.dart';
import '../../models/historique_performance.dart';
import '../../models/horse.dart';
import '../../models/performance.dart';
import '../../models/programme_extrait.dart';

/// Interface minimale pour permettre à CourseRepository de recevoir un faux
/// client en test (spec-3-5) sans mocker Dio — ApiClient reste la seule
/// implémentation réelle.
abstract class CoursesApi {
  Future<List<CourseSummary>> getCourses(DateTime date);
}

/// Interface minimale pour `import_photo_screen.dart` (spec-4-3), même
/// convention que `CoursesApi` : les tests widget fournissent un faux
/// `ExtractionApi` et n'ont jamais besoin de mocker Dio. `bytes`/`filename`/
/// `contentType` sont le fichier déjà normalisé par l'appelant (photo ou
/// PDF) — le picker natif n'entre jamais dans cette interface.
abstract class ExtractionApi {
  Future<ProgrammeExtrait> extractProgramme({
    required List<int> bytes,
    required String filename,
    required String contentType,
  });
}

/// Client HTTP vers le backend — section 6 du document mobile. Ne JAMAIS
/// embarquer de clé API tierce ici : l'extraction vision passe entièrement
/// par le backend (section 6.3).
class ApiClient implements CoursesApi, ExtractionApi {
  final Dio _dio;

  ApiClient({String baseUrl = 'http://102.220.19.200:8000'})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  @override
  Future<List<CourseSummary>> getCourses(DateTime date) async {
    final iso = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final response = await _dio.get('/courses', queryParameters: {'date': iso});
    return (response.data as List).map((j) => CourseSummary.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Horse>> getPartants(int courseId) async {
    final response = await _dio.get('/courses/$courseId/partants');
    return (response.data as List).map((j) => _horseFromJson(j as Map<String, dynamic>)).toList();
  }

  /// Bouton "Voir tout l'historique" de la fiche cheval (section 7.4). Ne
  /// touche jamais aux 6 lignes utilisées par le moteur — lecture seule.
  /// Nécessite une connexion réseau : l'appelant décide de l'affichage
  /// hors-ligne (griser le bouton, message clair), voir HorseEditScreen.
  Future<List<HistoriquePerformance>> backfillCheval(int chevalId) async {
    final response = await _dio.post('/chevaux/$chevalId/backfill');
    return (response.data as List)
        .map((j) => HistoriquePerformance.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// `POST /extraction/programme` (Story 4.2) — multipart, champ `file`
  /// (nom exact attendu par `backend/app/api/routes_analyse.py`). Les codes
  /// d'erreur (400/413/429/502) ne sont pas interceptés ici : c'est
  /// `import_photo_screen.dart` qui les mappe en messages français, ce
  /// client se contente de relayer la `DioException` (même répartition des
  /// responsabilités que `getCourses`/`getPartants` ci-dessus).
  @override
  Future<ProgrammeExtrait> extractProgramme({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final response = await _dio.post('/extraction/programme', data: formData);
    return ProgrammeExtrait.fromJson(response.data as Map<String, dynamic>);
  }

  Horse _horseFromJson(Map<String, dynamic> json) {
    final performances = (json['performances'] as List).map((p) {
      final perf = p as Map<String, dynamic>;
      return Performance(
        partants: perf['nb_participants'] as int? ?? 0,
        rang: perf['rang'] as int?,
        distance: (perf['distance'] as num?)?.toDouble(),
        terrain: terrainCoefficient(perf['terrain'] as String?),
        niveau: null, // pas encore dérivé côté backend (section 10 du document backend)
        incident: perf['incident'] as String?,
      );
    }).toList();

    return Horse(
      nom: json['nom'] as String,
      numPmu: json['num_pmu'] as int?,
      age: json['age_a_la_course'] as int?,
      poids: (json['poids'] as num?)?.toDouble(),
      cote: (json['cote_reference'] as num?)?.toDouble() ?? (json['cote_direct'] as num?)?.toDouble(),
      inedit: json['inedit'] as bool? ?? false,
      performances: performances,
      chevalId: json['cheval_id'] as int?,
    );
  }
}
