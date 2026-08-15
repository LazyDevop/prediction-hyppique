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

  AnalyseResult(this.resultats, this.nbReels, this.combinaisons);
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
    state = AnalyseResult(resultats, horses.length, combinaisons);
  }

  void clear() => state = null;
}

final resultsProvider = NotifierProvider<ResultsNotifier, AnalyseResult?>(ResultsNotifier.new);
