/// Paramètres réglables du moteur — mêmes défauts que DEFAULT_PARAMETERS
/// côté backend (section 7 du document backend).
class EngineParams {
  final String modeRecence; // 'std' | 'forme' | 'flat'
  final double malusIncident;
  final double sensibilitePoids;
  final double ageMin;
  final double ageMax;
  final double shrink;
  final double coefInedit;
  final double contraste;
  final double bankroll;
  final double fractionKelly;

  const EngineParams({
    this.modeRecence = 'std',
    this.malusIncident = 1.0,
    this.sensibilitePoids = 1.0,
    this.ageMin = 4,
    this.ageMax = 7,
    this.shrink = 2,
    this.coefInedit = 0.75,
    this.contraste = 3,
    this.bankroll = 100.0,
    this.fractionKelly = 0.25,
  });

  /// Sérialisation pour la persistance SharedPreferences (FR-20). Un seul
  /// blob JSON sous une clé unique — pas une clé par champ, l'objet ne
  /// change jamais partiellement en dehors de l'app elle-même.
  Map<String, Object?> toJson() => {
        'mode_recence': modeRecence,
        'malus_incident': malusIncident,
        'sensibilite_poids': sensibilitePoids,
        'age_min': ageMin,
        'age_max': ageMax,
        'shrink': shrink,
        'coef_inedit': coefInedit,
        'contraste': contraste,
        'bankroll': bankroll,
        'fraction_kelly': fractionKelly,
      };

  /// Ne lève jamais — un champ manquant ou mal typé retombe sur le défaut de
  /// ce champ précis plutôt que de faire échouer tout le chargement (voir
  /// EngineParamsNotifier.build, qui encadre déjà l'appel dans un try/catch
  /// pour un JSON complètement invalide ; ce fromJson gère en plus le cas
  /// JSON valide mais partiellement incohérent, ex. après un futur champ
  /// ajouté/retiré).
  factory EngineParams.fromJson(Map<String, Object?> json) {
    const defaults = EngineParams();
    double asDouble(String key, double fallback) {
      final v = json[key];
      return v is num ? v.toDouble() : fallback;
    }

    return EngineParams(
      modeRecence: json['mode_recence'] is String ? json['mode_recence'] as String : defaults.modeRecence,
      malusIncident: asDouble('malus_incident', defaults.malusIncident),
      sensibilitePoids: asDouble('sensibilite_poids', defaults.sensibilitePoids),
      ageMin: asDouble('age_min', defaults.ageMin),
      ageMax: asDouble('age_max', defaults.ageMax),
      shrink: asDouble('shrink', defaults.shrink),
      coefInedit: asDouble('coef_inedit', defaults.coefInedit),
      contraste: asDouble('contraste', defaults.contraste),
      bankroll: asDouble('bankroll', defaults.bankroll),
      fractionKelly: asDouble('fraction_kelly', defaults.fractionKelly),
    );
  }

  EngineParams copyWith({
    String? modeRecence,
    double? malusIncident,
    double? sensibilitePoids,
    double? ageMin,
    double? ageMax,
    double? shrink,
    double? coefInedit,
    double? contraste,
    double? bankroll,
    double? fractionKelly,
  }) {
    return EngineParams(
      modeRecence: modeRecence ?? this.modeRecence,
      malusIncident: malusIncident ?? this.malusIncident,
      sensibilitePoids: sensibilitePoids ?? this.sensibilitePoids,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      shrink: shrink ?? this.shrink,
      coefInedit: coefInedit ?? this.coefInedit,
      contraste: contraste ?? this.contraste,
      bankroll: bankroll ?? this.bankroll,
      fractionKelly: fractionKelly ?? this.fractionKelly,
    );
  }
}
