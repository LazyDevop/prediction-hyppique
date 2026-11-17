import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';

import 'auth_test_helpers.dart';

void main() {
  const numero = '+237677123456';

  test('aucune session : Connexion', () async {
    final c = conteneur(store: MemorySessionStore());
    addTearDown(c.dispose);
    expect((await c.read(authProvider.future)).porte, Porte.aucuneSession);
  });

  test('code correct sur appareil : choix du PIN, puis ouverte ; PIN stocké haché seulement', () async {
    final store = MemorySessionStore();
    final c = conteneur(store: store);
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    final n = c.read(authProvider.notifier);
    await n.demanderCode(numero);
    expect(await n.verifierCode(numero, '123456'), isA<SessionOuverte>());
    expect(c.read(authProvider).value!.porte, Porte.choixPin);
    await n.definirPin('4821');
    final etat = c.read(authProvider).value!;
    expect(etat.porte, Porte.ouverte);
    expect(etat.pinLongueur, 4);
    expect(store.session!.pin, isNotNull);
    expect(store.session!.pin!.empreinte, isNot(equals('4821'.codeUnits)));
  });

  test('la version provisoire des CGU est transmise', () async {
    final api = FauxAuthApi();
    final c = conteneur(store: MemorySessionStore(), api: api);
    addTearDown(c.dispose);
    await c.read(authProvider.notifier).demanderCode(numero);
    expect(api.derniereCguVersion, '2026-11-provisoire');
  });

  test('code correct sur le web : Accueil directement, sans PIN', () async {
    final c = conteneur(store: MemorySessionStore(), web: true);
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    final n = c.read(authProvider.notifier);
    await n.demanderCode(numero);
    await n.verifierCode(numero, '123456');
    expect(c.read(authProvider).value!.porte, Porte.ouverte);
  });

  test('démarrage à froid avec session et PIN : verrouillée (web : ouverte)', () async {
    final appareil = conteneur(store: await storeAvecSession(pin: '4821'));
    addTearDown(appareil.dispose);
    expect((await appareil.read(authProvider.future)).porte, Porte.verrouillee);

    final web = conteneur(store: await storeAvecSession(pin: '4821'), web: true);
    addTearDown(web.dispose);
    expect((await web.read(authProvider.future)).porte, Porte.ouverte);
  });

  test('session sans PIN au démarrage (appareil) : effacée, Connexion', () async {
    final store = await storeAvecSession();
    final c = conteneur(store: store);
    addTearDown(c.dispose);
    expect((await c.read(authProvider.future)).porte, Porte.aucuneSession);
    expect(store.session, isNull);
  });

  test('échecs enregistrés ≥ 5 au démarrage : effacée, Connexion avec message', () async {
    final store = await storeAvecSession(pin: '4821', echecs: essaisPinMax);
    final c = conteneur(store: store);
    addTearDown(c.dispose);
    final etat = await c.read(authProvider.future);
    expect(etat.porte, Porte.aucuneSession);
    expect(etat.message, messageSessionEffacee);
    expect(store.session, isNull);
  });

  test("l'échec est enregistré AVANT la vérification du PIN", () async {
    final store = await storeAvecSession(pin: '4821', echecs: 1);
    final c = conteneur(store: store, hasher: HasherEnPanne());
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    await expectLater(c.read(authProvider.notifier).deverrouiller('4821'), throwsException);
    expect(store.session!.echecsPin, 2);
  });

  test('lecture du stockage en échec : erreur (la porte affiche Connexion)', () async {
    final c = conteneur(store: StoreEnPanne());
    addTearDown(c.dispose);
    c.listen(authProvider, (_, _) {});
    await pumpEventQueue();
    expect(c.read(authProvider).hasError, isTrue);
  });

  test('session illisible juste après écriture : verifierCode lève une erreur', () async {
    final c = conteneur(store: _StoreSansRelecture());
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    final n = c.read(authProvider.notifier);
    await n.demanderCode(numero);
    await expectLater(n.verifierCode(numero, '123456'), throwsStateError);
  });

  test('en debug, authApiProvider fournit le faux serveur de démonstration', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(authApiProvider), isA<FauxAuthApi>());
    expect(c.read(modeDemoProvider), isTrue);
  });

  test('déverrouillage : bon PIN ouvre et remet les échecs à zéro', () async {
    final store = await storeAvecSession(pin: '4821', echecs: 2);
    final c = conteneur(store: store);
    addTearDown(c.dispose);
    expect((await c.read(authProvider.future)).essaisPinRestants, 3);
    expect(await c.read(authProvider.notifier).deverrouiller('4821'), isTrue);
    expect(c.read(authProvider).value!.porte, Porte.ouverte);
    expect(store.session!.echecsPin, 0);
  });

  test('5 mauvais PIN : session effacée, Connexion avec message', () async {
    final store = await storeAvecSession(pin: '4821');
    final c = conteneur(store: store);
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    final n = c.read(authProvider.notifier);
    for (var restants = 4; restants >= 1; restants--) {
      expect(await n.deverrouiller('0000'), isFalse);
      final etat = c.read(authProvider).value!;
      expect(etat.porte, Porte.verrouillee);
      expect(etat.essaisPinRestants, restants);
      expect(store.session!.echecsPin, 5 - restants);
    }
    expect(await n.deverrouiller('0000'), isFalse);
    final etat = c.read(authProvider).value!;
    expect(etat.porte, Porte.aucuneSession);
    expect(etat.message, messageSessionEffacee);
    expect(store.session, isNull);
  });

  test('les échecs survivent à un redémarrage', () async {
    final store = await storeAvecSession(pin: '4821', echecs: 4);
    final c = conteneur(store: store);
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    await c.read(authProvider.notifier).deverrouiller('0000');
    expect(c.read(authProvider).value!.porte, Porte.aucuneSession);
  });

  test('« Code oublié ? » efface la session', () async {
    final store = await storeAvecSession(pin: '4821');
    final c = conteneur(store: store);
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    await c.read(authProvider.notifier).seReconnecter();
    expect(c.read(authProvider).value!.porte, Porte.aucuneSession);
    expect(store.session, isNull);
  });

  group('retour au premier plan', () {
    Future<(AuthNotifier, Horloge, dynamic)> ouverte({bool web = false}) async {
      final horloge = Horloge();
      final c = conteneur(store: await storeAvecSession(pin: '4821'), horloge: horloge, web: web);
      addTearDown(c.dispose);
      await c.read(authProvider.future);
      final n = c.read(authProvider.notifier);
      if (!web) await n.deverrouiller('4821');
      return (n, horloge, c);
    }

    test('après ≥ 5 min : verrouillée', () async {
      final (n, horloge, c) = await ouverte();
      n.passerEnArrierePlan();
      horloge.avancer(DELAI_VERROUILLAGE);
      n.revenirAuPremierPlan();
      expect(c.read(authProvider).value!.porte, Porte.verrouillee);
    });

    test('avant 5 min : reste ouverte', () async {
      final (n, horloge, c) = await ouverte();
      n.passerEnArrierePlan();
      horloge.avancer(DELAI_VERROUILLAGE - const Duration(seconds: 1));
      n.revenirAuPremierPlan();
      expect(c.read(authProvider).value!.porte, Porte.ouverte);
    });

    test('web : jamais verrouillée', () async {
      final (n, horloge, c) = await ouverte(web: true);
      n.passerEnArrierePlan();
      horloge.avancer(const Duration(hours: 1));
      n.revenirAuPremierPlan();
      expect(c.read(authProvider).value!.porte, Porte.ouverte);
    });
  });
}

/// Écrit mais ne relit jamais rien (stockage corrompu entre écriture et lecture).
class _StoreSansRelecture extends MemorySessionStore {
  @override
  Future<SessionLocale?> lire() async => null;
}
