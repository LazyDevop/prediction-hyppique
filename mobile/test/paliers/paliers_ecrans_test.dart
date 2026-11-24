// Story 9.8 — verrous par palier sur la VRAIE application, téléphone et
// web large : chaque point d'entrée, achat, fin du droit, changement de compte.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prediction_hippique/data/acces_paliers.dart';
import 'package:prediction_hippique/data/local/courses_suivies_store.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/api_client.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/data/remote/offres_api.dart';
import 'package:prediction_hippique/main.dart';
import 'package:prediction_hippique/models/course_suivie.dart';
import 'package:prediction_hippique/models/course_summary.dart';
import 'package:prediction_hippique/models/engine_params.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/models/programme_extrait.dart';
import 'package:prediction_hippique/providers/api_provider.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/providers/courses_suivies_provider.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/palier_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/pronostic_provider.dart';
import 'package:prediction_hippique/providers/race_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';
import 'package:prediction_hippique/repository/course_repository.dart';
import 'package:prediction_hippique/screens/horse_edit_screen.dart';
import 'package:prediction_hippique/screens/horse_list_screen.dart';
import 'package:prediction_hippique/screens/import_photo_screen.dart';
import 'package:prediction_hippique/screens/offres_screen.dart';
import 'package:prediction_hippique/screens/race_config_screen.dart';
import 'package:prediction_hippique/screens/results_screen.dart';
import 'package:prediction_hippique/screens/settings_screen.dart';
import 'package:prediction_hippique/screens/web_shell.dart';
import 'package:prediction_hippique/widgets/auth_styles.dart';
import 'package:prediction_hippique/widgets/combo_block.dart';
import 'package:prediction_hippique/widgets/locked_feature.dart';

import '../auth/auth_test_helpers.dart';
import 'paliers_test_helpers.dart';

part 'paliers_revue.part.dart';

class _Store implements CoursesSuiviesStore {
  final lignes = <CourseSuivie>[];
  @override
  Future<List<CourseSuivie>> lireCoursesSuivies() async => lignes;
  @override
  Future<void> enregistrerCourseSuivie(CourseSuivie course) async {}
}

class _Repo extends CourseRepository {
  final List<CourseSummary> programme;
  _Repo(this.programme) : super(ApiClient());

  @override
  Future<ProgrammeResult> programmeDuJour(DateTime date) async =>
      ProgrammeResult(courses: programme, fromCache: true);

  @override
  Future<List<Horse>> partants(int courseId) async => [
    for (var i = 1; i <= 5; i++) Horse(nom: 'CHEVAL $i', numPmu: i, age: 5, cote: 3.0 + i),
  ];
}

class _Pronostics implements PronosticsApi {
  final envoyes = <Map<String, Object?>>[];
  @override
  Future<void> envoyerPronostic(Map<String, Object?> pronostic) async => envoyes.add(pronostic);
}

class _Compte extends FauxCompteApi {
  bool enPanne = false;

  /// Retient la réponse (calculée après l'attente).
  Completer<void>? attente;

  /// Compte lu par chaque lecture (nul : aucun compte ouvert).
  final cles = <String?>[];
  _Compte({super.horloge, super.web, super.palier, super.finDroit});
  @override
  Future<ProfilCompte> lireProfil() async {
    cles.add(cleCompteCourant);
    await attente?.future;
    if (enPanne) throw Exception('réseau');
    return super.lireProfil();
  }
}

final _course = CourseSummary(
  id: 9,
  date: DateTime(2026, 11, 17),
  heureDepart: DateTime(2026, 11, 17, 14, 5),
  hippodrome: 'VINCENNES',
  discipline: 'ATTELE',
  distance: 2700,
  nbPartants: 5,
  finalisee: false,
  source: 'pmu',
  numeroReunion: 1,
  numeroCourse: 4,
  cleCourse: '20261117-R1-C4',
);

