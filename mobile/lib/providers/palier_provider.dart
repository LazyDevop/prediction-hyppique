import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/acces_paliers.dart';
import '../data/remote/compte_api.dart';
import '../data/remote/offres_api.dart' show palierExpert, rangPalier;
import 'auth_provider.dart';
import 'paiement_provider.dart';

/// Attente maximale d'un minuteur : `setTimeout` du navigateur déborde
/// au-delà de 24 jours. L'échéance plus lointaine est reprogrammée.
const attenteMaxEcheance = Duration(hours: 12);

/// Plus courte attente d'un minuteur reprogrammé : une horloge qui n'avance
/// pas ne peut pas le faire tourner en boucle.
const attenteMinEcheance = Duration(seconds: 1);

/// Plus proche échéance acceptée d'une relecture faite à l'échéance : un
/// serveur qui redonne sans cesse une date imminente est relu au plus une
/// fois par minute.
const resteMinApresVerification = Duration(minutes: 1);

/// Au-delà, une lecture du palier compte comme un échec.
const delaiLecturePalier = Duration(seconds: 10);

/// Nouveaux essais automatiques tant que le palier est inconnu.
const reessaisPalier = [Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 45)];

/// Droit donné comme actif par le serveur mais déjà échu à l'horloge de
/// l'appareil (déréglée) : pas d'échéance locale, une relecture espacée.
const relectureHorlogeDereglee = Duration(minutes: 15);

/// Palier du compte ouvert. [palier] est nul tant qu'il n'est pas connu
/// (aucun compte, première lecture en cours) : ni contenu ni verrou.
class EtatPalier {
  /// Change à chaque compte fermé : rien ne passe d'un compte à l'autre.
  final int session;
  final String? palier;
  final DateTime? finDroit;

  /// Vrai si le palier a été lu au moins une fois dans cette session
  /// (faux : Gratuit par défaut, lecture en échec).
  final bool connu;

  /// Dernière lecture en échec : « Réessayer ».
  final bool erreur;

  /// Échéance locale atteinte, relecture en cours : ni contenu ni verrou,
  /// résultats et écrans conservés.
  final bool verification;

  /// Échéance locale atteinte et relecture en échec : Gratuit.
  final bool echuLocalement;

  /// Faux sans CompteApi : paliers non gérés, aucune fonction verrouillée.
  final bool gere;

  const EtatPalier({
    this.session = 0,
    this.palier,
    this.finDroit,
    this.connu = false,
    this.erreur = false,
    this.verification = false,
    this.echuLocalement = false,
    this.gere = true,
  });

  bool get enChargement => gere && (palier == null || verification);

  /// Vrai si [f] est ouverte ; faux pendant le chargement.
  bool autorise(Fonction f) {
    if (!gere) return true;
    final p = palier;
    return p != null && !verification && palierAutorise(p, f);
  }

  /// Rang du palier (non géré : tout est ouvert).
  int get rang => gere ? rangPalier(palier ?? palierGratuit) : rangPalier(palierExpert);

  EtatPalier enVerification() => EtatPalier(
    session: session,
    palier: palier,
    finDroit: finDroit,
    connu: connu,
    erreur: erreur,
    verification: true,
    gere: gere,
  );

  @override
  bool operator ==(Object other) =>
      other is EtatPalier &&
      other.session == session &&
      other.palier == palier &&
      other.finDroit == finDroit &&
      other.connu == connu &&
      other.erreur == erreur &&
      other.verification == verification &&
      other.echuLocalement == echuLocalement &&
      other.gere == gere;

  @override
  int get hashCode =>
      Object.hash(session, palier, finDroit, connu, erreur, verification, echuLocalement, gere);
}

/// Palier unique de l'app, lu par `CompteApi` : à la connexion, au
/// déverrouillage, au retour au premier plan (porte), sur
/// [signalDroitProvider] et à la fin du droit. Oublié à la déconnexion.
/// Lecture en échec : dernier palier connu de la session, sinon Gratuit.
///
/// Une lecture réussie fait foi sur l'horloge de l'appareil ; le temps
/// restant est ensuite compté sur l'horloge monotone depuis sa réception.
class PalierNotifier extends Notifier<EtatPalier> {
  Timer? _echeance;
  Timer? _reessaiAuto;
  ProfilCompte? _profil;
  String? _compte;
  bool _ouvert = false;
  bool _reessai = false;
  int _session = 0;

  /// Incrémentée à chaque compte fermé : une lecture commencée avant est
  /// ignorée.
  int _generation = 0;

  /// Rang de la dernière lecture lancée, de la dernière acceptée, et de la
  /// première lancée après l'échéance locale en cours de vérification.
  int _lancee = 0;
  int _acceptee = 0;
  int _minimum = 0;

  int _reessaisFaits = 0;

  /// Échéance sur l'horloge monotone ; nulle sans droit daté.
  Duration? _finMonotone;

  @override
  EtatPalier build() {
    ref.onDispose(_arreter);
    ref.listen(authProvider, (_, suivant) => _surAuth(suivant));
    ref.listen(signalDroitProvider, (_, _) => actualiser());
    final auth = ref.read(authProvider).value;
    if (auth?.porte == Porte.ouverte) {
      _ouvert = true;
      _compte = auth?.numeroMasque;
      scheduleMicrotask(() {
        if (ref.mounted) actualiser();
      });
    }
    return EtatPalier(gere: ref.read(compteDisponibleProvider));
  }

