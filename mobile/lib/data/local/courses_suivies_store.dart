import '../../models/course_suivie.dart';

/// Stockage local des courses suivies (story 8.9), table `course_suivie` du
/// cache `hippique_cache.db` (implémenté par DatabaseHelper). Ne lève
/// jamais : sans cache disponible, la lecture renvoie [] et l'écriture est
/// ignorée — l'état de la session (CoursesSuiviesNotifier) reste utilisable.
abstract class CoursesSuiviesStore {
  /// Toutes les lignes, y compris celles avec `suivie = 0`.
  Future<List<CourseSuivie>> lireCoursesSuivies();

  /// Insère ou remplace la ligne de cette clé.
  Future<void> enregistrerCourseSuivie(CourseSuivie course);
}
