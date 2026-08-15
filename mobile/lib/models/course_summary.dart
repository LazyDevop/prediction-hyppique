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
}
