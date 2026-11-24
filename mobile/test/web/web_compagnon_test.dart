// Story 8.7 (web) — matrice I/O de spec-web-compagnon-8-7.md : porte
// d'appairage par QR code et layout large en deux colonnes, sur la VRAIE
// application (PredictionHippiqueApp), web forcé par `estWebProvider`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prediction_hippique/data/local/courses_suivies_store.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/api_client.dart';
import 'package:prediction_hippique/data/remote/appairage_api.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/main.dart';
import 'package:prediction_hippique/models/course_suivie.dart';
import 'package:prediction_hippique/models/course_summary.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/providers/api_provider.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/providers/courses_suivies_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/repository/course_repository.dart';
import 'package:prediction_hippique/screens/appareil_bloque_screen.dart';
import 'package:prediction_hippique/screens/home_screen.dart';
import 'package:prediction_hippique/screens/import_photo_screen.dart';
import 'package:prediction_hippique/screens/mes_appareils_screen.dart';
import 'package:prediction_hippique/screens/profil_screen.dart';
import 'package:prediction_hippique/screens/settings_screen.dart';
import 'package:prediction_hippique/screens/web_shell.dart';
import 'package:prediction_hippique/widgets/auth_styles.dart';
import 'package:prediction_hippique/widgets/contour_focus.dart';

import '../auth/auth_test_helpers.dart';

part 'web_revue.part.dart';

class _StoreMemoire implements CoursesSuiviesStore {
  @override
  Future<List<CourseSuivie>> lireCoursesSuivies() async => [];

  @override
  Future<void> enregistrerCourseSuivie(CourseSuivie course) async {}
}

class _FauxRepo extends CourseRepository {
  final List<CourseSummary> programme;
  bool partantsEnEchec = false;
  bool programmeEnEchec = false;

  /// Retient le chargement des partants.
  Completer<void>? attente;
  final partantsDemandes = <int>[];
  _FauxRepo(this.programme) : super(ApiClient());

  @override
  Future<ProgrammeResult> programmeDuJour(DateTime date) async {
    if (programmeEnEchec) throw Exception('backend injoignable');
    return ProgrammeResult(courses: programme, fromCache: true);
  }

  @override
  Future<ProgrammeResult> rafraichirProgramme(DateTime date) async =>
      ProgrammeResult(courses: programme, fromCache: false);

  @override
  Future<List<Horse>> partants(int courseId) async {
    partantsDemandes.add(courseId);
    await attente?.future;
    if (partantsEnEchec) throw Exception('backend injoignable');
    return [Horse(nom: 'FOUDRE NOIRE')];
  }
}

/// Création en échec tant que [enPanne].
class _ApiEnPanne extends FauxAppairageApi {
  bool enPanne = true;
  _ApiEnPanne({super.horloge});

  @override
  Future<Appairage> creer() async {
    if (enPanne) throw Exception('réseau');
    return super.creer();
  }
}

CourseSummary _course(int id, int heure) => CourseSummary(
      id: id,
      date: DateTime(2026, 11, 17),
      heureDepart: DateTime(2026, 11, 17, heure, 5),
      hippodrome: 'VINCENNES',
      discipline: 'ATTELE',
      distance: 2700,
      nbPartants: 14,
      finalisee: false,
      source: 'pmu',
    );

class _Env {
  final Horloge horloge;
  final MemorySessionStore store;
  final FauxAppairageApi api;
  final _FauxRepo repo;
  _Env(this.horloge, this.store, this.api, this.repo);
}

const _large = Size(1280, 800);
const _etroit = Size(800, 800);

