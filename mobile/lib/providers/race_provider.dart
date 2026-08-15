import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/race_config.dart';

class RaceConfigNotifier extends Notifier<RaceConfig> {
  @override
  RaceConfig build() => const RaceConfig(hippodrome: 'Vincennes', distance: 2000, terrain: 1.0, niveau: 3.0);

  void update(RaceConfig config) => state = config;
}

final raceConfigProvider = NotifierProvider<RaceConfigNotifier, RaceConfig>(RaceConfigNotifier.new);
