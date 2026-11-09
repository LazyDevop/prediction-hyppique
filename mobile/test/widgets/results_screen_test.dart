import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';
import 'package:prediction_hippique/screens/results_screen.dart';
import 'package:prediction_hippique/widgets/experimental_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _staleBanner = 'Recalcul nécessaire — les partants ont changé depuis ce calcul.';

// Les cartes de classement sont loin dans la ListView (sous la grille de
// combinaisons) : la sliver ne les matérialise qu'une fois scrollées en vue
// (même raison que le scroll du disclaimer dans widget_test.dart).
Future<void> _scrollToText(WidgetTester tester, String text) {
  return tester.scrollUntilVisible(find.text(text), 500, scrollable: find.byType(Scrollable).first);
}

Future<ProviderContainer> _pumpWithHorses(WidgetTester tester, List<String> names) {
  return _pumpWith(tester, [for (final name in names) Horse(nom: name)]);
}

Future<ProviderContainer> _pumpWith(
  WidgetTester tester,
  List<Horse> horses, {
  bool experimental = kValueExperimental,
}) async {
  // calculer() lit engineParamsProvider, qui lit sharedPreferencesProvider
  // (FR-20, spec-3-7) : même override minimal que main.dart, sans quoi il lève.
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  for (final horse in horses) {
    container.read(horsesProvider.notifier).add(horse);
  }
  container.read(resultsProvider.notifier).calculer();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: ResultsScreen(experimental: experimental)),
    ),
  );
  await tester.pump();

  return container;
}

// Deux inédits à cote longue : probabilité modèle ~50 % contre une cote à
// 10 -> value et mise Kelly positives, donc chiffres affichés sur la carte.
List<Horse> _valueHorses() => [
  Horse(nom: 'Foudre Noire', cote: 10, inedit: true),
  Horse(nom: 'Vent Rapide', cote: 12, inedit: true),
];

Horse _analysed({double? value, double probabilite = 0.2, int nbPerfs = 3}) {
  return Horse(nom: 'X')
    ..nbPerfs = nbPerfs
    ..value = value
    ..probabilite = probabilite;
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

  group('ResultsScreen experimental value & Kelly (spec-value-experimentale)', () {
    testWidgets('banner pinned with its exact text, visible without scrolling', (tester) async {
      await _pumpWith(tester, _valueHorses(), experimental: true);

      expect(find.text(kExperimentalBannerText), findsOneWidget);
      expect(
        kExperimentalBannerText,
        'Value et mises expérimentales : le moteur ne bat pas encore le marché.',
      );
      // Hors de la ListView : épinglé, donc pas descendant du Scrollable.
      expect(
        find.descendant(of: find.byType(Scrollable), matching: find.text(kExperimentalBannerText)),
        findsNothing,
      );
      expect(tester.getRect(find.text(kExperimentalBannerText)).bottom, lessThan(600));
    });

    testWidgets('stale -> both banners, stale first', (tester) async {
      final container = await _pumpWith(tester, _valueHorses(), experimental: true);

      container.read(horsesProvider.notifier).removeAt(0);
      await tester.pump();

      expect(find.text(_staleBanner), findsOneWidget);
      expect(find.text(kExperimentalBannerText), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_staleBanner)).dy,
        lessThan(tester.getTopLeft(find.text(kExperimentalBannerText)).dy),
      );
    });

    testWidgets('banner is one semantic container read as one sentence', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpWith(tester, _valueHorses(), experimental: true);

      final node = tester.getSemantics(find.byKey(const Key('experimental-banner-semantics')));
      expect(node.label, kExperimentalBannerText);

      handle.dispose();
    });

    testWidgets('card shows exp. on value and stake, stake not green', (tester) async {
      final container = await _pumpWith(tester, _valueHorses(), experimental: true);
      // Précondition du fixture : sans value ni mise positives, il n'y
      // aurait rien à marquer et le test ne prouverait rien.
      final analyses = container.read(resultsProvider)!.resultats;
      expect(analyses.any((h) => (h.value ?? 0) > 0 && (h.mise ?? 0) > 0.01), isTrue);
      await _scrollToText(tester, 'Foudre Noire');

      expect(find.textContaining('Value exp. +'), findsWidgets);
      final stake = find.textContaining(RegExp(r'^Mise exp\. \d+\.\d u$'));
      expect(stake, findsWidgets);
      for (final element in stake.evaluate()) {
        expect((element.widget as Text).style?.color, isNot(Colors.greenAccent));
      }
    });

    testWidgets('no displayed verdict contains jouable', (tester) async {
      await _pumpWith(tester, _valueHorses(), experimental: true);
      await _scrollToText(tester, 'Vent Rapide');

      expect(find.textContaining('jouable'), findsNothing);
      expect(find.textContaining('avec la cote'), findsWidgets);
    });

    testWidgets('switch off -> no banner, no exp. mark, verdicts stay neutral', (tester) async {
      await _pumpWith(tester, _valueHorses(), experimental: false);

      expect(find.text(kExperimentalBannerText), findsNothing);
      await _scrollToText(tester, 'Vent Rapide');
      expect(find.textContaining(kExperimentalMark), findsNothing);
      expect(find.textContaining(RegExp(r'^\+\d+\.\d %$')), findsWidgets);
      final stake = find.textContaining(RegExp(r'^\d+\.\d u$'));
      expect(stake, findsWidgets);
      for (final element in stake.evaluate()) {
        expect((element.widget as Text).style?.color, Colors.greenAccent);
      }
      expect(find.textContaining('jouable'), findsNothing);
      expect(find.textContaining('avec la cote'), findsWidgets);
    });

    test('verdicts map from their value range', () {
      expect(recoLabel(_analysed(value: 0.20, probabilite: 0.10), 3), 'Écart positif marqué avec la cote');
      // Value forte mais probabilité trop faible -> retombe sur l'écart simple.
      expect(recoLabel(_analysed(value: 0.20, probabilite: 0.05), 3), 'Écart positif avec la cote');
      expect(recoLabel(_analysed(value: 0.10), 3), 'Écart positif avec la cote');
      expect(recoLabel(_analysed(value: 0.03), 3), 'Écart faible avec la cote');
      expect(recoLabel(_analysed(value: -0.10), 0), 'Favori du modèle, cote plus courte que son estimation');
      expect(recoLabel(_analysed(value: -0.10), 1), 'Favori du modèle, cote plus courte que son estimation');
      expect(recoLabel(_analysed(value: -0.10), 2), "Pas d'écart positif avec la cote");
      expect(recoLabel(_analysed(value: 0), 5), "Pas d'écart positif avec la cote");
      expect(recoLabel(_analysed(value: null), 0), 'Cote manquante');
      expect(recoLabel(_analysed(value: 0.20, nbPerfs: 0), 0), 'Données non saisies');
      // Bornes : 0.15 et 0.07 inclus, 0.05 exclu.
      expect(recoLabel(_analysed(value: 0.15, probabilite: 0.07), 3), 'Écart positif marqué avec la cote');
      expect(recoLabel(_analysed(value: 0.15, probabilite: 0.069), 3), 'Écart positif avec la cote');
      expect(recoLabel(_analysed(value: 0.05), 3), 'Écart faible avec la cote');
      // Un inédit sans performance n'est pas un cheval sans données.
      final inedit = Horse(nom: 'X', inedit: true)
        ..nbPerfs = 0
        ..value = 0.20
        ..probabilite = 0.2;
      expect(recoLabel(inedit, 3), isNot('Données non saisies'));
    });
  });
}
