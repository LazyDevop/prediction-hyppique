import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/combinatoire.dart';
import '../engine/scoring.dart';
import '../models/horse.dart';
import 'horses_provider.dart';
import 'params_provider.dart';
import 'race_provider.dart';

class AnalyseResult {
  final List<Horse> resultats;
  final int nbReels;
  final Combinaisons combinaisons;
  final bool isStale;

  AnalyseResult(this.resultats, this.nbReels, this.combinaisons, {this.isStale = false});
}

class ResultsNotifier extends Notifier<AnalyseResult?> {
  @override
  AnalyseResult? build() => null;

  void calculer() {
    final horses = ref.read(horsesProvider);
    final target = ref.read(raceConfigProvider);
    final params = ref.read(engineParamsProvider);

    final resultats = analyseCourse(horses, target, params: params);
    final combinaisons = buildCombinaisons(resultats, horses.length);
    state = AnalyseResult(resultats, horses.length, combinaisons, isStale: false);
  }

  /// Marque le résultat courant comme périmé (partants modifiés depuis le
  /// calcul). No-op si aucun résultat n'existe encore ou s'il est déjà
  /// périmé — évite un rebuild Riverpod inutile. Remplace l'état par une
  /// nouvelle instance (mêmes données, isStale: true) : muter en place ne
  /// déclencherait aucun listener.
  void markStale() {
    final current = state;
    if (current == null || current.isStale) return;
    state = AnalyseResult(current.resultats, current.nbReels, current.combinaisons, isStale: true);
  }

  /// Appelé par `HorsesNotifier.clear()` quand une toute nouvelle course est
  /// chargée — une réinitialisation complète, pas un marquage périmé, parce
  /// que c'est un contexte entièrement différent, pas une édition du
  /// résultat courant.
  void clear() => state = null;
}

final resultsProvider = NotifierProvider<ResultsNotifier, AnalyseResult?>(ResultsNotifier.new);
