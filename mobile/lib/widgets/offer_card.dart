import 'package:flutter/material.dart';

import '../data/remote/offres_api.dart';
import 'auth_styles.dart';

/// Texte dont les passages entre `**` sont en gras (couleur [fort]).
List<TextSpan> segmentsEnrichis(String texte, {Color? fort}) {
  final morceaux = texte.split('**');
  return [
    for (var i = 0; i < morceaux.length; i++)
      if (morceaux[i].isNotEmpty)
        TextSpan(
          text: morceaux[i],
          style: i.isOdd ? TextStyle(fontWeight: FontWeight.w600, color: fort) : null,
        ),
  ];
}

/// Texte brut, sans les marques `**` (lecture TalkBack, tests).
String texteBrut(String texte) => texte.replaceAll('**', '');

/// En-tête d'un groupe d'offres : « TURFISTE · INSTANTANÉS H-60… » (or,
/// complément en `muted`).
class TitreGroupe extends StatelessWidget {
  final String titre;
  final String? aparte;
  const TitreGroupe(this.titre, {super.key, this.aparte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: titre.toUpperCase()),
              if (aparte != null)
                TextSpan(text: ' · ${aparte!}'.toUpperCase(), style: const TextStyle(color: JetonsAuth.muted)),
            ],
          ),
          style: const TextStyle(fontSize: 11, letterSpacing: .7, color: JetonsAuth.gold),
        ),
      ),
    );
  }
}

/// Repère de sélection carré (`radio` de la maquette) : plein en `text`.
class RepereSelection extends StatelessWidget {
  final bool selectionne;
  const RepereSelection({super.key, required this.selectionne});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: JetonsAuth.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: JetonsAuth.lineCard),
      ),
      child: selectionne
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: JetonsAuth.text, borderRadius: BorderRadius.circular(3)),
            )
          : null,
    );
  }
}

/// `offer-card` : surface-2, bordure line-card (2px `text` si
/// sélectionnée, jamais d'or), rounded.lg. Nom, prix, durée et ce que
/// l'offre débloque ; « Sélectionnée » écrit. Toute la carte est la cible ;
/// TalkBack la lit en un seul nœud.
class CarteOffre extends StatelessWidget {
  final Offre offre;
  final bool selectionnee;
  final VoidCallback? onTap;
  const CarteOffre({super.key, required this.offre, required this.selectionnee, this.onTap});

  @override
  Widget build(BuildContext context) {
    final o = offre;
    final prix = formaterPrix(o.prixFcfa);
    final lu = [
      o.nom,
      'palier ${o.palier}',
      o.libelleDuree,
      'prix $prix',
      texteBrut(o.debloque),
      if (selectionnee) 'sélectionnée',
    ].join(', ');
    final forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: selectionnee ? JetonsAuth.text : JetonsAuth.lineCard, width: selectionnee ? 2 : 1),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        container: true,
        button: onTap != null,
        selected: selectionnee,
        label: lu,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: JetonsAuth.surface2,
          shape: forme,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 1), child: RepereSelection(selectionne: selectionnee)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          spacing: 8,
                          children: [
                            Text(
                              o.nom,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: JetonsAuth.text,
                              ),
                            ),
                            Text(
                              prix,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: JetonsAuth.text,
                                fontFeatures: JetonsAuth.tabulaire,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${o.libelleDuree}. '),
                              ...segmentsEnrichis(o.debloque, fort: JetonsAuth.text),
                            ],
                          ),
                          style: const TextStyle(fontSize: 11.5, height: 1.4, color: JetonsAuth.muted),
                        ),
                        if (selectionnee)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Sélectionnée'.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                letterSpacing: .6,
                                fontWeight: FontWeight.w700,
                                color: JetonsAuth.text,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rappel de jeu responsable (Offres, Paiement), dans le flux de lecture.
class RappelJeuResponsable extends StatelessWidget {
  final String texte;
  const RappelJeuResponsable(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: JetonsAuth.lineDisclaimer))),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, height: 1.4, color: JetonsAuth.muted, fontStyle: FontStyle.italic),
      ),
    );
  }
}