class _Env {
  final Horloge horloge;
  final _Compte compte;
  final _Pronostics pronostics;
  final ProviderContainer c;
  _Env(this.horloge, this.compte, this.pronostics, this.c);
}

Future<void> _attendre(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _attendre(tester);
}

Future<_Env> _app(
  WidgetTester tester, {
  bool large = false,
  bool telephone = false,
  String masque = masqueGratuit,
  String? palier,
  Duration? droit,
  bool enPanne = false,
  bool suivie = false,
  bool demo = true,
  SessionStore? store,
}) async {
  tester.view.physicalSize = large ? const Size(1400, 1000) : const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final horloge = Horloge();
  final web = !telephone;
  final compte = _Compte(
    horloge: horloge.call,
    web: web,
    palier: palier,
    finDroit: droit == null ? null : horloge().toUtc().add(droit),
  )..enPanne = enPanne;
  final pronostics = _Pronostics();
  final suivies = _Store();
  if (suivie) suivies.lignes.add(CourseSuivie.depuisCourse(_course, suivie: true, maintenant: horloge())!);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overridesAuth(
          store: store ?? await storeAvecSession(pin: telephone ? '4821' : null, numeroMasque: masque),
          compte: compte,
          web: web,
          horloge: horloge,
        ),
        courseRepositoryProvider.overrideWithValue(_Repo([_course])),
        coursesSuiviesStoreProvider.overrideWithValue(suivies),
        if (!demo) demoAutoriseeProvider.overrideWithValue(false),
        pronosticsApiProvider.overrideWithValue(pronostics),
      ],
      child: const PredictionHippiqueApp(),
    ),
  );
  await _attendre(tester);
  if (telephone) {
    for (final t in '4821'.split('')) {
      await tester.tap(find.text(t));
      await tester.pump();
    }
    await _attendre(tester);
  }
  return _Env(
    horloge,
    compte,
    pronostics,
    ProviderScope.containerOf(tester.element(find.byType(PredictionHippiqueApp))),
  );
}

Finder _verrou(Fonction f) => find.byWidgetPredicate((w) => w is LockedFeature && w.fonction == f);
final _ligneCourse = find.byKey(const ValueKey('course-9'));
final _cta = find.text('VOIR LE PRONOSTIC DU MATIN');

Finder _offresDe(Fonction f) => find.descendant(of: _verrou(f), matching: find.text('Voir les offres'));

/// Verrou [f] → [offre] → Paiement confirmé → retour à l'écran d'origine.
Future<void> _acheter(WidgetTester tester, _Env env, Fonction f, String offre) async {
  await _toucher(tester, _offresDe(f));
  await _toucher(tester, find.text(offre));
  await _toucher(tester, find.text('CONTINUER VERS LE PAIEMENT'));
  await _toucher(tester, find.text('MTN MoMo'));
  await tester.enterText(find.byType(TextField).last, '677000000');
  await tester.pump();
  await _toucher(tester, find.text('PAYER'));
  env.horloge.avancer(const Duration(seconds: 5));
  await tester.pump(const Duration(seconds: 2));
  await _attendre(tester);
  await _toucher(tester, find.text("REVENIR À L'ÉCRAN PRÉCÉDENT"));
}

Future<void> _defiler(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find.descendant(of: find.byType(ResultsScreen), matching: find.byType(Scrollable)).first,
  );
  await tester.pump();
}

Future<void> _retour(WidgetTester tester, Type ecran) =>
    _toucher(tester, find.descendant(of: find.byType(ecran), matching: find.byType(BackButton)));

