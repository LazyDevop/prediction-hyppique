import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';

void main() {
  group('HorsesNotifier mutations invalidate resultsProvider (FR-6)', () {
    test('add horse, no prior result -> markStale no-ops, state stays null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));

      expect(container.read(resultsProvider), isNull);
    });

    test('remove horse, result exists -> state becomes same data + isStale: true', () {
      final container = ProviderContainer();
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
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(resultsProvider.notifier).calculer();
      expect(container.read(resultsProvider)!.isStale, isFalse);

      container.read(horsesProvider.notifier).add(Horse(nom: 'B'));

      expect(container.read(resultsProvider)!.isStale, isTrue);
    });

    test('edit horse via replaceAt -> isStale: true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(resultsProvider.notifier).calculer();
      expect(container.read(resultsProvider)!.isStale, isFalse);

      container.read(horsesProvider.notifier).replaceAt(0, Horse(nom: 'A bis'));

      expect(container.read(resultsProvider)!.isStale, isTrue);
    });

    test('recalculate after stale -> new state, isStale: false', () {
      final container = ProviderContainer();
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
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(horsesProvider.notifier).add(Horse(nom: 'A'));
      container.read(resultsProvider.notifier).calculer();
      expect(container.read(resultsProvider), isNotNull);

      container.read(horsesProvider.notifier).clear();

      expect(container.read(resultsProvider), isNull);
      expect(container.read(horsesProvider), isEmpty);
    });

    test('already stale, another edit -> stays isStale: true, no redundant rebuild', () {
      final container = ProviderContainer();
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
