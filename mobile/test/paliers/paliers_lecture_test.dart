// Revue de la story 9.8 : lectures du palier (L2, L4, L5, L6, L14), envoi des
// pronostics (L1), comptes de démonstration (L13).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prediction_hippique/data/remote/api_client.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/data/remote/offres_api.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/palier_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/pronostic_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';

import '../auth/auth_test_helpers.dart';
import 'paliers_test_helpers.dart';

/// Chaque lecture attend la réponse donnée par le test.
class _Scripte extends FauxCompteApi {
  final lectures = <Completer<ProfilCompte>>[];
  _Scripte() : super(web: true);

  @override
  Future<ProfilCompte> lireProfil() {
    final c = Completer<ProfilCompte>();
    lectures.add(c);
    return c.future;
  }
}

ProfilCompte _profil(String palier, [DateTime? fin]) => ProfilCompte(
  email: null,
  emailVerifie: false,
  palier: palier,
  finDroit: fin,
  cguVersion: 'v',
  cguAccepteeLe: DateTime(2026),
  nbAppareils: 1,
  limiteAppareils: 2,
);

class _Pronostics implements PronosticsApi {
  int envois = 0;
  @override
  Future<void> envoyerPronostic(Map<String, Object?> pronostic) async => envois++;
}

void main() {
  group('lectures', () {
    late DateTime murale;
    late Duration monotone;
    var monotoneLue = 0;
    late _Scripte api;
    late ProviderContainer c;
    EtatPalier etat() => c.read(palierProvider);

    Future<void> ouvrir(WidgetTester tester) async {
      murale = DateTime.utc(2026, 11, 17, 10);
      monotone = Duration.zero;
      api = _Scripte();
      c = ProviderContainer(
        overrides: [
          ...overridesAuth(store: await storeAvecSession(), compte: api, web: true),
          horlogeMuraleProvider.overrideWithValue(() => murale),
          horlogeMonotoneProvider.overrideWithValue(() {
            monotoneLue++;
            return monotone;
          }),
        ],
      );
      c.listen(palierProvider, (_, _) {});
      await tester.pump();
      await tester.pump();
      expect(api.lectures, hasLength(1));
    }

    Future<void> repondre(WidgetTester tester, int i, ProfilCompte? p) async {
      p == null ? api.lectures[i].completeError(Exception('réseau')) : api.lectures[i].complete(p);
      await tester.pump();
    }

    /// Fin du test : les délais des lectures sans réponse s'éteignent.
    Future<void> fermer(WidgetTester tester) async {
      c.dispose();
      await tester.pump(delaiLecturePalier);
    }

    Future<void> passer(WidgetTester tester, Duration d) async {
      murale = murale.add(d);
      monotone += d;
      await tester.pump(d);
    }

    testWidgets('L4 : réussite ancienne arrivée après une récente → ignorée', (tester) async {
      await ouvrir(tester);
      unawaited(c.read(palierProvider.notifier).actualiser());
      await repondre(tester, 1, _profil(palierExpert));
      await repondre(tester, 0, _profil(palierGratuit));
      expect(etat().palier, palierExpert);
      await fermer(tester);
    });

    testWidgets("L4 : échec ancien après une réussite récente → sans effet, pas d'erreur", (tester) async {
      await ouvrir(tester);
      unawaited(c.read(palierProvider.notifier).actualiser());
      await repondre(tester, 1, _profil(palierExpert));
      await repondre(tester, 0, null);
      expect(etat().palier, palierExpert);
      expect(etat().erreur, isFalse);
      await fermer(tester);
    });

    testWidgets('L4 : échec récent puis réussite plus ancienne de la session → réussite gardée', (tester) async {
      await ouvrir(tester);
      unawaited(c.read(palierProvider.notifier).actualiser());
      await repondre(tester, 1, null);
      await repondre(tester, 0, _profil(palierTurfiste));
      expect(etat().palier, palierTurfiste);
      expect(etat().erreur, isFalse);
      await fermer(tester);
    });

    testWidgets('L4 : échec ancien pendant une lecture récente → toujours en chargement', (tester) async {
      await ouvrir(tester);
      unawaited(c.read(palierProvider.notifier).actualiser());
      await repondre(tester, 0, null);
      expect(etat().enChargement, isTrue);
      await fermer(tester);
    });

    testWidgets('L4 : palier inconnu → nouveaux essais automatiques, en nombre borné', (tester) async {
      await ouvrir(tester);
      await repondre(tester, 0, null);
      expect((etat().palier, etat().erreur), (palierGratuit, true));
      for (var i = 0; i < reessaisPalier.length; i++) {
        await tester.pump(reessaisPalier[i]);
        expect(api.lectures, hasLength(i + 2));
        await repondre(tester, i + 1, null);
      }
      await tester.pump(const Duration(hours: 1));
      expect(api.lectures, hasLength(reessaisPalier.length + 1));
      await fermer(tester);
    });

    testWidgets('L4 : un essai automatique réussi rétablit le palier', (tester) async {
      await ouvrir(tester);
      await repondre(tester, 0, null);
      await tester.pump(reessaisPalier.first);
      await repondre(tester, 1, _profil(palierTurfiste));
      expect((etat().palier, etat().erreur), (palierTurfiste, false));
      await tester.pump(const Duration(hours: 1));
      expect(api.lectures, hasLength(2));
      await fermer(tester);
    });

    testWidgets('L5 : lecture sans réponse → échec après le délai, « Réessayer » utilisable', (tester) async {
      await ouvrir(tester);
      await tester.pump(delaiLecturePalier);
      expect((etat().palier, etat().erreur), (palierGratuit, true));
      final n = c.read(palierProvider.notifier);
      unawaited(n.reessayer());
      unawaited(n.reessayer());
      expect(api.lectures, hasLength(2));
      await tester.pump(delaiLecturePalier);
      final avant = api.lectures.length;
      unawaited(n.reessayer());
      expect(api.lectures, hasLength(avant + 1));
      await repondre(tester, avant, _profil(palierExpert));
      expect(etat().palier, palierExpert);
      await fermer(tester);
    });

    testWidgets("L6 : droit actif selon le serveur, échu à l'horloge de l'appareil → actif", (tester) async {
      await ouvrir(tester);
      await repondre(tester, 0, _profil(palierTurfiste, murale.subtract(const Duration(days: 1))));
      expect((etat().palier, etat().verification), (palierTurfiste, false));
      await passer(tester, const Duration(minutes: 1));
      expect(etat().palier, palierTurfiste);
      // Pas d'échéance locale : une relecture espacée.
      await passer(tester, relectureHorlogeDereglee);
      expect(api.lectures, hasLength(2));
      expect(etat().verification, isFalse);
      await fermer(tester);
    });

    testWidgets("L6 : horloge de l'appareil avancée après la réception → aucune échéance", (tester) async {
      await ouvrir(tester);
      await repondre(tester, 0, _profil(palierTurfiste, murale.add(const Duration(hours: 2))));
      murale = murale.add(const Duration(days: 3));
      unawaited(c.read(palierProvider.notifier).actualiser());
      expect(etat().verification, isFalse);
      await repondre(tester, 1, null);
      expect(etat().palier, palierTurfiste);
      await fermer(tester);
    });

    testWidgets("L6 : horloge de l'appareil reculée → l'échéance tombe quand même", (tester) async {
      await ouvrir(tester);
      await repondre(tester, 0, _profil(palierTurfiste, murale.add(const Duration(hours: 2))));
      murale = murale.subtract(const Duration(days: 3));
      monotone += const Duration(hours: 2);
      await tester.pump(const Duration(hours: 2));
      expect(etat().verification, isTrue);
      await repondre(tester, 1, null);
      expect(etat().palier, palierGratuit);
      await fermer(tester);
    });

    testWidgets("L2 : une réponse lancée avant l'échéance ne lève pas la vérification", (tester) async {
      await ouvrir(tester);
      final fin = murale.add(const Duration(seconds: 8));
      await repondre(tester, 0, _profil(palierTurfiste, fin));
      unawaited(c.read(palierProvider.notifier).actualiser());
      await passer(tester, const Duration(seconds: 8));
      expect(etat().verification, isTrue);
      expect(api.lectures, hasLength(3));
      await repondre(tester, 1, _profil(palierTurfiste, fin));
      expect(etat().verification, isTrue);
      await repondre(tester, 2, _profil(palierGratuit));
      expect((etat().palier, etat().verification), (palierGratuit, false));
      await fermer(tester);
    });

    testWidgets('L2 : sans réponse après l\'échéance → Gratuit + erreur après le délai', (tester) async {
      await ouvrir(tester);
      await repondre(tester, 0, _profil(palierTurfiste, murale.add(const Duration(hours: 1))));
      await passer(tester, const Duration(hours: 1));
      expect(etat().verification, isTrue);
      await passer(tester, delaiLecturePalier);
      expect((etat().palier, etat().erreur, etat().verification), (palierGratuit, true, false));
      await fermer(tester);
    });

    testWidgets('lectures bornées : le serveur redonne sans cesse une date imminente', (tester) async {
      await ouvrir(tester);
      var i = 0;
      for (var t = 0; t < 6000; t++) {
        while (i < api.lectures.length) {
          await repondre(tester, i++, _profil(palierTurfiste, murale.add(const Duration(milliseconds: 1))));
        }
        await passer(tester, const Duration(milliseconds: 100)); // 10 min en tout
      }
      expect(api.lectures.length, inInclusiveRange(9, 12));
      expect(etat().palier, palierTurfiste);
      await fermer(tester);
    });

    testWidgets('lectures bornées : le serveur redonne sans cesse une date échue', (tester) async {
      await ouvrir(tester);
      final fin = murale.add(const Duration(seconds: 1));
      var i = 0;
      for (var t = 0; t < 3600; t++) {
        while (i < api.lectures.length) {
          await repondre(tester, i++, _profil(palierTurfiste, fin));
        }
        await passer(tester, const Duration(seconds: 1)); // 1 h en tout
      }
      expect(api.lectures.length, inInclusiveRange(4, 6));
      await fermer(tester);
    });

    testWidgets('lectures bornées : horloge monotone figée, aucune boucle', (tester) async {
      await ouvrir(tester);
      await repondre(tester, 0, _profil(palierTurfiste, murale.add(const Duration(milliseconds: 300))));
      final avant = monotoneLue;
      await tester.pump(const Duration(minutes: 1));
      expect(api.lectures, hasLength(1));
      expect(monotoneLue - avant, lessThan(200));
      await fermer(tester);
    });

    testWidgets('L14 : échéance lointaine atteinte par pas de 12 h', (tester) async {
      await ouvrir(tester);
      await repondre(tester, 0, _profil(palierTurfiste, murale.add(const Duration(days: 30))));
      for (var i = 0; i < 59; i++) {
        await passer(tester, attenteMaxEcheance);
        expect(etat().palier, palierTurfiste);
        expect(etat().verification, isFalse);
      }
      expect(api.lectures, hasLength(1));
      await passer(tester, attenteMaxEcheance);
      expect(etat().verification, isTrue);
      expect(api.lectures, hasLength(2));
      await repondre(tester, 1, _profil(palierGratuit));
      expect(etat().palier, palierGratuit);
      await fermer(tester);
    });
  });

  group('L1 : envoi sur action seulement', () {
    late _Pronostics api;
    late PalierFixe palier;

    Future<ProviderContainer> conteneurDe(String p) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      api = _Pronostics();
      palier = PalierFixe(p);
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          pronosticsApiProvider.overrideWithValue(api),
          palierProvider.overrideWith(() => palier),
        ],
      );
      addTearDown(c.dispose);
      c.listen(resultsProvider, (_, _) {});
      c.read(horsesProvider.notifier).setAll([for (var i = 1; i <= 5; i++) Horse(nom: 'C$i', numPmu: i, cote: 2.0 + i)]);
      c.read(pronosticContextProvider.notifier).courseChargee(42);
      return c;
    }

    test('montée, chute, remontée écran ouvert : 0 envoi', () async {
      final c = await conteneurDe(palierGratuit);
      c.read(resultsProvider.notifier).ecranOuvert();
      for (final p in [palierTurfiste, palierExpert, palierTurfiste, palierGratuit, palierExpert]) {
        palier.passerA(p);
      }
      expect(c.read(resultsProvider)!.combinaisons, isNotNull);
      expect(api.envois, 0);
      c.read(resultsProvider.notifier).calculer();
      expect(api.envois, 1);
    });

    test('résultat périmé, palier qui monte : reste périmé, non recalculé', () async {
      final c = await conteneurDe(palierTurfiste);
      c.read(resultsProvider.notifier).calculer();
      c.read(horsesProvider.notifier).removeAt(0);
      final perime = c.read(resultsProvider)!;
      palier.passerA(palierExpert);
      expect(c.read(resultsProvider), same(perime));
      expect(c.read(resultsProvider)!.isStale, isTrue);
      expect(api.envois, 1);
    });

    test('résultat périmé, Expert → Turfiste : combinaisons retirées, reste périmé', () async {
      final c = await conteneurDe(palierExpert);
      c.read(resultsProvider.notifier).calculer();
      c.read(horsesProvider.notifier).removeAt(0);
      palier.passerA(palierTurfiste);
      final r = c.read(resultsProvider)!;
      expect(r.combinaisons, isNull);
      expect(r.isStale, isTrue);
      expect(r.nbReels, 5);
      expect(api.envois, 1);
    });

    test('vérification puis même palier : résultat intact', () async {
      final c = await conteneurDe(palierExpert);
      c.read(resultsProvider.notifier).calculer();
      final r = c.read(resultsProvider);
      final avant = palier.initial;
      palier.passerEtat(avant.enVerification());
      expect(c.read(resultsProvider), same(r));
      palier.passerEtat(avant);
      expect(c.read(resultsProvider), same(r));
      expect(api.envois, 1);
    });

    test('vérification puis Turfiste : recalculé sans combinaisons, sans envoi', () async {
      final c = await conteneurDe(palierExpert);
      c.read(resultsProvider.notifier).calculer();
      palier.passerEtat(palier.initial.enVerification());
      palier.passerA(palierTurfiste);
      expect(c.read(resultsProvider)!.combinaisons, isNull);
      expect(api.envois, 1);
    });
  });

  group('L13 : Expert de démonstration', () {
    test('655000056 (même masque) : Gratuit, avant comme après 677123456', () async {
      final api = FauxCompteApi();
      api.rattacher('+237655000056', cguVersion: 'v');
      expect((await api.lireProfil()).palier, palierGratuit);
      api.rattacher('+237677123456', cguVersion: 'v');
      expect((await api.lireProfil()).palier, palierExpert);
      api.rattacher('+237655000056', cguVersion: 'v');
      expect((await api.lireProfil()).palier, palierGratuit);
    });

    test('session Expert restaurée, puis connexion de 655000056 : Gratuit', () async {
      final api = FauxCompteApi()..restaurerSession(masqueExpert);
      expect((await api.lireProfil()).palier, palierExpert);
      api.rattacher('+237655000056', cguVersion: 'v');
      expect((await api.lireProfil()).palier, palierGratuit);
      expect(api.numeroCourant, '+237655000056');
    });

    test("restaurée dans le même lancement : le dernier compte connecté sous ce masque", () async {
      final api = FauxCompteApi()
        ..rattacher('+237677123456', cguVersion: 'v')
        ..rattacher('+237655000056', cguVersion: 'v')
        ..deconnecter()
        ..restaurerSession(masqueExpert);
      expect((await api.lireProfil()).palier, palierGratuit);
    });
  });
}
