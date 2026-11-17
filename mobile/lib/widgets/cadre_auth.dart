import 'package:flutter/material.dart';

import 'auth_styles.dart';

/// Squelette commun des écrans-portes : défilable, contenu poussé en bas
/// par un `Spacer`, largeur bornée (web), gouttière 16px.
class CadreAuth extends StatelessWidget {
  final List<Widget> enfants;

  /// Barre d'action épinglée sous la zone défilante (fond `bg`, filet haut
  /// `line-card`), jamais par-dessus le contenu. Absente si nulle ou vide.
  final List<Widget>? barre;
  const CadreAuth({super.key, required this.enfants, this.barre});

  @override
  Widget build(BuildContext context) {
    final defilant = CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: enfants),
          ),
        ),
      ],
    );
    final actions = barre;
    return Scaffold(
      backgroundColor: JetonsAuth.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: actions == null || actions.isEmpty
                ? defilant
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: defilant),
                      Container(
                        decoration: const BoxDecoration(
                          color: JetonsAuth.bg,
                          border: Border(top: BorderSide(color: JetonsAuth.lineCard)),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < actions.length; i++) ...[
                              if (i > 0) const SizedBox(height: 8),
                              actions[i],
                            ],
                          ],
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
