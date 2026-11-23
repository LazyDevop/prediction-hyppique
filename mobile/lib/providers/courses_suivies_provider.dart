import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/courses_suivies_store.dart';
import '../data/local/database_helper.dart';
import '../models/course_suivie.dart';
import '../models/course_summary.dart';
import 'auth_provider.dart';
import 'pronostic_provider.dart';

/// Stockage des courses suivies : le cache local `hippique_cache.db`.
final coursesSuiviesStoreProvider = Provider<CoursesSuiviesStore>((ref) => DatabaseHelper.instance);

/// Suivre une course n'existe pas sur le web avant la story 8.8 (pas de
/// cache local, lecture serveur à venir) : ni étoile ni section, jamais une
/// section vide par erreur.
final suiviDisponibleProvider = Provider<bool>((ref) => !ref.watch(estWebProvider));

/// État des courses suivies : les lignes par clé PMU et [charge], vrai une
/// fois la lecture du cache terminée (réussie ou non).
class EtatCoursesSuivies {
  final Map<String, CourseSuivie> lignes;
  final bool charge;

  const EtatCoursesSuivies({this.lignes = const {}, this.charge = false});

  CourseSuivie? operator [](String cle) => lignes[cle];
}

/// Courses suivies. L'étoile reste inactive tant que le cache n'a pas été
/// lu (un tap ne peut donc pas écraser une ligne stockée depuis un état
/// vide). Ensuite l'état de la session fait foi : il bascule tout de suite
/// et l'écriture dans le cache suit en tâche de fond ; un cache
/// indisponible n'empêche jamais de suivre une course pendant la session
/// (la lecture échouée compte comme chargée, sans ligne).
class CoursesSuiviesNotifier extends Notifier<EtatCoursesSuivies> {
  Future<void> _ecritures = Future.value();
  int _generation = 0;

  /// Instantanés reçus avant la fin du chargement, appliqués ensuite.
  final _instantanesEnAttente = <CourseSummary>[];

  @override
  EtatCoursesSuivies build() {
    final generation = ++_generation;
    _instantanesEnAttente.clear();
    if (!ref.watch(suiviDisponibleProvider)) return const EtatCoursesSuivies();
    _charger(ref.watch(coursesSuiviesStoreProvider), generation);
    return const EtatCoursesSuivies();
  }

  Future<void> _charger(CoursesSuiviesStore store, int generation) async {
    List<CourseSuivie> lues;
    try {
      lues = await store.lireCoursesSuivies();
    } catch (_) {
      lues = const [];
    }
    if (!ref.mounted || generation != _generation) return;
    state = EtatCoursesSuivies(lignes: {for (final c in lues) c.cleCourse: c}, charge: true);
    final enAttente = List.of(_instantanesEnAttente);
    _instantanesEnAttente.clear();
    actualiserInstantanes(enAttente);
  }

  bool estSuivie(String cleCourse) => state[cleCourse]?.suivie ?? false;

  /// Bascule depuis l'écran d'une course ; sans clé PMU ou avant le
  /// chargement, ne fait rien.
  void basculerCourse(CourseSummary course) {
    final cle = course.cleCourse;
    if (cle == null || !state.charge) return;
    final maintenant = ref.read(horlogeMuraleProvider)();
    final ligne = CourseSuivie.depuisCourse(course, suivie: !estSuivie(cle), maintenant: maintenant);
    if (ligne != null) _ecrire(ligne);
  }

  /// Étoile d'une ligne de la section « Courses suivies ».
  void nePlusSuivre(String cleCourse) {
    final actuelle = state[cleCourse];
    if (!state.charge || actuelle == null || !actuelle.suivie) return;
    _ecrire(actuelle.basculee(suivie: false, maintenant: ref.read(horlogeMuraleProvider)()));
  }

  /// Course ouverte ou programme (re)chargé : remet à jour l'heure de départ
  /// et l'hippodrome des courses suivies concernées, sans toucher `suivie`,
  /// `modifiee_le` ni `synchronise`.
  void actualiserInstantanes(Iterable<CourseSummary> courses) {
    if (!ref.read(suiviDisponibleProvider)) return;
    if (!state.charge) {
      _instantanesEnAttente.addAll(courses);
      return;
    }
    for (final course in courses) {
      final cle = course.cleCourse;
      final actuelle = cle == null ? null : state[cle];
      if (actuelle != null && actuelle.instantaneDiffere(course)) _ecrire(actuelle.avecInstantane(course));
    }
  }

  void _ecrire(CourseSuivie ligne) {
    state = EtatCoursesSuivies(lignes: {...state.lignes, ligne.cleCourse: ligne}, charge: state.charge);
    final store = ref.read(coursesSuiviesStoreProvider);
    // Écritures en file : la dernière bascule est toujours la dernière écrite.
    _ecritures = _ecritures.then((_) => store.enregistrerCourseSuivie(ligne)).catchError((Object _) {});
  }

  /// Attend la fin des écritures en cours (tests).
  Future<void> ecrituresTerminees() => _ecritures;
}

final coursesSuiviesProvider =
    NotifierProvider<CoursesSuiviesNotifier, EtatCoursesSuivies>(CoursesSuiviesNotifier.new);

/// Course du programme actuellement ouverte (posée par l'Accueil à
/// l'ouverture d'une course). Sert à l'étoile des écrans de la course.
class CourseCouranteNotifier extends Notifier<CourseSummary?> {
  @override
  CourseSummary? build() => null;

  void definir(CourseSummary course) => state = course;

  /// Saisie manuelle : plus de course du programme ouverte.
  void effacer() => state = null;
}

final courseCouranteProvider =
    NotifierProvider<CourseCouranteNotifier, CourseSummary?>(CourseCouranteNotifier.new);

/// Course que l'étoile peut suivre : la course courante, si elle a une clé
/// PMU et que les partants affichés sont toujours les siens (une course
/// importée par photo ou saisie à la main remet le contexte à zéro).
final courseSuivableProvider = Provider<CourseSummary?>((ref) {
  if (!ref.watch(suiviDisponibleProvider)) return null;
  final course = ref.watch(courseCouranteProvider);
  if (course == null || course.cleCourse == null) return null;
  if (ref.watch(pronosticContextProvider).courseId != course.id) return null;
  return course;
});
