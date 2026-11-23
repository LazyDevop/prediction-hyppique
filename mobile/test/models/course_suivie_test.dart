import 'package:flutter_test/flutter_test.dart';

import 'package:prediction_hippique/models/course_suivie.dart';
import 'package:prediction_hippique/models/course_summary.dart';

Map<String, dynamic> _json({bool avecPmu = true}) => {
      'id': 7,
      'date': '2026-11-23',
      'heure_depart': '2026-11-23T14:05:00Z',
      'hippodrome': 'VINCENNES',
      'discipline': 'ATTELE',
      'distance': 2700.0,
      'allocation': null,
      'nb_partants': 14,
      'corde': null,
      'terrain': null,
      'niveau_estime': null,
      'finalisee': false,
      'source': 'pmu',
      if (avecPmu) ...{'numero_reunion': 1, 'numero_course': 4, 'cle_course': '20261123-R1-C4'},
    };

void main() {
  group('CourseSummary et la référence PMU (story 8.9)', () {
    test('fromJson lit numero_reunion, numero_course, cle_course', () {
      final c = CourseSummary.fromJson(_json());
      expect(c.numeroReunion, 1);
      expect(c.numeroCourse, 4);
      expect(c.cleCourse, '20261123-R1-C4');
    });

    test('ancien backend sans les champs : nuls, rien ne casse', () {
      final c = CourseSummary.fromJson(_json(avecPmu: false));
      expect(c.cleCourse, isNull);
      expect(c.numeroReunion, isNull);
      expect(c.numeroCourse, isNull);
      expect(c.hippodrome, 'VINCENNES');
    });

    test('aller-retour cache', () {
      final c = CourseSummary.fromCacheMap(CourseSummary.fromJson(_json()).toCacheMap());
      expect(c.cleCourse, '20261123-R1-C4');
      expect(c.numeroReunion, 1);
      expect(c.numeroCourse, 4);
    });

    test("ligne de cache v1 (sans colonnes PMU) : clé nulle", () {
      final map = CourseSummary.fromJson(_json()).toCacheMap()
        ..remove('numero_reunion')
        ..remove('numero_course')
        ..remove('cle_course');
      expect(CourseSummary.fromCacheMap(map).cleCourse, isNull);
    });
  });

  group('CourseSuivie', () {
    final course = CourseSummary.fromJson(_json());

    test('instantané depuis une course : clé PMU, UTC, date calendaire', () {
      final s = CourseSuivie.depuisCourse(course, suivie: true, maintenant: DateTime(2026, 11, 23, 9))!;
      expect(s.cleCourse, '20261123-R1-C4');
      expect(s.modifieeLe.isUtc, isTrue);
      expect(s.heureDepart!.isUtc, isTrue);
      expect(s.dateIso, '2026-11-23');
      expect(s.numeroReunion, 1);
      expect(s.numeroCourse, 4);
      expect(s.synchronise, isFalse);
    });

    test('sans clé PMU : pas de course suivie', () {
      final manuelle = CourseSummary.fromJson(_json(avecPmu: false));
      expect(CourseSuivie.depuisCourse(manuelle, suivie: true, maintenant: DateTime(2026, 11, 23)), isNull);
    });

    test('aller-retour cache', () {
      final s = CourseSuivie.depuisCourse(course, suivie: true, maintenant: DateTime.utc(2026, 11, 23, 9))!;
      final relue = CourseSuivie.fromCacheMap(s.toCacheMap());
      expect(relue.cleCourse, s.cleCourse);
      expect(relue.suivie, isTrue);
      expect(relue.modifieeLe, s.modifieeLe);
      expect(relue.heureDepart, s.heureDepart);
      expect(relue.date, DateTime(2026, 11, 23));
    });

    test('la date de la ligne est toujours celle de la clé', () {
      // Même si la date du résumé diverge (heure portée, fuseau), la clé fait foi.
      final decalee = CourseSummary(
        id: 1,
        date: DateTime(2026, 11, 22, 23, 30),
        hippodrome: 'X',
        discipline: 'ATTELE',
        finalisee: false,
        source: 'pmu',
        cleCourse: '20261123-R1-C4',
      );
      final s = CourseSuivie.depuisCourse(decalee, suivie: true, maintenant: DateTime(2026, 11, 23))!;
      expect(s.dateIso.replaceAll('-', ''), s.cleCourse.substring(0, 8));
      final normale = CourseSuivie.depuisCourse(course, suivie: true, maintenant: DateTime(2026, 11, 23))!;
      expect(normale.dateIso.replaceAll('-', ''), normale.cleCourse.substring(0, 8));
    });

    CourseSuivie l(String cle, DateTime date, DateTime? h) => CourseSuivie(
          cleCourse: cle,
          suivie: true,
          modifieeLe: DateTime.utc(2026),
          date: date,
          heureDepart: h,
          hippodrome: 'X',
        );

    test('tri par (date, heure) ; sans heure : fin de sa journée, avant le lendemain', () {
      final lignes = coursesSuiviesAVenir([
        l('20261124-R1-C1', DateTime(2026, 11, 24), DateTime(2026, 11, 24, 9).toUtc()),
        l('20261123-R2-C1', DateTime(2026, 11, 23), null),
        // Réunion nocturne datée du 23, départ après minuit : reste au 23,
        // après la course sans heure (23:59:59 le 23).
        l('20261123-R3-C1', DateTime(2026, 11, 23), DateTime(2026, 11, 24, 0, 30).toUtc()),
        l('20261123-R1-C1', DateTime(2026, 11, 23), DateTime(2026, 11, 23, 13).toUtc()),
      ], DateTime(2026, 11, 23, 10));
      expect(lignes.map((c) => c.cleCourse),
          ['20261123-R1-C1', '20261123-R2-C1', '20261123-R3-C1', '20261124-R1-C1']);
    });

    test('borne : 23:59 les deux, 00:01 seule la course après minuit', () {
      final soir = l('20261123-R1-C6', DateTime(2026, 11, 23), DateTime(2026, 11, 23, 20).toUtc());
      final nuit = l('20261123-R1-C9', DateTime(2026, 11, 23), DateTime(2026, 11, 24, 0, 30).toUtc());
      expect(coursesSuiviesAVenir([soir, nuit], DateTime(2026, 11, 23, 23, 59)), hasLength(2));
      expect(coursesSuiviesAVenir([soir, nuit], DateTime(2026, 11, 24, 0, 1)).map((c) => c.cleCourse),
          ['20261123-R1-C9']);
      expect(coursesSuiviesAVenir([soir, nuit], DateTime(2026, 11, 24, 0, 31)), isEmpty);
    });

    test("à venir : suivies, aujourd'hui ou plus tard, triées par heure de départ", () {
      CourseSuivie l(String cle, DateTime date, DateTime? h, {bool suivie = true}) => CourseSuivie(
            cleCourse: cle,
            suivie: suivie,
            modifieeLe: DateTime.utc(2026),
            date: date,
            heureDepart: h,
            hippodrome: 'X',
          );
      final lignes = coursesSuiviesAVenir([
        l('20261122-R1-C1', DateTime(2026, 11, 22), DateTime.utc(2026, 11, 22, 13)), // hier
        l('20261123-R1-C5', DateTime(2026, 11, 23), DateTime.utc(2026, 11, 23, 16)),
        l('20261123-R1-C2', DateTime(2026, 11, 23), DateTime.utc(2026, 11, 23, 13)),
        l('20261124-R2-C1', DateTime(2026, 11, 24), null),
        l('20261123-R1-C3', DateTime(2026, 11, 23), DateTime.utc(2026, 11, 23, 14), suivie: false),
      ], DateTime(2026, 11, 23, 23, 59));
      expect(lignes.map((c) => c.cleCourse), ['20261123-R1-C2', '20261123-R1-C5', '20261124-R2-C1']);
    });
  });
}
