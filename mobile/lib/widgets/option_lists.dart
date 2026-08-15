/// Listes d'options pour les menus déroulants — mêmes libellés que les deux
/// prototypes (analyse_hippique_v2.html / analyse_hippique_ia.jsx).
const List<MapEntry<double, String>> terrainOptions = [
  MapEntry(1.08, 'Très léger'),
  MapEntry(1.05, 'Léger'),
  MapEntry(1.02, 'Bon léger'),
  MapEntry(1.0, 'Bon'),
  MapEntry(0.97, 'Bon souple'),
  MapEntry(0.93, 'Souple'),
  MapEntry(0.88, 'Très souple'),
  MapEntry(0.83, 'Collant'),
  MapEntry(0.77, 'Lourd'),
  MapEntry(0.70, 'Très lourd'),
  MapEntry(1.001, 'Rapide (PSF)'),
  MapEntry(0.99, 'Standard (PSF)'),
  MapEntry(0.95, 'Lent (PSF)'),
];

const List<MapEntry<double, String>> niveauOptions = [
  MapEntry(5.0, 'Groupe I'),
  MapEntry(4.5, 'Groupe II'),
  MapEntry(4.0, 'Groupe III'),
  MapEntry(3.5, 'Groupe IV'),
  MapEntry(3.0, 'Listed'),
  MapEntry(2.6, 'Catégorie A'),
  MapEntry(2.3, 'Catégorie B'),
  MapEntry(2.0, 'Catégorie C'),
  // 2.001 (au lieu de 2.0) pour éviter une valeur de dropdown en double avec
  // Catégorie C — poids identique en pratique.
  MapEntry(2.001, 'Handicap'),
  MapEntry(1.7, 'Catégorie D'),
  MapEntry(1.4, 'Catégorie E'),
  MapEntry(1.1, 'Catégorie F'),
  MapEntry(1.0, 'Catégorie G/H'),
  // 1.001 / 1.002 (au lieu de 1.0) pour éviter une valeur de dropdown en
  // double avec Catégorie G/H — poids identique en pratique.
  MapEntry(1.001, 'Maiden'),
  MapEntry(1.002, 'Inédits'),
];

// '' (vide) = pas d'incident ; n'existe pas dans engine/constants.dart (le
// backend n'a pas cette entrée), c'est un choix propre à la couche UI.
const List<MapEntry<String, String>> incidentOptions = [
  MapEntry('', '—'),
  MapEntry('T', 'T · Tombé'),
  MapEntry('F', 'F · Fell'),
  MapEntry('BD', 'BD · Brought Down'),
  MapEntry('U', 'U · Désarçonné'),
  MapEntry('A', 'A · Arrêté'),
  MapEntry('RO', 'RO · Sorti piste'),
  MapEntry('RR', 'RR · Refus départ'),
  MapEntry('D', 'D · Disqualifié'),
  MapEntry('R', 'R · Rétrogradé'),
  MapEntry('NR', 'NR · Non partant'),
];

const List<MapEntry<String, String>> modeRecenceOptions = [
  MapEntry('std', 'Standard (dégressif)'),
  MapEntry('forme', 'Forme récente (fort)'),
  MapEntry('flat', 'Uniforme (aucune)'),
];
