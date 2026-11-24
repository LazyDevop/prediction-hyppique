import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/course_repository.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

/// Date choisie sur la web app, gardée quand la fenêtre passe d'une à deux
/// colonnes (story 8.7). Toujours nulle hors du web.
class DateProgrammeWebNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void choisir(DateTime date) {
    if (ref.read(estWebProvider)) state = date;
  }
}

final dateProgrammeWebProvider =
    NotifierProvider<DateProgrammeWebNotifier, DateTime?>(DateProgrammeWebNotifier.new);

/// Cache-first (voir CourseRepository.programmeDuJour) : ne déclenche un
/// appel réseau que si aucun cache n'existe pour ce jour. Le rafraîchissement
/// explicite passe par CourseRepository.rafraichirProgramme, appelé
/// directement par home_screen.dart, pas par ce provider.
final programmeProvider = FutureProvider.family<ProgrammeResult, DateTime>((ref, date) {
  return ref.watch(courseRepositoryProvider).programmeDuJour(date);
});
