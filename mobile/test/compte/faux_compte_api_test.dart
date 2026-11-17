import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';

import '../auth/auth_test_helpers.dart';

void main() {
  group('FauxCompteApi', () {
    late Horloge horloge;
    late FauxCompteApi api;

    setUp(() {
      horloge = Horloge();
      api = FauxCompteApi(horloge: horloge.call);
    });

    test('profil par défaut : Gratuit, sans fin de droit, sans email, CGU provisoires', () async {
      final p = await api.lireProfil();
      expect(p.palier, palierGratuit);
      expect(p.palierPayant, isFalse);
      expect(p.finDroit, isNull);
      expect(p.email, isNull);
      expect(p.cguVersion, CGU_VERSION_PROVISOIRE);
      expect(p.limiteAppareils, 2);
      expect(p.nbAppareils, 2);
    });

    test('email : code 123456 → vérifié', () async {
      expect(await api.definirEmail('marc@exemple.cm'), isA<CodeEmailEnvoye>());
      expect(await api.verifierEmail('123456'), isA<EmailVerifie>());
      final p = await api.lireProfil();
      expect(p.email, 'marc@exemple.cm');
      expect(p.emailVerifie, isTrue);
    });

    test('email invalide refusé', () async {
      expect(await api.definirEmail('marc@'), isA<EmailInvalide>());
    });

    test('mauvais code : essais décomptés, 5e → trop d\'essais, email inchangé', () async {
      await api.definirEmail('marc@exemple.cm');
      for (var restants = 4; restants >= 1; restants--) {
        final r = await api.verifierEmail('000000');
        expect((r as CodeEmailIncorrect).essaisRestants, restants);
      }
      expect(await api.verifierEmail('000000'), isA<TropDEssaisEmail>());
      expect(await api.verifierEmail('123456'), isA<CodeEmailExpire>());
      expect((await api.lireProfil()).email, isNull);
    });

    test('code email expiré après 5 minutes', () async {
      await api.definirEmail('marc@exemple.cm');
      horloge.avancer(const Duration(minutes: 5));
      expect(await api.verifierEmail('123456'), isA<CodeEmailExpire>());
    });

    test('appareils : cet appareil en premier, retrait d\'un autre, pas de l\'appareil courant', () async {
      final liste = await api.listerAppareils();
      expect(liste.appareils.first.estCourant, isTrue);
      expect(liste.appareils.last.nom, 'Chrome sur Windows');
      expect(liste.appareils.last.nouveau, isTrue);
      await api.retirerAppareil('chrome-windows');
      expect((await api.listerAppareils()).appareils, hasLength(1));
      expect(() => api.retirerAppareil(FauxCompteApi.idCourant), throwsStateError);
    });

    test('numéro 699999999 : bloqué avec jeton de 10 min ; un seul retrait ; puis rattachement possible', () async {
      final bloque = api.rattacher(FauxCompteApi.numeroBloque, cguVersion: CGU_VERSION_PROVISOIRE);
      expect(bloque, isNotNull);
      expect(bloque!.limite, 2);
      expect(bloque.jeton.expireLe, horloge.maintenant.add(const Duration(minutes: 10)));
      final liste = await api.listerAppareilsRestreint(bloque.jeton);
      expect(liste.appareils.map((a) => a.nom), ['Samsung Galaxy A14', 'Chrome sur Windows']);

      final r = await api.retirerAppareilRestreint(bloque.jeton, 'chrome-windows');
      expect((r as AppareilRetire).nom, 'Chrome sur Windows');
      expect(await api.retirerAppareilRestreint(bloque.jeton, 'samsung-a14'), isA<AccesRestreintExpire>());
      expect(() => api.listerAppareilsRestreint(bloque.jeton), throwsA(isA<AccesRestreintRefuse>()));

      expect(api.rattacher(FauxCompteApi.numeroBloque, cguVersion: CGU_VERSION_PROVISOIRE), isNull);
      final apres = await api.listerAppareils();
      expect(apres.appareils, hasLength(2));
      expect(apres.appareils.first.estCourant, isTrue);
    });

    test('accès limité expiré après 10 minutes', () async {
      final bloque = api.rattacher(FauxCompteApi.numeroBloque, cguVersion: CGU_VERSION_PROVISOIRE)!;
      horloge.avancer(const Duration(minutes: 10));
      expect(await api.retirerAppareilRestreint(bloque.jeton, 'chrome-windows'), isA<AccesRestreintExpire>());
    });

    test('autre numéro : rattaché, CGU et date de connexion enregistrées', () async {
      horloge.avancer(const Duration(days: 1));
      expect(api.rattacher('+237677123456', cguVersion: 'v-test'), isNull);
      final p = await api.lireProfil();
      expect(p.cguVersion, 'v-test');
      expect(p.cguAccepteeLe, horloge.maintenant);
    });
  });

  group('FauxAuthApi + FauxCompteApi', () {
    test('code correct sur le numéro bloqué → AppareilBloque, sans session', () async {
      final compte = FauxCompteApi();
      final auth = FauxAuthApi(rattachement: compte);
      await auth.demanderCode(FauxCompteApi.numeroBloque, CGU_VERSION_PROVISOIRE);
      expect(await auth.verifierCode(FauxCompteApi.numeroBloque, '123456'), isA<AppareilBloque>());
      await auth.demanderCode('+237677123456', CGU_VERSION_PROVISOIRE);
      expect(await auth.verifierCode('+237677123456', '123456'), isA<SessionOuverte>());
    });
  });

  group('AuthNotifier', () {
    test('connexion bloquée : porte appareilBloque, rien enregistré ; quitter → Connexion avec message', () async {
      final store = MemorySessionStore();
      final c = conteneur(store: store);
      addTearDown(c.dispose);
      await c.read(authProvider.future);
      final n = c.read(authProvider.notifier);
      await n.demanderCode(FauxCompteApi.numeroBloque);
      expect(await n.verifierCode(FauxCompteApi.numeroBloque, '123456'), isA<AppareilBloque>());
      final etat = c.read(authProvider).value!;
      expect(etat.porte, Porte.appareilBloque);
      expect(etat.blocage, isNotNull);
      expect(store.session, isNull);

      n.quitterAppareilBloque(message: 'm');
      expect(c.read(authProvider).value!.porte, Porte.aucuneSession);
      expect(c.read(authProvider).value!.message, 'm');
    });

    test('seDeconnecter efface jetons et PIN → aucuneSession', () async {
      final store = await storeAvecSession(pin: '4821');
      final c = conteneur(store: store);
      addTearDown(c.dispose);
      await c.read(authProvider.future);
      await c.read(authProvider.notifier).seDeconnecter();
      expect(store.session, isNull);
      expect(c.read(authProvider).value!.porte, Porte.aucuneSession);
    });
  });
}
