import 'package:flutter/material.dart';

import 'auth_styles.dart';

enum EtatPaiement { enAttente, confirme, echoue }

/// `payment-status` : comme un `status-banner` (surface, line-card,
/// rounded.sm, texte `text`) ; l'échec en variante forte (2px `text`).
/// Jamais de vert ni de rouge : l'état est écrit. Région live polie, lue
/// en un seul nœud ([lu]) : le passage « en attente » → « actif » ou
/// « non confirmé » est annoncé une fois, sans déplacer le focus.
class StatutPaiementBloc extends StatelessWidget {
  final EtatPaiement etat;

  /// Étiquette (« Paiement confirmé »), en `label`, facultative.
  final String? etiquette;

  /// Titre en gras.
  final String titre;
  final String? texte;
  final String? note;
  final String lu;

  const StatutPaiementBloc({
    super.key,
    required this.etat,
    required this.titre,
    required this.lu,
    this.etiquette,
    this.texte,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final fort = etat == EtatPaiement.echoue;
    final grand = etat != EtatPaiement.enAttente;
    return Semantics(
      liveRegion: true,
      container: true,
      label: lu,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: JetonsAuth.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fort ? JetonsAuth.text : JetonsAuth.lineCard, width: fort ? 2 : 1),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 12, height: 1.45, color: JetonsAuth.text),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (etiquette != null) Text(etiquette!.toUpperCase(), style: JetonsAuth.label),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (etat == EtatPaiement.enAttente) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: JetonsAuth.muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: grand ? 4 : 0),
                      child: Text(
                        titre,
                        style: TextStyle(
                          fontSize: grand ? 18 : 12,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          fontFeatures: JetonsAuth.tabulaire,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (texte != null) Padding(padding: const EdgeInsets.only(top: 5), child: Text(texte!)),
              if (note != null)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(note!, style: JetonsAuth.meta)),
            ],
          ),
        ),
      ),
    );
  }
}
