import 'remote/compte_api.dart' show palierGratuit;
import 'remote/offres_api.dart' show palierExpert, palierTurfiste, rangPalier;

/// Fonctions de l'app soumises au palier (PRD FR-39).
enum Fonction {
  programme('Programme du jour'),
  partants('Liste des partants'),
  suivreCourse('Suivre une course'),
  compte('Compte'),
  offres('Offres'),
  configuration('Configuration de la course'),
  saisieManuelle('Saisie manuelle'),
  modifierPartants('Modification des partants'),
  ficheCheval('Fiche cheval'),
  importPhoto('Import photo'),
  calculLocal("Calcul sur l'appareil"),
  valueEtMise('Value et mise suggérée'),
  bankrollEtKelly('Bankroll et fraction de Kelly'),
  combinaisons('Combinaisons'),
  coefficientsMoteur('Réglages du moteur');

  /// Ce que le verrou dit débloquer, dans les termes de l'écran.
  final String libelle;
  const Fonction(this.libelle);
}

/// Matrice PRD FR-39 : palier minimal de chaque fonction. Provisoire, copie
/// côté app jusqu'à `fixtures/acces_paliers.json` (story 9.2).
const accesPaliers = <Fonction, String>{
  Fonction.programme: palierGratuit,
  Fonction.partants: palierGratuit,
  Fonction.suivreCourse: palierGratuit,
  Fonction.compte: palierGratuit,
  Fonction.offres: palierGratuit,
  Fonction.configuration: palierTurfiste,
  Fonction.saisieManuelle: palierTurfiste,
  Fonction.modifierPartants: palierTurfiste,
  Fonction.ficheCheval: palierTurfiste,
  Fonction.importPhoto: palierTurfiste,
  Fonction.calculLocal: palierTurfiste,
  Fonction.valueEtMise: palierTurfiste,
  Fonction.bankrollEtKelly: palierTurfiste,
  Fonction.combinaisons: palierExpert,
  Fonction.coefficientsMoteur: palierExpert,
};

/// Palier minimal de [f] (une fonction absente de la matrice : Expert).
String palierRequis(Fonction f) => accesPaliers[f] ?? palierExpert;

/// Vrai si [palier] ouvre [f]. Un palier inconnu vaut Gratuit.
bool palierAutorise(String palier, Fonction f) => rangPalier(palier) >= rangPalier(palierRequis(f));
