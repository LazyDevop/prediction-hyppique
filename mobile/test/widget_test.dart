import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prediction_hippique/main.dart';

void main() {
  testWidgets('parcours complet : accueil -> saisie manuelle -> ajout cheval -> résultats', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PredictionHippiqueApp()));
    // Un seul pump (pas pumpAndSettle) : l'accueil déclenche un appel réseau
    // vers le backend, absent dans cet environnement de test. Le bouton
    // "Saisie manuelle" est visible dès la première frame, indépendamment
    // de l'état (chargement/erreur) de cet appel.
    await tester.pump();

    expect(find.text('Programme du jour'), findsOneWidget);
    await tester.tap(find.text('Saisie manuelle'));
    await tester.pumpAndSettle();

    // Écran de config course : passer directement aux partants.
    expect(find.text('Configuration course'), findsOneWidget);
    await tester.tap(find.text('Voir les partants'));
    await tester.pumpAndSettle();

    // Liste des partants (vide) : ajouter un cheval.
    expect(find.text('Aucun cheval saisi — appuyez sur + pour en ajouter un.'), findsOneWidget);
    await tester.tap(find.text('Cheval'));
    await tester.pumpAndSettle();

    // Fiche cheval : renseigner un nom puis enregistrer.
    await tester.enterText(find.widgetWithText(TextField, 'Nom'), 'Foudre Noire');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // De retour sur la liste, le cheval apparaît.
    expect(find.text('Foudre Noire'), findsOneWidget);

    // Calculer -> écran de résultats.
    await tester.tap(find.text('Calculer'));
    await tester.pumpAndSettle();

    expect(find.text('Classement & recommandations'), findsOneWidget);

    // Le disclaimer est en bas de la ListView, hors du viewport initial.
    final disclaimer = find.textContaining('aucun modèle ne garantit un gain');
    await tester.scrollUntilVisible(disclaimer, 500, scrollable: find.byType(Scrollable).first);
    expect(disclaimer, findsOneWidget);
  });
}
