import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/main.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/screens/email_secours_screen.dart';
import 'package:prediction_hippique/screens/mes_appareils_screen.dart';
import 'package:prediction_hippique/screens/profil_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_test_helpers.dart';
import 'compte_test_helpers.dart';

/// Retrait en accès limité suspendu jusqu'à [fin].
class _RetraitSuspendu extends FauxCompteApi {
  final fin = Completer<RetraitRestreintResultat>();
  _RetraitSuspendu() : super(web: true);

  @override
  Future<RetraitRestreintResultat> retirerAppareilRestreint(JetonGestionAppareils jeton, String id) => fin.future;
}

/// Quota quotidien atteint (429).
class _Quota extends FauxCompteApi {
  _Quota() : super(web: true);

  @override
  Future<RetraitRestreintResultat> retirerAppareilRestreint(JetonGestionAppareils jeton, String id) async =>
      const TropDeTentativesAujourdhui();
}

/// La liste réussit [succes] fois puis échoue.
class _ListePuisPanne extends FauxCompteApi {
  int succes;
  _ListePuisPanne(this.succes) : super(web: true);

  @override
  Future<ListeAppareils> listerAppareils() async {
    if (succes-- <= 0) throw Exception('réseau');
    return super.listerAppareils();
  }
}

/// Le profil se lit une fois, puis échoue.
class _ProfilPuisPanne extends FauxCompteApi {
  int lectures = 0;
  _ProfilPuisPanne() : super(web: true);

  @override
  Future<ProfilCompte> lireProfil() async {
    if (lectures++ > 0) throw Exception('réseau');
    return super.lireProfil();
  }
}

Future<void> _retour(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await attendre(tester);
}

Future<void> _jusquALAccesLimite(WidgetTester tester, {CompteApi? compte}) async {
  await pumpApp(tester, store: MemorySessionStore(), compte: compte);
  await connexion(tester, '699999999');
  await tester.tap(find.text('RETIRER UN APPAREIL'));
  await attendre(tester);
}

Future<void> _confirmerRetrait(WidgetTester tester, {int index = 0}) async {
  await tester.tap(find.text('Retirer').at(index));
  await attendre(tester);
  await tester.tap(find.widgetWithText(TextButton, 'Retirer'));
  await attendre(tester);
}

