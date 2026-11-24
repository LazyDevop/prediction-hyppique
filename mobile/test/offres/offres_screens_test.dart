import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/data/remote/offres_api.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/providers/paiement_provider.dart';
import 'package:prediction_hippique/screens/connexion_screen.dart';
import 'package:prediction_hippique/screens/offres_screen.dart';
import 'package:prediction_hippique/screens/paiement_screen.dart';
import 'package:prediction_hippique/widgets/auth_styles.dart';
import 'package:prediction_hippique/widgets/offer_card.dart';
import 'package:prediction_hippique/widgets/payment_status.dart';

import '../auth/auth_test_helpers.dart';
import '../compte/compte_test_helpers.dart';
import 'offres_test_helpers.dart';

const _attente = 'Paiement en attente de confirmation — validez sur votre téléphone';

ProviderContainer _conteneur(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

Color _bordureMateriau(WidgetTester tester, Finder dans) {
  final forme = tester.widget<Material>(find.descendant(of: dans, matching: find.byType(Material)).first).shape
      as RoundedRectangleBorder;
  return forme.side.color;
}

void main() {
  group('Offres', () {
    testWidgets('Profil → Offres : offres groupées, rien de sélectionné, CTA désactivé, prix « … FCFA »', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirProfil(tester);
      // Le prix n'apparaît que sur Offres et Paiement.
      expect(find.textContaining('FCFA'), findsNothing);
      await toucher(tester, find.text('Offres'));

      expect(find.text('OFFRES'), findsOneWidget);
      expect(find.text('GRATUIT'), findsOneWidget);
      expect(find.text('Paiement par MTN MoMo ou Orange Money.'), findsOneWidget);
      expect(find.text(messageModeDemoPaiement), findsOneWidget);
      expect(find.textContaining("actif jusqu'au"), findsNothing);
      expect(find.text('TURFISTE · INSTANTANÉS H-60, H-30, H-15'), findsOneWidget);
      expect(find.text('EXPERT · + INSTANTANÉ H-10'), findsOneWidget);
      expect(find.text('DUO · CHAQUE PALIER', skipOffstage: false), findsOneWidget);
      expect(find.byType(CarteOffre, skipOffstage: false), findsNWidgets(7));
      for (final nom in [
        'Pass semaine Turfiste',
        'Mensuel Turfiste',
        'Pass journée Expert',
        'Pass semaine Expert',
        'Mensuel Expert',
        'Offre Duo Turfiste',
        'Offre Duo Expert',
      ]) {
        expect(find.text(nom, skipOffstage: false), findsOneWidget, reason: nom);
      }
      expect(find.text('… FCFA', skipOffstage: false), findsNWidgets(7));
      expect(
        find.textContaining('7 jours. Débloque les instantanés H-60, H-30 et H-15', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.textContaining('Pour 2 personnes. Partagez le palier Expert', skipOffstage: false), findsOneWidget);
      expect(find.textContaining('Chacun garde son compte', skipOffstage: false), findsNWidgets(2));
      expect(find.text('SÉLECTIONNÉE', skipOffstage: false), findsNothing);
      expect(pressionCta(tester, 'CONTINUER VERS LE PAIEMENT'), isNull);
      expect(find.text(rappelJeuOffres, skipOffstage: false), findsOneWidget);
      expect(
        find.text('ℹ️ Les prix et les durées sont indiqués avant tout paiement.', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('chargement raté : message + « Réessayer », puis la liste', (tester) async {
      final horloge = Horloge();
      final (compte, offres) = fauxLies(horloge);
      offres.echecsListe = 1;
      await pumpApp(tester, store: await storeAvecSession(), compte: compte, offres: offres, horloge: horloge);
      await ouvrirOffres(tester);
      expect(find.text(messageChargementOffres), findsOneWidget);
      expect(find.byType(CarteOffre), findsNothing);
      await toucher(tester, find.text('Réessayer'));
      expect(find.text(messageChargementOffres), findsNothing);
      expect(find.byType(CarteOffre, skipOffstage: false), findsNWidgets(7));
    });

    testWidgets('catalogue vide : « Aucune offre disponible pour le moment » + « Réessayer »', (tester) async {
      final horloge = Horloge();
      final (compte, offres) = fauxLies(horloge);
      offres.catalogueVide = true;
      await pumpApp(tester, store: await storeAvecSession(), compte: compte, offres: offres, horloge: horloge);
      await ouvrirOffres(tester);
      expect(find.text(messageAucuneOffre), findsOneWidget);
      expect(pressionCta(tester, 'CONTINUER VERS LE PAIEMENT'), isNull);
      offres.catalogueVide = false;
      await toucher(tester, find.text('Réessayer'));
      expect(find.text(messageAucuneOffre), findsNothing);
      expect(find.byType(CarteOffre, skipOffstage: false), findsNWidgets(7));
    });

    testWidgets('sélection : « Sélectionnée » sur une seule carte (bordure text, jamais or), CTA actif', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirOffres(tester);
      await toucher(tester, find.text('Mensuel Turfiste'));
      expect(find.text('SÉLECTIONNÉE'), findsOneWidget);
      expect(pressionCta(tester, 'CONTINUER VERS LE PAIEMENT'), isNotNull);

      await toucher(tester, find.text('Pass journée Expert'));
      expect(find.text('SÉLECTIONNÉE'), findsOneWidget);
      final carte = find.ancestor(of: find.text('Pass journée Expert'), matching: find.byType(CarteOffre));
      expect(tester.widget<CarteOffre>(carte).selectionnee, isTrue);
      expect(_bordureMateriau(tester, carte), JetonsAuth.text);
      final semantique = tester.getSemantics(find.descendant(of: carte, matching: find.byType(Material)).first);
      expect(semantique.label, contains('Pass journée Expert, palier Expert, 24 h, prix … FCFA'));
      expect(semantique.label, endsWith('sélectionnée'));
    });

    testWidgets('double toucher sur « Continuer » : un seul écran Paiement', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirOffres(tester);
      await toucher(tester, find.text('Pass semaine Turfiste'));
      await tester.tap(find.text('CONTINUER VERS LE PAIEMENT'));
      await tester.tap(find.text('CONTINUER VERS LE PAIEMENT'), warnIfMissed: false);
      await attendre(tester);
      expect(find.byType(PaiementScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('palier payant : en-tête et droit actif affichés', (tester) async {
      final horloge = Horloge();
      final compte = FauxCompteApi(
        horloge: horloge.call,
        web: true,
        palier: palierExpert,
        finDroit: DateTime(2026, 11, 24, 10).toUtc(),
      );
      await pumpApp(tester, store: await storeAvecSession(), compte: compte, horloge: horloge);
      await ouvrirOffres(tester);
      expect(find.text('EXPERT'), findsOneWidget);
      expect(find.text("Palier Expert actif jusqu'au 24/11 à 10 h 00."), findsOneWidget);
    });
  });

  group('Paiement', () {
    testWidgets('paiement abouti : résumé, MTN MoMo, en attente, puis « … actif jusqu\'au … », Profil Turfiste', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: await storeAvecSession(), horloge: horloge);
      await ouvrirPaiement(tester);

      expect(find.text('PAIEMENT'), findsOneWidget);
      expect(find.text('Offre'), findsOneWidget);
      expect(find.text('Pass semaine Turfiste'), findsOneWidget);
      expect(find.text('7 jours'), findsOneWidget);
      expect(find.text('… FCFA'), findsOneWidget);
      expect(find.text(messageModeDemoPaiement), findsOneWidget);
      expect(find.text('MOYEN DE PAIEMENT'), findsOneWidget);
      expect(find.text('Orange Money'), findsOneWidget);
      expect(find.text(rappelJeuPaiement, skipOffstage: false), findsOneWidget);
      // Aucun moyen ni numéro (session restaurée : numéro complet inconnu).
      expect(pressionCta(tester, 'PAYER'), isNull);

      await toucher(tester, find.text('MTN MoMo'));
      expect(find.text('SÉLECTIONNÉ'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '677123456');
      await tester.pump();
      expect(pressionCta(tester, 'PAYER'), isNotNull);
      await toucher(tester, find.text('PAYER'));

      expect(find.text(_attente, skipOffstage: false), findsOneWidget);
      expect(
        find.text(
          "Une demande MTN MoMo vient d'arriver sur le +237 6 77 12 34 56. Saisissez votre code Mobile Money pour la valider.",
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(
        find.text("Le pass s'active dès que MTN MoMo confirme, même si vous quittez cet écran.", skipOffstage: false),
        findsOneWidget,
      );
      expect(pressionCta(tester, 'PAIEMENT EN COURS…'), isNull);
      expect(find.text('Revenir au profil'), findsOneWidget);
      // L'app ne décide pas seule : rien avant la réponse du serveur.
      await tester.pump(const Duration(seconds: 2));
      await attendre(tester);
      expect(find.textContaining('actif jusqu'), findsNothing);

      await laisserConfirmer(tester, horloge);
      expect(find.text('PAIEMENT CONFIRMÉ'), findsOneWidget);
      expect(find.text("✓ Pass semaine Turfiste actif jusqu'au 24/11"), findsOneWidget);
      expect(find.textContaining('Fin du pass : mardi 24/11 à 10 h 00.'), findsOneWidget);
      expect(find.textContaining('Ensuite, retour au palier Gratuit'), findsOneWidget);
      expect(find.text(noteDuo), findsNothing);
      expect(find.text('TURFISTE'), findsOneWidget);

      await toucher(tester, find.text('REVENIR AU PROFIL'));
      expect(find.text('PROFIL'), findsOneWidget);
      expect(find.text('OFFRES'), findsNothing);
      expect(find.text('Turfiste'), findsOneWidget);
      expect(find.text('24/11/2026 à 10 h 00'), findsOneWidget);

      // Offres affiche le pass actif.
      await toucher(tester, find.text('Offres'));
      expect(find.text('TURFISTE'), findsOneWidget);
      expect(find.text("Palier Turfiste actif jusqu'au 24/11 à 10 h 00."), findsOneWidget);
    });

    testWidgets('Duo confirmé : rappel que l\'invitation arrivera plus tard', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: await storeAvecSession(), horloge: horloge);
      await ouvrirPaiement(tester, offre: 'Offre Duo Turfiste');
      await payer(tester);
      await laisserConfirmer(tester, horloge);
      expect(find.text("✓ Offre Duo Turfiste active jusqu'au 17/12"), findsOneWidget);
      expect(find.text(noteDuo), findsOneWidget);
    });

    testWidgets('échec (690000000) : saisie en lecture seule, Réessayer reprend moyen et numéro payés', (tester) async {
      final horloge = Horloge();
      final (compte, offres) = fauxLies(horloge);
      await pumpApp(tester, store: await storeAvecSession(), compte: compte, offres: offres, horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester, numero: FauxOffresApi.numeroEchec);
      await laisserConfirmer(tester, horloge);

      expect(find.text('PAIEMENT NON CONFIRMÉ'), findsOneWidget);
      expect(find.text("Aucun droit activé"), findsOneWidget);
      expect(find.textContaining("MTN MoMo n'a pas confirmé le paiement."), findsOneWidget);
      expect(find.text('RÉESSAYER'), findsOneWidget);
      expect(find.text('Changer de moyen'), findsOneWidget);
      expect(find.text('GRATUIT'), findsOneWidget);
      expect((await compte.lireProfil()).palier, palierGratuit);

      // Lecture seule : ce qui est affiché est ce qui est payé.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('+237 6 90 00 00 00'), findsOneWidget);
      await toucher(tester, find.text('Orange Money'));
      final orange = find.ancestor(of: find.text('Orange Money'), matching: find.byType(Material)).first;
      expect((tester.widget<Material>(orange).shape as RoundedRectangleBorder).side.color, JetonsAuth.lineCard);
      expect(find.text('SÉLECTIONNÉ'), findsOneWidget);

      // Double toucher sur « Réessayer » : une seule nouvelle initiation.
      await tester.tap(find.text('RÉESSAYER'));
      await tester.tap(find.text('RÉESSAYER'), warnIfMissed: false);
      await attendre(tester);
      expect(offres.initiations, 2);
      expect(find.text(_attente, skipOffstage: false), findsOneWidget);
      expect(find.textContaining("Une demande MTN MoMo vient d'arriver sur le +237 6 90 00 00 00."), findsOneWidget);
      await laisserConfirmer(tester, horloge);
      expect(find.text('PAIEMENT NON CONFIRMÉ'), findsOneWidget);

      await toucher(tester, find.text('Changer de moyen'));
      expect(find.text('PAIEMENT NON CONFIRMÉ'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('SÉLECTIONNÉ'), findsNothing);
      expect(pressionCta(tester, 'PAYER'), isNull);
      await toucher(tester, find.text('Orange Money'));
      expect(find.text('SÉLECTIONNÉ'), findsOneWidget);
      expect(pressionCta(tester, 'PAYER'), isNotNull);
      expect((await compte.lireProfil()).palier, palierGratuit);
    });

    testWidgets('numéro non camerounais : erreur en ligne, « Payer » désactivé', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirPaiement(tester);
      await toucher(tester, find.text('Orange Money'));
      await tester.enterText(find.byType(TextField), '512345678');
      await tester.pump();
      expect(find.text(messageNumeroInvalide), findsOneWidget);
      expect(pressionCta(tester, 'PAYER'), isNull);
      await tester.enterText(find.byType(TextField), '6771234');
      await tester.pump();
      expect(find.text(messageNumeroInvalide), findsNothing);
      expect(pressionCta(tester, 'PAYER'), isNull);
      await tester.enterText(find.byType(TextField), '+237 6 77 12 34 56');
      await tester.pump();
      expect(pressionCta(tester, 'PAYER'), isNotNull);
    });

    testWidgets('palier inférieur à un palier actif : refus dit clairement, rien initié', (tester) async {
      final horloge = Horloge();
      final compte = FauxCompteApi(
        horloge: horloge.call,
        web: true,
        palier: palierExpert,
        finDroit: DateTime(2026, 11, 24, 10).toUtc(),
      );
      await pumpApp(tester, store: await storeAvecSession(), compte: compte, horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester);
      expect(find.text("Votre palier Expert est actif jusqu'au 24/11."), findsOneWidget);
      expect(find.text(_attente, skipOffstage: false), findsNothing);
      expect(pressionCta(tester, 'PAYER'), isNotNull);
    });

    testWidgets('quitter pendant l\'attente : le sondage continue, Profil se recharge seul', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: await storeAvecSession(), horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester);
      // Retour : Offres (paiement en attente signalé, CTA bloqué), puis Profil.
      await toucher(tester, find.byTooltip('Retour'));
      expect(find.text('OFFRES'), findsOneWidget);
      expect(find.text(messagePaiementEnAttente), findsOneWidget);
      expect(find.text('Voir le paiement'), findsOneWidget);
      expect(pressionCta(tester, 'CONTINUER VERS LE PAIEMENT'), isNull);
      await toucher(tester, find.byTooltip('Retour'));
      expect(find.text('PROFIL'), findsOneWidget);
      expect(find.text('GRATUIT'), findsOneWidget);

      await laisserConfirmer(tester, horloge);
      expect(find.text('TURFISTE'), findsOneWidget);
      expect(find.text('24/11/2026 à 10 h 00'), findsOneWidget);
    });

    testWidgets('Offres : « Voir le paiement » rouvre le statut en cours ; échec tardif visible à la réouverture', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: await storeAvecSession(), horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester, numero: FauxOffresApi.numeroEchec);
      await toucher(tester, find.byTooltip('Retour'));
      await toucher(tester, find.text('Voir le paiement'));
      expect(find.text(_attente, skipOffstage: false), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await toucher(tester, find.byTooltip('Retour'));

      // Échec pendant que Paiement est fermé.
      await laisserConfirmer(tester, horloge);
      expect(find.text('Paiement non confirmé'), findsOneWidget);
      await toucher(tester, find.text('Voir le paiement'));
      expect(find.text('PAIEMENT NON CONFIRMÉ'), findsOneWidget);
      // Issue vue : l'avis disparaît d'Offres.
      await toucher(tester, find.byTooltip('Retour'));
      await attendre(tester);
      expect(find.text('Paiement non confirmé'), findsNothing);
    });

    testWidgets('« Revenir au profil » pendant l\'attente : Offres et Paiement se ferment', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: await storeAvecSession(), horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester);
      await toucher(tester, find.text('Revenir au profil'));
      expect(find.text('PROFIL'), findsOneWidget);
      expect(find.text('OFFRES', skipOffstage: false), findsNothing);
      expect(find.byType(PaiementScreen, skipOffstage: false), findsNothing);
    });

    testWidgets('double toucher sur « Payer » : un seul paiement initié', (tester) async {
      final horloge = Horloge();
      final (compte, offres) = fauxLies(horloge);
      await pumpApp(tester, store: await storeAvecSession(), compte: compte, offres: offres, horloge: horloge);
      await ouvrirPaiement(tester);
      await toucher(tester, find.text('MTN MoMo'));
      await tester.enterText(find.byType(TextField), '677123456');
      await tester.pump();
      await tester.tap(find.text('PAYER'));
      await tester.tap(find.text('PAYER'), warnIfMissed: false);
      await attendre(tester);
      expect(offres.initiations, 1);
    });

    testWidgets('initiation en erreur : message, puis « Payer » réutilise la même clé (pas de second paiement)', (tester) async {
      final horloge = Horloge();
      final (compte, offres) = fauxLies(horloge);
      offres.reponsesPerdues = 1;
      await pumpApp(tester, store: await storeAvecSession(), compte: compte, offres: offres, horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester);
      expect(find.text(messageErreur), findsOneWidget);
      expect(find.text(_attente, skipOffstage: false), findsNothing);

      await toucher(tester, find.text('PAYER'));
      expect(offres.initiations, 2);
      expect(offres.cles[1], offres.cles[0]);
      expect(find.text(_attente, skipOffstage: false), findsOneWidget);
      await laisserConfirmer(tester, horloge);
      expect(find.text("✓ Pass semaine Turfiste actif jusqu'au 24/11"), findsOneWidget);
    });

    testWidgets('sondage : 5 erreurs → avis non bloquant et ralentissement ; arrêt après 10 minutes', (tester) async {
      final horloge = Horloge();
      final (compte, offres) = fauxLies(horloge);
      offres.echecsStatut = -1;
      await pumpApp(tester, store: await storeAvecSession(), compte: compte, offres: offres, horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 2));
      }
      await tester.pump();
      expect(offres.lecturesStatut, 4);
      expect(find.text(messageStatutNonActualise), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(offres.lecturesStatut, 5);
      expect(find.text(messageStatutNonActualise), findsOneWidget);
      expect(find.text(_attente, skipOffstage: false), findsOneWidget);

      // Ralenti : plus de lecture à 2 s, une à 10 s.
      await tester.pump(const Duration(seconds: 2));
      expect(offres.lecturesStatut, 5);
      await tester.pump(const Duration(seconds: 8));
      await tester.pump();
      expect(offres.lecturesStatut, 6);

      await tester.pump(const Duration(minutes: 11));
      await tester.pump();
      final lectures = offres.lecturesStatut;
      await tester.pump(const Duration(minutes: 5));
      expect(offres.lecturesStatut, lectures);
      expect(find.text(messageStatutNonActualise), findsOneWidget);
      // Toujours aucune issue décidée par l'app.
      expect(find.text(_attente, skipOffstage: false), findsOneWidget);
    });

    testWidgets('paiement inconnu du serveur : issue définitive, le sondage s\'arrête', (tester) async {
      final horloge = Horloge();
      final (compte, offres) = fauxLies(horloge);
      offres.statutInconnu = true;
      await pumpApp(tester, store: await storeAvecSession(), compte: compte, offres: offres, horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester);
      await tester.pump(const Duration(seconds: 2));
      await attendre(tester);
      expect(find.text('PAIEMENT NON CONFIRMÉ'), findsOneWidget);
      expect(find.textContaining('Le statut de ce paiement est introuvable.'), findsOneWidget);
      final lectures = offres.lecturesStatut;
      await tester.pump(const Duration(seconds: 30));
      expect(offres.lecturesStatut, lectures);
    });

    testWidgets('statut : un seul emplacement, région live, libellé qui change ; jamais d\'or', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: await storeAvecSession(), horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester);

      final emplacement = find.byKey(cleStatutPaiement);
      expect(emplacement, findsOneWidget);
      final avant = tester.element(emplacement);
      var noeud = tester.getSemantics(emplacement);
      expect(noeud.flagsCollection.isLiveRegion, isTrue);
      expect(noeud.label, startsWith('Paiement en attente de confirmation'));
      final bordure = (tester.widget<Container>(
        find.descendant(of: emplacement, matching: find.byType(Container)).first,
      ).decoration as BoxDecoration).border as Border;
      expect(bordure.top.color, isNot(JetonsAuth.gold));
      expect(bordure.top.color, JetonsAuth.lineCard);
      final mtn = find.ancestor(of: find.text('MTN MoMo'), matching: find.byType(Material)).first;
      final cote = (tester.widget<Material>(mtn).shape as RoundedRectangleBorder).side.color;
      expect(cote, JetonsAuth.text);
      expect(cote, isNot(JetonsAuth.gold));

      await laisserConfirmer(tester, horloge);
      // Même élément : seul le libellé change (une annonce).
      expect(tester.element(emplacement), same(avant));
      noeud = tester.getSemantics(emplacement);
      expect(noeud.flagsCollection.isLiveRegion, isTrue);
      expect(noeud.label, startsWith("Paiement confirmé. Pass semaine Turfiste actif jusqu'au 24/11"));
      expect(tester.widget<StatutPaiementBloc>(emplacement).etat, EtatPaiement.confirme);
    });

    testWidgets('numéro du compte proposé après connexion, modifiable', (tester) async {
      await pumpApp(tester, store: MemorySessionStore());
      await connexion(tester, '677000000');
      expect(find.text('ACCUEIL'), findsOneWidget);
      await ouvrirPaiement(tester);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '677000000');
      expect(find.text('Le numéro de votre compte est proposé ; vous pouvez en saisir un autre.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '655000011');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '655000011');
    });

    testWidgets('déconnexion : le paiement suivi est effacé', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: await storeAvecSession(), horloge: horloge);
      await ouvrirPaiement(tester);
      await payer(tester);
      final conteneur = _conteneur(tester);
      expect(conteneur.read(paiementEnCoursProvider)?.etape, EtapePaiement.enAttente);
      await conteneur.read(authProvider.notifier).seDeconnecter();
      await attendre(tester);
      expect(conteneur.read(paiementEnCoursProvider), isNull);
    });

    testWidgets('confirmé puis verrouillage : retour système → rien ne se dépile derrière la porte', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: await storeAvecSession(pin: '1234'), horloge: horloge, web: false);
      await taperPin(tester, '1234');
      expect(find.text('ACCUEIL'), findsOneWidget);
      await ouvrirPaiement(tester);
      await payer(tester);
      await laisserConfirmer(tester, horloge);
      expect(find.text('PAIEMENT CONFIRMÉ'), findsOneWidget);

      final auth = _conteneur(tester).read(authProvider.notifier);
      auth.passerEnArrierePlan();
      horloge.avancer(const Duration(minutes: 6));
      auth.revenirAuPremierPlan();
      await attendre(tester);
      expect(find.byType(PaiementScreen), findsNothing); // masqué par la porte
      expect(find.byType(PaiementScreen, skipOffstage: false), findsOneWidget);

      await tester.binding.handlePopRoute();
      await attendre(tester);
      await tester.binding.handlePopRoute();
      await attendre(tester);
      expect(find.byType(PaiementScreen, skipOffstage: false), findsOneWidget);

      await taperPin(tester, '1234');
      expect(find.text('PAIEMENT CONFIRMÉ'), findsOneWidget);
    });

    testWidgets('textes d\'Offres et de Paiement : aucune urgence ni promesse de gain', (tester) async {
      final horloge = Horloge();
      final textes = <String>[];
      void relever() => textes.addAll(textesConstruits(tester));

      await pumpApp(tester, store: await storeAvecSession(), horloge: horloge);
      await ouvrirOffres(tester);
      await toucher(tester, find.text('Offre Duo Turfiste'));
      relever();
      await toucher(tester, find.text('CONTINUER VERS LE PAIEMENT'));
      relever();
      await payer(tester, numero: FauxOffresApi.numeroEchec);
      relever();
      await laisserConfirmer(tester, horloge);
      relever();
      await toucher(tester, find.text('Changer de moyen'));
      await payer(tester);
      await laisserConfirmer(tester, horloge);
      relever();
      expect(find.text('PAIEMENT CONFIRMÉ'), findsOneWidget);

      expect(textes.length, greaterThan(40));
      for (final t in textes) {
        final bas = t.toLowerCase();
        for (final mot in motsInterdits) {
          expect(bas.contains(mot), isFalse, reason: '« $mot » dans « $t »');
        }
      }
    });
  });

  group('drapeaux de démo', () {
    test('release (démo interdite) : pas d\'Offres, pas de mode démo, aucune OffresApi', () {
      final c = ProviderContainer(overrides: [demoAutoriseeProvider.overrideWithValue(false)]);
      addTearDown(c.dispose);
      expect(c.read(offresDisponiblesProvider), isFalse);
      expect(c.read(modeDemoPaiementProvider), isFalse);
      expect(() => c.read(offresApiProvider), throwsA(anything));
    });

    test('démo autorisée : faux serveur → mode démo ; OffresApi réelle → pas de mode démo', () {
      final faux = ProviderContainer(overrides: [demoAutoriseeProvider.overrideWithValue(true)]);
      addTearDown(faux.dispose);
      expect(faux.read(offresApiProvider), isA<FauxOffresApi>());
      expect(faux.read(modeDemoPaiementProvider), isTrue);
      final reel = ProviderContainer(
        overrides: [offresApiProvider.overrideWithValue(OffresDeleguees(FauxOffresApi()))],
      );
      addTearDown(reel.dispose);
      expect(reel.read(modeDemoPaiementProvider), isFalse);
    });

    testWidgets('OffresApi réelle : ligne « Mode démo » absente d\'Offres et de Paiement', (tester) async {
      final horloge = Horloge();
      final (compte, faux) = fauxLies(horloge);
      await pumpApp(
        tester,
        store: await storeAvecSession(),
        compte: compte,
        offres: OffresDeleguees(faux),
        horloge: horloge,
      );
      await ouvrirOffres(tester);
      expect(find.text(messageModeDemoPaiement), findsNothing);
      await toucher(tester, find.text('Pass semaine Turfiste'));
      await toucher(tester, find.text('CONTINUER VERS LE PAIEMENT'));
      expect(find.text('PAIEMENT'), findsOneWidget);
      expect(find.text(messageModeDemoPaiement), findsNothing);
    });
  });
}
