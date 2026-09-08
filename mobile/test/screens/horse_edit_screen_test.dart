import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/models/performance.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/screens/horse_edit_screen.dart';

const _counterFinder = 'performances avec terrain inconnu';

// Le compteur est sous les 6 lignes de performance dans la ListView : hors
// du viewport de test par défaut (même raison que le scroll du disclaimer
// dans widget_test.dart).
Future<void> _scrollToCounter(WidgetTester tester) {
  return tester.scrollUntilVisible(
    find.textContaining(_counterFinder),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  group('HorseEditScreen terrain-inconnu counter (FR-5)', () {
    testWidgets('new horse, nothing entered -> 0/6', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HorseEditScreen(index: null)),
        ),
      );
      await tester.pump();

      await _scrollToCounter(tester);
      expect(find.textContaining('0/6 $_counterFinder'), findsOneWidget);
    });

    testWidgets('entering a rang without setting terrain -> counter increments', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HorseEditScreen(index: null)),
        ),
      );
      await tester.pump();

      await _scrollToCounter(tester);
      expect(find.textContaining('0/6 $_counterFinder'), findsOneWidget);

      // Renseigne le rang de C1 sans toucher au terrain (reste null). Le
      // champ Rang est en haut de la ListView, hors du viewport actuel
      // (scrollé vers le compteur) : on le retrouve via scrollUntilVisible.
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Rang').first,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.widgetWithText(TextField, 'Rang').first, '3');
      await tester.pump();

      await _scrollToCounter(tester);
      expect(find.textContaining('1/6 $_counterFinder'), findsOneWidget);
    });

    testWidgets('existing horse with mixed terrain-known/unknown performances -> counts only the unknown ones', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(
            nom: 'Cheval Mixte',
            performances: const [
              Performance(partants: 10, rang: 2, terrain: 1.0), // terrain connu
              Performance(partants: 8, rang: 5), // terrain inconnu
              Performance(partants: 9, rang: 1, incident: 'D'), // terrain inconnu
            ],
          ));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HorseEditScreen(index: 0)),
        ),
      );
      await tester.pump();

      await _scrollToCounter(tester);
      expect(find.textContaining('2/6 $_counterFinder'), findsOneWidget);
    });

    testWidgets('a blank row (never touched) never counts as terrain inconnu', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(
            nom: 'Cheval Solo',
            performances: const [Performance(partants: 10, rang: 4)],
          ));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HorseEditScreen(index: 0)),
        ),
      );
      await tester.pump();

      // Une seule perf réellement saisie (terrain inconnu) sur les 6 lignes,
      // les 5 lignes vides restantes ne comptent pas.
      await _scrollToCounter(tester);
      expect(find.textContaining('1/6 $_counterFinder'), findsOneWidget);
    });
  });
}
