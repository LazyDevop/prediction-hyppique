import 'course_summary.dart';

/// Course suivie (`followed-race`, story 8.9), nommée par sa clé PMU
/// `AAAAMMJJ-Rn-Cn` (AD-12), jamais par l'id autoincrément du backend.
///
/// Une course qu'on cesse de suivre garde sa ligne avec [suivie] faux : la
/// synchronisation (story 8.8) doit pouvoir l'envoyer. [date], [heureDepart]
/// et [hippodrome] sont un instantané d'affichage, pour rendre la ligne de
/// l'Accueil sans le programme en cache.
class CourseSuivie {
  final String cleCourse;
  final bool suivie;

  /// Instant de la dernière bascule, en UTC.
  final DateTime modifieeLe;

  /// Faux jusqu'à la story 8.8 (toute bascule locale le remet à faux).
  final bool synchronise;

  /// Date calendaire de la course (minuit local, sans fuseau).
  final DateTime date;

  /// Heure de départ, en UTC (affichée via `.toLocal()`).
  final DateTime? heureDepart;
  final String hippodrome;

  const CourseSuivie({
    required this.cleCourse,
    required this.suivie,
    required this.modifieeLe,
    this.synchronise = false,
    required this.date,
    this.heureDepart,
    required this.hippodrome,
  });

  /// Instantané d'une course du programme ; null sans [CourseSummary.cleCourse]
  /// (course saisie à la main ou importée par photo).
  static CourseSuivie? depuisCourse(CourseSummary course, {required bool suivie, required DateTime maintenant}) {
    final cle = course.cleCourse;
    if (cle == null) return null;
    return CourseSuivie(
      cleCourse: cle,
      suivie: suivie,
      modifieeLe: maintenant.toUtc(),
      // La date de la clé fait foi : `date` et `cle_course` ne divergent jamais.
      date: dateDeCle(cle) ?? DateTime(course.date.year, course.date.month, course.date.day),
      heureDepart: course.heureDepart?.toUtc(),
      hippodrome: course.hippodrome,
    );
  }

  /// Date `AAAAMMJJ` d'une clé PMU (minuit local), null si mal formée.
  static DateTime? dateDeCle(String cle) {
    final m = RegExp(r'^(\d{4})(\d{2})(\d{2})-').firstMatch(cle);
    if (m == null) return null;
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  /// Instantané d'affichage remis à jour depuis le programme ; `suivie`,
  /// `modifiee_le` et `synchronise` sont conservés.
  CourseSuivie avecInstantane(CourseSummary course) => CourseSuivie(
        cleCourse: cleCourse,
        suivie: suivie,
        modifieeLe: modifieeLe,
        synchronise: synchronise,
        date: date,
        heureDepart: course.heureDepart?.toUtc(),
        hippodrome: course.hippodrome,
      );

  /// Vrai si l'instantané diffère de celui de [course].
  bool instantaneDiffere(CourseSummary course) =>
      hippodrome != course.hippodrome || heureDepart != course.heureDepart?.toUtc();

  CourseSuivie basculee({required bool suivie, required DateTime maintenant}) => CourseSuivie(
        cleCourse: cleCourse,
        suivie: suivie,
        modifieeLe: maintenant.toUtc(),
        date: date,
        heureDepart: heureDepart,
        hippodrome: hippodrome,
      );

  static final _formatCle = RegExp(r'^\d{8}-R(\d+)-C(\d+)$');

  int? get numeroReunion => int.tryParse(_formatCle.firstMatch(cleCourse)?.group(1) ?? '');
  int? get numeroCourse => int.tryParse(_formatCle.firstMatch(cleCourse)?.group(2) ?? '');

  /// Date calendaire au format `AAAA-MM-JJ` (colonne `date`).
  String get dateIso => isoDate(date);

  static String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toCacheMap() => {
        'cle_course': cleCourse,
        'suivie': suivie ? 1 : 0,
        'modifiee_le': modifieeLe.toUtc().toIso8601String(),
        'synchronise': synchronise ? 1 : 0,
        'date': dateIso,
        'heure_depart': heureDepart?.toUtc().toIso8601String(),
        'hippodrome': hippodrome,
      };

  factory CourseSuivie.fromCacheMap(Map<String, Object?> map) {
    final jour = DateTime.parse(map['date'] as String);
    return CourseSuivie(
      cleCourse: map['cle_course'] as String,
      suivie: (map['suivie'] as int) != 0,
      modifieeLe: DateTime.parse(map['modifiee_le'] as String).toUtc(),
      synchronise: (map['synchronise'] as int? ?? 0) != 0,
      date: DateTime(jour.year, jour.month, jour.day),
      heureDepart: map['heure_depart'] != null ? DateTime.parse(map['heure_depart'] as String).toUtc() : null,
      hippodrome: map['hippodrome'] as String,
    );
  }
}

/// Lignes de la section « Courses suivies » : suivies, et datées
/// d'aujourd'hui ou plus tard OU pas encore parties (une réunion nocturne
/// datée d'hier qui court après minuit reste visible jusqu'à son départ).
/// Une course passée sort donc le lendemain de sa date. Tri par (date,
/// heure de départ), une course sans heure en fin de sa journée.
List<CourseSuivie> coursesSuiviesAVenir(Iterable<CourseSuivie> toutes, DateTime maintenant) {
  final aujourdhui = CourseSuivie.isoDate(maintenant.toLocal());
  final lignes = toutes
      .where((c) =>
          c.suivie && (c.dateIso.compareTo(aujourdhui) >= 0 || (c.heureDepart?.isAfter(maintenant) ?? false)))
      .toList();
  DateTime depart(CourseSuivie c) =>
      c.heureDepart ?? DateTime(c.date.year, c.date.month, c.date.day, 23, 59, 59, 999);
  lignes.sort((a, b) {
    final parDate = a.dateIso.compareTo(b.dateIso);
    return parDate != 0 ? parDate : depart(a).compareTo(depart(b));
  });
  return lignes;
}
