import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';
import 'package:prediction_hippique/screens/results_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _staleBanner = 'Recalcul nécessaire — les partants ont changé depuis ce calcul.';

// Les cartes de classement sont loin dans la ListView (sous la grille de
// combinaisons) : la sliver ne les matérialise qu'une fois scrollées en vue
// (même raison que le scroll du disclaimer dans widget_test.dart).
Future<void> _scrollToText(WidgetTester tester, String text) {
  return tester.scrollUntilVisible(find.text(text), 500, scrollable: find.byType(Scrollable).first);
}

Future<ProviderContainer> _pumpWithHorses(WidgetTester tester, List<String> names) async {
  // calculer() lit engineParamsProvider, qui lit sharedPreferencesProvider
  // (FR-20, spec-3-7) : même override minimal que main.dart, sans quoi il lève.
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  for (final name in names) {
    container.read(horsesProvider.notifier).add(Horse(nom: name));
  }
  container.read(resultsProvider.notifier).calculer();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ResultsScreen()),
    ),
  );
  await tester.pump();

  return container;
}

void main() {
  group('ResultsScreen stale banner (FR-6)', () {
    testWidgets('non-stale result -> no banner', (tester) async {
      await _pumpWithHorses(tester, ['Foudre Noire']);

      expect(find.text(_staleBanner), findsNothing);
      expect(find.text('Recalculer'), findsNothing);

      await _scrollToText(tester, 'Foudre Noire');
      expect(find.text('Foudre Noire'), findsOneWidget);
    });

    testWidgets('horse removed after calc -> banner shown, old ranking still visible beneath', (tester) async {
      final container = await _pumpWithHorses(tester, ['Foudre Noire', 'Vent Rapide']);

      // Édition après calcul : retire un partant -> le résultat affiché devient périmé.
      container.read(horsesProvider.notifier).removeAt(0);
      await tester.pump();

      expect(find.text(_staleBanner), findsOneWidget);
      expect(find.text('Recalculer'), findsOneWidget);

      // L'ancien classement reste visible sous le bandeau (jamais un écran blanc).
      await _scrollToText(tester, 'Foudre Noire');
      expect(find.text('Foudre Noire'), findsOneWidget);
      expect(find.text('Vent Rapide'), findsOneWidget);
    });

    testWidgets('horse added (not removed) after calc -> banner shown too', (tester) async {
      final container = await _pumpWithHorses(tester, ['Foudre Noire']);

      container.read(horsesProvider.notifier).add(Horse(nom: 'Vent Rapide'));
      await tester.pump();

      expect(find.text(_staleBanner), findsOneWidget);
    });

    testWidgets('stale with roster emptied -> Recalculer button disabled', (tester) async {
      final container = await _pumpWithHorses(tester, ['Foudre Noire']);

      container.read(horsesProvider.notifier).removeAt(0);
      await tester.pump();

      expect(find.text(_staleBanner), findsOneWidget);
      expect(container.read(horsesProvider), isEmpty);

      final button = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Recalculer'));
      expect(button.onPressed, isNull);
    });

    testWidgets('tap Recalculer -> banner disappears, ranking reflects current roster', (tester) async {
      final container = await _pumpWithHorses(tester, ['Foudre Noire', 'Vent Rapide']);

      container.read(horsesProvider.notifier).removeAt(0);
      await tester.pump();
      expect(find.text(_staleBanner), findsOneWidget);

      await tester.tap(find.text('Recalculer'));
      await tester.pump();

      expect(find.text(_staleBanner), findsNothing);
      expect(container.read(resultsProvider)!.isStale, isFalse);

      // Le cheval retiré n'apparaît plus dans le classement recalculé.
      await _scrollToText(tester, 'Vent Rapide');
      expect(find.text('Vent Rapide'), findsOneWidget);
      expect(find.text('Foudre Noire'), findsNothing);
    });

    testWidgets('HorsesNotifier.clear() -> resultsProvider.state becomes null, not stale', (tester) async {
      final container = await _pumpWithHorses(tester, ['Foudre Noire']);
      expect(container.read(resultsProvider), isNotNull);

      container.read(horsesProvider.notifier).clear();

      expect(container.read(resultsProvider), isNull);
    });

    testWidgets('stale after removal -> header shows live roster count, not the frozen one', (tester) async {
      final container = await _pumpWithHorses(tester, ['Foudre Noire', 'Vent Rapide']);

      container.read(horsesProvider.notifier).removeAt(0);
      await tester.pump();

      expect(find.text('1 partants actuellement — recalcul nécessaire'), findsOneWidget);
      expect(find.textContaining('2 partants'), findsNothing);
    });

    testWidgets('stale after addition -> header shows the larger live roster count', (tester) async {
      final container = await _pumpWithHorses(tester, ['Foudre Noire']);

      container.read(horsesProvider.notifier).add(Horse(nom: 'Vent Rapide'));
      await tester.pump();

      expect(find.text('2 partants actuellement — recalcul nécessaire'), findsOneWidget);
    });

    testWidgets('non-stale -> header keeps the frozen count, no live-roster phrasing', (tester) async {
      await _pumpWithHorses(tester, ['Foudre Noire']);

      expect(find.textContaining('partants actuellement'), findsNothing);
      expect(find.textContaining('1 partants'), findsOneWidget);
    });

    testWidgets('banner carries a liveRegion semantics flag for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      final container = await _pumpWithHorses(tester, ['Foudre Noire']);

      container.read(horsesProvider.notifier).removeAt(0);
      await tester.pump();

      final node = tester.getSemantics(find.byKey(const Key('stale-banner-semantics')));
      expect(node.flagsCollection.isLiveRegion, isTrue);

      handle.dispose();
    });
  });
}
