/// Course cible de l'analyse (équivalent du CourseTarget backend).
/// nbPartantsCourse nullable : "auto" tant que l'utilisateur ne le renseigne
/// pas explicitement — résolu à la taille du lot saisi dans addOutsiders.
class RaceConfig {
  final String hippodrome;
  final double? distance;
  final double? terrain;
  final double? niveau;
  final int? nbPartantsCourse;

  const RaceConfig({
    this.hippodrome = '',
    this.distance,
    this.terrain,
    this.niveau,
    this.nbPartantsCourse,
  });

  RaceConfig copyWith({
    String? hippodrome,
    double? distance,
    double? terrain,
    double? niveau,
    int? nbPartantsCourse,
  }) {
    return RaceConfig(
      hippodrome: hippodrome ?? this.hippodrome,
      distance: distance ?? this.distance,
      terrain: terrain ?? this.terrain,
      niveau: niveau ?? this.niveau,
      nbPartantsCourse: nbPartantsCourse ?? this.nbPartantsCourse,
    );
  }
}
