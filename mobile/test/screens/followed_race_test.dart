// Story 8.9 — `followed-race` : matrice I/O de spec-8-9-suivre-une-course.md.
// Un stockage en mémoire remplace le cache SQLite (couvert par
// test/data/courses_suivies_cache_test.dart) ; un CourseRepository factice
// remplace le réseau.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prediction_hippique/data/local/courses_suivies_store.dart';
import 'package:prediction_hippique/data/remote/api_client.dart';
import 'package:prediction_hippique/models/course_suivie.dart';
import 'package:prediction_hippique/models/course_summary.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/providers/api_provider.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/providers/courses_suivies_provider.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/pronostic_provider.dart';
import 'package:prediction_hippique/repository/course_repository.dart';
import 'package:prediction_hippique/screens/home_screen.dart';
import 'package:prediction_hippique/screens/horse_list_screen.dart';
import 'package:prediction_hippique/screens/race_config_screen.dart';
import 'package:prediction_hippique/screens/results_screen.dart';
import 'package:prediction_hippique/widgets/auth_styles.dart';

final _maintenant = DateTime(2026, 11, 23, 10);
final _etoile = find.byKey(const Key('etoile-suivi-course'));
final _section = find.byKey(const Key('section-courses-suivies'));

class _StoreMemoire implements CoursesSuiviesStore {
  final lignes = <String, CourseSuivie>{};

  @override
  Future<List<CourseSuivie>> lireCoursesSuivies() async => lignes.values.toList();

  @override
  Future<void> enregistrerCourseSuivie(CourseSuivie course) async => lignes[course.cleCourse] = course;
}

/// Lecture du cache retenue jusqu'à [lecture].complete().
class _StoreLent implements CoursesSuiviesStore {
  final lignes = <String, CourseSuivie>{};
  final lecture = Completer<void>();
  int ecritures = 0;

  @override
  Future<List<CourseSuivie>> lireCoursesSuivies() async {
    await lecture.future;
    return lignes.values.toList();
  }

  @override
  Future<void> enregistrerCourseSuivie(CourseSuivie course) async {
    ecritures++;
    lignes[course.cleCourse] = course;
  }
}

class _StoreEnPanne implements CoursesSuiviesStore {
  @override
  Future<List<CourseSuivie>> lireCoursesSuivies() => Future.error(StateError('cache indisponible'));

  @override
  Future<void> enregistrerCourseSuivie(CourseSuivie course) => Future.error(StateError('cache indisponible'));
}

class _FauxRepo extends CourseRepository {
  /// Programme du cache.
  final List<CourseSummary> programme;

  /// Programme du réseau (rafraîchissement) ; nul = réseau en échec.
  List<CourseSummary>? reseau;
  final partantsDemandes = <int>[];
  final rafraichissements = <DateTime>[];
  /// Jours dont la lecture du programme échoue (backend injoignable, sans cache).
  final joursEnEchec = <DateTime>{};

  _FauxRepo(this.programme, {this.reseau = const []}) : super(ApiClient());

  List<CourseSummary> _du(List<CourseSummary> courses, DateTime date) => courses
      .where((c) => c.date.year == date.year && c.date.month == date.month && c.date.day == date.day)
      .toList();

  @override
  Future<ProgrammeResult> programmeDuJour(DateTime date) async {
    if (joursEnEchec.contains(DateTime(date.year, date.month, date.day))) {
      throw Exception('backend injoignable');
    }
    return ProgrammeResult(courses: _du(programme, date), fromCache: true);
  }

  @override
  Future<ProgrammeResult> rafraichirProgramme(DateTime date) async {
    rafraichissements.add(date);
    final r = reseau;
    if (r == null) throw Exception('backend injoignable');
    return ProgrammeResult(courses: _du(r, date), fromCache: false);
  }

  @override
  Future<List<Horse>> partants(int courseId) async {
    partantsDemandes.add(courseId);
    return [Horse(nom: 'FOUDRE NOIRE')];
  }
}

CourseSummary _course({int id = 9, DateTime? date, int reunion = 1, int numero = 4, bool pmu = true}) {
  final jour = date ?? DateTime(2026, 11, 23);
  final aaaammjj = CourseSuivie.isoDate(jour).replaceAll('-', '');
  return CourseSummary(
    id: id,
    date: jour,
    heureDepart: DateTime.utc(jour.year, jour.month, jour.day, 14, 5),
    hippodrome: 'VINCENNES',
    discipline: 'ATTELE',
    distance: 2700,
    nbPartants: 14,
    finalisee: false,
    source: 'pmu',
    numeroReunion: pmu ? reunion : null,
    numeroCourse: pmu ? numero : null,
    cleCourse: pmu ? '$aaaammjj-R$reunion-C$numero' : null,
  );
}

