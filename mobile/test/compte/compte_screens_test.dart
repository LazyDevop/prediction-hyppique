import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/screens/mes_appareils_screen.dart';
import 'package:prediction_hippique/screens/profil_screen.dart';

import '../auth/auth_test_helpers.dart';
import 'compte_test_helpers.dart';

void main() {
  group('Profil', () {
    testWidgets('icône de compte → Profil : numéro, email non renseigné, Gratuit, CGU, Mes appareils', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirProfil(tester);

      expect(find.text('PROFIL'), findsOneWidget);
      expect(find.text('+237 6 •• •• •• 00'), findsOneWidget);
      expect(find.text('Non renseigné'), findsOneWidget);
      expect(find.text('Gratuit'), findsOneWidget);
      expect(find.text('GRATUIT'), findsOneWidget);
      expect(find.text('Sans date de fin'), findsOneWidget);
      expect(find.text('Version $CGU_VERSION_PROVISOIRE'), findsOneWidget);
      expect(find.text('Acceptées le 17/11/2026'), findsOneWidget);
      expect(find.text('Mes appareils'), findsOneWidget);
      expect(find.text('2 sur 2'), findsOneWidget);
      expect(find.text('Se déconnecter'), findsOneWidget);
      // Offres (story 9.4) : ligne de la section Palier.
      expect(find.text('Offres'), findsOneWidget);
      expect(find.text('Voir les offres'), findsOneWidget);
      // Stories non livrées : absentes, jamais désactivées.
      expect(find.textContaining('Duo'), findsNothing);
      expect(find.textContaining('QR'), findsNothing);
      expect(find.textContaining('Changer de numéro'), findsNothing);
      expect(find.textContaining('Code PIN et verrouillage'), findsNothing);
      // Palier Gratuit : pas de rappel email.
      expect(find.textContaining('Ajoutez un email de secours vérifié'), findsNothing);
    });

    testWidgets('palier payant sans email vérifié : rappel non bloquant, état écrit « Non vérifié »', (tester) async {
      final compte = FauxCompteApi(web: true, palier: 'Expert', email: 'marc@exemple.cm');
      await pumpApp(tester, store: await storeAvecSession(), compte: compte);
      await ouvrirProfil(tester);
      expect(find.textContaining('Ajoutez un email de secours vérifié.'), findsOneWidget);
      expect(find.text('NON VÉRIFIÉ'), findsOneWidget);
      expect(find.text('EXPERT'), findsOneWidget);
    });

    testWidgets('ajout d\'email : adresse invalide → erreur ; code 123456 → « Vérifié »', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirProfil(tester);
      await tester.tap(find.text('Ajouter'));
      await attendre(tester);

      expect(find.text('Votre email de secours'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'marc@');
      await tester.pump();
      await tester.tap(find.text('RECEVOIR LE CODE PAR EMAIL'));
      await attendre(tester);
      expect(find.text('Adresse email invalide.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'marc@exemple.cm');
      await tester.pump();
      await tester.tap(find.text('RECEVOIR LE CODE PAR EMAIL'));
      await attendre(tester);
      expect(find.text('Mode démo : le code est 123456'), findsOneWidget);
      expect(find.textContaining('marc@exemple.cm'), findsOneWidget);

      await saisirCode(tester, '123456');
      expect(find.text('PROFIL'), findsOneWidget);
      expect(find.text('marc@exemple.cm'), findsOneWidget);
      expect(find.text('VÉRIFIÉ'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
    });

    testWidgets('mauvais code email : essais restants, 5e → retour à la saisie de l\'adresse', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirProfil(tester);
      await tester.tap(find.text('Ajouter'));
      await attendre(tester);
      await tester.enterText(find.byType(TextField), 'marc@exemple.cm');
      await tester.pump();
      await tester.tap(find.text('RECEVOIR LE CODE PAR EMAIL'));
      await attendre(tester);

      await saisirCode(tester, '000000');
      expect(find.text('Code incorrect — 4 essais restants'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await saisirCode(tester, '000000');
      }
      expect(find.text('Votre email de secours'), findsOneWidget);
      expect(find.text("Trop d'essais — demandez un nouveau code"), findsOneWidget);
    });

    testWidgets('se déconnecter : Annuler ne change rien ; confirmer efface la session et ouvre Connexion', (
      tester,
    ) async {
      final store = await storeAvecSession();
      await pumpApp(tester, store: store);
      await ouvrirProfil(tester);

      await tester.tap(find.text('Se déconnecter'));
      await attendre(tester);
      expect(find.text('Se déconnecter de cet appareil ?'), findsOneWidget);
      expect(find.text('Vous devrez recevoir un nouveau code pour vous reconnecter.'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await attendre(tester);
      expect(find.text('PROFIL'), findsOneWidget);
      expect(store.session, isNotNull);

      await tester.tap(find.text('Se déconnecter'));
      await attendre(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Se déconnecter'));
      await attendre(tester);
      expect(store.session, isNull);
      expect(find.text('Votre numéro de téléphone'), findsOneWidget);
      // Pile détruite : Profil (route poussée) n'existe plus.
      expect(find.byType(ProfilScreen, skipOffstage: false), findsNothing);
    });
  });

  group('Mes appareils', () {
    testWidgets('liste : cet appareil en premier, l\'autre avec dernière activité et « Nouveau »', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirAppareils(tester);

      expect(find.text('MES APPAREILS'), findsOneWidget);
      expect(find.textContaining('Navigateur web'), findsOneWidget);
      expect(find.textContaining('CET APPAREIL'), findsOneWidget);
      expect(find.textContaining('NOUVEAU'), findsOneWidget);
      expect(find.textContaining('Nouvel appareil rattaché'), findsOneWidget);
      expect(find.text("Navigateur · web app · dernière activité aujourd'hui à 9 h 00"), findsOneWidget);
      expect(find.text('Navigateur · web app · actif maintenant'), findsOneWidget);
      // Cet appareil n'a pas de « Retirer ».
      expect(find.text('Retirer'), findsOneWidget);
      // QR (8.7) et Duo (Epic 9) absents.
      expect(find.textContaining('Scanner'), findsNothing);
      expect(find.textContaining('QR'), findsNothing);
      expect(find.textContaining('Duo'), findsNothing);
      final premier = tester.getTopLeft(find.textContaining('Navigateur web')).dy;
      final second = tester.getTopLeft(find.textContaining('Chrome sur Windows').last).dy;
      expect(premier, lessThan(second));
    });

    testWidgets('erreur de chargement : message + Réessayer', (tester) async {
      await pumpApp(tester, store: await storeAvecSession(), compte: CompteEnPanne(1));
      await ouvrirAppareils(tester);
      expect(find.text(messageChargementAppareils), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await attendre(tester);
      expect(find.text(messageChargementAppareils), findsNothing);
      expect(find.textContaining('CET APPAREIL'), findsOneWidget);
    });

    testWidgets('retirer : Annuler ne change rien, confirmer retire la ligne', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirAppareils(tester);

      await tester.tap(find.text('Retirer'));
      await attendre(tester);
      expect(find.text('Retirer Chrome sur Windows ?'), findsOneWidget);
      expect(find.text('Il sera déconnecté et une alerte partira vers votre numéro.'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await attendre(tester);
      expect(find.text('Retirer'), findsOneWidget);

      await tester.tap(find.text('Retirer'));
      await attendre(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Retirer'));
      await attendre(tester);
      expect(find.text('Retirer'), findsNothing);
      expect(find.text('Chrome sur Windows a été retiré.'), findsOneWidget);
      expect(find.text('1 sur 2 · limite du palier Gratuit'), findsOneWidget);
    });
  });

  group('Appareil bloqué', () {
    testWidgets('numéro 699999999, code ok : Appareil bloqué, aucune session ouverte', (tester) async {
      final store = MemorySessionStore();
      await pumpApp(tester, store: store);
      await connexion(tester, '699999999');

      expect(find.text('APPAREIL BLOQUÉ'), findsOneWidget);
      expect(find.text('Limite de 2 appareils atteinte'), findsOneWidget);
      expect(find.text("Aucun appareil n'a été déconnecté."), findsOneWidget);
      expect(find.text('Samsung Galaxy A14'), findsOneWidget);
      expect(find.text('ACCUEIL', skipOffstage: false), findsNothing);
      expect(store.session, isNull);
    });

    testWidgets('« Découvrir l\'offre Duo » : texte seul, sans paiement', (tester) async {
      await pumpApp(tester, store: MemorySessionStore());
      await connexion(tester, '699999999');
      await tester.tap(find.text("Découvrir l'offre Duo"));
      await attendre(tester);
      expect(find.text('Souscrivez depuis un appareil déjà connecté.'), findsOneWidget);
      await tester.tap(find.byTooltip('Retour'));
      await attendre(tester);
      expect(find.text('Limite de 2 appareils atteinte'), findsOneWidget);
    });

    testWidgets('accès limité : un retrait → Connexion avec message, puis connexion possible', (tester) async {
      final store = MemorySessionStore();
      await pumpApp(tester, store: store);
      await connexion(tester, '699999999');
      await tester.tap(find.text('RETIRER UN APPAREIL'));
      await attendre(tester);

      expect(find.text('Retirez un appareil pour connecter celui-ci'), findsOneWidget);
      expect(find.text('Accès limité : un seul retrait, pendant 10 minutes.'), findsOneWidget);
      expect(find.byType(MesAppareilsScreen), findsOneWidget);
      expect(find.text('Retirer'), findsNWidgets(2));
      // Accès limité : ni bandeau « Nouveau » ni note de bas de page.
      expect(find.textContaining('Nouvel appareil rattaché'), findsNothing);
      expect(find.textContaining('NOUVEAU'), findsNothing);
      expect(find.textContaining('Chaque navigateur connecté'), findsNothing);

      await tester.tap(find.text('Retirer').last);
      await attendre(tester);
      expect(find.text('Retirer Chrome sur Windows ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Retirer'));
      await attendre(tester);
      // Retrait fait : directement Connexion, avec le message.
      final message = messageAppareilRetire('Chrome sur Windows');
      expect(find.text('Votre numéro de téléphone'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(store.session, isNull);

      // Une place s'est libérée : la connexion aboutit (web : Accueil).
      await connexion(tester, '699999999');
      expect(find.text('ACCUEIL'), findsOneWidget);
      expect(store.session, isNotNull);
    });

    testWidgets('accès limité après 10 min : « Délai dépassé » → Connexion', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: MemorySessionStore(), horloge: horloge);
      await connexion(tester, '699999999');
      await tester.tap(find.text('RETIRER UN APPAREIL'));
      await attendre(tester);

      horloge.avancer(const Duration(minutes: 10));
      await tester.tap(find.text('Retirer').first);
      await attendre(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Retirer'));
      await attendre(tester);

      expect(find.text('Votre numéro de téléphone'), findsOneWidget);
      expect(find.text(messageDelaiDepasse), findsOneWidget);
    });
  });
}
