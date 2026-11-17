import 'compte_api.dart';

const palierTurfiste = 'Turfiste';
const palierExpert = 'Expert';

/// Nombre de personnes d'une offre Duo. Provisoire (PRD OQ 13).
// ignore: constant_identifier_names
const PERSONNES_DUO_PROVISOIRE = 2;

enum GroupeOffre { turfiste, expert, duo }

enum MoyenPaiement { mtnMomo, orangeMoney }

String libelleMoyen(MoyenPaiement m) => switch (m) {
  MoyenPaiement.mtnMomo => 'MTN MoMo',
  MoyenPaiement.orangeMoney => 'Orange Money',
};

/// Offre du catalogue (PRD FR-41). Le prix est une donnée de configuration
/// (PRD OQ 13) : null tant qu'il n'est pas fixé, affiché « … FCFA ».
class Offre {
  final String id;

  /// « Pass semaine Turfiste ».
  final String nom;
  final String palier;
  final GroupeOffre groupe;

  /// « 7 jours », « 24 h ».
  final String libelleDuree;
  final Duration duree;
  final int? prixFcfa;

  /// Ce que l'offre débloque ; les passages entre `**` sont en gras.
  final String debloque;

  /// Phrase de l'état confirmé : « Les instantanés … sont débloqués, … ».
  final String debloqueConfirme;

  /// Personnes couvertes (Duo : [PERSONNES_DUO_PROVISOIRE]).
  final int personnes;

  const Offre({
    required this.id,
    required this.nom,
    required this.palier,
    required this.groupe,
    required this.libelleDuree,
    required this.duree,
    required this.prixFcfa,
    required this.debloque,
    required this.debloqueConfirme,
    this.personnes = 1,
  });

  bool get duo => groupe == GroupeOffre.duo;

  /// « Pass semaine Turfiste actif », « Offre Duo Expert active ».
  String get libelleActif => duo ? '$nom active' : '$nom actif';
}

/// « … FCFA » tant que le prix n'est pas fixé, sinon « 1 500 FCFA ».
String formaterPrix(int? prix) {
  if (prix == null) return '… FCFA';
  final chiffres = prix.toString();
  final groupes = <String>[];
  for (var fin = chiffres.length; fin > 0; fin -= 3) {
    groupes.insert(0, chiffres.substring(fin - 3 < 0 ? 0 : fin - 3, fin));
  }
  return '${groupes.join(' ')} FCFA';
}

/// Rang d'un palier : Gratuit < Turfiste < Expert.
int rangPalier(String palier) => switch (palier) {
  palierExpert => 2,
  palierTurfiste => 1,
  _ => 0,
};

/// Droit en cours du compte (palier, fin ; null pour Gratuit).
class DroitActuel {
  final String palier;
  final DateTime? finDroit;
  const DroitActuel(this.palier, this.finDroit);

  bool get payant => rangPalier(palier) > 0 && finDroit != null;
}

/// Résultat de `OffresApi.initierPaiement`.
sealed class InitiationPaiementResultat {
  const InitiationPaiementResultat();
}

class PaiementInitie extends InitiationPaiementResultat {
  final String id;
  const PaiementInitie(this.id);
}

class NumeroPaiementInvalide extends InitiationPaiementResultat {
  const NumeroPaiementInvalide();
}

/// Offre d'un palier inférieur au palier payant en cours : refusée.
class PalierSuperieurActif extends InitiationPaiementResultat {
  final String palier;
  final DateTime finDroit;
  const PalierSuperieurActif(this.palier, this.finDroit);
}

/// Aucun compte ouvert : rien n'est initié.
class AucunCompte extends InitiationPaiementResultat {
  const AucunCompte();
}

/// Un autre paiement du compte attend encore sa confirmation.
class PaiementDejaEnCours extends InitiationPaiementResultat {
  const PaiementDejaEnCours();
}

/// Statut d'un paiement : seul le serveur décide (PRD FR-42).
sealed class StatutPaiement {
  const StatutPaiement();
}

class PaiementEnAttente extends StatutPaiement {
  const PaiementEnAttente();
}

class PaiementConfirme extends StatutPaiement {
  final String palier;
  final DateTime finDroit;
  const PaiementConfirme({required this.palier, required this.finDroit});
}

/// Non confirmé : aucun droit activé.
class PaiementEchoue extends StatutPaiement {
  const PaiementEchoue();
}

/// Paiement inconnu du serveur : issue définitive, on n'interroge plus.
class PaiementIntrouvable extends StatutPaiement {
  const PaiementIntrouvable();
}

/// Port Offres et paiement Mobile Money (stories 9.4, 9.5). Les écrans ne
/// dépendent que de cette interface ; [FauxOffresApi] la remplace tant que
/// le serveur (agrégateur, prix) n'existe pas.
abstract class OffresApi {
  Future<List<Offre>> listerOffres();

  /// Palier et fin du droit du compte courant.
  Future<DroitActuel> droitActuel();

  /// Numéro du compte proposé pour le paiement (9 chiffres locaux), ou null.
  Future<String?> numeroPropose();

