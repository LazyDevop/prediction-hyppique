// Story 9.8 — matrice FR-39, état du palier, calcul selon le palier.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prediction_hippique/data/acces_paliers.dart';
import 'package:prediction_hippique/data/remote/api_client.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/data/remote/offres_api.dart';
import 'package:prediction_hippique/models/engine_params.dart';
import 'package:prediction_hippique/models/horse.dart';
import 'package:prediction_hippique/models/performance.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';
import 'package:prediction_hippique/providers/horses_provider.dart';
import 'package:prediction_hippique/providers/paiement_provider.dart';
import 'package:prediction_hippique/providers/palier_provider.dart';
import 'package:prediction_hippique/providers/params_provider.dart';
import 'package:prediction_hippique/providers/pronostic_provider.dart';
import 'package:prediction_hippique/providers/results_provider.dart';

import '../auth/auth_test_helpers.dart';
import 'paliers_test_helpers.dart';

/// Lecture du profil en échec tant que [enPanne], ou retenue par [attente].
class CompteInstrumente extends FauxCompteApi {
  bool enPanne = false;
  Completer<void>? attente;
  int lectures = 0;
  CompteInstrumente({super.horloge, super.palier, super.finDroit}) : super(web: true);

  @override
  Future<ProfilCompte> lireProfil() async {
    lectures++;
    if (enPanne) throw Exception('réseau');
    final profil = await super.lireProfil();
    await attente?.future;
    return profil;
  }
}

class _Pronostics implements PronosticsApi {
  final envoyes = <Map<String, Object?>>[];
  @override
  Future<void> envoyerPronostic(Map<String, Object?> pronostic) async => envoyes.add(pronostic);
}

Horse _cheval(int n, int rang) => Horse(
  nom: 'C$n',
  numPmu: n,
  age: 5,
  cote: 3.0 + n,
  performances: [Performance(partants: 10, rang: rang, distance: 1600, terrain: 1.0)],
);

