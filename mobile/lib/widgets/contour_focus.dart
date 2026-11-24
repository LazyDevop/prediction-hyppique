import 'package:flutter/material.dart';

import 'auth_styles.dart';

/// `focus-indicator` (DESIGN.md) : contour or 2px, décalage 2px, autour de
/// [child] quand lui ou un descendant a le focus en navigation clavier —
/// jamais au simple toucher ou clic. Seul usage permis de l'or comme
/// contour hors du signal principal.
class ContourFocus extends StatefulWidget {
  final Widget child;
  final double rayon;

  /// Contour tracé à l'intérieur de [child] (lignes d'une liste défilante,
  /// dont le viewport couperait un contour extérieur).
  final bool interieur;
  const ContourFocus({super.key, required this.child, this.rayon = 10, this.interieur = false});

  @override
  State<ContourFocus> createState() => _ContourFocusState();
}

class _ContourFocusState extends State<ContourFocus> {
  bool _focus = false;
  bool _clavier = FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_surMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_surMode);
    super.dispose();
  }

  void _surMode(FocusHighlightMode mode) {
    final clavier = mode == FocusHighlightMode.traditional;
    if (clavier != _clavier && mounted) setState(() => _clavier = clavier);
  }

  @override
  Widget build(BuildContext context) {
    final actif = _focus && _clavier;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) {
        if (f != _focus) setState(() => _focus = f);
      },
      // Structure stable (pas de clé changeante) : l'élément focalisé n'est
      // jamais reconstruit, donc ne perd pas le focus.
      child: CustomPaint(
        foregroundPainter: actif ? PeintreContourFocus(widget.rayon, interieur: widget.interieur) : null,
        child: widget.child,
      ),
    );
  }
}

/// Contour or du `focus-indicator` (public pour les tests).
class PeintreContourFocus extends CustomPainter {
  final double rayon;
  final bool interieur;
  const PeintreContourFocus(this.rayon, {this.interieur = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Décalage 2px + demi-trait : le contour ne recouvre pas l'élément.
    // Intérieur : décalage 2px vers l'intérieur.
    final rect = interieur ? (Offset.zero & size).deflate(3) : (Offset.zero & size).inflate(3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(interieur ? rayon : rayon + 3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = JetonsAuth.gold,
    );
  }

  @override
  bool shouldRepaint(PeintreContourFocus ancien) => ancien.rayon != rayon || ancien.interieur != interieur;
}
