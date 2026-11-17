import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/main.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_test_helpers.dart';

/// La VRAIE application (PredictionHippiqueApp, branchement de main.dart),
/// avec stockage en mémoire, faux serveur et Argon2id réduit.
Future<void> _pumpVraieApp(WidgetTester tester, SessionStore store) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overridesAuth(store: store),
    ],
    child: const PredictionHippiqueApp(),
  ));
  await _attendre(tester);
}

Future<void> _attendre(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

final _accueil = find.byType(HomeScreen, skipOffstage: false);

void main() {
  testWidgets('sans session : Connexion, Accueil jamais construit', (tester) async {
    await _pumpVraieApp(tester, MemorySessionStore());
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    expect(_accueil, findsNothing);
  });

  testWidgets('session + PIN sur appareil : Déverrouillage, Accueil non construit avant le déverrouillage',
      (tester) async {
    await _pumpVraieApp(tester, await storeAvecSession(pin: '4821'));
    expect(find.text('Saisissez votre code PIN'), findsOneWidget);
    expect(_accueil, findsNothing);
  });

  testWidgets('parcours appareil : Connexion → code → PIN → confirmation → Accueil', (tester) async {
    final store = MemorySessionStore();
    await _pumpVraieApp(tester, store);
    await tester.enterText(find.byType(TextField), '677123456');
    await tester.tap(find.textContaining("J'accepte"));
    await tester.pump();
    await tester.tap(find.text('RECEVOIR LE CODE PAR SMS'));
    await _attendre(tester);
    expect(find.text('Mode démo : le code est 123456'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('VALIDER'));
    await _attendre(tester);

    expect(find.text('Choisissez un code PIN'), findsOneWidget);
    expect(_accueil, findsNothing);
    for (final c in '4821'.split('')) {
      await tester.tap(find.text(c));
      await tester.pump();
    }
    await tester.tap(find.text('CONTINUER'));
    await tester.pump();
    for (final c in '4821'.split('')) {
      await tester.tap(find.text(c));
      await tester.pump();
    }
    await _attendre(tester);

    // Accueil appelle le backend, absent ici : seule la première frame compte.
    expect(find.text('Programme du jour'), findsOneWidget);
    expect(store.session!.pinDefini, isTrue);
  });
}
