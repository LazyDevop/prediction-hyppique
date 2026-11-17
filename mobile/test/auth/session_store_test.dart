import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';

import 'auth_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SecureSessionStore> storeAvec(Map<String, String> valeurs) async {
    FlutterSecureStorage.setMockInitialValues(valeurs);
    return SecureSessionStore();
  }

  Future<void> ouvrir(SessionStore store) =>
      store.enregistrerSession(accessToken: 'acces', refreshToken: 'renouv', numeroMasque: '+237 6 •• •• •• 56');

  test('aller-retour : session, PIN et échecs persistent', () async {
    final store = await storeAvec({});
    expect(await store.lire(), isNull);
    await ouvrir(store);
    final pin = await pinHasherRapide().hacher('48210');
    await store.enregistrerPin(pin, 5);
    await store.enregistrerEchecsPin(3);

    // Nouvelle instance sur le même stockage (redémarrage).
    final relu = await SecureSessionStore().lire();
    expect(relu!.accessToken, 'acces');
    expect(relu.refreshToken, 'renouv');
    expect(relu.numeroMasque, '+237 6 •• •• •• 56');
    expect(relu.pinLongueur, 5);
    expect(relu.pin!.empreinte, pin.empreinte);
    expect(relu.pin!.sel, pin.sel);
    expect(relu.echecsPin, 3);
    expect(await pinHasherRapide().verifier('48210', relu.pin!), isTrue);
  });

  test('session et PIN sont chacun une seule valeur, sans le PIN en clair', () async {
    final store = await storeAvec({});
    await ouvrir(store);
    await store.enregistrerPin(await pinHasherRapide().hacher('4821'), 4);
    final tout = await const FlutterSecureStorage().readAll();
    expect(tout.keys.toSet(), {'auth.session', 'auth.pin', 'auth.echecs_pin'});
    expect(tout.values.any((v) => v.contains('4821')), isFalse);
  });

  test('enregistrerSession efface un ancien PIN', () async {
    final store = await storeAvec({});
    await ouvrir(store);
    await store.enregistrerPin(await pinHasherRapide().hacher('4821'), 4);
    await store.enregistrerEchecsPin(2);
    await ouvrir(store);
    final relu = await store.lire();
    expect(relu!.pinDefini, isFalse);
    expect(relu.echecsPin, 0);
  });

  test('effacer supprime tout', () async {
    final store = await storeAvec({});
    await ouvrir(store);
    await store.enregistrerPin(await pinHasherRapide().hacher('4821'), 4);
    await store.effacer();
    expect(await store.lire(), isNull);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
  });

  const sessionOk = '{"accessToken":"a","refreshToken":"r","numeroMasque":"+237 6 •• •• •• 56"}';
  final corrompus = <String, Map<String, String>>{
    'JSON de session invalide': {'auth.session': '{pas du json'},
    'champ de session manquant': {'auth.session': '{"accessToken":"a"}'},
    'base64 invalide': {
      'auth.session': sessionOk,
      'auth.pin': '{"empreinte":"%%%","sel":"AAAA","longueur":4}',
    },
    'longueur de PIN hors 4..6': {
      'auth.session': sessionOk,
      'auth.pin': '{"empreinte":"AAAA","sel":"AAAA","longueur":9}',
    },
    'compteur illisible': {'auth.session': sessionOk, 'auth.echecs_pin': 'x'},
  };
  corrompus.forEach((nom, valeurs) {
    test('valeur corrompue ($nom) : null et stockage effacé', () async {
      final store = await storeAvec(valeurs);
      expect(await store.lire(), isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    });
  });
}
