import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/combinatoire.dart';
import '../engine/scoring.dart';
import '../models/engine_params.dart';
import '../models/horse.dart';
import 'horses_provider.dart';
import 'params_provider.dart';
import 'pronostic_provider.dart';
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
    _envoyerPronostic(resultats, target.terrain, params);
  }

  /// Transmis au backend pour être comparé à l'arrivée officielle (tableau
  /// de bord). En arrière-plan : un échec réseau ou un refus (course déjà
  /// partie) ne doit jamais gêner l'utilisateur.
  void _envoyerPronostic(List<Horse> resultats, double? terrain, EngineParams params) {
    final contexte = ref.read(pronosticContextProvider);
    final courseId = contexte.courseId;
    if (courseId == null) return;

    final pronostic = <String, Object?>{
      'course_id': courseId,
      'installation_id': ref.read(installationIdProvider),
      'chevaux': [
        for (final h in resultats)
          if (h.numPmu != null) {'num_pmu': h.numPmu, 'probabilite': h.probabilite, 'cote': h.cote},
      ],
      'parametres': params.toJson(),
      'reglages_par_defaut': _reglagesMoteur(params) == _reglagesMoteur(const EngineParams()),
      'donnees_modifiees': contexte.donneesModifiees,
      'terrain': terrain,
    };
    unawaited(ref.read(pronosticsApiProvider).envoyerPronostic(pronostic).catchError((Object e) {
      developer.log('Pronostic non transmis : $e', name: 'ResultsNotifier');
    }));
  }

  /// Bankroll et fraction de Kelly ne changent que la mise suggérée, pas les
  /// probabilités : les modifier ne fait pas un pronostic "réglé".
  static String _reglagesMoteur(EngineParams params) {
    final reglages = Map<String, Object?>.from(params.toJson())
      ..remove('bankroll')
      ..remove('fraction_kelly');
    return jsonEncode(reglages);
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
