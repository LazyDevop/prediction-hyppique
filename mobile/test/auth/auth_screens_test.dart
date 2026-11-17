import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/screens/connexion_screen.dart' show messageErreur;
import 'package:prediction_hippique/screens/porte_screen.dart';

import 'auth_test_helpers.dart';

const _ctaCode = 'RECEVOIR LE CODE PAR SMS';

/// Même branchement que main.dart (porte via `builder`), avec un Accueil
/// factice : pas d'appel réseau.
Future<void> _pumpApp(
  WidgetTester tester, {
  required SessionStore store,
  bool web = false,
  Horloge? horloge,
  AuthApi? api,
}) async {
  // Écran de téléphone (390 × 844), comme la maquette.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final cle = GlobalKey<NavigatorState>();
  await tester.pumpWidget(ProviderScope(
    overrides: overridesAuth(store: store, web: web, horloge: horloge, api: api),
    child: MaterialApp(
      navigatorKey: cle,
      builder: (context, nav) => PorteScreen(application: nav!, navigatorKey: cle),
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(children: [
            const Text('ACCUEIL'),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const Scaffold(body: Text('ÉCRAN POUSSÉ'))),
              ),
              child: const Text('Ouvrir'),
            ),
          ]),
        ),
      ),
    ),
  ));
  await _attendre(tester);
}

