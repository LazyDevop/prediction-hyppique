import 'package:flutter/material.dart';

/// Jetons DESIGN.md utilisés par Connexion / Déverrouillage (epic-8-context).
/// `gold`, `bg` et `surface` sont ceux du thème de main.dart.
abstract final class JetonsAuth {
  static const bg = Color(0xFF0B1120);
  static const surface = Color(0xFF131C2E);
  static const surface2 = Color(0xFF0F1728);
  static const lineCard = Color(0x5CFFFFFF); // rgba(255,255,255,.36)
  static const line = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const lineDisclaimer = Color(0x24FFFFFF); // rgba(255,255,255,.14), filet du disclaimer
  static const text = Color(0xFFE7E4DA);
  static const muted = Color(0xFF8B93A7);
  static const gold = Color(0xFFE8B33C);
  static const onGold = Color(0xFF14100A);

  static const tabulaire = [FontFeature.tabularFigures()];

  static const brand = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: .6,
    color: gold,
  );
  static const lead = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, color: text);
  static const sub = TextStyle(fontSize: 13, height: 1.45, color: muted);
  static const label = TextStyle(fontSize: 11, letterSpacing: .7, color: muted);
  static const meta = TextStyle(fontSize: 11, height: 1.4, color: muted, fontFeatures: tabulaire);
  static const chiffres = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: text,
    fontFeatures: tabulaire,
  );
}

/// Marque « Analyseur Hippique » (or, capitales).
class MarqueAuth extends StatelessWidget {
  final TextAlign textAlign;
  const MarqueAuth({super.key, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) =>
      Text('Analyseur Hippique'.toUpperCase(), style: JetonsAuth.brand, textAlign: textAlign);
}

/// En-tête « ← Titre » (titre en or, capitales).
class EnTeteAuth extends StatelessWidget {
  final String titre;
  final VoidCallback? onRetour;
  final String retourLabel;

  /// Affiche la flèche même quand [onRetour] est nul (alors désactivée).
  final bool avecRetour;
  const EnTeteAuth({
    super.key,
    required this.titre,
    this.onRetour,
    this.retourLabel = 'Retour',
    this.avecRetour = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(children: [
        if (onRetour != null || avecRetour)
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              tooltip: retourLabel,
              onPressed: onRetour,
              icon: const Icon(Icons.arrow_back, color: JetonsAuth.muted),
            ),
          ),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(titre.toUpperCase(), style: JetonsAuth.brand),
          ),
        ),
      ]),
    );
  }
}

/// `cta-primary` : fond or, capitales, rounded.md — un seul par écran.
/// Désactivé : surface + line-card + muted (maquette `.cta.off`).
class CtaPrimaire extends StatelessWidget {
  final String texte;
  final VoidCallback? onPressed;
  const CtaPrimaire({super.key, required this.texte, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final actif = onPressed != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: JetonsAuth.gold,
          foregroundColor: JetonsAuth.onGold,
          disabledBackgroundColor: JetonsAuth.surface,
          disabledForegroundColor: JetonsAuth.muted,
          padding: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: actif ? BorderSide.none : const BorderSide(color: JetonsAuth.lineCard),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: .6),
        ),
        child: Text(texte.toUpperCase(), textAlign: TextAlign.center),
      ),
    );
  }
}

/// `cta-ghost` : surface + line-card + text.
class CtaFantome extends StatelessWidget {
  final String texte;
  final VoidCallback? onPressed;
  const CtaFantome({super.key, required this.texte, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: JetonsAuth.surface,
          foregroundColor: JetonsAuth.text,
          disabledForegroundColor: JetonsAuth.muted,
          side: const BorderSide(color: JetonsAuth.lineCard),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFeatures: JetonsAuth.tabulaire),
        ),
        child: Text(texte, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Lien souligné (cible ≥ 48dp).
class LienAuth extends StatelessWidget {
  final String texte;
  final VoidCallback? onPressed;
  const LienAuth({super.key, required this.texte, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: JetonsAuth.text,
        disabledForegroundColor: JetonsAuth.muted,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(texte, textAlign: TextAlign.center),
    );
  }
}

/// `status-banner` : surface + line-card, rounded.sm ; variante forte
/// bordure 2px `text`. Annoncé poliment (live region) quand [annonce].
class BandeauStatut extends StatelessWidget {
  final Widget child;
  final bool fort;
  final bool annonce;
  const BandeauStatut({super.key, required this.child, this.fort = false, this.annonce = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: annonce,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: JetonsAuth.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: fort ? JetonsAuth.text : JetonsAuth.lineCard,
            width: fort ? 2 : 1,
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 12, height: 1.45, color: JetonsAuth.text),
          child: child,
        ),
      ),
    );
  }
}

/// « 1 chiffre » / « 3 chiffres » (0 et 1 au singulier).
String nChiffres(int n) => n <= 1 ? '$n chiffre' : '$n chiffres';

/// « 1 chiffre saisi » / « 3 chiffres saisis ».
String chiffresSaisis(int n) => n <= 1 ? '$n chiffre saisi' : '$n chiffres saisis';

/// « 1 essai restant » / « 3 essais restants ».
String essaisRestants(int n) => n <= 1 ? '$n essai restant' : '$n essais restants';
