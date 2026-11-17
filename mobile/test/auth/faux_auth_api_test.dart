import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';

void main() {
  const numero = '+237677123456';
  late DateTime maintenant;
  late FauxAuthApi api;

  setUp(() {
    maintenant = DateTime(2026, 11, 17, 10);
    api = FauxAuthApi(horloge: () => maintenant);
  });

  test('code 123456 ouvre une session avec le numéro masqué', () async {
    expect(await api.demanderCode(numero, CGU_VERSION_PROVISOIRE), isA<CodeEnvoye>());
    expect(api.derniereCguVersion, CGU_VERSION_PROVISOIRE);
    final r = await api.verifierCode(numero, '123456');
    expect(r, isA<SessionOuverte>());
    final s = r as SessionOuverte;
    expect(s.numeroMasque, '+237 6 •• •• •• 56');
    expect(s.accessToken, isNotEmpty);
    expect(s.refreshToken, isNot(s.accessToken));
  });

  test('même réponse quel que soit le numéro', () async {
    expect(await api.demanderCode('+237699999999', CGU_VERSION_PROVISOIRE), isA<CodeEnvoye>());
    expect(await api.demanderCode(numero, CGU_VERSION_PROVISOIRE), isA<CodeEnvoye>());
  });

  test('mauvais code : essais restants décroissants, puis trop d\'essais au 5e', () async {
    await api.demanderCode(numero, CGU_VERSION_PROVISOIRE);
    for (var restants = 4; restants >= 1; restants--) {
      final r = await api.verifierCode(numero, '000000');
      expect((r as CodeIncorrect).essaisRestants, restants);
    }
    expect(await api.verifierCode(numero, '000000'), isA<TropDEssais>());
    // Le code est invalidé, même le bon ne passe plus.
    expect(await api.verifierCode(numero, '123456'), isA<CodeExpire>());
  });

  test('code expiré après 5 minutes', () async {
    await api.demanderCode(numero, CGU_VERSION_PROVISOIRE);
    maintenant = maintenant.add(const Duration(minutes: 5));
    expect(await api.verifierCode(numero, '123456'), isA<CodeExpire>());
  });

  test('sans demande préalable : code expiré', () async {
    expect(await api.verifierCode(numero, '123456'), isA<CodeExpire>());
  });

  test('trop de demandes au-delà du quota, rétabli après la fenêtre', () async {
    for (var i = 0; i < FauxAuthApi.demandesMax; i++) {
      expect(await api.demanderCode(numero, CGU_VERSION_PROVISOIRE), isA<CodeEnvoye>());
    }
    expect(await api.demanderCode(numero, CGU_VERSION_PROVISOIRE), isA<TropDeDemandes>());
    maintenant = maintenant.add(FauxAuthApi.fenetreDemandes);
    expect(await api.demanderCode(numero, CGU_VERSION_PROVISOIRE), isA<CodeEnvoye>());
  });

  test('masquerNumero', () {
    expect(masquerNumero('+237677123456'), '+237 6 •• •• •• 56');
  });
}
