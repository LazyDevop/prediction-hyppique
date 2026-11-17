import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/screens/porte_screen.dart';
import 'package:prediction_hippique/screens/profil_screen.dart';

import '../auth/auth_test_helpers.dart';

/// Même branchement que main.dart (porte via `builder`), avec un Accueil
/// factice portant l'icône de compte (pas d'appel réseau). Web : la
/// session pré-remplie ouvre directement Accueil (pas de PIN).
Future<void> pumpApp(
  WidgetTester tester, {
  required SessionStore store,
  CompteApi? compte,
  Horloge? horloge,
  bool web = true,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final cle = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overridesAuth(store: store, web: web, compte: compte, horloge: horloge ?? Horloge()),
      child: MaterialApp(
        navigatorKey: cle,
        builder: (context, nav) => PorteScreen(application: nav!, navigatorKey: cle),
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  tooltip: 'Profil',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfilScreen())),
                ),
              ],
            ),
            body: const Text('ACCUEIL'),
          ),
        ),
      ),
    ),
  );
  await attendre(tester);
}

Future<void> attendre(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> ouvrirProfil(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profil'));
  await attendre(tester);
}

Future<void> ouvrirAppareils(WidgetTester tester) async {
  await ouvrirProfil(tester);
  await tester.tap(find.text('Mes appareils'));
  await attendre(tester);
}

Future<void> saisirCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.pump();
  await tester.tap(find.text('VALIDER'));
  await attendre(tester);
}

Future<void> connexion(WidgetTester tester, String numero) async {
  await tester.enterText(find.byType(TextField), numero);
  await tester.tap(find.textContaining("J'accepte"));
  await tester.pump();
  await tester.tap(find.text('RECEVOIR LE CODE PAR SMS'));
  await attendre(tester);
  await saisirCode(tester, '123456');
}

/// CompteApi dont la liste des appareils échoue [echecs] fois.
class CompteEnPanne extends FauxCompteApi {
  int echecs;
  CompteEnPanne(this.echecs) : super(web: true);

  @override
  Future<ListeAppareils> listerAppareils() async {
    if (echecs > 0) {
      echecs--;
      throw Exception('réseau');
    }
    return super.listerAppareils();
  }
}

/// Déverrouillage (appareil) par les touches du pin-pad.
Future<void> taperPin(WidgetTester tester, String pin) async {
  for (final c in pin.split('')) {
    await tester.tap(find.text(c));
    await tester.pump();
  }
  await attendre(tester);
}
