/// Miroir Dart de `backend/app/schemas/extraction.py` (`ProgrammeExtraitOut`
/// / `HorseProgrammeOut` / `PerfProgrammeOut`) — réponse de
/// `POST /extraction/programme` (Story 4.2), affichée en lecture seule et
/// marquée "à vérifier" par `import_photo_screen.dart` (section 7.5 du
/// document mobile). Classe simple + `fromJson`, même convention que
/// `CourseSummary` (`freezed` est listé dans pubspec.yaml mais inutilisé par
/// les modèles existants — spec-4-3).
// Helper top-level (hors des classes) : `HorseProgrammeExtrait` déclare un
// champ nommé `num`, qui masquerait le type `num` de dart:core si on
// écrivait `as num?` directement dans son `fromJson` (piège Dart connu).
double? _asDouble(dynamic v) => (v as num?)?.toDouble();

class PerfProgrammeExtrait {
  final int? rank;
  final String incident;

  const PerfProgrammeExtrait({this.rank, required this.incident});

  factory PerfProgrammeExtrait.fromJson(Map<String, dynamic> json) {
    return PerfProgrammeExtrait(
      rank: json['rank'] as int?,
      incident: json['incident'] as String,
    );
  }
}

class HorseProgrammeExtrait {
  final int? num;
  final String? name;
  final int? age;
  final double? poids;
  final double? cote;
  final List<PerfProgrammeExtrait> perfs;

  const HorseProgrammeExtrait({
    this.num,
    this.name,
    this.age,
    this.poids,
    this.cote,
    this.perfs = const [],
  });

  factory HorseProgrammeExtrait.fromJson(Map<String, dynamic> json) {
    return HorseProgrammeExtrait(
      num: json['num'] as int?,
      name: json['name'] as String?,
      age: json['age'] as int?,
      poids: _asDouble(json['poids']),
      cote: _asDouble(json['cote']),
      perfs: (json['perfs'] as List<dynamic>? ?? [])
          .map((p) => PerfProgrammeExtrait.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Racine de la réponse `/extraction/programme` — hippodrome/distance/
/// terrain/niveau/partants de la course cible + la liste des partants
/// extraits. `dist`/`terr`/`niveau` restent les noms de champs bruts du
/// backend (pas de renommage, pour rester un miroir direct et vérifiable).
class ProgrammeExtrait {
  final String? hippo;
  final double? dist;
  final double? terr;
  final double? niveau;
  final int? partants;
  final List<HorseProgrammeExtrait> horses;

  const ProgrammeExtrait({
    this.hippo,
    this.dist,
    this.terr,
    this.niveau,
    this.partants,
    this.horses = const [],
  });

  factory ProgrammeExtrait.fromJson(Map<String, dynamic> json) {
    return ProgrammeExtrait(
      hippo: json['hippo'] as String?,
      dist: _asDouble(json['dist']),
      terr: _asDouble(json['terr']),
      niveau: _asDouble(json['niveau']),
      partants: json['partants'] as int?,
      horses: (json['horses'] as List<dynamic>? ?? [])
          .map((h) => HorseProgrammeExtrait.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }
}
