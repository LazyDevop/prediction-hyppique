import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/course_repository.dart';
import 'api_provider.dart';

/// Cache-first (voir CourseRepository.programmeDuJour) : ne déclenche un
/// appel réseau que si aucun cache n'existe pour ce jour. Le rafraîchissement
/// explicite passe par CourseRepository.rafraichirProgramme, appelé
/// directement par home_screen.dart, pas par ce provider.
final programmeProvider = FutureProvider.family<ProgrammeResult, DateTime>((ref, date) {
  return ref.watch(courseRepositoryProvider).programmeDuJour(date);
});
