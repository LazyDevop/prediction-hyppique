// Couverture de spec-3-7-settings-persistence-and-reset.md (FR-20) : les
// réglages moteur doivent survivre à un redémarrage (persistance
// SharedPreferences) et la réinitialisation doit revenir aux défauts en un
// geste, elle aussi persistée.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prediction_hippique/engine/combinatoire.dart';
import 'package:prediction_hippique/models/engine_params.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';

void main() {
  Future<ProviderContainer> containerWithPrefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('premier lancement, aucune valeur stockée -> défauts', () async {
    final container = await containerWithPrefs({});

    expect(container.read(engineParamsProvider), const EngineParams());
  });

  test('redémarrage après personnalisation -> valeurs stockées relues', () async {
    const customized = EngineParams(bankroll: 500, contraste: 5, modeRecence: 'forme');
    final firstRun = await containerWithPrefs({});
    firstRun.read(engineParamsProvider.notifier).update(customized);
    // Simule un redémarrage : nouveau container sur la même SharedPreferences
    // (setMockInitialValues n'est pas ré-appelé, l'instance partagée persiste).
    final prefs = await SharedPreferences.getInstance();
    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);

    final reloaded = restarted.read(engineParamsProvider);
    expect(reloaded.bankroll, 500);
    expect(reloaded.contraste, 5);
    expect(reloaded.modeRecence, 'forme');
  });

  test('valeur stockée corrompue -> repli sur les défauts, ne lève pas', () async {
    final container = await containerWithPrefs({'engine_params': 'pas du json valide'});

    expect(container.read(engineParamsProvider), const EngineParams());
  });

  test('update() persiste immédiatement (relecture directe des prefs)', () async {
    final container = await containerWithPrefs({});

    container.read(engineParamsProvider.notifier).update(const EngineParams(bankroll: 250));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('engine_params');
    expect(raw, isNotNull);
    expect(raw, contains('250'));
  });

  group('reset()', () {
    test('sans résultat existant -> revient aux défauts, pas de bandeau périmé', () async {
      final container = await containerWithPrefs({});
      container.read(engineParamsProvider.notifier).update(const EngineParams(bankroll: 999));

      container.read(engineParamsProvider.notifier).reset();

      expect(container.read(engineParamsProvider), const EngineParams());
      expect(container.read(resultsProvider), isNull);
    });

    test('avec résultat existant -> périme le résultat (isStale)', () async {
      final container = await containerWithPrefs({});
      container.read(engineParamsProvider.notifier).update(const EngineParams(bankroll: 999));
      // Réutilise le même seeding minimal que race_and_params_provider_test.
      container.read(resultsProvider.notifier).state = AnalyseResult(
        const [],
        0,
        Combinaisons(
          couple: ComboOrdreDesordre([], []),
          trio: ComboOrdreDesordre([], []),
          quarte: ComboOrdreDesordre([], []),
          quinte: ComboOrdreDesordre([], []),
          couplePlace: [],
          deuxSurQuatre: [],
        ),
      );

      container.read(engineParamsProvider.notifier).reset();

      expect(container.read(engineParamsProvider), const EngineParams());
      expect(container.read(resultsProvider)!.isStale, isTrue);
    });

    test('reset() persiste les défauts (un redémarrage juste après ne les ressuscite pas)', () async {
      final container = await containerWithPrefs({});
      container.read(engineParamsProvider.notifier).update(const EngineParams(bankroll: 999));

      container.read(engineParamsProvider.notifier).reset();

      final prefs = await SharedPreferences.getInstance();
      final restarted = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(restarted.dispose);
      // EngineParams n'a pas d'operator== : la valeur relue passe par
      // fromJson() (nouvelle instance), pas par le const canonique — compare
      // les champs plutôt que l'identité d'objet.
      expect(restarted.read(engineParamsProvider).bankroll, const EngineParams().bankroll);
    });
  });
}