  /// [numero] : 9 chiffres locaux du numéro Mobile Money. [cleIdempotence] :
  /// générée une fois par tentative ; la même clé ne crée jamais un second
  /// paiement (le serveur renvoie le paiement existant).
  Future<InitiationPaiementResultat> initierPaiement({
    required String offreId,
    required MoyenPaiement moyen,
    required String numero,
    required String cleIdempotence,
  });

  Future<StatutPaiement> statutPaiement(String id);
}

final _mobileCamerounais = RegExp(r'^6\d{8}$');

class _PaiementDemo {
  final Offre offre;
  final String numero;
  final String cleCompte;
  final DateTime creeLe;
  StatutPaiement statut = const PaiementEnAttente();
  _PaiementDemo(this.offre, this.numero, this.cleCompte, this.creeLe);
}

/// Faux serveur de paiement, en mémoire, sans aucun paiement réel. Un
/// paiement reste en attente pendant [delai], puis est confirmé — sauf
/// avec le numéro [numeroEchec], qui échoue. La confirmation met à jour le
/// palier du [FauxCompteApi] lié, même si plus personne n'interroge le
/// statut (relu à la lecture du profil).
class FauxOffresApi implements OffresApi {
  static const numeroEchec = '690000000';
  static const delaiDemo = Duration(seconds: 4);

  final FauxCompteApi? _compte;
  final DateTime Function() _horloge;
  /// Attente avant que le faux serveur règle un paiement.
  final Duration delai;
  final Map<String, _PaiementDemo> _paiements = {};
  final Map<String, String> _parCle = {};
  int _suivant = 0;

  FauxOffresApi({FauxCompteApi? compte, DateTime Function()? horloge, this.delai = delaiDemo})
    : _compte = compte,
      _horloge = horloge ?? DateTime.now {
    compte?.regularisation = _regulariser;
  }

  /// Durée des offres Duo (30 jours) : provisoire, à confirmer avec les
  /// prix (PRD OQ 13).
  static const catalogue = <Offre>[
    Offre(
      id: 'turfiste-semaine',
      nom: 'Pass semaine Turfiste',
      palier: palierTurfiste,
      groupe: GroupeOffre.turfiste,
      libelleDuree: '7 jours',
      duree: Duration(days: 7),
      prixFcfa: null,
      debloque:
          "**Débloque les instantanés H-60, H-30 et H-15**, la value, la mise suggérée et l'historique complet des chevaux.",
      debloqueConfirme: "Les instantanés H-60, H-30 et H-15 sont débloqués, sans redémarrer l'app.",
    ),
    Offre(
      id: 'turfiste-mensuel',
      nom: 'Mensuel Turfiste',
      palier: palierTurfiste,
      groupe: GroupeOffre.turfiste,
      libelleDuree: '30 jours',
      duree: Duration(days: 30),
      prixFcfa: null,
      debloque: 'Le même contenu que le pass semaine Turfiste.',
      debloqueConfirme: "Les instantanés H-60, H-30 et H-15 sont débloqués, sans redémarrer l'app.",
    ),
    Offre(
      id: 'expert-journee',
      nom: 'Pass journée Expert',
      palier: palierExpert,
      groupe: GroupeOffre.expert,
      libelleDuree: '24 h',
      duree: Duration(hours: 24),
      prixFcfa: null,
      debloque:
          "Tout le palier Turfiste, plus **l'instantané H-10**, les paris combinés, le moteur expert réglable et le Multi.",
      debloqueConfirme: "L'instantané H-10, les paris combinés et le Multi sont débloqués, sans redémarrer l'app.",
    ),
    Offre(
      id: 'expert-semaine',
      nom: 'Pass semaine Expert',
      palier: palierExpert,
      groupe: GroupeOffre.expert,
      libelleDuree: '7 jours',
      duree: Duration(days: 7),
      prixFcfa: null,
      debloque: 'Le même contenu que le pass journée Expert.',
      debloqueConfirme: "L'instantané H-10, les paris combinés et le Multi sont débloqués, sans redémarrer l'app.",
    ),
    Offre(
      id: 'expert-mensuel',
      nom: 'Mensuel Expert',
      palier: palierExpert,
      groupe: GroupeOffre.expert,
      libelleDuree: '30 jours',
      duree: Duration(days: 30),
      prixFcfa: null,
      debloque: 'Le même contenu que le pass journée Expert.',
      debloqueConfirme: "L'instantané H-10, les paris combinés et le Multi sont débloqués, sans redémarrer l'app.",
    ),
    Offre(
      id: 'duo-turfiste',
      nom: 'Offre Duo Turfiste',
      palier: palierTurfiste,
      groupe: GroupeOffre.duo,
      libelleDuree: '30 jours',
      duree: Duration(days: 30),
      prixFcfa: null,
      personnes: PERSONNES_DUO_PROVISOIRE,
      debloque:
          '**Pour $PERSONNES_DUO_PROVISOIRE personnes.** Partagez le palier Turfiste avec un proche. Chacun garde son compte et ses appareils ; tous ont les mêmes dates de fin que vous.',
      debloqueConfirme: "Les instantanés H-60, H-30 et H-15 sont débloqués, sans redémarrer l'app.",
    ),
    Offre(
      id: 'duo-expert',
      nom: 'Offre Duo Expert',
      palier: palierExpert,
      groupe: GroupeOffre.duo,
      libelleDuree: '30 jours',
      duree: Duration(days: 30),
      prixFcfa: null,
      personnes: PERSONNES_DUO_PROVISOIRE,
      debloque:
          '**Pour $PERSONNES_DUO_PROVISOIRE personnes.** Partagez le palier Expert avec un proche. Chacun garde son compte et ses appareils ; tous ont les mêmes dates de fin que vous.',
      debloqueConfirme: "L'instantané H-10, les paris combinés et le Multi sont débloqués, sans redémarrer l'app.",
    ),
  ];