Future<void> _attendre(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Avance l'horloge murale ET le temps simulé des minuteurs.
Future<void> _avancer(WidgetTester tester, Horloge h, Duration d) async {
  h.avancer(d);
  await tester.pump(d);
  await _attendre(tester);
}

Future<_Env> _pump(
  WidgetTester tester, {
  Size taille = _large,
  bool web = true,
  MemorySessionStore? store,
  FauxAppairageApi? api,
  String numero = FauxAppairageApi.numeroDemo,
  bool programmeEnEchec = false,
}) async {
  tester.view.physicalSize = taille;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final horloge = Horloge();
  final compte = FauxCompteApi(horloge: horloge.call, web: web);
  final appairage = api ?? FauxAppairageApi(horloge: horloge.call, rattachement: compte, numero: numero);
  final s = store ?? MemorySessionStore();
  final repo = _FauxRepo([_course(9, 14), _course(10, 15)])..programmeEnEchec = programmeEnEchec;
  await tester.pumpWidget(ProviderScope(
    // Sans les nouveaux essais de Riverpod, qui retardent l'état d'erreur.
    retry: programmeEnEchec ? (_, _) => null : null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overridesAuth(store: s, compte: compte, web: web, horloge: horloge, appairage: true),
      appairageApiProvider.overrideWithValue(appairage),
      courseRepositoryProvider.overrideWithValue(repo),
      coursesSuiviesStoreProvider.overrideWithValue(_StoreMemoire()),
    ],
    child: const PredictionHippiqueApp(),
  ));
  await _attendre(tester);
  return _Env(horloge, s, appairage, repo);
}

final _qr = find.byKey(const Key('qr-appairage'));
final _shell = find.byType(WebShell);
final _gauche = find.byKey(const Key('colonne-gauche'));
final _droite = find.byKey(const Key('colonne-droite'));

Finder _texte(String t) => find.textContaining(t, findRichText: true);

Future<void> _approuver(WidgetTester tester) async {
  await tester.tap(find.text("Mode démo : simuler l'approbation du téléphone"));
  await _attendre(tester);
}

