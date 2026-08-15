import '../engine/constants.dart';

/// Une performance passée d'un cheval (une des ~6 dernières courses).
/// terrain est nullable : l'historique issu du backend PMU ne fournit pas la
/// pénétrométrie (limitation connue, cf. section 10 du document backend).
class Performance {
  final int partants;
  final int? rang;
  final double? distance;
  final double? terrain;
  final double? niveau;
  final String? incident;

  const Performance({
    required this.partants,
    this.rang,
    this.distance,
    this.terrain,
    this.niveau,
    this.incident,
  });

  bool get isNr {
    if (incident == null) return false;
    final def = incidents[incident];
    return def?.ignore ?? false;
  }
}
