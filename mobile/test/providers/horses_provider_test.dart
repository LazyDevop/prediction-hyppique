import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // calculer() lit engineParamsProvider, qui lit sharedPreferencesProvider
  // (FR-20, spec-3-7) : résolue une seule fois, réutilisée par chaque test.
  late SharedPreferences prefs;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  ProviderContainer newContainer() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

  group('HorsesNotifier mutations invalidate resultsProvider (FR-6)', () {
    test('add horse, no prior result -> markStale no-ops, state stays null', () {
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));

      expect(container.read(resultsProvider), isNull);
    });

    test('remove horse, result exists -> state becomes same data + isStale: true', () {
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(resultsProvider.notifier).calculer();
      final before = container.read(resultsProvider)!;
      expect(before.isStale, isFalse);

      container.read(horsesProvider.notifier).removeAt(0);
      final after = container.read(resultsProvider)!;

      expect(after.isStale, isTrue);
      expect(after.resultats, same(before.resultats));
      expect(after.combinaisons, same(before.combinaisons));
    });

    test('add horse, result already exists -> isStale: true', () {
      // Distinct from removeAt/replaceAt: proves add() itself calls
      // markStale() rather than relying on some other mutation's side
      // effect (mutation-testing gap closed per review).
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(resultsProvider.notifier).calculer();
      expect(container.read(resultsProvider)!.isStale, isFalse);

      container.read(horsesProvider.notifier).add(Horse(nom: 'B'));

      expect(container.read(resultsProvider)!.isStale, isTrue);
    });

    test('edit horse via replaceAt -> isStale: true', () {
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(resultsProvider.notifier).calculer();
      expect(container.read(resultsProvider)!.isStale, isFalse);

      container.read(horsesProvider.notifier).replaceAt(0, Horse(nom: 'A bis'));

      expect(container.read(resultsProvider)!.isStale, isTrue);
    });

    test('recalculate after stale -> new state, isStale: false', () {
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(horsesProvider.notifier).add(Horse(nom: 'B'));
      container.read(resultsProvider.notifier).calculer();

      container.read(horsesProvider.notifier).removeAt(0);
      expect(container.read(resultsProvider)!.isStale, isTrue);

      container.read(resultsProvider.notifier).calculer();

      final result = container.read(resultsProvider)!;
      expect(result.isStale, isFalse);
      expect(result.nbReels, 1);
    });

    test('clear() (new course loaded) -> resultsProvider.state becomes null, not stale', () {
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(resultsProvider.notifier).calculer();
      expect(container.read(resultsProvider), isNotNull);

      container.read(horsesProvider.notifier).clear();

      expect(container.read(resultsProvider), isNull);
      expect(container.read(horsesProvider), isEmpty);
    });

    test('setAll (spec-4-4) — bulk replace, no prior result -> state becomes the given list', () {
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).setAll([Horse(nom: 'A'), Horse(nom: 'B')]);

      expect(container.read(horsesProvider).map((h) => h.nom), ['A', 'B']);
      expect(container.read(resultsProvider), isNull);
    });

    test('setAll (spec-4-4) — result existed -> resultsProvider becomes null, not isStale', () {
      // Matches clear()'s "nouvelle course chargée" semantics (Intent de
      // spec-4-4) : un programme importé est un nouveau contexte, pas une
      // édition du précédent — jamais un bandeau "recalculer la même course".
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(resultsProvider.notifier).calculer();
      expect(container.read(resultsProvider), isNotNull);

      container.read(horsesProvider.notifier).setAll([Horse(nom: 'C')]);

      expect(container.read(resultsProvider), isNull);
      expect(container.read(horsesProvider).map((h) => h.nom), ['C']);
    });

    test('setAll (spec-4-4) — empty list -> horsesProvider becomes []', () {
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));

      container.read(horsesProvider.notifier).setAll([]);

      expect(container.read(horsesProvider), isEmpty);
    });

    test('already stale, another edit -> stays isStale: true, no redundant rebuild', () {
      final container = newContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(resultsProvider.notifier).calculer();

      container.read(horsesProvider.notifier).removeAt(0);
      final firstStale = container.read(resultsProvider);
      expect(firstStale!.isStale, isTrue);

      container.read(horsesProvider.notifier).add(Horse(nom: 'B'));
      final secondStale = container.read(resultsProvider);

      expect(secondStale!.isStale, isTrue);
      expect(identical(firstStale, secondStale), isTrue);
    });
  });
}