void main() {
  tearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

  group('porte d\'appairage', () {
    testWidgets('web large, sans session : QR, temps restant écrit et mis à jour, étapes, repli SMS', (tester) async {
      final env = await _pump(tester);
      expect(find.text('Connecter cet ordinateur'), findsOneWidget);
      expect(_qr, findsOneWidget);
      expect(find.text("Scannez avec l'app sur votre téléphone · expire dans 2 min"), findsOneWidget);
      expect(_texte("Ouvrez l'app sur votre téléphone, déjà connectée, puis Profil → Scanner un QR code."), findsOneWidget);
      expect(find.text('Visez ce QR code.'), findsOneWidget);
      expect(_texte('vérifiez le nom « Navigateur web », puis appuyez sur Autoriser.'), findsOneWidget);
      expect(find.text("Le QR code ne sert qu'une fois. Cet ordinateur comptera parmi vos appareils."), findsOneWidget);
      expect(find.text('Afficher un nouveau QR code'), findsOneWidget);
      expect(find.text('Se connecter avec un code SMS'), findsOneWidget);
      expect(
        _texte("La web app nécessite une connexion — pas de mode hors ligne. Elle propose les mêmes fonctions que "
            "l'app du téléphone, aucune de plus."),
        findsOneWidget,
      );
      expect(find.text('ANALYSEUR HIPPIQUE'), findsOneWidget);
      expect(_shell, findsNothing);

      await _avancer(tester, env.horloge, const Duration(seconds: 15));
      expect(find.text("Scannez avec l'app sur votre téléphone · expire dans 1 min 45 s"), findsOneWidget);
    });

    testWidgets('QR : modules `bg` sur zone calme `text`', (tester) async {
      await _pump(tester);
      final zone = tester.widget<Container>(find.ancestor(of: _qr, matching: find.byType(Container)).first);
      expect(zone.color, const Color(0xFFE7E4DA));
    });

    testWidgets('création en échec : message + « Réessayer », puis QR', (tester) async {
      final horloge = Horloge();
      final api = _ApiEnPanne(horloge: horloge.call);
      await _pump(tester, api: api);
      expect(find.text("Impossible d'afficher un QR code — vérifiez votre connexion."), findsOneWidget);
      expect(_qr, findsNothing);
      api.enPanne = false;
      await tester.tap(find.text('Réessayer'));
      await _attendre(tester);
      expect(_qr, findsOneWidget);
    });

    testWidgets('approbation de démo : session ouverte, Accueil en deux colonnes', (tester) async {
      final env = await _pump(tester);
      await _approuver(tester);
      expect(env.store.session, isNotNull);
      expect(env.store.session!.numeroMasque, '+237 6 •• •• •• 56');
      expect(_shell, findsOneWidget);
      expect(find.text('Connecter cet ordinateur'), findsNothing);
    });

    testWidgets('sondage toutes les 2 s : une approbation venue du téléphone ouvre la session', (tester) async {
      final env = await _pump(tester);
      env.api.approuverDemo(env.api.dernierId!);
      await _avancer(tester, env.horloge, const Duration(seconds: 2));
      expect(_shell, findsOneWidget);
    });

    testWidgets('expiration après 2 min : « Code expiré », nouveau QR en un tap', (tester) async {
      final env = await _pump(tester);
      final premier = env.api.dernierId;
      await _avancer(tester, env.horloge, const Duration(minutes: 2));
      expect(find.text('Code expiré'), findsWidgets);
      expect(_qr, findsNothing);
      expect(find.text("Mode démo : simuler l'approbation du téléphone"), findsNothing);

      await tester.tap(find.text('Afficher un nouveau QR code'));
      await _attendre(tester);
      expect(_qr, findsOneWidget);
      expect(env.api.dernierId, isNot(premier));
      expect(find.text("Scannez avec l'app sur votre téléphone · expire dans 2 min"), findsOneWidget);
    });

    testWidgets('refus sur le téléphone : message + nouveau QR', (tester) async {
      final env = await _pump(tester);
      env.api.refuserDemo(env.api.dernierId!);
      await _avancer(tester, env.horloge, const Duration(seconds: 2));
      expect(find.text('Connexion refusée sur le téléphone'), findsWidgets);
      expect(_qr, findsNothing);
      await tester.tap(find.text('Afficher un nouveau QR code'));
      await _attendre(tester);
      expect(_qr, findsOneWidget);
      expect(find.text('Connexion refusée sur le téléphone'), findsNothing);
    });

    testWidgets('repli SMS : Connexion existante, retour au QR possible, puis Accueil large', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Se connecter avec un code SMS'));
      await _attendre(tester);
      expect(find.text('Votre numéro de téléphone'), findsOneWidget);

      await tester.tap(find.text('Se connecter avec un QR code'));
      await _attendre(tester);
      expect(_qr, findsOneWidget);

      await tester.tap(find.text('Se connecter avec un code SMS'));
      await _attendre(tester);
      await tester.enterText(find.byType(TextField), '677123456');
      await tester.tap(find.textContaining("J'accepte"));
      await tester.pump();
      await tester.tap(find.text('RECEVOIR LE CODE PAR SMS'));
      await _attendre(tester);
      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.tap(find.text('VALIDER'));
      await _attendre(tester);
      expect(_shell, findsOneWidget);
    });

    testWidgets('web étroit, sans session : même écran d\'appairage', (tester) async {
      await _pump(tester, taille: _etroit);
      expect(find.text('Connecter cet ordinateur'), findsOneWidget);
      expect(_qr, findsOneWidget);
    });

    testWidgets('Android, sans session : Connexion, jamais de QR', (tester) async {
      await _pump(tester, web: false);
      expect(find.text('Votre numéro de téléphone'), findsOneWidget);
      expect(find.text('Connecter cet ordinateur'), findsNothing);
      expect(find.text('Se connecter avec un QR code'), findsNothing);
    });

    _testsRevuePorte();
  });

  group('layout large', () {
    _testsRevueLarge();

    testWidgets('connecté, ≥ 1024 : en-tête, bandeau, deux colonnes, colonne de droite vide', (tester) async {
      await _pump(tester, store: await storeAvecSession());
      expect(_shell, findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('ANALYSEUR HIPPIQUE'), findsOneWidget);
      expect(find.text('Programme du jour'), findsOneWidget);
      expect(find.text('Réglages'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('GRATUIT'), findsOneWidget, reason: 'pastille du palier');
      expect(find.text('Courses suivies'), findsNothing);
      expect(find.textContaining('Synchronisé'), findsNothing);
      expect(
        _texte("La web app nécessite une connexion — pas de mode hors ligne. Sur l'hippodrome sans réseau, "
            "utilisez l'app du téléphone."),
        findsOneWidget,
      );
      expect(find.text('Choisissez une course dans la liste.'), findsOneWidget);
      expect(find.descendant(of: _gauche, matching: find.text('17/11/2026')), findsOneWidget);
      expect(find.descendant(of: _gauche, matching: find.text('VINCENNES')), findsOneWidget);
    });

    testWidgets('ouvrir une course : à droite, liste visible, « Ouverte » ; retour : vide', (tester) async {
      final env = await _pump(tester, store: await storeAvecSession());
      await tester.tap(find.byKey(const ValueKey('course-9')));
      await tester.pumpAndSettle();
      expect(env.repo.partantsDemandes, [9]);
      expect(find.descendant(of: _droite, matching: find.text('Configuration course')), findsOneWidget);
      expect(find.descendant(of: _gauche, matching: find.text('Ouverte')), findsOneWidget);
      expect(find.text('ANALYSEUR HIPPIQUE'), findsOneWidget);
      // La ligne ouverte n'est jamais en or.
      final ouverte = tester.widget<Text>(find.text('Ouverte'));
      expect(ouverte.style?.color, isNot(const Color(0xFFE8B33C)));

      // Écran poussé : reste dans la colonne de droite.
      await tester.tap(find.descendant(of: _droite, matching: find.text('Voir les partants')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _droite, matching: find.text('Calculer')), findsOneWidget);
      expect(_gauche, findsOneWidget);

      // Autre course : remplace la première.
      await tester.tap(find.byKey(const ValueKey('course-10')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _droite, matching: find.text('Configuration course')), findsOneWidget);
      expect(find.text('Ouverte'), findsOneWidget);

      await tester.tap(find.descendant(of: _droite, matching: find.byType(BackButton)));
      await tester.pumpAndSettle();
      expect(find.text('Choisissez une course dans la liste.'), findsOneWidget);
      expect(find.text('Ouverte'), findsNothing);
    });

    testWidgets('échec du chargement des partants : snackbar, colonne de droite inchangée', (tester) async {
      final env = await _pump(tester, store: await storeAvecSession());
      env.repo.partantsEnEchec = true;
      await tester.tap(find.byKey(const ValueKey('course-9')));
      await _attendre(tester);
      expect(find.textContaining('Échec du chargement des partants'), findsOneWidget);
      expect(find.text('Choisissez une course dans la liste.'), findsOneWidget);
      expect(find.text('Ouverte'), findsNothing);
    });

    testWidgets('Profil et Réglages s\'ouvrent dans la colonne de droite ; double clic sans doublon', (tester) async {
      await _pump(tester, store: await storeAvecSession());
      await tester.tap(find.text('Profil'));
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _droite, matching: find.text('PROFIL')), findsOneWidget);
      expect(_gauche, findsOneWidget);
      await tester.tap(find.descendant(of: _droite, matching: find.byTooltip('Retour')));
      await tester.pumpAndSettle();
      expect(find.text('Choisissez une course dans la liste.'), findsOneWidget);

      await tester.tap(find.text('Réglages'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _droite, matching: find.byType(BackButton)), findsOneWidget);
      expect(_gauche, findsOneWidget);
    });

    testWidgets('clavier : colonne de gauche puis de droite, contour de focus visible', (tester) async {
      await _pump(tester, store: await storeAvecSession());
      await tester.tap(find.byKey(const ValueKey('course-9')));
      await tester.pumpAndSettle();
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();

      String zone() {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null) return 'aucune';
        var z = 'autre';
        ctx.visitAncestorElements((e) {
          final k = e.widget.key;
          if (k == const Key('colonne-gauche')) z = 'gauche';
          if (k == const Key('colonne-droite')) z = 'droite';
          return z == 'autre';
        });
        return z;
      }

      final zones = <String>[];
      var contourVu = false;
      for (var i = 0; i < 30; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final z = zone();
        if (zones.isEmpty || zones.last != z) zones.add(z);
        if (find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is PeintreContourFocus).evaluate().isNotEmpty) {
          contourVu = true;
        }
      }
      expect(contourVu, isTrue);
      // Après la colonne de gauche, la tabulation passe à la colonne de droite.
      final g = zones.indexOf('gauche');
      expect(g, isNot(-1), reason: '$zones');
      expect(zones.skip(g + 1).firstOrNull, 'droite', reason: '$zones');
    });

    testWidgets('web étroit, connecté : Accueil du téléphone inchangé', (tester) async {
      await _pump(tester, taille: _etroit, store: await storeAvecSession());
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(_shell, findsNothing);
      expect(find.text('Saisie manuelle'), findsOneWidget);
    });

    testWidgets('Android large, déverrouillé : Accueil du téléphone, jamais deux colonnes', (tester) async {
      await _pump(tester, web: false, store: await storeAvecSession(pin: '4821'));
      for (final c in '4821'.split('')) {
        await tester.tap(find.text(c));
        await tester.pump();
      }
      await _attendre(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(_shell, findsNothing);
    });
  });
}
