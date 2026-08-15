import 'package:flutter/material.dart';

/// Double jauge modèle (or) vs marché/cote implicite (bleu) — reprise du
/// prototype HTML/React.
class ProbabilityGauge extends StatelessWidget {
  final double modele;
  final double? marche;
  final double maxProb;

  const ProbabilityGauge({super.key, required this.modele, this.marche, required this.maxProb});

  @override
  Widget build(BuildContext context) {
    final wModele = maxProb > 0 ? (modele / maxProb).clamp(0.0, 1.0) : 0.0;
    final wMarche = (marche != null && maxProb > 0) ? (marche! / maxProb).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(wModele, Colors.amber),
        const SizedBox(height: 3),
        _bar(wMarche, Colors.lightBlue),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Modèle ${(modele * 100).toStringAsFixed(1)} %', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            if (marche != null)
              Text('Marché ${(marche! * 100).toStringAsFixed(1)} %', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _bar(double fraction, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: Colors.white10,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}
