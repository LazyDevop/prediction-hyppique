import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engine_params.dart';
import 'results_provider.dart';

class EngineParamsNotifier extends Notifier<EngineParams> {
  @override
  EngineParams build() => const EngineParams();

  // Périme un résultat déjà calculé (FR-13/FR-6 — voir spec-3-6) : changer un
  // réglage doit produire un effet démontrable au recalcul, jamais laisser un
  // classement silencieusement obsolète affiché comme à jour.
  void update(EngineParams params) {
    state = params;
    ref.read(resultsProvider.notifier).markStale();
  }
}

final engineParamsProvider = NotifierProvider<EngineParamsNotifier, EngineParams>(EngineParamsNotifier.new);
