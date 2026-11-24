import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:prediction_hippique/data/remote/offres_api.dart';
import 'package:prediction_hippique/providers/palier_provider.dart';

/// Palier imposé, sans compte ni lecture : pour les tests qui visent autre
/// chose que les paliers (calcul, édition, import…).
class PalierFixe extends PalierNotifier {
  final EtatPalier initial;
  int relectures = 0;
  PalierFixe(String? palier, {bool erreur = false})
    : initial = EtatPalier(palier: palier, connu: !erreur, erreur: erreur);

  @override
  EtatPalier build() => initial;

  @override
  Future<void> actualiser() async => relectures++;

  void passerEtat(EtatPalier etat) => state = etat;

  void passerA(String? palier, {int? session}) =>
      state = EtatPalier(session: session ?? state.session, palier: palier, connu: true);
}

/// Expert par défaut : aucune fonction verrouillée.
Override palierFixe([String? palier = palierExpert]) => palierProvider.overrideWith(() => PalierFixe(palier));
