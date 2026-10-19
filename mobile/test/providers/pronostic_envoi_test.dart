import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/remote/api_client.dart';
import 'package:prediction_hippique/models/engine_params.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/models/performance.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/pronostic_provider.dart';
import 'package:prediction_hippique/providers/race_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';
import 'package:prediction_hippique/models/race_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePronosticsApi implements PronosticsApi {
  final List<Map<String, Object?>> envoyes = [];

  @override
  Future<void> envoyerPronostic(Map<String, Object?> pronostic) async => envoyes.add(pronostic);
}

Horse cheval(int numPmu, int rang) => Horse(
      nom: 'C$numPmu',
      numPmu: numPmu,
      age: 5,
      cote: 3.0 + numPmu,
      performances: [Performance(partants: 10, rang: rang, distance: 1600, terrain: 1.0)],
    );

void main() {
  late SharedPreferences prefs;
  late FakePronosticsApi api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = FakePronosticsApi();
  });

  ProviderContainer newContainer() {
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      pronosticsApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  void chargerCourse(ProviderContainer c, int courseId) {
    c.read(horsesProvider.notifier).setAll([cheval(1, 1), cheval(2, 6)]);
    c.read(pronosticContextProvider.notifier).courseChargee(courseId);
    c.read(raceConfigProvider.notifier).update(const RaceConfig(hippodrome: 'Deauville', distance: 1600, terrain: 0.97));
  }

  test('calcul sur une course du programme : pronostic envoyé avec ses indicateurs', () async {
    final c = newContainer();
    chargerCourse(c, 42);

    c.read(resultsProvider.notifier).calculer();
    await Future<void>.delayed(Duration.zero);

    expect(api.envoyes, hasLength(1));
    final envoi = api.envoyes.single;
    expect(envoi['course_id'], 42);
    expect(envoi['installation_id'], isA<String>());
    expect((envoi['installation_id'] as String).length, greaterThanOrEqualTo(8));
    expect(envoi['donnees_modifiees'], isFalse);
    expect(envoi['reglages_par_defaut'], isTrue);
    expect(envoi['terrain'], 0.97);
    final chevaux = (envoi['chevaux'] as List).cast<Map<String, Object?>>();
    // Seuls les vrais partants : les outsiders virtuels n'ont pas de numéro.
    expect(chevaux.map((h) => h['num_pmu']), [1, 2]);
    expect((chevaux[0]['probabilite'] as double) > (chevaux[1]['probabilite'] as double), isTrue);
    expect(chevaux[0]['cote'], 4.0);
    // Toutes les sorties du moteur, pour évaluer aussi placé et combinaisons.
    expect((chevaux[0]['top3'] as double) >= (chevaux[0]['probabilite'] as double), isTrue);
    expect(chevaux[0].containsKey('top2') && chevaux[0].containsKey('top4'), isTrue);
    expect(chevaux[0].containsKey('value') && chevaux[0].containsKey('mise'), isTrue);
    final combinaisons = envoi['combinaisons'] as Map<String, Object?>;
    expect(combinaisons.keys,
        containsAll(['couple', 'trio', 'quarte', 'quinte', 'couple_place', 'deux_sur_quatre']));
    final couple = combinaisons['couple'] as Map<String, Object?>;
    expect(couple['ordre'], [[1, 2], [2, 1]]);
    expect(combinaisons['couple_place'], isA<List>());
  });

  test('cheval modifié après chargement : donnees_modifiees vrai', () async {
    final c = newContainer();
    chargerCourse(c, 42);
    c.read(horsesProvider.notifier).replaceAt(1, cheval(2, 1));

    c.read(resultsProvider.notifier).calculer();
    await Future<void>.delayed(Duration.zero);

    expect(api.envoyes.single['donnees_modifiees'], isTrue);
  });

  test('changer seulement la bankroll laisse les réglages "par défaut"', () async {
    final c = newContainer();
    chargerCourse(c, 42);
    c.read(engineParamsProvider.notifier).update(const EngineParams(bankroll: 500));

    c.read(resultsProvider.notifier).calculer();
    await Future<void>.delayed(Duration.zero);

    expect(api.envoyes.single['reglages_par_defaut'], isTrue);
  });

  test('changer un réglage du moteur : reglages_par_defaut faux', () async {
    final c = newContainer();
    chargerCourse(c, 42);
    c.read(engineParamsProvider.notifier).update(const EngineParams(contraste: 5));

    c.read(resultsProvider.notifier).calculer();
    await Future<void>.delayed(Duration.zero);

    expect(api.envoyes.single['reglages_par_defaut'], isFalse);
  });

  test('course importée ou saisie à la main : rien n\'est envoyé', () async {
    final c = newContainer();
    c.read(horsesProvider.notifier).setAll([cheval(1, 1), cheval(2, 6)]);

    c.read(resultsProvider.notifier).calculer();
    await Future<void>.delayed(Duration.zero);

    expect(api.envoyes, isEmpty);
  });

  test("l'identifiant d'installation est stable d'un calcul à l'autre", () async {
    final c = newContainer();
    chargerCourse(c, 42);
    c.read(resultsProvider.notifier).calculer();
    c.read(resultsProvider.notifier).calculer();
    await Future<void>.delayed(Duration.zero);

    expect(api.envoyes[0]['installation_id'], api.envoyes[1]['installation_id']);
  });
}
