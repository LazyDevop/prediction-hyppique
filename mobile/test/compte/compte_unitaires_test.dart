import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/widgets/device_row.dart';

import '../auth/auth_test_helpers.dart';

Appareil _appareil(DateTime activite) => Appareil(
  id: 'x',
  type: TypeAppareil.navigateur,
  nom: 'Chrome sur Windows',
  derniereActivite: activite,
  rattacheLe: activite,
);

void main() {
  group('drapeaux de démo', () {
    test('ne dépendent pas de l\'échec des providers d\'API', () {
      final c = ProviderContainer(
        overrides: [
          authApiProvider.overrideWith((ref) => throw StateError('pas de client')),
          compteApiProvider.overrideWith((ref) => throw StateError('pas de client')),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(modeDemoProvider), isTrue);
      expect(c.read(modeDemoCompteProvider), isTrue);
      expect(c.read(compteDisponibleProvider), isTrue);
    });

    test('release sans AUTH_DEMO : drapeaux faux, pas de CompteApi', () {
      final c = ProviderContainer(overrides: [demoAutoriseeProvider.overrideWithValue(false)]);
      addTearDown(c.dispose);
      expect(c.read(modeDemoProvider), isFalse);
      expect(c.read(modeDemoCompteProvider), isFalse);
      expect(c.read(compteDisponibleProvider), isFalse);
      expect(() => c.read(compteApiProvider), throwsA(anything));
      expect(() => c.read(authApiProvider), throwsA(anything));
    });
  });

  test('vrais providers : 699999999 bloqué, faux serveurs liés et conservés', () async {
    final c = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(MemorySessionStore()), estWebProvider.overrideWithValue(true)],
    );
    addTearDown(c.dispose);
    await c.read(authProvider.future);
    final compte = c.read(compteApiProvider);
    final auth = c.read(authApiProvider);
    final n = c.read(authProvider.notifier);
    await n.demanderCode(FauxCompteApi.numeroBloque);
    expect(await n.verifierCode(FauxCompteApi.numeroBloque, '123456'), isA<AppareilBloque>());
    expect(c.read(authProvider).value!.porte, Porte.appareilBloque);

    // Reconstruire authApiProvider ne recrée pas les faux (état conservé).
    c.invalidate(authApiProvider);
    c.invalidate(compteApiProvider);
    expect(identical(c.read(authApiProvider), auth), isTrue);
    expect(identical(c.read(compteApiProvider), compte), isTrue);
  });

  group('FauxCompteApi : session', () {
    test('démarrage avec session : compte retrouvé par le numéro masqué', () async {
      final fake = FauxCompteApi();
      expect(fake.rattacher('+237677123456', cguVersion: 'v-x'), isNull);
      fake.deconnecter();
      expect((await fake.lireProfil()).cguVersion, CGU_VERSION_PROVISOIRE);

      final c = conteneur(
        store: await storeExpert(pin: '4821'),
        compte: fake,
      );
      addTearDown(c.dispose);
      await c.read(authProvider.future);
      expect((await fake.lireProfil()).cguVersion, 'v-x');
    });

    test('seDeconnecter réinitialise le faux (code email en cours abandonné)', () async {
      final fake = FauxCompteApi();
      final c = conteneur(
        store: await storeAvecSession(pin: '4821'),
        compte: fake,
      );
      addTearDown(c.dispose);
      await c.read(authProvider.future);
      await fake.definirEmail('a@b.cm');
      await c.read(authProvider.notifier).seDeconnecter();
      expect(await fake.verifierEmail('123456'), isA<CodeEmailExpire>());
    });
  });

  group('email', () {
    test('format : libellés vides refusés', () {
      expect(formatEmail.hasMatch('a@b.cm'), isTrue);
      expect(formatEmail.hasMatch('a@mail.exemple.cm'), isTrue);
      expect(formatEmail.hasMatch('a@.b.cm'), isFalse);
      expect(formatEmail.hasMatch('a@b..cm'), isFalse);
      expect(formatEmail.hasMatch('a@b.c'), isFalse);
      expect(formatEmail.hasMatch('@b.cm'), isFalse);
    });

    test('normalisation : espaces et majuscules', () async {
      expect(normaliserEmail('  Marc@Exemple.CM '), 'marc@exemple.cm');
      final fake = FauxCompteApi();
      await fake.definirEmail(' Marc@Exemple.CM ');
      await fake.verifierEmail('123456');
      expect((await fake.lireProfil()).email, 'marc@exemple.cm');
    });
  });

  group('dates', () {
    test('année affichée quand elle diffère', () {
      final maintenant = DateTime(2026, 1, 5, 10);
      expect(
        formaterActivite(_appareil(DateTime(2025, 12, 30, 21, 41)), maintenant),
        'dernière activité le 30/12/2025 à 21 h 41',
      );
      expect(formaterJourHeure(DateTime(2025, 12, 30, 21, 41), maintenant), 'mardi 30/12/2025 à 21 h 41');
      expect(formaterJourHeure(DateTime(2026, 11, 14, 21, 41), DateTime(2026, 11, 17)), 'samedi 14/11 à 21 h 41');
      expect(
        formaterActivite(_appareil(DateTime(2026, 11, 10, 8, 5)), DateTime(2026, 11, 17)),
        'dernière activité le 10/11 à 8 h 05',
      );
    });

    test('minuit UTC : formaté en heure locale', () {
      final utc = DateTime.utc(2026, 11, 17);
      final local = utc.toLocal();
      String deux(int n) => n.toString().padLeft(2, '0');
      expect(formaterDate(utc), '${deux(local.day)}/${deux(local.month)}/${local.year}');
      expect(formaterHeure(utc), '${local.hour} h ${deux(local.minute)}');
      final maintenantUtc = DateTime.utc(2026, 11, 17, 12);
      expect(
        formaterActivite(_appareil(DateTime.utc(2026, 11, 16)), maintenantUtc),
        formaterActivite(_appareil(DateTime.utc(2026, 11, 16).toLocal()), maintenantUtc.toLocal()),
      );
      expect(formaterActivite(_appareil(DateTime.utc(2026, 11, 16)), maintenantUtc), contains(formaterHeure(utc)));
    });
  });
}
