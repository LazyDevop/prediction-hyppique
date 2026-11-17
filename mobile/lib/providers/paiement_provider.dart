import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/offres_api.dart';
import 'auth_provider.dart';

/// Intervalle entre deux lectures du statut d'un paiement en attente.
const intervalleSondageParDefaut = Duration(seconds: 2);

/// Lectures ratées d'affilée avant l'avis « Statut non actualisé » et le
/// ralentissement du sondage ([facteurRalentissement] × l'intervalle).
const erreursAvantRalentissement = 5;
const facteurRalentissement = 5;

/// Au-delà, le sondage s'arrête (l'avis reste affiché).
const dureeMaxSondage = Duration(minutes: 10);

const messageStatutNonActualise = "Statut non actualisé — le pass s'activera dès la confirmation";

final intervalleSondageProvider = Provider<Duration>((ref) => intervalleSondageParDefaut);

/// Signal « le droit du compte a changé » (paiement confirmé) : Profil et
/// Offres rechargent palier et fin du droit sans action de l'utilisateur.
class SignalDroit extends Notifier<int> {
  @override
  int build() => 0;

  void signaler() => state++;
}

final signalDroitProvider = NotifierProvider<SignalDroit, int>(SignalDroit.new);

enum EtapePaiement { initiation, enAttente, confirme, echoue, introuvable }

/// Paiement suivi au niveau de l'app (pas de l'écran) : le sondage continue
/// quand Paiement est fermé.
class PaiementEnCours {
  final Offre offre;
  final MoyenPaiement moyen;

  /// 9 chiffres locaux.
  final String numero;
  final String cleIdempotence;
  final String? id;
  final EtapePaiement etape;
  final PaiementConfirme? confirmation;

  /// Statut non actualisé : lectures ratées d'affilée, ou sondage arrêté.
  final bool nonActualise;

  const PaiementEnCours({
    required this.offre,
    required this.moyen,
    required this.numero,
    required this.cleIdempotence,
    required this.etape,
    this.id,
    this.confirmation,
    this.nonActualise = false,
  });

  bool get enCours => etape == EtapePaiement.initiation || etape == EtapePaiement.enAttente;
  bool get termine => !enCours;

  PaiementEnCours copier({
    String? id,
    EtapePaiement? etape,
    PaiementConfirme? confirmation,
    bool? nonActualise,
  }) => PaiementEnCours(
    offre: offre,
    moyen: moyen,
    numero: numero,
    cleIdempotence: cleIdempotence,
    id: id ?? this.id,
    etape: etape ?? this.etape,
    confirmation: confirmation ?? this.confirmation,
    nonActualise: nonActualise ?? this.nonActualise,
  );
}

typedef _Tentative = ({String offreId, MoyenPaiement moyen, String numero, String cle});

/// Tient le paiement en cours et interroge son statut. Seul le statut
/// renvoyé par [OffresApi] décide de l'issue. Effacé à la déconnexion.
class PaiementEnCoursNotifier extends Notifier<PaiementEnCours?> {
  final _aleatoire = Random.secure();
  Timer? _minuteur;
  OffresApi? _api;
  int _erreurs = 0;
  Duration _ecoule = Duration.zero;
  Duration _pas = Duration.zero;
  bool _lecture = false;

  /// Incrémentée à chaque nouveau paiement ou effacement : une réponse
  /// tardive d'un paiement abandonné est ignorée.
  int _generation = 0;

  /// Tentative dont l'initiation a échoué (réseau) : le « Payer » suivant,
  /// mêmes offre, moyen et numéro, réutilise sa clé d'idempotence.
  _Tentative? _nonAboutie;

  @override
  PaiementEnCours? build() {
    ref.onDispose(_arreter);
    ref.listen(authProvider, (_, suivant) {
      final porte = suivant.value?.porte;
      if (porte == Porte.aucuneSession || porte == Porte.appareilBloque) effacer();
    });
    return null;
  }

  String _nouvelleCle() =>
      'cli-${List.generate(16, (_) => _aleatoire.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';