/// Laisse passer les futures (stockage, Argon2id) sans vider le minuteur
/// de renvoi par un pumpAndSettle.
Future<void> _attendre(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

VoidCallback? _onPressed(WidgetTester tester, String texte) {
  final bouton = find.ancestor(of: find.text(texte), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  return tester.widget<ButtonStyleButton>(bouton.first).onPressed;
}

Future<void> _jusquAuCode(WidgetTester tester, {String numero = '677123456'}) async {
  await tester.enterText(find.byType(TextField), numero);
  await tester.tap(find.textContaining("J'accepte"));
  await tester.pump();
  await tester.tap(find.text(_ctaCode));
  await _attendre(tester);
}

Future<void> _saisirCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.pump();
  await tester.tap(find.text('VALIDER'));
  await _attendre(tester);
}

Future<void> _taperPin(WidgetTester tester, String pin) async {
  for (final c in pin.split('')) {
    await tester.tap(find.text(c));
    await tester.pump();
  }
  await _attendre(tester);
}

Future<void> _arrierePlan(WidgetTester tester) async {
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

Future<void> _premierPlan(WidgetTester tester) async {
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await _attendre(tester);
}

void main() {
  testWidgets('premier lancement : Connexion étape 1', (tester) async {
    await _pumpApp(tester, store: MemorySessionStore());
    expect(find.text('ANALYSEUR HIPPIQUE'), findsOneWidget);
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    expect(find.text('ACCUEIL'), findsNothing);
    expect(find.textContaining('aucun modèle ne garantit un gain'), findsOneWidget);
  });

  testWidgets('demande de code : bouton désactivé tant que numéro et CGU manquent', (tester) async {
    await _pumpApp(tester, store: MemorySessionStore());
    expect(_onPressed(tester, _ctaCode), isNull);
    await tester.enterText(find.byType(TextField), '677123456');
    await tester.pump();
    expect(_onPressed(tester, _ctaCode), isNull, reason: 'CGU non cochées');
    await tester.tap(find.textContaining("J'accepte"));
    await tester.pump();
    expect(_onPressed(tester, _ctaCode), isNotNull);
    await tester.tap(find.text(_ctaCode));
    await _attendre(tester);

    expect(find.text('CODE REÇU'), findsOneWidget);
    expect(
      find.text("Si ce numéro peut recevoir un code, il vient d'être envoyé au +237 6 77 12 34 56."),
      findsOneWidget,
    );
    expect(find.text('Mode démo : le code est 123456'), findsOneWidget);
    expect(find.text('VALIDER · 0 CHIFFRE SUR 6'), findsOneWidget);
    expect(find.text('Renvoyer le code · dans 60 s'), findsOneWidget);
    expect(_onPressed(tester, 'Renvoyer le code · dans 60 s'), isNull);

    await tester.enterText(find.byType(TextField), '4820');
    await tester.pump();
    expect(find.text('VALIDER · 4 CHIFFRES SUR 6'), findsOneWidget);
    expect(_onPressed(tester, 'VALIDER · 4 CHIFFRES SUR 6'), isNull);

    await tester.pump(const Duration(seconds: 61));
    expect(_onPressed(tester, 'Renvoyer le code'), isNotNull);
  });

  testWidgets("numéro invalide : reste à l'étape 1 avec un message", (tester) async {
    await _pumpApp(tester, store: MemorySessionStore());
    await _jusquAuCode(tester, numero: '712345678');
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    expect(find.textContaining('Numéro invalide'), findsOneWidget);
  });

  testWidgets('code 123456 sur appareil : choix du PIN, puis Accueil', (tester) async {
    final store = MemorySessionStore();
    await _pumpApp(tester, store: store);
    await _jusquAuCode(tester);
    await _saisirCode(tester, '123456');

    expect(find.text('Choisissez un code PIN'), findsOneWidget);
    expect(find.text('0 chiffre saisi · encore 4 au minimum'), findsOneWidget);
    await _taperPin(tester, '482');
    expect(find.text('3 chiffres saisis · encore 1 au minimum'), findsOneWidget);
    expect(_onPressed(tester, 'CONTINUER'), isNull);
    await _taperPin(tester, '1');
    await tester.tap(find.text('CONTINUER'));
    await tester.pump();

    expect(find.text('Confirmez votre code PIN'), findsOneWidget);
    await _taperPin(tester, '4821');
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(store.session!.pinDefini, isTrue);
  });

  testWidgets('code 123456 sur le web : Accueil sans PIN', (tester) async {
    await _pumpApp(tester, store: MemorySessionStore(), web: true);
    await _jusquAuCode(tester);
    await _saisirCode(tester, '123456');
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.text('Choisissez un code PIN'), findsNothing);
  });

  testWidgets("mauvais code : essais restants, puis retour à l'étape 1 au 5e", (tester) async {
    await _pumpApp(tester, store: MemorySessionStore());
    await _jusquAuCode(tester);
    await _saisirCode(tester, '000000');
    expect(find.text('Code incorrect — 4 essais restants'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await _saisirCode(tester, '000000');
    }
    expect(find.text('Code incorrect — 1 essai restant'), findsOneWidget);
    await _saisirCode(tester, '000000');
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    expect(find.text("Trop d'essais — demandez un nouveau code"), findsOneWidget);
  });

  testWidgets("code expiré : retour à l'étape 1", (tester) async {
    final horloge = Horloge();
    await _pumpApp(tester, store: MemorySessionStore(), horloge: horloge);
    await _jusquAuCode(tester);
    horloge.avancer(const Duration(minutes: 6));
    await _saisirCode(tester, '123456');
    expect(find.text('Code expiré — demandez un nouveau code'), findsOneWidget);
  });

  testWidgets('confirmation différente : on recommence le choix avec un message', (tester) async {
    await _pumpApp(tester, store: MemorySessionStore());
    await _jusquAuCode(tester);
    await _saisirCode(tester, '123456');
    expect(find.text('Choisissez un code PIN'), findsOneWidget);
    await _taperPin(tester, '4821');
    await tester.tap(find.text('CONTINUER'));
    await tester.pump();
    await _taperPin(tester, '4822');
    expect(find.text('Choisissez un code PIN'), findsOneWidget);
    expect(find.textContaining('ne correspondent pas'), findsOneWidget);
  });

  testWidgets('démarrage à froid avec PIN : Déverrouillage, bon PIN → Accueil', (tester) async {
    await _pumpApp(tester, store: await storeAvecSession(pin: '4821'));
    expect(find.text('Saisissez votre code PIN'), findsOneWidget);
    expect(find.text('Compte +237 6 •• •• •• 56'), findsOneWidget);
    expect(find.text('0 chiffre saisi sur 4'), findsOneWidget);
    await _taperPin(tester, '4821');
    expect(find.text('ACCUEIL'), findsOneWidget);
  });

  testWidgets('démarrage à froid sur le web : Accueil', (tester) async {
    await _pumpApp(tester, store: await storeAvecSession(pin: '4821'), web: true);
    expect(find.text('ACCUEIL'), findsOneWidget);
  });

  testWidgets('mauvais PIN : essais restants, 5e → session effacée → Connexion', (tester) async {
    final store = await storeAvecSession(pin: '4821');
    await _pumpApp(tester, store: store);
    await _taperPin(tester, '0000');
    expect(find.textContaining('Code incorrect — 4 essais restants'), findsOneWidget);
    expect(find.text('0 chiffre saisi sur 4'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await _taperPin(tester, '0000');
    }
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    expect(find.text('Session effacée — reconnectez-vous par code SMS'), findsOneWidget);
    expect(store.session, isNull);
  });

  testWidgets('« Code oublié ? » : Connexion', (tester) async {
    final store = await storeAvecSession(pin: '4821');
    await _pumpApp(tester, store: store);
    await tester.tap(find.text('Code oublié ? Se reconnecter par code SMS'));
    await _attendre(tester);
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    expect(store.session, isNull);
  });

  testWidgets("retour au premier plan après 5 min : Déverrouillage par-dessus l'écran poussé", (tester) async {
    final horloge = Horloge();
    await _pumpApp(tester, store: await storeAvecSession(pin: '4821'), horloge: horloge);
    await _taperPin(tester, '4821');
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('ÉCRAN POUSSÉ'), findsOneWidget);

    await _arrierePlan(tester);
    horloge.avancer(DELAI_VERROUILLAGE);
    await _premierPlan(tester);
    expect(find.text('Saisissez votre code PIN'), findsOneWidget);
    expect(find.text('ÉCRAN POUSSÉ'), findsNothing);

    await _taperPin(tester, '4821');
    // La pile de navigation est intacte.
    expect(find.text('ÉCRAN POUSSÉ'), findsOneWidget);
  });

  testWidgets('retour au premier plan avant 5 min : pas de verrouillage', (tester) async {
    final horloge = Horloge();
    await _pumpApp(tester, store: await storeAvecSession(pin: '4821'), horloge: horloge);
    await _taperPin(tester, '4821');
    await _arrierePlan(tester);
    horloge.avancer(const Duration(minutes: 4));
    await _premierPlan(tester);
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.text('Saisissez votre code PIN'), findsNothing);
  });

  testWidgets('pin-pad : touches ≥ 48dp, étiquetées, saisie annoncée sans les chiffres', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester, store: await storeAvecSession(pin: '4821'));
    expect(tester.getSize(find.bySemanticsLabel('5')).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Effacer'), findsOneWidget);
    await _taperPin(tester, '48');
    expect(find.bySemanticsLabel('2 chiffres sur 4 saisis'), findsOneWidget);
    await tester.tap(find.text('⌫ Effacer'));
    await tester.pump();
    expect(find.text('1 chiffre saisi sur 4'), findsOneWidget);
    handle.dispose();
  });

  testWidgets("trop de demandes : message à l'étape 1", (tester) async {
    final api = ApiScriptee([const TropDeDemandes()]);
    await _pumpApp(tester, store: MemorySessionStore(), api: api);
    await _jusquAuCode(tester);
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    expect(find.text('Trop de demandes — réessayez dans quelques minutes'), findsOneWidget);
  });

  testWidgets("« Renvoyer le code » refait une demande ; trop de demandes affiché à l'étape 2", (tester) async {
    final api = ApiScriptee([const CodeEnvoye(), const CodeEnvoye(), const TropDeDemandes()]);
    await _pumpApp(tester, store: MemorySessionStore(), api: api);
    await _jusquAuCode(tester);
    expect(api.appelsDemande, 1);
    expect(find.textContaining('Le renvoi est possible dans 60 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 61));
    expect(find.textContaining('puis renvoyez le code'), findsOneWidget);
    await tester.ensureVisible(find.text('Renvoyer le code'));
    await tester.tap(find.text('Renvoyer le code'));
    await _attendre(tester);
    expect(api.appelsDemande, 2);
    expect(find.text('Renvoyer le code · dans 60 s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 61));
    await tester.ensureVisible(find.text('Renvoyer le code'));
    await tester.tap(find.text('Renvoyer le code'));
    await _attendre(tester);
    expect(api.appelsDemande, 3);
    expect(find.text('CODE REÇU'), findsOneWidget);
    expect(find.text('Trop de demandes — réessayez dans quelques minutes'), findsOneWidget);
  });

  testWidgets('erreur du serveur : message générique, on peut réessayer', (tester) async {
    await _pumpApp(tester, store: MemorySessionStore(), api: _ApiEnPanne());
    await _jusquAuCode(tester);
    expect(find.text(messageErreur), findsOneWidget);
    expect(_onPressed(tester, _ctaCode), isNotNull);
  });

  testWidgets('stockage illisible : Connexion', (tester) async {
    await _pumpApp(tester, store: StoreEnPanne());
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);
    expect(find.text('ACCUEIL'), findsNothing);
  });

  testWidgets('collage « +237 6 77 12 34 56 », « 00237… » ou « 0677123456 » : 9 chiffres locaux', (tester) async {
    await _pumpApp(tester, store: MemorySessionStore());
    for (final colle in ['+237 6 77 12 34 56', '00237677123456', '0677123456', '237677123456']) {
      await tester.enterText(find.byType(TextField), colle);
      await tester.pump();
      expect(find.widgetWithText(TextField, '677123456'), findsOneWidget, reason: colle);
    }
  });

  testWidgets('message « session effacée » retiré dès que le numéro est modifié', (tester) async {
    await _pumpApp(tester, store: await storeAvecSession(pin: '4821', echecs: essaisPinMax));
    expect(find.text('Session effacée — reconnectez-vous par code SMS'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '6');
    await tester.pump();
    expect(find.text('Session effacée — reconnectez-vous par code SMS'), findsNothing);
  });

  testWidgets('retour système : étape 2 → étape 1 ; étape 1 et choix du PIN bloqués ; confirmation → choix',
      (tester) async {
    await _pumpApp(tester, store: MemorySessionStore());
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);

    await _jusquAuCode(tester);
    expect(find.text('CODE REÇU'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Votre numéro de téléphone'), findsOneWidget);

    // Numéro et CGU sont conservés : on redemande directement.
    await tester.tap(find.text(_ctaCode));
    await _attendre(tester);
    await _saisirCode(tester, '123456');
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Choisissez un code PIN'), findsOneWidget);
    await _taperPin(tester, '4821');
    await tester.tap(find.text('CONTINUER'));
    await tester.pump();
    expect(find.text('Confirmez votre code PIN'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Choisissez un code PIN'), findsOneWidget);
  });

  testWidgets("retour système sur Déverrouillage : la pile masquée n'est pas dépilée", (tester) async {
    final horloge = Horloge();
    await _pumpApp(tester, store: await storeAvecSession(pin: '4821'), horloge: horloge);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Saisissez votre code PIN'), findsOneWidget);

    await _taperPin(tester, '4821');
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await _arrierePlan(tester);
    horloge.avancer(DELAI_VERROUILLAGE);
    await _premierPlan(tester);
    expect(find.text('Saisissez votre code PIN'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Saisissez votre code PIN'), findsOneWidget);
    await _taperPin(tester, '4821');
    expect(find.text('ÉCRAN POUSSÉ'), findsOneWidget);

    // Déverrouillée : le retour fonctionne de nouveau normalement.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('ACCUEIL'), findsOneWidget);
  });

  testWidgets('erreur pendant la vérification du PIN : message, essai compté, pavé réactivé', (tester) async {
    final store = await storeAvecSession(pin: '4821');
    await tester.pumpWidget(ProviderScope(
      overrides: overridesAuth(store: store, hasher: HasherEnPanne()),
      child: MaterialApp(builder: (context, nav) => PorteScreen(application: nav!), home: const Text('ACCUEIL')),
    ));
    await _attendre(tester);
    await _taperPin(tester, '4821');
    expect(find.text(messageErreur), findsOneWidget);
    expect(store.session!.echecsPin, 1);
    expect(find.text('0 chiffre saisi sur 4'), findsOneWidget);
  });
}

class _ApiEnPanne implements AuthApi {
  @override
  Future<DemandeCodeResultat> demanderCode(String numero, String cguVersion) async => throw Exception('réseau');

  @override
  Future<VerificationResultat> verifierCode(String numero, String code) async => throw Exception('réseau');
}
