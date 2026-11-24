import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/constants.dart';
import '../models/course_summary.dart';
import '../models/race_config.dart';
import '../providers/api_provider.dart';
import '../providers/courses_suivies_provider.dart';
import '../providers/horses_provider.dart';
import '../providers/pronostic_provider.dart';
import '../providers/race_provider.dart';

/// Nom de la route de la course ouverte (Configuration), téléphone et web.
const routeCourse = 'course';

/// Ouverture d'une course du programme, commune à l'Accueil (téléphone) et
/// à la colonne de gauche de la web app : charge les partants, puis
/// préremplit partants, contexte du pronostic, course courante et config.
/// Lève l'erreur du chargement (l'appelant affiche le snackbar) ; rien
/// n'est modifié dans ce cas.
///
/// Dépôt et notifiers lus AVANT l'attente : l'écran appelant peut être
/// démonté pendant le chargement. [encoreValide] est relu après l'attente :
/// s'il est faux (écran démonté, colonne de droite occupée), rien n'est
/// modifié. Renvoie vrai si la course a été posée.
Future<bool> chargerCourse(WidgetRef ref, CourseSummary course, {required bool Function() encoreValide}) async {
  final repo = ref.read(courseRepositoryProvider);
  final horses = ref.read(horsesProvider.notifier);
  final pronostic = ref.read(pronosticContextProvider.notifier);
  final courante = ref.read(courseCouranteProvider.notifier);
  final suivies = ref.read(coursesSuiviesProvider.notifier);
  final config = ref.read(raceConfigProvider.notifier);

  final partants = await repo.partants(course.id);
  if (!encoreValide()) return false;

  horses.setAll(partants);
  pronostic.courseChargee(course.id);
  courante.definir(course);
  suivies.actualiserInstantanes([course]);
  config.update(RaceConfig(
    hippodrome: course.hippodrome,
    distance: course.distance,
    terrain: terrainCoefficient(course.terrain),
    niveau: null,
    nbPartantsCourse: course.nbPartants,
  ));
  return true;
}
