// Story 8.7 (web) — FauxAppairageApi : création, statuts, expiration à
// 2 min, approbation de démonstration à usage unique.

import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/remote/appairage_api.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/screens/appairage_screen.dart' show formaterRestant;

import '../auth/auth_test_helpers.dart';

void main() {
  late Horloge horloge;
  late FauxCompteApi compte;
  late FauxAppairageApi api;

  setUp(() {
    horloge = Horloge();
    compte = FauxCompteApi(horloge: horloge.call, web: true);
    api = FauxAppairageApi(horloge: horloge.call, rattachement: compte);
  });

  test('création : identifiant, contenu de QR, expiration à 2 min ; en attente', () async {
    final a = await api.creer();
    expect(a.id, isNotEmpty);
    expect(a.contenuQr, contains(a.id));
    expect(a.validite, const Duration(minutes: 2));
    expect(a.nomAppareil, FauxAppairageApi.nomNavigateurDemo);
    expect(api.dernierId, a.id);
    expect(await api.statut(a.id), isA<AppairageEnAttente>());
  });

  test('deux QR : contenus différents', () async {
    final a = await api.creer();
    final b = await api.creer();
    expect(a.id, isNot(b.id));
    expect(a.contenuQr, isNot(b.contenuQr));
  });

  test('2 min écoulées : expiré, et l\'approbation n\'a plus d\'effet', () async {
    final a = await api.creer();
    horloge.avancer(const Duration(minutes: 1, seconds: 59));
    expect(await api.statut(a.id), isA<AppairageEnAttente>());
    horloge.avancer(const Duration(seconds: 1));
    api.approuverDemo(a.id);
    expect(await api.statut(a.id), isA<AppairageExpire>());
  });

  test('approbation de démo : session au numéro masqué, rattache ce navigateur, usage unique', () async {
    final a = await api.creer();
    api.approuverDemo(a.id);
    final s = await api.statut(a.id);
    expect(s, isA<AppairageApprouve>());
    final session = (s as AppairageApprouve).session;
    expect(session.numeroMasque, masquerNumero(FauxAppairageApi.numeroDemo));
    expect(session.accessToken, isNotEmpty);
    expect(compte.cleCompteCourant, masquerNumero(FauxAppairageApi.numeroDemo));
    expect(await api.statut(a.id), isA<AppairageExpire>(), reason: 'le QR ne sert qu\'une fois');
  });

  test('refus : statut refusé ; inconnu : expiré', () async {
    final a = await api.creer();
    api.refuserDemo(a.id);
    expect(await api.statut(a.id), isA<AppairageRefuse>());
    api.approuverDemo(a.id);
    expect(await api.statut(a.id), isA<AppairageRefuse>());
    expect(await api.statut('inconnu'), isA<AppairageExpire>());
  });

  test("limite d'appareils : bloqué avec le jeton de gestion, aucune session", () async {
    final bloquee = FauxAppairageApi(
      horloge: horloge.call,
      rattachement: compte,
      numero: FauxCompteApi.numeroBloque,
    );
    final a = await bloquee.creer();
    bloquee.approuverDemo(a.id);
    final s = await bloquee.statut(a.id);
    expect(s, isA<AppairageBloque>());
    expect((s as AppairageBloque).blocage.jeton.valeur, isNotEmpty);
    expect(compte.cleCompteCourant, isNull);
  });

  test('temps restant écrit', () {
    expect(formaterRestant(const Duration(minutes: 2)), '2 min');
    expect(formaterRestant(const Duration(seconds: 105)), '1 min 45 s');
    expect(formaterRestant(const Duration(seconds: 65)), '1 min 05 s');
    expect(formaterRestant(const Duration(milliseconds: 44200)), '45 s');
    expect(formaterRestant(const Duration(seconds: -3)), '0 s');
  });
}