  void _arreter() {
    _echeance?.cancel();
    _reessaiAuto?.cancel();
  }

  void _surAuth(AsyncValue<EtatAuth> suivant) {
    final etat = suivant.value;
    if (etat == null) {
      if (suivant.hasError) _oublier();
      return;
    }
    switch (etat.porte) {
      case Porte.aucuneSession || Porte.choixPin || Porte.appareilBloque:
        _oublier();
      case Porte.verrouillee:
        _ouvert = false;
      case Porte.ouverte:
        if (_compte != etat.numeroMasque) _oublier();
        _compte = etat.numeroMasque;
        _ouvert = true;
        actualiser();
    }
  }

  void _oublier() {
    _ouvert = false;
    _generation++;
    _arreter();
    _profil = null;
    _finMonotone = null;
    _reessaisFaits = 0;
    if (_compte == null) return;
    _compte = null;
    state = EtatPalier(session: ++_session, gere: ref.read(compteDisponibleProvider));
  }

  bool get _echeanceAtteinte {
    final fin = _finMonotone;
    return fin != null && ref.read(horlogeMonotoneProvider)() >= fin;
  }

  /// Relit le palier du compte ouvert ; sans effet derrière une porte.
  Future<void> actualiser() async {
    if (!ref.read(compteDisponibleProvider)) return;
    if (_echeanceAtteinte && !state.verification) _verifier();
    if (!_ouvert) return;
    final generation = _generation;
    final rang = ++_lancee;
    final api = ref.read(compteApiProvider);
    ProfilCompte? profil;
    try {
      profil = await api.lireProfil().timeout(delaiLecturePalier);
    } catch (_) {
      profil = null;
    }
    if (!ref.mounted || generation != _generation) return;
    if (profil != null) {
      // Plus ancienne que la dernière acceptée, ou lancée avant l'échéance.
      if (rang < _acceptee || rang < _minimum) return;
      _accepter(profil, rang);
    } else if (rang == _lancee && rang >= _minimum) {
      // Sinon une lecture plus récente (en cours, finie ou à venir au
      // déverrouillage) décide à sa place.
      _echouer();
    }
  }

  void _verifier() {
    _minimum = _lancee + 1;
    state = state.enVerification();
  }

  void _accepter(ProfilCompte profil, int rang) {
    _acceptee = rang;
    final apresVerification = state.verification;
    _profil = profil;
    _reessaisFaits = 0;
    _reessaiAuto?.cancel();
    state = EtatPalier(session: _session, palier: profil.palier, finDroit: profil.finDroit, connu: true);
    _programmer(profil, apresVerification: apresVerification);
  }

  void _echouer() {
    final profil = _profil;
    if (profil != null && state.verification) {
      // Échéance passée, relecture impossible : le droit est terminé.
      _finMonotone = null;
      _echeance?.cancel();
      state = EtatPalier(
        session: _session,
        palier: palierGratuit,
        connu: true,
        erreur: true,
        echuLocalement: true,
      );
      return;
    }
    state = EtatPalier(
      session: _session,
      palier: state.echuLocalement ? palierGratuit : profil?.palier ?? palierGratuit,
      finDroit: state.echuLocalement ? null : profil?.finDroit,
      connu: profil != null,
      erreur: true,
      echuLocalement: state.echuLocalement,
    );
    if (profil == null && _reessaisFaits < reessaisPalier.length) {
      _reessaiAuto?.cancel();
      _reessaiAuto = Timer(reessaisPalier[_reessaisFaits++], () {
        if (ref.mounted) actualiser();
      });
    }
  }

  /// « Réessayer » : un double toucher n'agit qu'une fois.
  Future<void> reessayer() async {
    if (_reessai) return;
    _reessai = true;
    try {
      await actualiser();
    } finally {
      _reessai = false;
    }
  }

  /// Le profil ne donne pas l'heure du serveur : la durée restante vient de
  /// l'horloge de l'appareil à la réception.
  void _programmer(ProfilCompte profil, {required bool apresVerification}) {
    _echeance?.cancel();
    _finMonotone = null;
    final fin = profil.finDroit;
    if (fin == null || !profil.palierPayant) return;
    var reste = fin.difference(ref.read(horlogeMuraleProvider)());
    if (reste <= Duration.zero) {
      _echeance = Timer(relectureHorlogeDereglee, () {
        if (ref.mounted) actualiser();
      });
      return;
    }
    if (apresVerification && reste < resteMinApresVerification) reste = resteMinApresVerification;
    _finMonotone = ref.read(horlogeMonotoneProvider)() + reste;
    _attendre();
  }

  void _attendre({Duration minimum = Duration.zero}) {
    final fin = _finMonotone;
    if (fin == null) return;
    final reste = fin - ref.read(horlogeMonotoneProvider)();
    final attente = reste > attenteMaxEcheance
        ? attenteMaxEcheance
        : reste < minimum
        ? minimum
        : reste;
    _echeance = Timer(attente, () {
      if (!ref.mounted) return;
      if (_echeanceAtteinte) {
        actualiser();
      } else {
        _attendre(minimum: attenteMinEcheance);
      }
    });
  }
}

/// Gardé en vie toute la session : la porte l'écoute (jamais en pause).
final palierProvider = NotifierProvider<PalierNotifier, EtatPalier>(PalierNotifier.new);
