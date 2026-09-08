import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/models/programme_extrait.dart';

void main() {
  group('ProgrammeExtrait.fromJson', () {
    test('parses a fully populated response (mirrors ProgrammeExtraitOut)', () {
      final json = {
        'hippo': 'Vincennes',
        'dist': 2100.0,
        'terr': 1.0,
        'niveau': 3.0,
        'partants': 14,
        'horses': [
          {
            'num': 3,
            'name': 'Bolide',
            'age': 5,
            'poids': 58.5,
            'cote': 6.5,
            'perfs': [
              {'rank': 1, 'incident': ''},
              {'rank': null, 'incident': 'D'},
            ],
          },
        ],
      };

      final extrait = ProgrammeExtrait.fromJson(json);

      expect(extrait.hippo, 'Vincennes');
      expect(extrait.dist, 2100.0);
      expect(extrait.terr, 1.0);
      expect(extrait.niveau, 3.0);
      expect(extrait.partants, 14);
      expect(extrait.horses, hasLength(1));

      final horse = extrait.horses.single;
      expect(horse.num, 3);
      expect(horse.name, 'Bolide');
      expect(horse.age, 5);
      expect(horse.poids, 58.5);
      expect(horse.cote, 6.5);
      expect(horse.perfs, hasLength(2));
      expect(horse.perfs[0].rank, 1);
      expect(horse.perfs[0].incident, '');
      expect(horse.perfs[1].rank, isNull);
      expect(horse.perfs[1].incident, 'D');
    });

    test('parses an entirely-null/empty response without throwing', () {
      final extrait = ProgrammeExtrait.fromJson(const {
        'hippo': null,
        'dist': null,
        'terr': null,
        'niveau': null,
        'partants': null,
        'horses': <dynamic>[],
      });

      expect(extrait.hippo, isNull);
      expect(extrait.dist, isNull);
      expect(extrait.terr, isNull);
      expect(extrait.niveau, isNull);
      expect(extrait.partants, isNull);
      expect(extrait.horses, isEmpty);
    });

    test('missing horses key defaults to an empty list', () {
      final extrait = ProgrammeExtrait.fromJson(const {'hippo': 'Auteuil'});
      expect(extrait.horses, isEmpty);
    });

    test('a horse with a missing perfs key defaults to an empty list', () {
      final extrait = ProgrammeExtrait.fromJson(const {
        'horses': [
          {'num': 1, 'name': 'Solo'},
        ],
      });
      expect(extrait.horses.single.perfs, isEmpty);
    });

    test('integer JSON values for double fields are accepted (num -> double coercion)', () {
      final extrait = ProgrammeExtrait.fromJson(const {
        'dist': 2100,
        'terr': 1,
        'niveau': 3,
        'horses': [
          {'poids': 58, 'cote': 6},
        ],
      });

      expect(extrait.dist, 2100.0);
      expect(extrait.terr, 1.0);
      expect(extrait.niveau, 3.0);
      expect(extrait.horses.single.poids, 58.0);
      expect(extrait.horses.single.cote, 6.0);
    });

    test('a perf missing the required "incident" key throws (backend contract, never silently tolerant)', () {
      // verification-gap + blind-hunter (revue de code) : "incident" est
      // requis côté backend (PerfProgrammeOut.incident: str, sans défaut,
      // backend/app/schemas/extraction.py) - le backend garantit déjà sa
      // présence (une réponse de vision_client sans ce champ échouerait la
      // validation Pydantic et deviendrait un 502 avant même d'atteindre le
      // mobile). Le miroir Dart reste donc volontairement strict : une clé
      // manquante indique une vraie violation de contrat, pas un cas normal
      // à masquer silencieusement. import_photo_screen.dart la rattrape via
      // son catch(_) générique ("Échec de l'extraction, réessayez"), jamais
      // un crash non géré.
      expect(
        () => ProgrammeExtrait.fromJson(const {
          'horses': [
            {
              'perfs': [
                {'rank': 1},
              ],
            },
          ],
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
