import 'package:flutter/material.dart';

import 'auth_styles.dart';

/// En-tête de section (or, capitales, 11sp).
class TitreSection extends StatelessWidget {
  final String texte;
  const TitreSection(this.texte, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(
          texte.toUpperCase(),
          style: const TextStyle(fontSize: 11, letterSpacing: .7, color: JetonsAuth.gold),
        ),
      ),
    );
  }
}

/// État écrit (« Vérifié », « Non vérifié ») dans un cadre `line-card` :
/// jamais de vert ni de rouge.
class EtatEcrit extends StatelessWidget {
  final String texte;
  final bool attenue;
  const EtatEcrit(this.texte, {super.key, this.attenue = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: JetonsAuth.lineCard),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        texte.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: .6,
          fontWeight: attenue ? FontWeight.w600 : FontWeight.w700,
          color: attenue ? JetonsAuth.muted : JetonsAuth.text,
        ),
      ),
    );
  }
}

/// `settings-row` : libellé `muted` à gauche, valeur `text` à droite (avec
/// détail facultatif), séparateur `line`, hauteur ≥ 52dp. Variantes :
/// [action] (lien souligné, ex. « Ajouter ») ou [navigation] (chevron).
/// Toute la ligne est la cible quand [onTap] est fourni ; TalkBack lit
/// la ligne en un seul nœud.
class LigneReglage extends StatelessWidget {
  final String libelle;
  final String? valeur;
  final String? detail;

  /// Remplace [detail] par un widget (ex. [EtatEcrit]).
  final Widget? detailWidget;
  final String? action;
  final bool navigation;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const LigneReglage({
    super.key,
    required this.libelle,
    this.valeur,
    this.detail,
    this.detailWidget,
    this.action,
    this.navigation = false,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final droite = <Widget>[
      if (valeur != null)
        Text(
          valeur!,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            color: JetonsAuth.text,
            fontWeight: navigation ? FontWeight.w600 : FontWeight.w400,
            fontFeatures: JetonsAuth.tabulaire,
          ),
        ),
      if (detail != null)
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(detail!, textAlign: TextAlign.right, style: JetonsAuth.meta),
        ),
      if (detailWidget != null) Padding(padding: const EdgeInsets.only(top: 2), child: detailWidget),
      if (action != null)
        Text(
          action!,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: JetonsAuth.text,
            decoration: TextDecoration.underline,
            decorationColor: JetonsAuth.text,
          ),
        ),
    ];
    final ligne = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: JetonsAuth.line))),
      child: Row(children: [
        Expanded(
          child: Text(libelle, style: const TextStyle(fontSize: 12.5, color: JetonsAuth.muted)),
        ),
        const SizedBox(width: 10),
        Flexible(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: droite),
        ),
        if (navigation)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Text('▸', style: TextStyle(color: JetonsAuth.muted)),
          ),
      ]),
    );
    final lu = semanticsLabel ??
        [libelle, ?valeur, ?detail, ?action].join(', ');
    return Semantics(
      button: onTap != null,
      label: lu,
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null ? ligne : InkWell(onTap: onTap, child: ligne),
    );
  }
}
