/// Résumé d'une course du programme (équivalent du schéma backend CourseOut).
class CourseSummary {
  final int id;
  final DateTime date;
  final DateTime? heureDepart;
  final String hippodrome;
  final String discipline;
  final double? distance;
  final double? allocation;
  final int? nbPartants;
  final String? corde;
  final String? terrain;
  final String? niveauEstime;
  final bool finalisee;
  final String source;

  const CourseSummary({
    required this.id,
    required this.date,
    this.heureDepart,
    required this.hippodrome,
    required this.discipline,
    this.distance,
    this.allocation,
    this.nbPartants,
    this.corde,
    this.terrain,
    this.niveauEstime,
    required this.finalisee,
    required this.source,
  });

  factory CourseSummary.fromJson(Map<String, dynamic> json) {
    return CourseSummary(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      heureDepart: json['heure_depart'] != null ? DateTime.parse(json['heure_depart'] as String) : null,
      hippodrome: json['hippodrome'] as String,
      discipline: json['discipline'] as String,
      distance: (json['distance'] as num?)?.toDouble(),
      allocation: (json['allocation'] as num?)?.toDouble(),
      nbPartants: json['nb_partants'] as int?,
      corde: json['corde'] as String?,
      terrain: json['terrain'] as String?,
      niveauEstime: json['niveau_estime'] as String?,
      finalisee: json['finalisee'] as bool,
      source: json['source'] as String,
    );
  }

  /// Sérialisation pour le cache local SQLite (data/local/database_helper.dart,
  /// table programme_courses — FR-1/FR-14). Même convention que
  /// HistoriquePerformance.toCacheMap.
  Map<String, Object?> toCacheMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'heure_depart': heureDepart?.toIso8601String(),
        'hippodrome': hippodrome,
        'discipline': discipline,
        'distance': distance,
        'allocation': allocation,
        'nb_partants': nbPartants,
        'corde': corde,
        'terrain': terrain,
        'niveau_estime': niveauEstime,
        'finalisee': finalisee ? 1 : 0,
        'source': source,
      };

  factory CourseSummary.fromCacheMap(Map<String, Object?> map) {
    return CourseSummary(
      id: map['id'] as int,
      date: DateTime.parse(map['date'] as String),
      heureDepart: map['heure_depart'] != null ? DateTime.parse(map['heure_depart'] as String) : null,
      hippodrome: map['hippodrome'] as String,
      discipline: map['discipline'] as String,
      distance: (map['distance'] as num?)?.toDouble(),
      allocation: (map['allocation'] as num?)?.toDouble(),
      nbPartants: map['nb_partants'] as int?,
      corde: map['corde'] as String?,
      terrain: map['terrain'] as String?,
      niveauEstime: map['niveau_estime'] as String?,
      finalisee: (map['finalisee'] as int) != 0,
      source: map['source'] as String,
    );
  }
}
