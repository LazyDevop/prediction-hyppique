import '../engine/constants.dart';
import '../models/horse.dart';

/// Unique source de vérité des trois libellés de transparence FR-4 :
/// "🐎 Inédit", "Données non saisies", "Historique court (N)". Les deux
/// écrans qui affichent ces états (`horse_card.dart`, pré-calcul, et
/// `results_screen.dart`, post-calcul) délèguent tous deux à cette fonction
/// plutôt que de re-dériver le seuil ou les libellés chacun de leur côté
/// (spec-3-3, "Approach").
///
/// [nbPerfs] est fourni par l'appelant plutôt que lu directement sur
/// [horse] : `horse_card.dart` doit passer `horse.performances.length`
/// (compte brut, `Horse.nbPerfs` valant toujours 0 avant `analyseCourse`)
/// tandis que `results_screen.dart` doit passer `h.nbPerfs` (compte filtré
/// NR, calculé par le moteur) — voir Design Notes de la spec.
///
/// Historique complet (`nbPerfs >= recenceStd.length`, la vraie fenêtre de
/// récence du moteur) : retourne `null`. "Silence = signal" — l'appelant
/// n'affiche alors aucun badge plutôt que d'inventer une valeur de
/// régularité non spécifiée.
String? transparencyLabel(Horse horse, int nbPerfs) {
  if (horse.inedit) return '🐎 Inédit';
  if (nbPerfs == 0) return 'Données non saisies';
  if (nbPerfs < recenceStd.length) return 'Historique court ($nbPerfs)';
  return null;
}
