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
