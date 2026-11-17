import 'package:flutter/material.dart';

import 'auth_styles.dart';

/// Squelette commun des écrans-portes : défilable, contenu poussé en bas
/// par un `Spacer`, largeur bornée (web), gouttière 16px.
class CadreAuth extends StatelessWidget {
  final List<Widget> enfants;
  const CadreAuth({super.key, required this.enfants});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JetonsAuth.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: enfants),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton retour système (Android) sur un écran-porte.
///
/// Les portes sont rendues au-dessus du Navigator (aucune route parente),
/// donc un `PopScope` n'y aurait aucun effet : l'écran reçoit le retour
/// directement du binding. [surRetour] renvoie toujours « traité » : la
/// pile masquée n'est jamais dépilée et l'app n'est pas quittée par
/// erreur. Quand la pile existe (re-verrouillage), `PorteScreen` bloque en
/// plus sa route du dessus.
mixin RetourPorte<T extends StatefulWidget> on State<T> {
  late final _observateur = _ObservateurRetour(() => surRetour());

  /// Étape précédente, ou rien (retour bloqué).
  void surRetour();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_observateur);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observateur);
    super.dispose();
  }
}

class _ObservateurRetour with WidgetsBindingObserver {
  final VoidCallback _surRetour;
  _ObservateurRetour(this._surRetour);

  @override
  Future<bool> didPopRoute() async {
    _surRetour();
    return true;
  }
}
