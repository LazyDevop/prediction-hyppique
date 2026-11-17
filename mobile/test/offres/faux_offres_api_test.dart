import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/data/remote/offres_api.dart';

import '../auth/auth_test_helpers.dart';

void main() {
  late Horloge horloge;
  late FauxCompteApi compte;
  late FauxOffresApi offres;
  var n = 0;

  /// Origine des horloges de test, en UTC.
  final t0 = DateTime(2026, 11, 17, 10).toUtc();

  setUp(() {
    horloge = Horloge();
    compte = FauxCompteApi(horloge: horloge.call, web: true);
    offres = FauxOffresApi(compte: compte, horloge: horloge.call);
    compte.rattacher('+237677123456', cguVersion: CGU_VERSION_PROVISOIRE);
  });

  Future<InitiationPaiementResultat> initier(String offreId, {String numero = '677123456', String? cle}) =>
      offres.initierPaiement(
        offreId: offreId,
        moyen: MoyenPaiement.mtnMomo,
        numero: numero,
        cleIdempotence: cle ?? 'cle-${n++}',
      );

  Future<String> payer(String offreId, {String numero = '677123456'}) async =>
      (await initier(offreId, numero: numero) as PaiementInitie).id;

  /// Paie [offreId] et laisse le délai s'écouler.
  Future<PaiementConfirme> payerEtConfirmer(String offreId) async {
    final id = await payer(offreId);
    horloge.avancer(const Duration(seconds: 5));
    return await offres.statutPaiement(id) as PaiementConfirme;
  }

  test('catalogue FR-41 : 2 Turfiste, 3 Expert, un Duo par palier payant, prix non fixés', () async {
    final liste = await offres.listerOffres();
    expect(liste.map((o) => o.nom), [
      'Pass semaine Turfiste',
      'Mensuel Turfiste',
      'Pass journée Expert',
      'Pass semaine Expert',
      'Mensuel Expert',
      'Offre Duo Turfiste',
      'Offre Duo Expert',
    ]);
    expect(liste.where((o) => o.duo).map((o) => o.palier), [palierTurfiste, palierExpert]);
    expect(liste.where((o) => o.duo).every((o) => o.personnes == 2), isTrue);
    expect(liste.every((o) => o.prixFcfa == null), isTrue);
    expect(formaterPrix(null), '… FCFA');
    expect(formaterPrix(1500), '1 500 FCFA');
    expect(formaterPrix(15000), '15 000 FCFA');
  });

  test('en attente, puis confirmé après le délai : palier et fin du droit (UTC) du compte', () async {
    final id = await payer('turfiste-semaine');
    expect(await offres.statutPaiement(id), isA<PaiementEnAttente>());
    horloge.avancer(const Duration(seconds: 3));
    expect(await offres.statutPaiement(id), isA<PaiementEnAttente>());
    expect((await compte.lireProfil()).palier, palierGratuit);

    horloge.avancer(const Duration(seconds: 1));
    final statut = await offres.statutPaiement(id) as PaiementConfirme;
    final fin = t0.add(FauxOffresApi.delaiDemo).add(const Duration(days: 7));
    expect(statut.palier, palierTurfiste);
    expect(statut.finDroit.isUtc, isTrue);
    expect(statut.finDroit, fin);
    final profil = await compte.lireProfil();
    expect(profil.palier, palierTurfiste);
    expect(profil.finDroit, fin);
    final droit = await offres.droitActuel();
    expect(droit.palier, palierTurfiste);
    expect(droit.payant, isTrue);
  });

  test('numéro 690000000 : en attente puis échoué, aucun palier', () async {
    final id = await payer('expert-journee', numero: FauxOffresApi.numeroEchec);
    expect(await offres.statutPaiement(id), isA<PaiementEnAttente>());
    horloge.avancer(const Duration(seconds: 10));
    expect(await offres.statutPaiement(id), isA<PaiementEchoue>());
    final profil = await compte.lireProfil();
    expect(profil.palier, palierGratuit);
    expect(profil.finDroit, isNull);
  });

  test('numéro non camerounais : refusé, rien initié', () async {
    for (final numero in ['512345678', '67712345', '6771234567', '']) {
      expect(await initier('turfiste-semaine', numero: numero), isA<NumeroPaiementInvalide>(), reason: numero);
    }
  });

  test('confirmation tardive : appliquée à la lecture du profil, sans lire le statut', () async {
    await payer('expert-mensuel');
    horloge.avancer(const Duration(minutes: 1));
    expect((await compte.lireProfil()).palier, palierExpert);
  });

  test('Duo : confirmé comme les autres, palier du Duo', () async {
    final c = await payerEtConfirmer('duo-expert');
    expect(c.palier, palierExpert);
    expect((await compte.lireProfil()).palier, palierExpert);
  });

  test('le paiement reste au compte qui a payé, même après déconnexion', () async {
    await payer('turfiste-semaine');
    compte.deconnecter();
    compte.rattacher('+237655000011', cguVersion: CGU_VERSION_PROVISOIRE);
    horloge.avancer(const Duration(seconds: 5));
    expect((await compte.lireProfil()).palier, palierGratuit);
    compte.restaurerSession(masquerNumero('+237677123456'));
    expect((await compte.lireProfil()).palier, palierTurfiste);
  });

  test('numéro proposé : celui du compte connecté dans ce lancement, sinon rien', () async {
    expect(await offres.numeroPropose(), '677123456');
    compte.deconnecter();
    expect(await offres.numeroPropose(), isNull);
  });

  test('sans compte courant : AucunCompte, jamais la clé vide', () async {
    compte.deconnecter();
    expect(await initier('turfiste-semaine'), isA<AucunCompte>());
    final seul = FauxOffresApi(horloge: horloge.call);
    final r = await seul.initierPaiement(
      offreId: 'turfiste-mensuel',
      moyen: MoyenPaiement.mtnMomo,
      numero: '677123456',
      cleIdempotence: 'x',
    );
    expect(r, isA<AucunCompte>());
    expect(await seul.numeroPropose(), isNull);
  });

  test('idempotence : même clé → même paiement, aucun second paiement', () async {
    final a = await initier('turfiste-semaine', cle: 'cle-unique') as PaiementInitie;
    final b = await initier('turfiste-semaine', cle: 'cle-unique') as PaiementInitie;
    expect(b.id, a.id);
    // Une autre clé pendant l'attente : bloquée (un paiement à la fois).
    expect(await initier('turfiste-semaine', cle: 'autre'), isA<PaiementDejaEnCours>());
    horloge.avancer(const Duration(seconds: 5));
    final fin = (await offres.statutPaiement(a.id) as PaiementConfirme).finDroit;
    // Une seule semaine accordée.
    expect(fin, t0.add(FauxOffresApi.delaiDemo).add(const Duration(days: 7)));
  });

  test('paiement inconnu : PaiementIntrouvable (issue définitive)', () async {
    expect(await offres.statutPaiement('inexistant'), isA<PaiementIntrouvable>());
  });

  group('règle des droits', () {
    test('même palier : prolongé depuis la fin actuelle', () async {
      final premier = await payerEtConfirmer('turfiste-semaine');
      horloge.avancer(const Duration(hours: 1));
      final second = await payerEtConfirmer('turfiste-mensuel');
      expect(second.palier, palierTurfiste);
      expect(second.finDroit, premier.finDroit.add(const Duration(days: 30)));
    });

    test('même palier échu : prolongé depuis maintenant', () async {
      await payerEtConfirmer('turfiste-semaine');
      horloge.avancer(const Duration(days: 8));
      final apres = horloge.maintenant.toUtc();
      final c = await payerEtConfirmer('turfiste-semaine');
      expect(c.finDroit, apres.add(FauxOffresApi.delaiDemo).add(const Duration(days: 7)));
    });

    test('palier supérieur : nouveau palier, fin = max(fin actuelle, maintenant + durée)', () async {
      final turfiste = await payerEtConfirmer('turfiste-mensuel');
      // 24 h d'Expert < 30 jours de Turfiste restants : la fin reste.
      final expert = await payerEtConfirmer('expert-journee');
      expect(expert.palier, palierExpert);
      expect(expert.finDroit, turfiste.finDroit);
    });

    test('palier supérieur plus long : fin = maintenant + durée', () async {
      await payerEtConfirmer('turfiste-semaine');
      final debut = horloge.maintenant.toUtc();
      final expert = await payerEtConfirmer('expert-mensuel');
      expect(expert.finDroit, debut.add(FauxOffresApi.delaiDemo).add(const Duration(days: 30)));
    });

    test('palier inférieur pendant un palier supérieur actif : refusé, typé', () async {
      final expert = await payerEtConfirmer('expert-semaine');
      final r = await initier('turfiste-semaine') as PalierSuperieurActif;
      expect(r.palier, palierExpert);
      expect(r.finDroit, expert.finDroit);
      // Échu : de nouveau possible.
      horloge.avancer(const Duration(days: 8));
      expect(await initier('turfiste-semaine'), isA<PaiementInitie>());
    });
  });
}
