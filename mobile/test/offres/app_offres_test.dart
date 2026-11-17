import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/main.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_test_helpers.dart';

void main() {
  testWidgets('vraie app : Profil → Offres → Paiement → confirmé → Profil affiche le palier payé', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final horloge = Horloge();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overridesAuth(store: await storeAvecSession(), web: true, horloge: horloge),
        ],
        child: const PredictionHippiqueApp(),
      ),
    );
    await attendreApp(tester);

    expect(find.text('Programme du jour'), findsOneWidget);
    await tester.tap(find.byTooltip('Profil'));
    await attendreApp(tester);
    expect(find.text('GRATUIT'), findsOneWidget);
    await toucherApp(tester, find.text('Offres'));
    await toucherApp(tester, find.text('Pass semaine Turfiste'));
    await toucherApp(tester, find.text('CONTINUER VERS LE PAIEMENT'));
    await toucherApp(tester, find.text('MTN MoMo'));
    await tester.enterText(find.byType(TextField), '677123456');
    await tester.pump();
    await toucherApp(tester, find.text('PAYER'));
    expect(
      find.text('Paiement en attente de confirmation — validez sur votre téléphone', skipOffstage: false),
      findsOneWidget,
    );

    horloge.avancer(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    await attendreApp(tester);
    expect(find.text("✓ Pass semaine Turfiste actif jusqu'au 24/11"), findsOneWidget);

    await toucherApp(tester, find.text('REVENIR AU PROFIL'));
    expect(find.text('PROFIL'), findsOneWidget);
    expect(find.text('TURFISTE'), findsOneWidget);
    expect(find.text('Turfiste'), findsOneWidget);
    expect(find.text('24/11/2026 à 10 h 00'), findsOneWidget);
  });
}

Future<void> attendreApp(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> toucherApp(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await attendreApp(tester);
}
