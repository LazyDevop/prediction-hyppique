/// Constantes du moteur — copiées à l'identique de la section 7 du document
/// backend (cahier_des_charges_backend_hippique.md). En cas de divergence,
/// le document backend fait foi : ne pas modifier ces valeurs ici sans les
/// répercuter côté Python.
library;

import 'dart:developer' as developer;

class IncidentDefinition {
  final double malus;
  final bool chute;
  final bool ignore;

  const IncidentDefinition({
    required this.malus,
    required this.chute,
    this.ignore = false,
  });
}

const Map<String, double> terrainCoefficientsGazon = {
  'Très léger': 1.08,
  'Léger': 1.05,
  'Bon léger': 1.02,
  'Bon': 1.00,
  'Bon souple': 0.97,
  'Souple': 0.93,
  'Très souple': 0.88,
  'Collant': 0.83,
  'Lourd': 0.77,
  'Très lourd': 0.70,
};

const Map<String, double> terrainCoefficientsPsf = {
  'Rapide': 1.00,
  'Standard': 0.99,
  'Lent': 0.95,
};

const Map<String, double> niveauCoefficients = {
  'Groupe I': 5.0,
  'Groupe II': 4.5,
  'Groupe III': 4.0,
  'Groupe IV': 3.5,
  'Listed': 3.0,
  'Catégorie A': 2.6,
  'Catégorie B': 2.3,
  'Catégorie C': 2.0,
  'Handicap': 2.001,
  'Catégorie D': 1.7,
  'Catégorie E': 1.4,
  'Catégorie F': 1.1,
  'Catégorie G/H': 1.0,
  'Maiden': 1.001,
  'Inédits': 1.002,
};

// NR exclut la ligne du calcul (ignore=true) ; les autres codes appliquent un
// malus soustractif à la note de la ligne plutôt que de la traiter comme une
// simple dernière place (section 7.4 du document backend).
const Map<String, IncidentDefinition> incidents = {
  'T': IncidentDefinition(malus: 1.2, chute: true),
  'F': IncidentDefinition(malus: 1.2, chute: true),
  'BD': IncidentDefinition(malus: 1.0, chute: true),
  'U': IncidentDefinition(malus: 1.0, chute: true),
  'A': IncidentDefinition(malus: 0.7, chute: false),
  'RO': IncidentDefinition(malus: 0.7, chute: true),
  'RR': IncidentDefinition(malus: 0.7, chute: false),
  'D': IncidentDefinition(malus: 0.8, chute: false),
  'R': IncidentDefinition(malus: 0.5, chute: false),
  'NR': IncidentDefinition(malus: 0.0, chute: false, ignore: true),
};

double? terrainCoefficient(String? label) {
  if (label == null) return null;
  if (terrainCoefficientsGazon.containsKey(label)) {
    return terrainCoefficientsGazon[label];
  }
  if (terrainCoefficientsPsf.containsKey(label)) {
    return terrainCoefficientsPsf[label];
  }
  return null;
}

/// Résolution du label de niveau vers son coefficient (Architecture Spine
/// AD-5) — symétrique de [terrainCoefficient] : un label `null` est un état
/// "non renseigné" silencieux, mais un label non-null absent de
/// [niveauCoefficients] est une anomalie distincte (faute de frappe, libellé
/// jamais synchronisé avec le backend...) et ne doit jamais être confondue
/// avec l'absence de valeur — elle est donc signalée via un log nommé
/// plutôt que simplement absorbée dans le même `null` de retour.
double? niveauCoefficient(String? label) {
  if (label == null) return null;
  final value = niveauCoefficients[label];
  if (value == null) {
    developer.log(
      'Label de niveau non reconnu : "$label"',
      name: 'niveau_label_unrecognized',
    );
  }
  return value;
}

// Pondération de récence : index 0 = C1 = course la plus récente = poids max.
const List<double> recenceStd = [1.00, 0.85, 0.70, 0.55, 0.42, 0.30];
const List<double> recenceForme = [1.00, 0.65, 0.42, 0.28, 0.18, 0.12];
const List<double> recenceFlat = [1.00, 1.00, 1.00, 1.00, 1.00, 1.00];
