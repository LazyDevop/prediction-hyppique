import 'performance.dart';

/// Cheval analysé. Volontairement mutable (et non `freezed`) : le moteur
/// (engine/scoring.dart, engine/harville.dart) le remplit en plusieurs passes
/// successives, à l'identique du dataclass Python HorseAnalysis côté backend.
/// Les champs poids/âge/cote doivent toujours être présents dès la
/// construction (section 8, point 6 du document mobile) : ce sont eux qui
/// alimentent value, l'ajustement poids et l'ajustement âge.
class Horse {
  final String nom;
  final int? numPmu;
  final int? age;
  final double? poids;
  final double? cote;
  final bool inedit;
  final List<Performance> performances;

  /// Identifiant du cheval côté backend (table chevaux). Absent pour un
  /// cheval saisi manuellement (jamais rattaché à un cheval connu du
  /// backend) — c'est ce qui conditionne l'affichage du bouton "Voir tout
  /// l'historique" (section 7.4 du document mobile).
  final int? chevalId;

  int nbPerfs = 0;
  double forme = 0.0;
  double cPoids = 1.0;
  double cAge = 1.0;
  double score = 0.0;
  double probabilite = 0.0;
  double top1 = 0.0;
  double top2 = 0.0;
  double top3 = 0.0;
  double top4 = 0.0;
  double? value;
  double? kelly;
  double? mise;

  Horse({
    required this.nom,
    this.numPmu,
    this.age,
    this.poids,
    this.cote,
    this.inedit = false,
    this.performances = const [],
    this.chevalId,
  });
}
