import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/data/remote/offres_api.dart';

import '../auth/auth_test_helpers.dart';
import '../compte/compte_test_helpers.dart';

Future<void> ouvrirOffres(WidgetTester tester) async {
  await ouvrirProfil(tester);
  await toucher(tester, find.text('Offres'));
}

Future<void> toucher(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await attendre(tester);
}

/// Offres → [offre] → « Continuer vers le paiement ».
Future<void> ouvrirPaiement(WidgetTester tester, {String offre = 'Pass semaine Turfiste'}) async {
  await ouvrirOffres(tester);
  await toucher(tester, find.text(offre));
  await toucher(tester, find.text('CONTINUER VERS LE PAIEMENT'));
}

/// Choisit [moyen], saisit [numero] et touche « Payer ».
Future<void> payer(WidgetTester tester, {String moyen = 'MTN MoMo', String numero = '677123456'}) async {
  await toucher(tester, find.text(moyen));
  await tester.enterText(find.byType(TextField), numero);
  await tester.pump();
  await toucher(tester, find.text('PAYER'));
}

/// Délai du faux serveur écoulé + un tour de sondage.
Future<void> laisserConfirmer(WidgetTester tester, Horloge horloge) async {
  horloge.avancer(const Duration(seconds: 5));
  await tester.pump(const Duration(seconds: 2));
  await attendre(tester);
}

VoidCallback? pressionCta(WidgetTester tester, String texte) {
  final bouton = find.ancestor(of: find.text(texte), matching: find.byType(FilledButton));
  return tester.widget<FilledButton>(bouton).onPressed;
}

/// Tous les textes construits, y compris hors écran (Text, Text.rich, RichText).
List<String> textesConstruits(WidgetTester tester) => [
  for (final w in tester.widgetList<RichText>(find.byType(RichText, skipOffstage: false))) w.text.toPlainText(),
];

/// Mots d'urgence ou de promesse de gain interdits (U-3).
const motsInterdits = [
  'gagnez',
  'gagner',
  'populaire',
  'urgent',
  'dernière chance',
  'derniers jours',
  'limité',
  'vite',
  'promo',
  'meilleur',
  'recommandé',
  'expire dans',
  'plus que',
  "aujourd'hui seulement",
  'ne ratez',
  'profitez',
  'exclusif',
  'offre spéciale',
  'réduction',
  'bonus',
  'dépêchez',
  '%',
];

/// FauxOffresApi instrumentée : compte les initiations et les clés, peut
/// perdre la réponse d'initiation (paiement créé, exception), échouer la
/// lecture du statut, oublier les paiements, vider ou casser le catalogue.
class OffresInstrumentees extends FauxOffresApi {
  int initiations = 0;
  final cles = <String>[];

  /// Initiations dont la réponse est perdue (après création côté serveur).
  int reponsesPerdues = 0;

  /// Lectures de statut en échec ; négatif : toujours.
  int echecsStatut = 0;
  int lecturesStatut = 0;
  bool statutInconnu = false;
  int echecsListe = 0;
  bool catalogueVide = false;

  OffresInstrumentees({super.compte, super.horloge});

  @override
  Future<List<Offre>> listerOffres() async {
    if (echecsListe > 0) {
      echecsListe--;
      throw Exception('réseau');
    }
    return catalogueVide ? const [] : super.listerOffres();
  }

  @override
  Future<InitiationPaiementResultat> initierPaiement({
    required String offreId,
    required MoyenPaiement moyen,
    required String numero,
    required String cleIdempotence,
  }) async {
    initiations++;
    cles.add(cleIdempotence);
    final r = await super.initierPaiement(
      offreId: offreId,
      moyen: moyen,
      numero: numero,
      cleIdempotence: cleIdempotence,
    );
    if (reponsesPerdues > 0) {
      reponsesPerdues--;
      throw Exception('réponse perdue');
    }
    return r;
  }

  @override
  Future<StatutPaiement> statutPaiement(String id) async {
    lecturesStatut++;
    if (echecsStatut != 0) {
      if (echecsStatut > 0) echecsStatut--;
      throw Exception('réseau');
    }
    if (statutInconnu) return const PaiementIntrouvable();
    return super.statutPaiement(id);
  }
}

/// OffresApi « réelle » (pas un FauxOffresApi) : délègue à un faux.
class OffresDeleguees implements OffresApi {
  final OffresApi _faux;
  OffresDeleguees(this._faux);

  @override
  Future<List<Offre>> listerOffres() => _faux.listerOffres();

  @override
  Future<DroitActuel> droitActuel() => _faux.droitActuel();

  @override
  Future<String?> numeroPropose() => _faux.numeroPropose();

  @override
  Future<InitiationPaiementResultat> initierPaiement({
    required String offreId,
    required MoyenPaiement moyen,
    required String numero,
    required String cleIdempotence,
  }) => _faux.initierPaiement(offreId: offreId, moyen: moyen, numero: numero, cleIdempotence: cleIdempotence);

  @override
  Future<StatutPaiement> statutPaiement(String id) => _faux.statutPaiement(id);
}

/// Faux compte + faux paiement instrumenté, liés et pilotés par [horloge].
(FauxCompteApi, OffresInstrumentees) fauxLies(Horloge horloge, {bool web = true}) {
  final compte = FauxCompteApi(horloge: horloge.call, web: web);
  return (compte, OffresInstrumentees(compte: compte, horloge: horloge.call));
}
