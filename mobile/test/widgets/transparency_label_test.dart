import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/engine/constants.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/widgets/transparency_label.dart';

void main() {
  group('transparencyLabel', () {
    test('inédit flagged, no performances -> 🐎 Inédit', () {
      final horse = Horse(nom: 'Test', inedit: true, performances: const []);
      expect(transparencyLabel(horse, 0), '🐎 Inédit');
    });

    test('inédit with stray performance rows -> 🐎 Inédit wins over count', () {
      final horse = Horse(nom: 'Test', inedit: true, performances: const []);
      expect(transparencyLabel(horse, 2), '🐎 Inédit');
    });

    test('not inédit, no performances entered -> Données non saisies', () {
      final horse = Horse(nom: 'Test', inedit: false, performances: const []);
      expect(transparencyLabel(horse, 0), 'Données non saisies');
    });

    test('partial history, list screen (raw performances.length = 3) -> Historique court (3)', () {
      final horse = Horse(nom: 'Test', inedit: false, performances: const []);
      expect(transparencyLabel(horse, 3), 'Historique court (3)');
    });

    test('partial history, results screen (nbPerfs = 2 post-engine) -> Historique court (2)', () {
      final horse = Horse(nom: 'Test', inedit: false, performances: const [])..nbPerfs = 2;
      expect(transparencyLabel(horse, horse.nbPerfs), 'Historique court (2)');
    });

    test('full history (nbPerfs == recenceStd.length) -> null', () {
      final horse = Horse(nom: 'Test', inedit: false, performances: const []);
      expect(transparencyLabel(horse, recenceStd.length), isNull);
    });

    test('over-full, defensive (nbPerfs > recenceStd.length) -> null, never throws', () {
      final horse = Horse(nom: 'Test', inedit: false, performances: const []);
      expect(() => transparencyLabel(horse, recenceStd.length + 1), returnsNormally);
      expect(transparencyLabel(horse, recenceStd.length + 1), isNull);
    });
  });
}
