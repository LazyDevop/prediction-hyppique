import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, {required bool experimental}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: SettingsScreen(experimental: experimental)),
    ),
  );
  await tester.pump();
}

void main() {
  group('SettingsScreen Kelly label (spec-value-experimentale)', () {
    testWidgets('experimental -> label says so', (tester) async {
      await _pump(tester, experimental: true);
      await tester.scrollUntilVisible(
        find.text('Fraction de Kelly (expérimental)'), 300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Fraction de Kelly (expérimental)'), findsOneWidget);
    });

    testWidgets('switch off -> plain label', (tester) async {
      await _pump(tester, experimental: false);
      await tester.scrollUntilVisible(
        find.text('Fraction de Kelly'), 300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Fraction de Kelly'), findsOneWidget);
      expect(find.text('Fraction de Kelly (expérimental)'), findsNothing);
    });
  });
}
