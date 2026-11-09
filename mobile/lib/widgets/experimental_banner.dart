import 'package:flutter/material.dart';

/// Interrupteur unique du traitement "expérimental" de la value et des mises
/// Kelly (roadmap du modèle prédictif, décision du 2026-10-22) : bandeau de
/// l'écran Résultats, marque `exp.` sur les chiffres des cartes et libellé
/// des Réglages. À passer à `false` une fois l'étape 3 de la roadmap validée
/// (le modèle combiné bat le marché) ; les verdicts restent neutres.
const bool kValueExperimental = true;

/// Texte exact du bandeau (spec-value-experimentale).
const String kExperimentalBannerText =
    'Value et mises expérimentales : le moteur ne bat pas encore le marché.';

/// Marque accolée aux libellés des chiffres de value et de mise.
const String kExperimentalMark = 'exp.';

/// Bandeau épinglé au-dessus du classement, sur le modèle du bandeau de
/// péremption. Un seul texte : le lecteur d'écran le lit comme une phrase.
class ExperimentalBanner extends StatelessWidget {
  const ExperimentalBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('experimental-banner-semantics'),
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.15),
          border: const Border(bottom: BorderSide(color: Colors.blueGrey)),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.science_outlined, color: Colors.blueGrey, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kExperimentalBannerText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
