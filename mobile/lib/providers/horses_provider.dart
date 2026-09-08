import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/horse.dart';
import 'results_provider.dart';

class HorsesNotifier extends Notifier<List<Horse>> {
  @override
  List<Horse> build() => [];

  void add(Horse horse) {
    state = [...state, horse];
    ref.read(resultsProvider.notifier).markStale();
  }

  void replaceAt(int index, Horse horse) {
    final copy = List<Horse>.from(state);
    copy[index] = horse;
    state = copy;
    ref.read(resultsProvider.notifier).markStale();
  }

  void removeAt(int index) {
    final copy = List<Horse>.from(state)..removeAt(index);
    state = copy;
    ref.read(resultsProvider.notifier).markStale();
  }

  /// Nouvelle course chargée (home_screen.dart `_selectCourse`) : contexte
  /// entièrement différent, pas une édition — réinitialise le résultat au
  /// lieu de le marquer périmé, pour ne pas afficher un bandeau "recalculer
  /// la même course" trompeur.
  void clear() {
    state = [];
    ref.read(resultsProvider.notifier).clear();
  }
}

final horsesProvider = NotifierProvider<HorsesNotifier, List<Horse>>(HorsesNotifier.new);
