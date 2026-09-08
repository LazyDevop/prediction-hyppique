import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/race_config.dart';
import 'results_provider.dart';

class RaceConfigNotifier extends Notifier<RaceConfig> {
  @override
  RaceConfig build() => const RaceConfig(hippodrome: 'Vincennes', distance: 2000, terrain: 1.0, niveau: 3.0);

  // Périme un résultat déjà calculé (FR-13/FR-6 — voir spec-3-6) : un résultat
  // affiché doit toujours refléter la config qui l'a produit. No-op si aucun
  // résultat n'existe (ex. chargement d'une toute nouvelle course, où
  // horsesProvider.clear() a déjà remis resultsProvider à null juste avant).
  void update(RaceConfig config) {
    state = config;
    ref.read(resultsProvider.notifier).markStale();
  }
}

final raceConfigProvider = NotifierProvider<RaceConfigNotifier, RaceConfig>(RaceConfigNotifier.new);