CourseSuivie _suivie(CourseSummary c) => CourseSuivie.depuisCourse(c, suivie: true, maintenant: _maintenant)!;

String _heureLocale(CourseSummary c) {
  final h = c.heureDepart!.toLocal();
  return '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
}

Future<ProviderContainer> _conteneur({
  CoursesSuiviesStore? store,
  List<CourseSummary> programme = const [],
  bool web = false,
  _FauxRepo? repo,
  DateTime Function()? horloge,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    coursesSuiviesStoreProvider.overrideWithValue(store ?? _StoreMemoire()),
    estWebProvider.overrideWithValue(web),
    horlogeMuraleProvider.overrideWithValue(horloge ?? () => _maintenant),
    courseRepositoryProvider.overrideWithValue(repo ?? _FauxRepo(programme)),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Course du programme ouverte, comme le fait l'Accueil.
void _ouvrir(ProviderContainer container, CourseSummary course) {
  container.read(horsesProvider.notifier).setAll([Horse(nom: 'FOUDRE NOIRE')]);
  container.read(pronosticContextProvider.notifier).courseChargee(course.id);
  container.read(courseCouranteProvider.notifier).definir(course);
}

Future<void> _pump(WidgetTester tester, ProviderContainer container, Widget ecran) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: ecran),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Suivre depuis Liste des partants : étoile pleine, « Suivie », ligne dans l\'Accueil', (tester) async {
    final store = _StoreMemoire();
    final course = _course();
    final container = await _conteneur(store: store, programme: [course]);
    _ouvrir(container, course);
    await _pump(tester, container, const HorseListScreen());

    expect(find.text('Suivre'), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    final h = course.heureDepart!.toLocal();
    expect(
      tester.getSemantics(_etoile),
      isSemantics(
        label: 'Suivre la course, ${h.hour} heures ${h.minute.toString().padLeft(2, '0')}, VINCENNES, course 4',
        // L'état n'est dit qu'une fois : par l'interrupteur, sans valeur.
        value: '',
        hasToggledState: true,
        isEnabled: true,
        isToggled: false,
        hasTapAction: true,
      ),
    );
    // Contour et libellé en `muted`, jamais en or.
    final contour = tester.widget<Icon>(find.byIcon(Icons.star_border));
    expect(contour.color, JetonsAuth.muted);
    expect(contour.color, isNot(JetonsAuth.gold));
    final texteSuivre = tester.widget<Text>(find.text('Suivre'));
    expect(texteSuivre.style?.color, JetonsAuth.muted);
    final taille = tester.getSize(_etoile);
    expect(taille.width, greaterThanOrEqualTo(48));
    expect(taille.height, greaterThanOrEqualTo(48));

    await tester.tap(_etoile);
    await tester.pump();

    expect(find.text('Suivie'), findsOneWidget);
    final icone = tester.widget<Icon>(find.byIcon(Icons.star));
    expect(icone.color, JetonsAuth.text);
    expect(icone.color, isNot(JetonsAuth.gold));
    expect(tester.getSemantics(_etoile), isSemantics(value: '', isToggled: true));
    final texteSuivie = tester.widget<Text>(find.text('Suivie'));
    expect(texteSuivie.style?.color, JetonsAuth.text);
    expect(texteSuivie.style?.color, isNot(JetonsAuth.gold));
    await container.read(coursesSuiviesProvider.notifier).ecrituresTerminees();
    expect(store.lignes['20261123-R1-C4']?.suivie, isTrue);
    expect(store.lignes['20261123-R1-C4']?.synchronise, isFalse);
    // `course_suivie.date` est la date de la clé.
    expect(store.lignes['20261123-R1-C4']?.dateIso.replaceAll('-', ''), '20261123');

    await _pump(tester, container, const HomeScreen());
    expect(_section, findsOneWidget);
    expect(find.text('Courses suivies'), findsOneWidget);
    expect(find.text('R1 C4 · VINCENNES'), findsOneWidget);
    expect(find.descendant(of: _section, matching: find.text(_heureLocale(course))), findsOneWidget);
    // Ligne : libellé parlé « 14 heures 05, R1 C4, VINCENNES ».
    expect(
      tester.getSemantics(find.bySemanticsLabel('${h.hour} heures ${h.minute.toString().padLeft(2, '0')}, R1 C4, VINCENNES')),
      isSemantics(isButton: true, hasTapAction: true),
    );
  });

  testWidgets('Ne plus suivre depuis la course : « Suivre », ligne retirée de l\'Accueil', (tester) async {
    final course = _course();
    final store = _StoreMemoire()..lignes[course.cleCourse!] = _suivie(course);
    final container = await _conteneur(store: store, programme: [course]);
    _ouvrir(container, course);
    await _pump(tester, container, const ResultsScreen());

    expect(find.text('Suivie'), findsOneWidget);
    await tester.tap(_etoile);
    await tester.pump();
    expect(find.text('Suivre'), findsOneWidget);
    await container.read(coursesSuiviesProvider.notifier).ecrituresTerminees();
    // La ligne reste en cache, `suivie = 0` (la synchronisation en aura besoin).
    expect(store.lignes[course.cleCourse!]?.suivie, isFalse);

    await _pump(tester, container, const HomeScreen());
    expect(_section, findsNothing);
    expect(find.text('Courses suivies'), findsNothing);
  });

  testWidgets("Ne plus suivre depuis l'Accueil : la ligne disparaît, la section se masque", (tester) async {
    final c1 = _course(id: 1, numero: 2);
    final c2 = _course(id: 2, numero: 5);
    final store = _StoreMemoire()
      ..lignes[c1.cleCourse!] = _suivie(c1)
      ..lignes[c2.cleCourse!] = _suivie(c2);
    final container = await _conteneur(store: store, programme: [c1, c2]);
    await _pump(tester, container, const HomeScreen());

    expect(find.text('R1 C2 · VINCENNES'), findsOneWidget);
    expect(find.text('R1 C5 · VINCENNES'), findsOneWidget);

    Finder etoileDe(String cle) =>
        find.descendant(of: find.byKey(ValueKey('suivie-$cle')), matching: find.byIcon(Icons.star));
    await tester.tap(etoileDe(c1.cleCourse!));
    await tester.pump();
    expect(find.text('R1 C2 · VINCENNES'), findsNothing);
    expect(_section, findsOneWidget);

    await tester.tap(etoileDe(c2.cleCourse!));
    await tester.pump();
    expect(_section, findsNothing);
    await container.read(coursesSuiviesProvider.notifier).ecrituresTerminees();
    expect(store.lignes.values.every((l) => !l.suivie), isTrue);
  });

  testWidgets('Course saisie à la main ou importée par photo : pas d\'étoile', (tester) async {
    final container = await _conteneur();
    // Saisie manuelle : aucune course courante.
    await _pump(tester, container, const HorseListScreen());
    expect(_etoile, findsNothing);
    expect(find.text('Suivre'), findsNothing);

    // Course du programme puis import photo : le contexte est remis à zéro.
    final course = _course();
    _ouvrir(container, course);
    await tester.pump();
    expect(_etoile, findsOneWidget);
    container.read(horsesProvider.notifier).setAll([Horse(nom: 'IMPORT PHOTO')]);
    await tester.pump();
    expect(_etoile, findsNothing);

    // Course sans clé PMU.
    final sansCle = _course(id: 3, pmu: false);
    _ouvrir(container, sansCle);
    await tester.pump();
    expect(_etoile, findsNothing);
  });

  testWidgets('Ouvrir depuis la section : même chemin qu\'une ligne du programme', (tester) async {
    final course = _course(id: 42, date: DateTime(2026, 11, 24));
    final repo = _FauxRepo([course]);
    final store = _StoreMemoire()..lignes[course.cleCourse!] = _suivie(course);
    final container = await _conteneur(store: store, repo: repo);
    await _pump(tester, container, const HomeScreen());

    await tester.tap(find.text('R1 C4 · VINCENNES'));
    await tester.pumpAndSettle();

    expect(repo.partantsDemandes, [42]);
    expect(find.byType(RaceConfigScreen), findsOneWidget);
    expect(container.read(pronosticContextProvider).courseId, 42);
    expect(container.read(courseCouranteProvider)?.cleCourse, course.cleCourse);
  });

  testWidgets('Ouvrir depuis la section, course absente du programme : snackbar', (tester) async {
    final course = _course();
    final store = _StoreMemoire()..lignes[course.cleCourse!] = _suivie(course);
    final container = await _conteneur(store: store, programme: const []);
    await _pump(tester, container, const HomeScreen());

    await tester.tap(find.text('R1 C4 · VINCENNES'));
    await tester.pumpAndSettle();

    expect(find.text('Course introuvable dans le programme'), findsOneWidget);
    expect(find.byType(RaceConfigScreen), findsNothing);
  });

  testWidgets('Le lendemain : une course suivie hier sort de la section', (tester) async {
    final hier = _course(date: DateTime(2026, 11, 22));
    final store = _StoreMemoire()..lignes[hier.cleCourse!] = _suivie(hier);
    final container = await _conteneur(store: store);
    await _pump(tester, container, const HomeScreen());

    expect(_section, findsNothing);
    expect(container.read(coursesSuiviesProvider)[hier.cleCourse!]?.suivie, isTrue);
  });

  testWidgets('Section triée par heure de départ', (tester) async {
    final tard = _course(id: 1, numero: 7).copieAvecHeure(DateTime.utc(2026, 11, 23, 17));
    final tot = _course(id: 2, numero: 1).copieAvecHeure(DateTime.utc(2026, 11, 23, 12));
    final store = _StoreMemoire()
      ..lignes[tard.cleCourse!] = _suivie(tard)
      ..lignes[tot.cleCourse!] = _suivie(tot);
    final container = await _conteneur(store: store);
    await _pump(tester, container, const HomeScreen());

    final yTot = tester.getTopLeft(find.text('R1 C1 · VINCENNES')).dy;
    final yTard = tester.getTopLeft(find.text('R1 C7 · VINCENNES')).dy;
    expect(yTot, lessThan(yTard));
  });

  testWidgets('Ancien backend (sans cle_course) : pas d\'étoile, l\'app fonctionne', (tester) async {
    final json = {
      'id': 5,
      'date': '2026-11-23',
      'heure_depart': '2026-11-23T14:05:00Z',
      'hippodrome': 'VINCENNES',
      'discipline': 'ATTELE',
      'finalisee': false,
      'source': 'pmu',
    };
    final course = CourseSummary.fromJson(json);
    final container = await _conteneur(programme: [course]);
    await _pump(tester, container, const HomeScreen());
    expect(find.text('ATTELE · — m'), findsOneWidget);
    expect(_section, findsNothing);

    _ouvrir(container, course);
    await _pump(tester, container, const HorseListScreen());
    expect(_etoile, findsNothing);
    expect(find.text('FOUDRE NOIRE'), findsOneWidget);
  });

  testWidgets('Web : ni étoile ni section, même avec des courses suivies', (tester) async {
    final course = _course();
    final store = _StoreMemoire()..lignes[course.cleCourse!] = _suivie(course);
    final container = await _conteneur(store: store, web: true, programme: [course]);
    await _pump(tester, container, const HomeScreen());
    expect(_section, findsNothing);
    expect(find.text('Courses suivies'), findsNothing);

    _ouvrir(container, course);
    await _pump(tester, container, const HorseListScreen());
    expect(_etoile, findsNothing);
  });

  testWidgets('Cache indisponible : l\'étoile reste utilisable pendant la session, sans plantage', (tester) async {
    final course = _course();
    final container = await _conteneur(store: _StoreEnPanne(), programme: [course]);
    _ouvrir(container, course);
    await _pump(tester, container, const HorseListScreen());

    await tester.tap(_etoile);
    await tester.pump();
    await container.read(coursesSuiviesProvider.notifier).ecrituresTerminees();
    expect(find.text('Suivie'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pump(tester, container, const HomeScreen());
    expect(find.text('R1 C4 · VINCENNES'), findsOneWidget);
  });

  testWidgets('Double tap : deux bascules, état final cohérent avec le cache', (tester) async {
    final store = _StoreMemoire();
    final course = _course();
    final container = await _conteneur(store: store, programme: [course]);
    _ouvrir(container, course);
    await _pump(tester, container, const HorseListScreen());

    await tester.tap(_etoile);
    await tester.tap(_etoile);
    await tester.pump();
    await container.read(coursesSuiviesProvider.notifier).ecrituresTerminees();
    expect(find.text('Suivre'), findsOneWidget);
    expect(store.lignes[course.cleCourse!]?.suivie, isFalse);
  });

  testWidgets("Course du programme puis saisie manuelle : pas d'étoile sur Partants ni Résultats", (tester) async {
    final course = _course();
    final container = await _conteneur(programme: [course]);
    _ouvrir(container, course);
    await _pump(tester, container, const HomeScreen());

    await tester.tap(find.text('Saisie manuelle'));
    await tester.pumpAndSettle();
    expect(find.byType(RaceConfigScreen), findsOneWidget);
    expect(container.read(courseCouranteProvider), isNull);

    await _pump(tester, container, const HorseListScreen());
    expect(_etoile, findsNothing);
    await _pump(tester, container, const ResultsScreen());
    expect(_etoile, findsNothing);
  });

  testWidgets('Ouvrir depuis la section : absente du cache, trouvée après rafraîchissement', (tester) async {
    final course = _course(id: 77, date: DateTime(2026, 11, 24));
    final repo = _FauxRepo(const [], reseau: [course]);
    final store = _StoreMemoire()..lignes[course.cleCourse!] = _suivie(course);
    final container = await _conteneur(store: store, repo: repo);
    await _pump(tester, container, const HomeScreen());

    await tester.tap(find.text('R1 C4 · VINCENNES'));
    await tester.pumpAndSettle();

    expect(repo.rafraichissements, [DateTime(2026, 11, 24)]);
    expect(repo.partantsDemandes, [77]);
    expect(find.byType(RaceConfigScreen), findsOneWidget);
  });

  testWidgets("Ouvrir depuis la section, programme en échec : snackbar d'erreur, puis nouvel essai possible",
      (tester) async {
    final jour = DateTime(2026, 11, 24);
    final course = _course(id: 78, date: jour);
    final repo = _FauxRepo(const [], reseau: null)..joursEnEchec.add(jour);
    final store = _StoreMemoire()..lignes[course.cleCourse!] = _suivie(course);
    final container = await _conteneur(store: store, repo: repo);
    await _pump(tester, container, const HomeScreen());

    await tester.tap(find.text('R1 C4 · VINCENNES'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Échec du chargement du programme'), findsOneWidget);
    expect(find.byType(RaceConfigScreen), findsNothing);

    // Le réseau revient : l'échec n'est pas resté en cache.
    repo.joursEnEchec.clear();
    repo.reseau = [course];
    ScaffoldMessenger.of(tester.element(find.byType(HomeScreen))).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(find.text('R1 C4 · VINCENNES'));
    await tester.pumpAndSettle();
    expect(repo.partantsDemandes, [78]);
    expect(find.byType(RaceConfigScreen), findsOneWidget);
  });

  testWidgets('Programme chargé : instantané (heure, hippodrome) remis à jour, état de suivi conservé',
      (tester) async {
    final ancienne = _course();
    final suivie = _suivie(ancienne);
    final store = _StoreMemoire()..lignes[ancienne.cleCourse!] = suivie;
    final nouvelle = CourseSummary(
      id: ancienne.id,
      date: ancienne.date,
      heureDepart: DateTime.utc(2026, 11, 23, 15, 20),
      hippodrome: 'PARIS-VINCENNES',
      discipline: 'ATTELE',
      finalisee: false,
      source: 'pmu',
      numeroReunion: 1,
      numeroCourse: 4,
      cleCourse: ancienne.cleCourse,
    );
    final container = await _conteneur(store: store, programme: [nouvelle]);
    await _pump(tester, container, const HomeScreen());
    await container.read(coursesSuiviesProvider.notifier).ecrituresTerminees();

    final ligne = store.lignes[ancienne.cleCourse!]!;
    expect(ligne.hippodrome, 'PARIS-VINCENNES');
    expect(ligne.heureDepart, DateTime.utc(2026, 11, 23, 15, 20));
    expect(ligne.suivie, isTrue);
    expect(ligne.modifieeLe, suivie.modifieeLe);
    expect(ligne.synchronise, suivie.synchronise);
    expect(find.text('R1 C4 · PARIS-VINCENNES'), findsOneWidget);
  });

  testWidgets('Course ouverte : instantané remis à jour', (tester) async {
    final jour = DateTime(2026, 11, 24);
    final ancienne = _course(id: 5, date: jour);
    final suivie = _suivie(ancienne);
    final store = _StoreMemoire()..lignes[ancienne.cleCourse!] = suivie;
    final ouverte = ancienne.copieAvecHeure(DateTime.utc(2026, 11, 24, 18));
    final container = await _conteneur(store: store, repo: _FauxRepo([ouverte]));
    await _pump(tester, container, const HomeScreen());

    await tester.tap(find.text('R1 C4 · VINCENNES'));
    await tester.pumpAndSettle();
    await container.read(coursesSuiviesProvider.notifier).ecrituresTerminees();

    final ligne = store.lignes[ancienne.cleCourse!]!;
    expect(ligne.heureDepart, DateTime.utc(2026, 11, 24, 18));
    expect(ligne.modifieeLe, suivie.modifieeLe);
    expect(ligne.suivie, isTrue);
  });

  testWidgets('Minuit : à 23:59 les deux courses, à 00:01 seule la course après minuit reste', (tester) async {
    var maintenant = DateTime(2026, 11, 23, 23, 59);
    final soir = _course(id: 1, numero: 6).copieAvecHeure(DateTime(2026, 11, 23, 20).toUtc());
    final nuit = _course(id: 2, numero: 9).copieAvecHeure(DateTime(2026, 11, 24, 0, 30).toUtc());
    final store = _StoreMemoire()
      ..lignes[soir.cleCourse!] = _suivie(soir)
      ..lignes[nuit.cleCourse!] = _suivie(nuit);
    final container = await _conteneur(store: store, horloge: () => maintenant);
    await _pump(tester, container, const HomeScreen());
    expect(find.text('R1 C6 · VINCENNES'), findsOneWidget);
    expect(find.text('R1 C9 · VINCENNES'), findsOneWidget);

    maintenant = DateTime(2026, 11, 24, 0, 1);
    await tester.pump(const Duration(minutes: 2)); // minuterie de minuit
    expect(find.text('R1 C6 · VINCENNES'), findsNothing);
    expect(find.text('R1 C9 · VINCENNES'), findsOneWidget);

    // Retour au premier plan après le départ : la course de nuit sort aussi.
    maintenant = DateTime(2026, 11, 24, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_section, findsNothing);
  });

  testWidgets("Étoile inactive tant que le cache n'est pas lu ; la ligne stockée n'est pas écrasée", (tester) async {
    final course = _course();
    final stockee = _suivie(course);
    final store = _StoreLent()..lignes[course.cleCourse!] = stockee;
    final container = await _conteneur(store: store, programme: [course]);
    _ouvrir(container, course);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HorseListScreen()),
    ));
    await tester.pump();

    expect(tester.getSemantics(_etoile), isSemantics(isEnabled: false, hasEnabledState: true));
    await tester.tap(_etoile);
    await tester.pump();
    expect(find.text('Suivre'), findsOneWidget);
    expect(store.ecritures, 0);

    store.lecture.complete();
    await tester.pumpAndSettle();
    expect(find.text('Suivie'), findsOneWidget);
    expect(store.lignes[course.cleCourse!]!.modifieeLe, stockee.modifieeLe);
    expect(tester.getSemantics(_etoile), isSemantics(isEnabled: true));
  });

  test('Vocabulaire : jamais « Favoris », « Mes paris », « Courses jouées » dans l\'app', () {
    // Dans les chaînes affichables uniquement (« ordreFavoris » est un nom de
    // variable du moteur, pas un libellé).
    final interdit = RegExp('''['"][^'"\\n]*(favoris|mes paris|courses jouées)''', caseSensitive: false);
    final fichiers = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final f in fichiers) {
      final trouve = interdit.firstMatch(f.readAsStringSync());
      expect(trouve, isNull, reason: '« ${trouve?.group(1)} » dans ${f.path}');
    }
    final widget = File('lib/widgets/followed_race.dart').readAsStringSync();
    expect(widget, contains("'Suivre la course'"));
    expect(File('lib/screens/home_screen.dart').readAsStringSync(), contains("'Courses suivies'"));
  });
}

extension on CourseSummary {
  CourseSummary copieAvecHeure(DateTime heure) => CourseSummary(
        id: id,
        date: date,
        heureDepart: heure,
        hippodrome: hippodrome,
        discipline: discipline,
        distance: distance,
        nbPartants: nbPartants,
        finalisee: finalisee,
        source: source,
        numeroReunion: numeroReunion,
        numeroCourse: numeroCourse,
        cleCourse: cleCourse,
      );
}