void main() {
  for (final large in [false, true]) {
    group(large ? 'web large' : 'une colonne', () {
      testWidgets('Expert : aucun verrou, parcours actuel', (tester) async {
        final env = await _app(tester, large: large, masque: masqueExpert);
        expect(find.byType(WebShell), large ? findsOneWidget : findsNothing);
        await _toucher(tester, _ligneCourse);
        expect(find.byType(RaceConfigScreen), findsOneWidget);
        await _toucher(tester, find.text('Voir les partants'));
        expect(find.byTooltip('Configuration course'), findsNothing);
        await _toucher(tester, find.text('Calculer'));
        expect(find.byType(ComboBlock), findsWidgets);
        expect(find.byType(LockedFeature, skipOffstage: false), findsNothing);
        expect(env.pronostics.envoyes.single['combinaisons'], isNotNull);
      });

      testWidgets('Gratuit : course → partants en lecture seule → Résultats verrouillés', (tester) async {
        final env = await _app(tester, large: large);
        await _toucher(tester, _ligneCourse);
        expect(find.byType(HorseListScreen), findsOneWidget);
        expect(find.byType(RaceConfigScreen), findsNothing);
        expect(find.text('CHEVAL 1'), findsOneWidget);
        expect(find.text('Calculer'), findsNothing);
        expect(find.text('Cheval'), findsNothing);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
        await _toucher(tester, find.text('CHEVAL 1'));
        expect(find.byType(HorseEditScreen), findsNothing);
        expect(_verrou(Fonction.modifierPartants), findsOneWidget);

        await _toucher(tester, _cta);
        expect(find.text('Pronostic du matin indisponible'), findsOneWidget);
        expect(_verrou(Fonction.valueEtMise), findsOneWidget);
        expect(_verrou(Fonction.combinaisons), findsOneWidget);
        expect(find.byType(ComboBlock), findsNothing);
        expect(find.text('CLASSEMENT'), findsNothing);
        expect(env.c.read(resultsProvider), isNull);
        expect(env.pronostics.envoyes, isEmpty);
      });

      testWidgets('Gratuit : saisie manuelle et import ouvrent une page à un verrou', (tester) async {
        await _app(tester, large: large);
        await _toucher(tester, find.text('Saisie manuelle').first);
        expect(_verrou(Fonction.saisieManuelle), findsOneWidget);
        expect(find.byType(LockedFeature), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        if (!large) await _toucher(tester, find.byType(BackButton));
        await _toucher(tester, find.byTooltip('Importer un programme par photo/PDF'));
        expect(find.byType(ImportPhotoScreen), findsOneWidget);
        expect(_verrou(Fonction.importPhoto), findsOneWidget);
        expect(find.byType(LockedFeature), findsOneWidget);
        expect(find.text('Galerie'), findsNothing);
      });

      testWidgets('achat Pass semaine Turfiste depuis Résultats : value et mise sans redémarrage', (tester) async {
        final env = await _app(tester, large: large);
        await _toucher(tester, _ligneCourse);
        await _toucher(tester, _cta);
        await _acheter(tester, env, Fonction.valueEtMise, 'Pass semaine Turfiste');

        expect(find.byType(ResultsScreen), findsOneWidget);
        expect(find.text('Pronostic du matin indisponible'), findsNothing);
        expect(_verrou(Fonction.valueEtMise), findsNothing);
        expect(_verrou(Fonction.combinaisons), findsOneWidget);
        expect(find.byType(ComboBlock), findsNothing);
        await _defiler(tester, find.text('Cote : 4.0'));
        expect(find.textContaining(' %'), findsWidgets);
        expect(env.c.read(resultsProvider)!.combinaisons, isNull);
        expect(env.pronostics.envoyes, isEmpty, reason: 'aucune action Calculer');

        // Retour aux partants : éditables, configuration accessible.
        await _retour(tester, ResultsScreen);
        expect(find.text('Calculer'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsWidgets);
        await _toucher(tester, find.byTooltip('Configuration course'));
        expect(find.byType(RaceConfigScreen), findsOneWidget);
        await _toucher(tester, find.text('Voir les partants'));
        expect(find.byType(RaceConfigScreen), findsNothing);
        expect(find.byType(HorseListScreen), findsOneWidget);
      });

      testWidgets('achat Expert depuis le verrou Combinaisons : combinaisons affichées', (tester) async {
        final env = await _app(tester, large: large, palier: palierTurfiste, droit: const Duration(days: 7));
        await _toucher(tester, _ligneCourse);
        await _toucher(tester, find.text('Voir les partants'));
        await _toucher(tester, find.text('Calculer'));
        await _acheter(tester, env, Fonction.combinaisons, 'Pass journée Expert');
        expect(find.byType(LockedFeature), findsNothing);
        expect(find.byType(ComboBlock), findsWidgets);
      });

      testWidgets('fin du droit, écrans déjà ouverts : les verrous reviennent', (tester) async {
        final env = await _app(tester, large: large, palier: palierExpert, droit: const Duration(hours: 1));
        await _toucher(tester, _ligneCourse);
        await _toucher(tester, find.text('Voir les partants'));
        await _toucher(tester, find.text('Calculer'));
        expect(find.byType(ComboBlock), findsWidgets);

        env.horloge.avancer(const Duration(hours: 1));
        await tester.pump(const Duration(hours: 1));
        await _attendre(tester);
        expect(find.byType(ComboBlock), findsNothing);
        expect(find.text('Pronostic du matin indisponible'), findsOneWidget);
        expect(env.c.read(resultsProvider), isNull);
        await _retour(tester, ResultsScreen);
        expect(find.text('Calculer'), findsNothing);
        expect(_cta, findsOneWidget);
        // Jusqu'à la racine : Configuration verrouillée, pas de second écran
        // de partants.
        await _retour(tester, HorseListScreen);
        expect(find.byType(RaceConfigScreen), findsOneWidget);
        expect(_verrou(Fonction.configuration), findsOneWidget);
        expect(find.byType(HorseListScreen, skipOffstage: false), findsNothing);
        await _retour(tester, RaceConfigScreen);
        expect(find.byType(RaceConfigScreen, skipOffstage: false), findsNothing);
        expect(_ligneCourse, findsOneWidget);
      });

      testWidgets('lecture du palier en échec : Gratuit + Réessayer, puis le contenu', (tester) async {
        final env = await _app(tester, large: large, palier: palierTurfiste, enPanne: true);
        await _toucher(tester, _ligneCourse);
        expect(find.text(messagePalierNonVerifie), findsOneWidget);
        expect(_cta, findsOneWidget);
        env.compte.enPanne = false;
        await _toucher(tester, find.text('Réessayer'));
        expect(find.text(messagePalierNonVerifie), findsNothing);
        expect(find.text('Calculer'), findsOneWidget);
      });

      testWidgets('changement de compte : rien du compte Expert', (tester) async {
        final env = await _app(tester, large: large, masque: masqueExpert);
        await _toucher(tester, _ligneCourse);
        await _toucher(tester, find.text('Voir les partants'));
        await _toucher(tester, find.text('Calculer'));
        expect(env.c.read(resultsProvider), isNotNull);
        final auth = env.c.read(authProvider.notifier);
        await auth.seDeconnecter();
        await _attendre(tester);
        expect(env.c.read(resultsProvider), isNull);
        expect(env.c.read(horsesProvider), isEmpty);
        await auth.demanderCode('+237677000000');
        await auth.verifierCode('+237677000000', '123456');
        await _attendre(tester);
        expect(find.byType(ResultsScreen), findsNothing);
        await _toucher(tester, _ligneCourse);
        expect(_cta, findsOneWidget);
      });
    });
  }

  testWidgets('téléphone, Gratuit : une course suivie ouvre les partants en lecture seule', (tester) async {
    await _app(tester, telephone: true, suivie: true);
    await _toucher(tester, find.byKey(const ValueKey('suivie-20261117-R1-C4')));
    expect(find.byType(HorseListScreen), findsOneWidget);
    expect(_cta, findsOneWidget);
    expect(find.byKey(const Key('etoile-suivi-course')), findsOneWidget, reason: 'suivre reste Gratuit');
  });

  void arrierePlan(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }

  void premierPlan(WidgetTester tester) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  testWidgets('téléphone : re-verrouillage passé la fin du droit, retour → verrous', (tester) async {
    final env = await _app(tester, telephone: true, palier: palierExpert, droit: const Duration(hours: 1));
    await _toucher(tester, _ligneCourse);
    await _toucher(tester, find.text('Voir les partants'));
    await _toucher(tester, find.text('Calculer'));
    arrierePlan(tester);
    env.horloge.avancer(const Duration(hours: 2));
    premierPlan(tester);
    await _attendre(tester);
    for (final t in '4821'.split('')) {
      await tester.tap(find.text(t));
      await tester.pump();
    }
    await _attendre(tester);
    expect(find.text('Pronostic du matin indisponible'), findsOneWidget);
    expect(find.byType(ComboBlock), findsNothing);
  });

  testWidgets('retour au premier plan : palier relu (droit accordé ailleurs)', (tester) async {
    final env = await _app(tester);
    await _toucher(tester, _ligneCourse);
    env.compte.activerPass(masqueGratuit, palier: palierTurfiste, finDroit: env.horloge().add(const Duration(days: 1)));
    arrierePlan(tester);
    premierPlan(tester);
    await _attendre(tester);
    expect(find.text('Calculer'), findsOneWidget);
  });

  testWidgets('Profil : « Droit Turfiste terminé le … » à la fin du droit, écran ouvert', (tester) async {
    final env = await _app(tester, palier: palierTurfiste, droit: const Duration(days: 5));
    await _toucher(tester, find.byTooltip('Profil'));
    expect(find.text('TURFISTE'), findsOneWidget);
    env.horloge.avancer(const Duration(days: 5));
    await tester.pump(const Duration(days: 5));
    await _attendre(tester);
    expect(find.text('Droit Turfiste terminé le 22/11'), findsOneWidget);
    expect(find.text('GRATUIT'), findsOneWidget);
    await _toucher(tester, find.text('Droit Turfiste terminé le 22/11'));
    expect(find.byType(OffresScreen), findsOneWidget);
  });

  _testsRevue();

  group('écran isolé', () {
    late PalierFixe palier;
    late ProviderContainer c;

    Future<void> pump(WidgetTester tester, Widget ecran, String? p) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      palier = PalierFixe(p);
      c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          palierProvider.overrideWith(() => palier),
          ...overridesAuth(store: await storeAvecSession(), web: true),
        ],
      );
      addTearDown(c.dispose);
      c.read(horsesProvider.notifier).setAll([Horse(nom: 'CHEVAL 1')]);
      await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: ecran)));
      await tester.pump();
    }

    for (final (nom, ecran) in <(String, Widget)>[
      ('Configuration', const RaceConfigScreen()),
      ('Partants', const HorseListScreen()),
      ('Fiche cheval', const HorseEditScreen(index: 0)),
      ('Import', const ImportPhotoScreen()),
      ('Résultats', const ResultsScreen()),
      ('Réglages', const SettingsScreen()),
    ]) {
      testWidgets('$nom en chargement : ni contenu ni verrou', (tester) async {
        await pump(tester, ecran, null);
        expect(find.byType(LockedFeature), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(_cta, findsNothing);
        expect(find.text(messagePronosticIndisponible), findsNothing);
      });
    }

    testWidgets('Fiche cheval déjà ouverte, palier tombé : verrou, puis saisie conservée', (tester) async {
      await pump(tester, const HorseEditScreen(index: 0), palierTurfiste);
      await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'NOUVEAU NOM');
      palier.passerA(palierGratuit);
      await tester.pump();
      expect(_verrou(Fonction.ficheCheval), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
      palier.passerA(palierTurfiste);
      await tester.pump();
      expect(find.text('NOUVEAU NOM'), findsOneWidget);
    });

    testWidgets('Réglages : Gratuit deux verrous, Turfiste bankroll et Kelly, Expert tout', (tester) async {
      await pump(tester, const SettingsScreen(), palierGratuit);
      expect(_verrou(Fonction.bankrollEtKelly), findsOneWidget);
      expect(_verrou(Fonction.coefficientsMoteur), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.restore), findsNothing);
      palier.passerA(palierTurfiste);
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Bankroll (unités)'), findsOneWidget);
      expect(find.text('Fraction de Kelly'), findsOneWidget);
      expect(_verrou(Fonction.coefficientsMoteur), findsOneWidget);
      expect(find.byType(LockedFeature), findsOneWidget);
      palier.passerA(palierExpert);
      await tester.pump();
      expect(find.byType(LockedFeature), findsNothing);
      expect(find.text('Pondération récence'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(8));
    });

    testWidgets('Réglages Turfiste : réinitialiser garde les coefficients enregistrés', (tester) async {
      await pump(tester, const SettingsScreen(), palierTurfiste);
      c.read(engineParamsProvider.notifier).update(const EngineParams(contraste: 9, bankroll: 500));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.restore));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réinitialiser'));
      await tester.pumpAndSettle();
      expect(c.read(engineParamsProvider).bankroll, 100);
      expect(c.read(engineParamsProvider).contraste, 9);
    });

    testWidgets("verrou : un nœud TalkBack groupé, jetons DESIGN.md, jamais d'or", (tester) async {
      await pump(tester, const ResultsScreen(), palierTurfiste);
      c.read(resultsProvider.notifier).calculer();
      await tester.pump();
      expect(find.text('Combinaisons — palier Expert'), findsOneWidget);
      expect(
        tester.getSemantics(_verrou(Fonction.combinaisons)),
        isSemantics(label: 'Combinaisons, palier Expert, bouton Voir les offres', hasTapAction: true),
      );
      final panneau = tester.widget<Container>(
        find.descendant(of: _verrou(Fonction.combinaisons), matching: find.byType(Container)).first,
      );
      final d = panneau.decoration! as BoxDecoration;
      expect(d.color, JetonsAuth.surface2);
      expect((d.border! as Border).top.color, JetonsAuth.lineCard);
      expect(d.borderRadius, BorderRadius.circular(12));
      for (final t in tester.widgetList<RichText>(
        find.descendant(of: _verrou(Fonction.combinaisons), matching: find.byType(RichText)),
      )) {
        t.text.visitChildren((s) {
          expect(s.style?.color, isNot(JetonsAuth.gold));
          return true;
        });
      }
    });

    testWidgets('« Voir les offres » : Expert en tête pour Combinaisons, double toucher sans doublon', (tester) async {
      await pump(tester, const ResultsScreen(), palierGratuit);
      await tester.tap(_offresDe(Fonction.combinaisons));
      await tester.tap(_offresDe(Fonction.combinaisons), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(OffresScreen, skipOffstage: false), findsOneWidget);
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Pass journée Expert'), lessThan(y('Offre Duo Expert')));
      expect(y('Offre Duo Expert'), lessThan(y('Offre Duo Turfiste')));
      expect(y('Offre Duo Turfiste'), lessThan(y('Pass semaine Turfiste')));
    });

    testWidgets('« Voir les offres » : Turfiste en tête pour Value et mise', (tester) async {
      await pump(tester, const ResultsScreen(), palierGratuit);
      await tester.tap(_offresDe(Fonction.valueEtMise));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Pass semaine Turfiste')).dy,
        lessThan(tester.getTopLeft(find.text('Pass journée Expert')).dy),
      );
    });

    testWidgets('« VOIR LE PRONOSTIC DU MATIN » : double toucher sans doublon', (tester) async {
      await pump(tester, const HorseListScreen(), palierGratuit);
      c.read(pronosticContextProvider.notifier).courseChargee(9);
      await tester.pump();
      await tester.tap(_cta);
      await tester.tap(_cta, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(ResultsScreen, skipOffstage: false), findsOneWidget);
    });
  });
}
