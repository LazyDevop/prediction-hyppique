import 'package:flutter/material.dart';

import 'auth_styles.dart';

/// `pin-pad` : grille 3×4, dix chiffres + « ⌫ Effacer », touches ≥ 48dp
/// (64 ici, comme la maquette). Jamais le clavier système.
class PinPad extends StatelessWidget {
  final ValueChanged<String> onChiffre;
  final VoidCallback onEffacer;
  final bool actif;

  const PinPad({super.key, required this.onChiffre, required this.onEffacer, this.actif = true});

  static const _lettres = {
    '1': '',
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '',
  };

  @override
  Widget build(BuildContext context) {
    Widget touche(String chiffre) => _Touche(
          semanticsLabel: chiffre,
          onTap: actif ? () => onChiffre(chiffre) : null,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(chiffre, style: JetonsAuth.chiffres),
            Text(_lettres[chiffre]!, style: const TextStyle(fontSize: 9.5, letterSpacing: 1, color: JetonsAuth.muted)),
          ]),
        );

    Widget ligne(List<Widget> touches) => Row(
          children: [
            for (var i = 0; i < touches.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: touches[i]),
            ],
          ],
        );

    return Column(mainAxisSize: MainAxisSize.min, children: [
      ligne([touche('1'), touche('2'), touche('3')]),
      const SizedBox(height: 10),
      ligne([touche('4'), touche('5'), touche('6')]),
      const SizedBox(height: 10),
      ligne([touche('7'), touche('8'), touche('9')]),
      const SizedBox(height: 10),
      ligne([
        const SizedBox(height: 64),
        touche('0'),
        _Touche(
          semanticsLabel: 'Effacer',
          fonction: true,
          onTap: actif ? onEffacer : null,
          child: const Text('⌫ Effacer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: JetonsAuth.text)),
        ),
      ]),
    ]);
  }
}

class _Touche extends StatelessWidget {
  final String semanticsLabel;
  final VoidCallback? onTap;
  final Widget child;
  final bool fonction;

  const _Touche({required this.semanticsLabel, required this.onTap, required this.child, this.fonction = false});

  @override
  Widget build(BuildContext context) {
    final forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: JetonsAuth.lineCard),
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: fonction ? Colors.transparent : JetonsAuth.surface,
        shape: forme,
        child: InkWell(
          customBorder: forme,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Indicateur de saisie : points sans les chiffres + texte de progression.
/// Un seul nœud TalkBack ([semanticsLabel], jamais les chiffres).
class PinPoints extends StatelessWidget {
  final int saisis;

  /// Cases pleines attendues ; [optionnelles] cases en pointillé au-delà.
  final int cases;
  final int optionnelles;
  final String texte;
  final String semanticsLabel;

  const PinPoints({
    super.key,
    required this.saisis,
    required this.cases,
    this.optionnelles = 0,
    required this.texte,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final total = cases + optionnelles;
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: _Point(plein: i < saisis, optionnel: i >= cases),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(texte, style: const TextStyle(fontSize: 11.5, color: JetonsAuth.muted, fontFeatures: JetonsAuth.tabulaire)),
        ]),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final bool plein;
  final bool optionnel;
  const _Point({required this.plein, required this.optionnel});

  @override
  Widget build(BuildContext context) {
    if (plein) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: JetonsAuth.text, borderRadius: BorderRadius.circular(4)),
      );
    }
    final vide = Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: JetonsAuth.surface,
        borderRadius: BorderRadius.circular(4),
        border: optionnel ? null : Border.all(color: JetonsAuth.lineCard),
      ),
    );
    // Case optionnelle : contour en pointillé.
    return optionnel ? CustomPaint(foregroundPainter: _Pointille(), child: vide) : vide;
  }
}

class _Pointille extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()
      ..color = JetonsAuth.lineCard
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const tiret = 3.0;
    final r = Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1);
    for (final (debut, fin) in [
      (r.topLeft, r.topRight),
      (r.topRight, r.bottomRight),
      (r.bottomRight, r.bottomLeft),
      (r.bottomLeft, r.topLeft),
    ]) {
      final longueur = (fin - debut).distance;
      final dir = (fin - debut) / longueur;
      for (var d = 0.0; d < longueur; d += tiret * 2) {
        final f = (d + tiret).clamp(0, longueur).toDouble();
        canvas.drawLine(debut + dir * d, debut + dir * f, peinture);
      }
    }
  }

  @override
  bool shouldRepaint(_Pointille oldDelegate) => false;
}

/// État « calcul en cours » sous les points pendant le hachage Argon2id
/// (le pavé est désactivé pendant ce temps).
class CalculPin extends StatelessWidget {
  final String texte;
  const CalculPin({super.key, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        liveRegion: true,
        label: texte,
        excludeSemantics: true,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: JetonsAuth.text),
          ),
          const SizedBox(width: 8),
          Text(texte, style: const TextStyle(fontSize: 11.5, color: JetonsAuth.muted)),
        ]),
      ),
    );
  }
}