  /// Initie un paiement. Null : erreur (réseau), la clé est gardée pour le
  /// prochain essai. L'état passe à « initiation » AVANT le premier `await`.
  Future<InitiationPaiementResultat?> payer({
    required Offre offre,
    required MoyenPaiement moyen,
    required String numero,
  }) async {
    final actuel = state;
    if (actuel != null && actuel.enCours) return const PaiementDejaEnCours();
    final t = _nonAboutie;
    final cle = t != null && t.offreId == offre.id && t.moyen == moyen && t.numero == numero ? t.cle : _nouvelleCle();
    _arreter();
    final generation = ++_generation;
    final api = ref.read(offresApiProvider);
    _api = api;
    state = PaiementEnCours(
      offre: offre,
      moyen: moyen,
      numero: numero,
      cleIdempotence: cle,
      etape: EtapePaiement.initiation,
    );
    final InitiationPaiementResultat resultat;
    try {
      resultat = await api.initierPaiement(offreId: offre.id, moyen: moyen, numero: numero, cleIdempotence: cle);
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        _nonAboutie = (offreId: offre.id, moyen: moyen, numero: numero, cle: cle);
        state = null;
      }
      return null;
    }
    if (!ref.mounted || generation != _generation) return resultat;
    _nonAboutie = null;
    if (resultat is PaiementInitie) {
      state = state!.copier(id: resultat.id, etape: EtapePaiement.enAttente);
      _erreurs = 0;
      _ecoule = Duration.zero;
      _programmer();
    } else {
      state = null;
    }
    return resultat;
  }

  void _programmer() {
    _minuteur?.cancel();
    final base = ref.read(intervalleSondageProvider);
    _pas = _erreurs >= erreursAvantRalentissement ? base * facteurRalentissement : base;
    _minuteur = Timer(_pas, () {
      _ecoule += _pas;
      _lire(relancer: true);
    });
  }

  /// Une lecture immédiate (Paiement rouvert alors que le sondage est
  /// arrêté).
  void actualiser() {
    final p = state;
    if (p == null || p.etape != EtapePaiement.enAttente) return;
    if (_minuteur?.isActive ?? false) return;
    _lire(relancer: false);
  }

  Future<void> _lire({required bool relancer}) async {
    final p = state;
    final api = _api;
    final id = p?.id;
    if (_lecture || p == null || p.etape != EtapePaiement.enAttente || id == null || api == null) return;
    _lecture = true;
    final generation = _generation;
    StatutPaiement? statut;
    try {
      statut = await api.statutPaiement(id);
    } catch (_) {
      statut = null;
    } finally {
      _lecture = false;
    }
    if (!ref.mounted) return;
    final actuel = state;
    if (generation != _generation || actuel == null || actuel.etape != EtapePaiement.enAttente) return;
    switch (statut) {
      case final PaiementConfirme c:
        _arreter();
        state = actuel.copier(etape: EtapePaiement.confirme, confirmation: c, nonActualise: false);
        ref.read(signalDroitProvider.notifier).signaler();
        return;
      case PaiementEchoue():
        _arreter();
        state = actuel.copier(etape: EtapePaiement.echoue, nonActualise: false);
        return;
      case PaiementIntrouvable():
        _arreter();
        state = actuel.copier(etape: EtapePaiement.introuvable, nonActualise: false);
        return;
      case PaiementEnAttente():
        _erreurs = 0;
        if (actuel.nonActualise && _ecoule < dureeMaxSondage) state = actuel.copier(nonActualise: false);
      case null:
        _erreurs++;
        if (_erreurs >= erreursAvantRalentissement && !actuel.nonActualise) {
          state = actuel.copier(nonActualise: true);
        }
    }
    if (!relancer) return;
    if (_ecoule >= dureeMaxSondage) {
      _arreter();
      if (!(state?.nonActualise ?? true)) state = state!.copier(nonActualise: true);
      return;
    }
    _programmer();
  }

  /// Issue vue (confirmé, échoué) : oubliée, sauf si un autre paiement a
  /// pris sa place.
  void oublier(String cle) {
    if (!ref.mounted) return;
    final p = state;
    if (p != null && p.termine && p.cleIdempotence == cle) state = null;
  }

  /// Déconnexion : plus aucun paiement suivi.
  void effacer() {
    if (!ref.mounted) return;
    _generation++;
    _arreter();
    _nonAboutie = null;
    _api = null;
    if (state != null) state = null;
  }

  void _arreter() {
    _minuteur?.cancel();
    _minuteur = null;
  }
}

/// Gardé en vie toute la session (pas d'autoDispose).
final paiementEnCoursProvider = NotifierProvider<PaiementEnCoursNotifier, PaiementEnCours?>(
  PaiementEnCoursNotifier.new,
);
