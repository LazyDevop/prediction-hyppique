/// Une ligne de l'historique complet d'un cheval, renvoyée par
/// POST /chevaux/{id}/backfill (section 7.4 du document mobile). Distincte
/// du modèle Performance utilisé par le moteur : purement informative,
/// jamais éditable, jamais consommée par computeForme (qui reste limité aux
/// 6 lignes saisies dans la fiche cheval — comportement inchangé côté
/// calcul, voir engine/scoring.dart).
class HistoriquePerformance {
  final DateTime? dateCourse;
  final String? hippodrome;
  final String? discipline;
  final double? allocation;
  final double? distance;
  final int? nbParticipants;
  final int? rang;
  final String? terrain;
  final String? incident;

  const HistoriquePerformance({
    this.dateCourse,
    this.hippodrome,
    this.discipline,
    this.allocation,
    this.distance,
    this.nbParticipants,
    this.rang,
    this.terrain,
    this.incident,
  });

  factory HistoriquePerformance.fromJson(Map<String, dynamic> json) {
    return HistoriquePerformance(
      dateCourse: json['date_course'] != null ? DateTime.tryParse(json['date_course'] as String) : null,
      hippodrome: json['hippodrome'] as String?,
      discipline: json['discipline'] as String?,
      allocation: (json['allocation'] as num?)?.toDouble(),
      distance: (json['distance'] as num?)?.toDouble(),
      nbParticipants: json['nb_participants'] as int?,
      rang: json['rang'] as int?,
      terrain: json['terrain'] as String?,
      incident: json['incident'] as String?,
    );
  }

  /// Sérialisation pour le cache local SQLite (data/local/database_helper.dart).
  Map<String, Object?> toCacheMap(int chevalId) => {
        'cheval_id': chevalId,
        'date_course': dateCourse?.toIso8601String(),
        'hippodrome': hippodrome,
        'discipline': discipline,
        'allocation': allocation,
        'distance': distance,
        'nb_participants': nbParticipants,
        'rang': rang,
        'terrain': terrain,
        'incident': incident,
      };

  factory HistoriquePerformance.fromCacheMap(Map<String, Object?> map) {
    return HistoriquePerformance(
      dateCourse: map['date_course'] != null ? DateTime.tryParse(map['date_course'] as String) : null,
      hippodrome: map['hippodrome'] as String?,
      discipline: map['discipline'] as String?,
      allocation: (map['allocation'] as num?)?.toDouble(),
      distance: (map['distance'] as num?)?.toDouble(),
      nbParticipants: map['nb_participants'] as int?,
      rang: map['rang'] as int?,
      terrain: map['terrain'] as String?,
      incident: map['incident'] as String?,
    );
  }
}
