import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/main.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_test_helpers.dart';

Future<void> _attendre(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<MemorySessionStore> _pumpVraieApp(WidgetTester tester, {MemorySessionStore? store}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final s = store ?? MemorySessionStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overridesAuth(store: s, web: true),
      ],
      child: const PredictionHippiqueApp(),
    ),
  );
  await _attendre(tester);
  return s;
}

void main() {
  testWidgets('vraie app : Accueil → icône de compte → Profil', (tester) async {
    await _pumpVraieApp(tester, store: await storeAvecSession());
    expect(find.text('Programme du jour'), findsOneWidget);
    await tester.tap(find.byTooltip('Profil'));
    await _attendre(tester);
    expect(find.text('PROFIL'), findsOneWidget);
    expect(find.text('Mes appareils'), findsOneWidget);
  });

  testWidgets('vraie app : connexion avec 699999999 → Appareil bloqué, ni session ni Accueil', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = MemorySessionStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overridesAuth(store: store),
        ],
        child: const PredictionHippiqueApp(),
      ),
    );
    await _attendre(tester);

    await tester.enterText(find.byType(TextField), '699999999');
    await tester.tap(find.textContaining("J'accepte"));
    await tester.pump();
    await tester.tap(find.text('RECEVOIR LE CODE PAR SMS'));
    await _attendre(tester);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.text('VALIDER'));
    await _attendre(tester);

    expect(find.text('APPAREIL BLOQUÉ'), findsOneWidget);
    expect(find.text("Aucun appareil n'a été déconnecté."), findsOneWidget);
    expect(find.text('Choisissez un code PIN'), findsNothing);
    expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
    expect(store.session, isNull);
  });
}
