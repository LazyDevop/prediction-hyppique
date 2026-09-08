// Couverture de spec-3-6-stale-on-config-param-change.md : changer la
// config course ou un réglage moteur doit périmer un résultat déjà calculé,
// même règle que HorsesNotifier (horses_provider_test.dart).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prediction_hippique/engine/combinatoire.dart';
import 'package:prediction_hippique/models/engine_params.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/models/race_config.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/race_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    // EngineParamsNotifier.build() lit sharedPreferencesProvider (FR-20,
    // spec-3-7) : même override minimal que main.dart, sans quoi il lève.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() => container.dispose());

  void seedResult() {
    ComboOrdreDesordre empty() => ComboOrdreDesordre([], []);
    container.read(resultsProvider.notifier).state = AnalyseResult(
      const [],
      0,
      Combinaisons(
        couple: empty(),
        trio: empty(),
        quarte: empty(),
        quinte: empty(),
        couplePlace: [],
        deuxSurQuatre: [],
      ),
    );
  }

  group('RaceConfigNotifier.update marks resultsProvider stale', () {
    test('config changée, aucun résultat -> markStale no-op, état reste null', () {
      container.read(raceConfigProvider.notifier).update(
            const RaceConfig(hippodrome: 'Chantilly', distance: 1600, terrain: 1.0, niveau: 3.0),
          );

      expect(container.read(resultsProvider), isNull);
    });

    test('config changée, résultat existant -> isStale: true', () {
      seedResult();

      container.read(raceConfigProvider.notifier).update(
            const RaceConfig(hippodrome: 'Chantilly', distance: 1600, terrain: 1.0, niveau: 3.0),
          );

      expect(container.read(resultsProvider)!.isStale, isTrue);
    });
  });

  group('EngineParamsNotifier.update marks resultsProvider stale', () {
    test('réglage changé, aucun résultat -> markStale no-op, état reste null', () {
      container.read(engineParamsProvider.notifier).update(const EngineParams(bankroll: 200));

      expect(container.read(resultsProvider), isNull);
    });

    test('réglage changé, résultat existant -> isStale: true', () {
      seedResult();

      container.read(engineParamsProvider.notifier).update(const EngineParams(bankroll: 200));

      expect(container.read(resultsProvider)!.isStale, isTrue);
    });
  });

  test(
    'séquence complète _selectCourse (clear -> add -> update config) -> aucun faux positif',
    () {
      seedResult();

      // Reproduit exactement home_screen.dart _selectCourse.
      container.read(horsesProvider.notifier).clear(); // -> resultsProvider.clear() (null)
      container.read(horsesProvider.notifier).add(Horse(nom: 'Foudre Noire'));
      container.read(raceConfigProvider.notifier).update(
            const RaceConfig(hippodrome: 'Vincennes', distance: 2000, terrain: 1.0, niveau: 3.0),
          );

      // Aucun résultat n'a jamais existé depuis le clear() -> jamais de bandeau.
      expect(container.read(resultsProvider), isNull);
    },
  );
}