  @override
  Future<List<Offre>> listerOffres() async => catalogue;

  /// Droit du compte [cle] à [maintenant] : un droit échu redevient Gratuit.
  DroitActuel _droit(String? cle, DateTime maintenant) {
    final compte = _compte;
    if (compte == null || cle == null) return const DroitActuel(palierGratuit, null);
    final (palier, fin) = compte.droitDe(cle);
    if (fin == null || !fin.isAfter(maintenant)) return const DroitActuel(palierGratuit, null);
    return DroitActuel(palier, fin);
  }

  @override
  Future<DroitActuel> droitActuel() async {
    _regulariser();
    return _droit(_compte?.cleCompteCourant, _horloge());
  }

  @override
  Future<String?> numeroPropose() async {
    final numero = _compte?.numeroCourant;
    if (numero == null) return null;
    return numero.startsWith('+237') ? numero.substring(4) : numero;
  }

  @override
  Future<InitiationPaiementResultat> initierPaiement({
    required String offreId,
    required MoyenPaiement moyen,
    required String numero,
    required String cleIdempotence,
  }) async {
    final existant = _parCle[cleIdempotence];
    if (existant != null) return PaiementInitie(existant);
    if (!_mobileCamerounais.hasMatch(numero)) return const NumeroPaiementInvalide();
    final cle = _compte?.cleCompteCourant;
    if (cle == null) return const AucunCompte();
    _regulariser();
    final offre = catalogue.firstWhere((o) => o.id == offreId, orElse: () => throw ArgumentError.value(offreId));
    final maintenant = _horloge();
    final droit = _droit(cle, maintenant);
    if (rangPalier(droit.palier) > rangPalier(offre.palier)) {
      return PalierSuperieurActif(droit.palier, droit.finDroit!);
    }
    if (_paiements.values.any((p) => p.cleCompte == cle && p.statut is PaiementEnAttente)) {
      return const PaiementDejaEnCours();
    }
    final id = 'demo-paiement-${_suivant++}';
    _paiements[id] = _PaiementDemo(offre, numero, cle, maintenant);
    _parCle[cleIdempotence] = id;
    return PaiementInitie(id);
  }

  @override
  Future<StatutPaiement> statutPaiement(String id) async {
    _regulariser();
    return _paiements[id]?.statut ?? const PaiementIntrouvable();
  }

  /// Règle les paiements en attente dont le délai est écoulé. Règle des
  /// droits (tient lieu du serveur), dates en UTC :
  /// - même palier : prolongé depuis max(maintenant, fin actuelle) ;
  /// - palier supérieur : nouveau palier, fin = max(fin actuelle,
  ///   maintenant + durée) ;
  /// - palier inférieur à un palier supérieur actif : droit inchangé
  ///   (refusé dès l'initiation).
  void _regulariser() {
    for (final p in _paiements.values) {
      if (p.statut is! PaiementEnAttente) continue;
      final confirmeLe = p.creeLe.toUtc().add(delai);
      if (_horloge().toUtc().isBefore(confirmeLe)) continue;
      if (p.numero == numeroEchec) {
        p.statut = const PaiementEchoue();
        continue;
      }
      final droit = _droit(p.cleCompte, confirmeLe);
      final finActuelle = droit.finDroit?.toUtc();
      final rangActuel = rangPalier(droit.palier);
      final rangOffre = rangPalier(p.offre.palier);
      var palier = p.offre.palier;
      DateTime fin;
      if (rangActuel == rangOffre && finActuelle != null) {
        fin = (finActuelle.isAfter(confirmeLe) ? finActuelle : confirmeLe).add(p.offre.duree);
      } else if (rangActuel > rangOffre) {
        palier = droit.palier;
        fin = finActuelle!;
      } else {
        final finOffre = confirmeLe.add(p.offre.duree);
        fin = finActuelle != null && finActuelle.isAfter(finOffre) ? finActuelle : finOffre;
      }
      p.statut = PaiementConfirme(palier: palier, finDroit: fin);
      _compte?.activerPass(p.cleCompte, palier: palier, finDroit: fin);
    }
  }
}
