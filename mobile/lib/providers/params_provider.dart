import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/engine_params.dart';
import 'results_provider.dart';

const _prefsKey = 'engine_params';

/// Résolu de façon synchrone au démarrage (main.dart, avant runApp) et
/// injecté via override — permet à EngineParamsNotifier.build() de rester
/// un Notifier synchrone comme tous les autres providers de l'app, plutôt
/// qu'un AsyncNotifier qui compliquerait chaque écran consommateur.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider doit être surchargé avant runApp (voir main.dart)'),
);

class EngineParamsNotifier extends Notifier<EngineParams> {
  @override
  EngineParams build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const EngineParams();
    try {
      return EngineParams.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (e) {
      // Blob corrompu (JSON invalide, forme inattendue) : ne jamais faire
      // planter l'app pour un réglage — retombe sur les défauts, loggé.
      developer.log('Réglages moteur illisibles, retour aux défauts : $e', name: 'EngineParamsNotifier');
      return const EngineParams();
    }
  }

  void _persist(EngineParams params) {
    ref.read(sharedPreferencesProvider).setString(_prefsKey, jsonEncode(params.toJson()));
  }

  // Périme un résultat déjà calculé (FR-13/FR-6 — voir spec-3-6). Persiste
  // avant de notifier, pour que le prochain build() (même sans redémarrage)
  // voie déjà la valeur à jour.
  void update(EngineParams params) {
    state = params;
    _persist(params);
    ref.read(resultsProvider.notifier).markStale();
  }

  /// Réinitialisation en un geste (FR-20). Persistée comme n'importe quel
  /// autre changement — un redémarrage juste après ne doit pas ressusciter
  /// les anciennes valeurs personnalisées.
  void reset() => update(const EngineParams());
}

final engineParamsProvider = NotifierProvider<EngineParamsNotifier, EngineParams>(EngineParamsNotifier.new);