void main() {
  group('accès limité', () {
    testWidgets('retour système bloqué pendant le retrait, puis sans effet sur Connexion', (tester) async {
      final compte = _RetraitSuspendu();
      await _jusquALAccesLimite(tester, compte: compte);
      await _confirmerRetrait(tester);

      await _retour(tester);
      expect(find.text('Retirez un appareil pour connecter celui-ci'), findsOneWidget);

      compte.fin.complete(const AppareilRetire('Samsung Galaxy A14'));
      await attendre(tester);
      expect(find.text('Votre numéro de téléphone'), findsOneWidget);
      expect(find.text(messageAppareilRetire('Samsung Galaxy A14')), findsOneWidget);

      await _retour(tester);
      expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    });

    testWidgets('retour système hors retrait : revient à Appareil bloqué', (tester) async {
      await _jusquALAccesLimite(tester);
      await _retour(tester);
      expect(find.text('Limite de 2 appareils atteinte'), findsOneWidget);
    });

    testWidgets('429 : « Trop de tentatives aujourd\'hui » → Connexion', (tester) async {
      await _jusquALAccesLimite(tester, compte: _Quota());
      await _confirmerRetrait(tester);
      expect(find.text('Votre numéro de téléphone'), findsOneWidget);
      expect(find.text(messageTropDeTentatives), findsOneWidget);
    });

    testWidgets('jeton expiré sans aucun geste, sur Appareil bloqué : Connexion « Délai dépassé »', (tester) async {
      await pumpApp(tester, store: MemorySessionStore());
      await connexion(tester, '699999999');
      expect(find.text('Limite de 2 appareils atteinte'), findsOneWidget);
      await tester.pump(dureeJetonGestion);
      await attendre(tester);
      expect(find.text('Votre numéro de téléphone'), findsOneWidget);
      expect(find.text(messageDelaiDepasse), findsOneWidget);
    });

    testWidgets('jeton expiré sans aucun geste, dans Mes appareils limité : Connexion « Délai dépassé »', (
      tester,
    ) async {
      await _jusquALAccesLimite(tester);
      await tester.pump(dureeJetonGestion);
      await attendre(tester);
      expect(find.text('Votre numéro de téléphone'), findsOneWidget);
      expect(find.text(messageDelaiDepasse), findsOneWidget);
    });

    testWidgets('jeton refusé au chargement d\'Appareil bloqué : Connexion « Délai dépassé »', (tester) async {
      final horloge = Horloge();
      await pumpApp(tester, store: MemorySessionStore(), horloge: horloge);
      await connexion(tester, '699999999');
      await tester.tap(find.text("Découvrir l'offre Duo"));
      await attendre(tester);
      horloge.avancer(dureeJetonGestion);
      // Retour à Appareil bloqué : la liste est rechargée, le jeton refusé.
      await tester.tap(find.byTooltip('Retour'));
      await attendre(tester);
      expect(find.text(messageDelaiDepasse), findsOneWidget);
    });
  });

  group('Mes appareils', () {
    testWidgets('double toucher sur « Retirer » : un seul dialogue', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirAppareils(tester);
      await tester.tap(find.text('Retirer'));
      await tester.tap(find.text('Retirer'), warnIfMissed: false);
      await attendre(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('rechargement raté après un retrait réussi : ligne retirée, succès affiché', (tester) async {
      await pumpApp(tester, store: await storeAvecSession(), compte: _ListePuisPanne(1));
      await ouvrirAppareils(tester);
      await _confirmerRetrait(tester);
      expect(find.text('Chrome sur Windows a été retiré.'), findsOneWidget);
      expect(find.text('Retirer'), findsNothing);
      expect(find.text(messageChargementAppareils), findsNothing);
    });

    testWidgets('appareil (pas web) : libellés téléphone', (tester) async {
      await pumpApp(tester, store: await storeAvecSession(pin: '4821'), web: false);
      await taperPin(tester, '4821');
      await ouvrirAppareils(tester);
      expect(find.textContaining('Téléphone Android'), findsOneWidget);
      expect(find.textContaining('CET APPAREIL'), findsOneWidget);
      expect(find.text('Application Android · actif maintenant'), findsOneWidget);
    });
  });

  group('Profil', () {
    testWidgets('appareil (pas web) : se déconnecter, puis reconnexion par code et choix du PIN → Accueil', (
      tester,
    ) async {
      final store = await storeAvecSession(pin: '4821');
      await pumpApp(tester, store: store, web: false);
      await taperPin(tester, '4821');
      await ouvrirProfil(tester);
      await tester.tap(find.text('Se déconnecter'));
      await attendre(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Se déconnecter'));
      await attendre(tester);
      expect(store.session, isNull);
      expect(find.byType(ProfilScreen, skipOffstage: false), findsNothing);

      await connexion(tester, '677123456');
      expect(find.text('Choisissez un code PIN'), findsOneWidget);
      await taperPin(tester, '4821');
      await tester.tap(find.text('CONTINUER'));
      await tester.pump();
      await taperPin(tester, '4821');
      expect(find.text('ACCUEIL'), findsOneWidget);
      expect(store.session!.pinDefini, isTrue);
    });

    testWidgets('rechargement raté : ancien profil gardé, avis « Profil non actualisé »', (tester) async {
      await pumpApp(tester, store: await storeAvecSession(), compte: _ProfilPuisPanne());
      await ouvrirAppareils(tester);
      await tester.tap(find.byTooltip('Retour'));
      await attendre(tester);
      expect(find.text('PROFIL'), findsOneWidget);
      expect(find.text(messageProfilNonActualise), findsOneWidget);
      expect(find.text('Non renseigné'), findsOneWidget);
    });

    testWidgets('email : retour système à l\'étape code → saisie de l\'adresse, puis Profil', (tester) async {
      await pumpApp(tester, store: await storeAvecSession());
      await ouvrirProfil(tester);
      await tester.tap(find.text('Ajouter'));
      await attendre(tester);
      await tester.enterText(find.byType(TextField), 'marc@exemple.cm');
      await tester.pump();
      await tester.tap(find.text('RECEVOIR LE CODE PAR EMAIL'));
      await attendre(tester);
      expect(find.text('Saisissez le code à 6 chiffres'), findsOneWidget);

      await _retour(tester);
      expect(find.text('Votre email de secours'), findsOneWidget);
      await _retour(tester);
      expect(find.text('PROFIL'), findsOneWidget);
    });

    testWidgets('email déjà vérifié ressaisi (casse, espaces) : pas de nouvelle vérification', (tester) async {
      final compte = FauxCompteApi(web: true, email: 'marc@exemple.cm', emailVerifie: true);
      await pumpApp(tester, store: await storeAvecSession(), compte: compte);
      await ouvrirProfil(tester);
      await tester.tap(find.text('Modifier'));
      await attendre(tester);
      expect(find.byType(EmailSecoursScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' Marc@Exemple.CM ');
      await tester.pump();
      await tester.tap(find.text('RECEVOIR LE CODE PAR EMAIL'));
      await attendre(tester);
      expect(find.text(messageEmailDejaVerifie), findsOneWidget);
      expect(find.text('Votre email de secours'), findsOneWidget);
    });
  });

  testWidgets('vraie app, release sans AUTH_DEMO : pas d\'icône de compte sur Accueil', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overridesAuth(store: await storeAvecSession(), web: true),
          demoAutoriseeProvider.overrideWithValue(false),
        ],
        child: const PredictionHippiqueApp(),
      ),
    );
    await attendre(tester);
    expect(find.text('Programme du jour'), findsOneWidget);
    expect(find.byTooltip('Profil'), findsNothing);
  });
}
