import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/engine/combinatoire.dart';
import 'package:prediction_hippique/engine/scoring.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/models/performance.dart';
import 'package:prediction_hippique/models/race_config.dart';

// Aucun test_combinatoire.py n'existe encore côté backend (section 9, cas 8,
// jamais automatisé) : ce fichier sert donc aussi de première vérification
// automatisée du calcul de combinaisons, des deux côtés.

void main() {
  test('couple : le ratio désordre/ordre est proche de 2', () {
    final horses = List<Horse>.generate(
      5,
      (i) => Horse(
        nom: 'H$i',
        numPmu: i + 1,
        age: 5,
        poids: 60,
        cote: 2.0 + i,
        performances: [
          Performance(partants: 10, rang: i + 1, distance: 1600, terrain: 1.0, niveau: 3.0),
        ],
      ),
    );
    final target = RaceConfig(distance: 1600, terrain: 1.0, niveau: 3.0, nbPartantsCourse: 5);
    final results = analyseCourse(horses, target);
    final combos = buildCombinaisons(results, horses.length);

    expect(combos.couple.ordre, isNotEmpty);
    expect(combos.couple.desordre, isNotEmpty);
    final ratio = combos.couple.desordre.first.probabilite / combos.couple.ordre.first.probabilite;
    expect(ratio, closeTo(2.0, 0.5));
  });

  test('couplé placé et 2 sur 4 renvoient des probabilités valides avec dossards', () {
    final horses = List<Horse>.generate(
      6,
      (i) => Horse(
        nom: 'H$i',
        numPmu: i + 1,
        age: 5,
        poids: 60,
        cote: 2.0 + i,
        performances: [
          Performance(partants: 10, rang: i + 1, distance: 1600, terrain: 1.0, niveau: 3.0),
        ],
      ),
    );
    final target = RaceConfig(distance: 1600, terrain: 1.0, niveau: 3.0, nbPartantsCourse: 6);
    final results = analyseCourse(horses, target);
    final combos = buildCombinaisons(results, horses.length);

    expect(combos.couplePlace, isNotEmpty);
    expect(combos.deuxSurQuatre, isNotEmpty);
    for (final item in [...combos.couplePlace, ...combos.deuxSurQuatre]) {
      expect(item.probabilite, greaterThanOrEqualTo(0.0));
      expect(item.probabilite, lessThanOrEqualTo(1.0));
      expect(item.dossards, hasLength(2));
      expect(item.dossards.every((d) => d != null), isTrue);
    }
  });

  test('quinté désordre sur 5 chevaux réels = probabilité 1 (un seul ensemble possible)', () {
    final horses = List<Horse>.generate(
      5,
      (i) => Horse(
        nom: 'H$i',
        numPmu: i + 1,
        age: 5,
        poids: 60,
        cote: 2.0 + i,
        performances: [
          Performance(partants: 10, rang: i + 1, distance: 1600, terrain: 1.0, niveau: 3.0),
        ],
      ),
    );
    final target = RaceConfig(distance: 1600, terrain: 1.0, niveau: 3.0, nbPartantsCourse: 5);
    final results = analyseCourse(horses, target);
    final combos = buildCombinaisons(results, horses.length);

    expect(combos.quinte.desordre, hasLength(1));
    expect(combos.quinte.desordre.first.probabilite, closeTo(1.0, 1e-6));
  });
}