Future<void> _tour() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  group('matrice FR-39', () {
    const gratuit = {
      Fonction.programme,
      Fonction.partants,
      Fonction.suivreCourse,
      Fonction.compte,
      Fonction.offres,
    };
    const turfiste = {
      Fonction.configuration,
      Fonction.saisieManuelle,
      Fonction.modifierPartants,
      Fonction.ficheCheval,
      Fonction.importPhoto,
      Fonction.calculLocal,
      Fonction.valueEtMise,
      Fonction.bankrollEtKelly,
    };
    const expert = {Fonction.combinaisons, Fonction.coefficientsMoteur};

    test('chaque fonction a une ligne', () {
      expect(accesPaliers.keys.toSet(), Fonction.values.toSet());
      expect({...gratuit, ...turfiste, ...expert}, Fonction.values.toSet());
    });

    for (final f in Fonction.values) {
      test('${f.name} : paliers', () {
        expect(palierAutorise(palierGratuit, f), gratuit.contains(f));
        expect(palierAutorise('Inconnu', f), gratuit.contains(f));
        expect(palierAutorise(palierTurfiste, f), !expert.contains(f));
        expect(palierAutorise(palierExpert, f), isTrue);
      });
    }
  });

  group('FauxCompteApi : paliers de démonstration', () {
    test('677123456 Expert (connexion ou session restaurée), autres numéros Gratuit', () async {
      final horloge = Horloge();
      final api = FauxCompteApi(horloge: horloge.call);
      api.rattacher('+237677000000', cguVersion: 'v');
      expect((await api.lireProfil()).palier, palierGratuit);
      api.rattacher('+237677123456', cguVersion: 'v');
      final p = await api.lireProfil();
      expect(p.palier, palierExpert);
      expect(p.finDroit!.isUtc, isTrue);
      final restaure = FauxCompteApi(horloge: horloge.call)..restaurerSession(masqueExpert);
      expect((await restaure.lireProfil()).palier, palierExpert);
    });

    test('droit échu : Gratuit, droit terminé gardé', () async {
      final horloge = Horloge();
      final fin = horloge().add(const Duration(days: 2));
      final api = FauxCompteApi(horloge: horloge.call, palier: palierTurfiste, finDroit: fin)
        ..restaurerSession(masqueGratuit);
      expect((await api.lireProfil()).palier, palierTurfiste);
      horloge.avancer(const Duration(days: 2));
      final p = await api.lireProfil();
      expect(p.palier, palierGratuit);
      expect(p.finDroit, isNull);
      expect(p.droitTermine!.palier, palierTurfiste);
      expect(p.droitTermine!.fin, fin);
      expect((await api.listerAppareils()).palier, palierGratuit);
    });
  });

  group('palierProvider', () {
    Future<(ProviderContainer, CompteInstrumente, Horloge)> ouvrir({
      String? palier,
      Duration? droit,
      bool enPanne = false,
      String masque = masqueGratuit,
    }) async {
      final horloge = Horloge();
      final compte = CompteInstrumente(
        horloge: horloge.call,
        palier: palier,
        finDroit: droit == null ? null : horloge().add(droit),
      )..enPanne = enPanne;
      final c = conteneur(
        store: await storeAvecSession(numeroMasque: masque),
        compte: compte,
        web: true,
        horloge: horloge,
      );
      addTearDown(c.dispose);
      c.listen(palierProvider, (_, _) {});
      return (c, compte, horloge);
    }

    test('en chargement : ni permis ni connu, puis le palier du compte', () async {
      final (c, _, _) = await ouvrir(masque: masqueExpert);
      expect(c.read(palierProvider).enChargement, isTrue);
      expect(c.read(palierProvider).autorise(Fonction.programme), isFalse);
      await _tour();
      expect(c.read(palierProvider).palier, palierExpert);
      expect(c.read(palierProvider).connu, isTrue);
    });

    test('première lecture en échec : Gratuit + erreur ; Réessayer (double toucher) retrouve le palier', () async {
      final (c, compte, _) = await ouvrir(palier: palierTurfiste, enPanne: true);
      await _tour();
      var e = c.read(palierProvider);
      expect((e.palier, e.erreur, e.connu), (palierGratuit, true, false));
      compte.enPanne = false;
      final lectures = compte.lectures;
      final n = c.read(palierProvider.notifier);
      await Future.wait([n.reessayer(), n.reessayer()]);
      expect(compte.lectures, lectures + 1);
      e = c.read(palierProvider);
      expect((e.palier, e.erreur, e.connu), (palierTurfiste, false, true));
    });

    test('lecture suivante en échec : dernier palier connu', () async {
      final (c, compte, _) = await ouvrir(palier: palierTurfiste);
      await _tour();
      compte.enPanne = true;
      c.read(signalDroitProvider.notifier).signaler();
      await _tour();
      expect(c.read(palierProvider).palier, palierTurfiste);
      expect(c.read(palierProvider).erreur, isTrue);
    });

    test('dernier palier connu mais échu : Gratuit même si la relecture échoue', () async {
      final (c, compte, horloge) = await ouvrir(palier: palierTurfiste, droit: const Duration(hours: 1));
      await _tour();
      compte.enPanne = true;
      horloge.avancer(const Duration(hours: 1));
      await c.read(palierProvider.notifier).actualiser();
      expect(c.read(palierProvider).palier, palierGratuit);
    });

    test('échéance : le minuteur fait tomber le droit tout seul', () async {
      final (c, _, horloge) = await ouvrir(palier: palierTurfiste, droit: const Duration(milliseconds: 60));
      await _tour();
      expect(c.read(palierProvider).palier, palierTurfiste);
      horloge.avancer(const Duration(milliseconds: 60));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.read(palierProvider).palier, palierGratuit);
    });

    test('déconnexion : oublié ; une lecture en retard ne revient pas', () async {
      final (c, compte, _) = await ouvrir(masque: masqueExpert);
      await _tour();
      final session = c.read(palierProvider).session;
      compte.attente = Completer();
      c.read(signalDroitProvider.notifier).signaler();
      await c.read(authProvider.notifier).seDeconnecter();
      expect(c.read(palierProvider).enChargement, isTrue);
      expect(c.read(palierProvider).session, isNot(session));
      compte.attente!.complete();
      await _tour();
      expect(c.read(palierProvider).enChargement, isTrue);
    });

    test('changement de compte, première lecture du second en échec : Gratuit, pas Expert', () async {
      final (c, compte, _) = await ouvrir(masque: masqueExpert);
      await _tour();
      expect(c.read(palierProvider).palier, palierExpert);
      await c.read(authProvider.notifier).seDeconnecter();
      compte.enPanne = true;
      await c.read(authProvider.notifier).demanderCode('+237677000000');
      await c.read(authProvider.notifier).verifierCode('+237677000000', '123456');
      await _tour();
      expect(c.read(palierProvider).palier, palierGratuit);
    });
  });

  group('calcul selon le palier', () {
    late SharedPreferences prefs;
    late _Pronostics api;
    late PalierFixe palier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      api = _Pronostics();
    });

    ProviderContainer conteneurDe(String? p) {
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
      c.read(horsesProvider.notifier).setAll([for (var i = 1; i <= 6; i++) _cheval(i, i)]);
      c.read(pronosticContextProvider.notifier).courseChargee(42);
      return c;
    }

    test('Gratuit ou chargement : rien de calculé ni envoyé', () {
      for (final p in [palierGratuit, null]) {
        final c = conteneurDe(p);
        c.read(resultsProvider.notifier).calculer();
        expect(c.read(resultsProvider), isNull);
      }
      expect(api.envoyes, isEmpty);
    });

    test('Turfiste : value et mise, aucune combinaison calculée ni envoyée', () {
      final c = conteneurDe(palierTurfiste);
      c.read(resultsProvider.notifier).calculer();
      final r = c.read(resultsProvider)!;
      expect(r.combinaisons, isNull);
      expect(r.resultats.any((h) => h.value != null), isTrue);
      expect(api.envoyes.single.containsKey('combinaisons'), isFalse);
      expect(((api.envoyes.single['chevaux'] as List).first as Map).containsKey('value'), isTrue);
    });

    test('Turfiste : coefficients par défaut, bankroll et Kelly gardés, valeurs enregistrées conservées', () {
      final c = conteneurDe(palierTurfiste);
      const perso = EngineParams(contraste: 9, shrink: 7, bankroll: 500, fractionKelly: .5);
      c.read(engineParamsProvider.notifier).update(perso);
      c.read(resultsProvider.notifier).calculer();
      final envoi = api.envoyes.single;
      expect(envoi['parametres'], const EngineParams(bankroll: 500, fractionKelly: .5).toJson());
      expect(envoi['reglages_par_defaut'], isTrue);
      expect(c.read(engineParamsProvider).contraste, 9);
      expect(prefs.getString('engine_params'), contains('"contraste":9'));
    });

    test('palier qui monte : résultat affiché recalculé avec les combinaisons', () {
      final c = conteneurDe(palierTurfiste);
      c.read(resultsProvider.notifier).calculer();
      palier.passerA(palierExpert);
      expect(c.read(resultsProvider)!.combinaisons, isNotNull);
    });

    test('palier qui monte sans Résultats ouvert : rien ; Résultats ouvert : calculé', () {
      final c = conteneurDe(palierGratuit);
      palier.passerA(palierTurfiste);
      expect(c.read(resultsProvider), isNull);
      palier.passerA(palierGratuit);
      c.read(resultsProvider.notifier).ecranOuvert();
      palier.passerA(palierTurfiste);
      expect(c.read(resultsProvider), isNotNull);
    });

    test('palier qui tombe : Expert → Turfiste sans combinaisons ; → Gratuit plus de résultat', () {
      final c = conteneurDe(palierExpert);
      c.read(resultsProvider.notifier).calculer();
      expect(c.read(resultsProvider)!.combinaisons, isNotNull);
      palier.passerA(palierTurfiste);
      expect(c.read(resultsProvider)!.combinaisons, isNull);
      palier.passerA(palierGratuit);
      expect(c.read(resultsProvider), isNull);
    });

    test('changement de compte : ni résultat ni partants du compte précédent', () {
      final c = conteneurDe(palierExpert);
      c.read(resultsProvider.notifier).calculer();
      palier.passerA(null, session: 1);
      expect(c.read(resultsProvider), isNull);
      expect(c.read(horsesProvider), isEmpty);
      expect(c.read(pronosticContextProvider).courseId, isNull);
    });
  });
}
