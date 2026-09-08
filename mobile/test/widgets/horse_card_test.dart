import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/models/performance.dart';
import 'package:prediction_hippique/widgets/horse_card.dart';

const _perf = Performance(partants: 10, rang: 3);

Future<void> _pump(WidgetTester tester, Horse horse) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HorseCard(horse: horse, onTap: () {}, onDelete: () {}),
      ),
    ),
  );
}

void main() {
  group('HorseCard transparency subtitle', () {
    testWidgets('inédit -> subtitle contains 🐎 Inédit, not a performance count', (tester) async {
      final horse = Horse(
        nom: 'Cheval Inédit',
        inedit: true,
        performances: const [_perf, _perf],
      );
      await _pump(tester, horse);

      expect(find.textContaining('🐎 Inédit'), findsOneWidget);
      expect(find.textContaining('perf(s)'), findsNothing);
    });

    testWidgets('no performances entered -> subtitle contains Données non saisies', (tester) async {
      final horse = Horse(nom: 'Cheval Vide', inedit: false, performances: const []);
      await _pump(tester, horse);

      expect(find.textContaining('Données non saisies'), findsOneWidget);
    });

    testWidgets('3 raw performances -> subtitle contains Historique court (3)', (tester) async {
      final horse = Horse(
        nom: 'Cheval Court',
        inedit: false,
        performances: const [_perf, _perf, _perf],
      );
      await _pump(tester, horse);

      expect(find.textContaining('Historique court (3)'), findsOneWidget);
    });

    testWidgets('full history (6 raw performances) -> no transparency badge, falls back to perf count', (tester) async {
      final horse = Horse(
        nom: 'Cheval Complet',
        inedit: false,
        performances: const [_perf, _perf, _perf, _perf, _perf, _perf],
      );
      await _pump(tester, horse);

      expect(find.textContaining('🐎'), findsNothing);
      expect(find.textContaining('Données non saisies'), findsNothing);
      expect(find.textContaining('Historique court'), findsNothing);
      expect(find.textContaining('6 perf(s)'), findsOneWidget);
    });
  });
}
