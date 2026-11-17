import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, kProfileMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/pin_hash.dart';
import '../data/local/session_store.dart';
import '../data/remote/auth_api.dart';
import '../data/remote/compte_api.dart';
import '../data/remote/offres_api.dart';

/// Inactivité (temps passé en arrière-plan) au-delà de laquelle l'app se
/// verrouille au retour au premier plan. Provisoire (PRD OQ 14).
// ignore: constant_identifier_names
const DELAI_VERROUILLAGE = Duration(minutes: 5);

/// Échecs de PIN avant effacement de la session locale (FR-32).
const essaisPinMax = 5;

const messageSessionEffacee = 'Session effacée — reconnectez-vous par code SMS';

/// `--dart-define=AUTH_DEMO=true` autorise le faux serveur dans un build release.
const _authDemo = bool.fromEnvironment('AUTH_DEMO');

const _demoAutorisee = kDebugMode || kProfileMode || _authDemo;

/// Règle de démonstration : faux serveurs seulement en debug/profile ou
/// avec `AUTH_DEMO=true`. Les drapeaux de démo et l'icône de compte
/// lisent ce booléen, jamais l'échec d'un provider.
final demoAutoriseeProvider = Provider<bool>((ref) => _demoAutorisee);

/// Horloge murale : dates du faux serveur et « dernière activité ».
final horlogeMuraleProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Les trois faux serveurs liés (la limite d'appareils du faux compte
/// décide du blocage à la connexion ; un paiement confirmé change son
/// palier), construits UNE fois : `ref.read` pour ne jamais être
/// reconstruits, ce qui effacerait leur état.
final _fauxServeursProvider = Provider<(FauxAuthApi, FauxCompteApi, FauxOffresApi)>((ref) {
  final horloge = ref.read(horlogeMuraleProvider);
  final compte = FauxCompteApi(horloge: horloge, web: ref.read(estWebProvider));
  return (FauxAuthApi(rattachement: compte), compte, FauxOffresApi(compte: compte, horloge: horloge));
});

/// FauxAuthApi seulement selon [demoAutoriseeProvider] : un build release
/// sans client réel échoue clairement au lieu d'accepter le code de
/// démonstration.
final authApiProvider = Provider<AuthApi>((ref) {
  if (ref.watch(demoAutoriseeProvider)) return ref.watch(_fauxServeursProvider).$1;
  throw StateError('aucune AuthApi réelle — story 8.1 serveur');
});

/// Même règle que [authApiProvider].
final compteApiProvider = Provider<CompteApi>((ref) {
  if (ref.watch(demoAutoriseeProvider)) return ref.watch(_fauxServeursProvider).$2;
  throw StateError('aucune CompteApi réelle — stories 8.4 et 8.6 serveur');
});

/// Même règle que [authApiProvider]. Aucun paiement réel tant que le
/// serveur (stories 9.4, 9.5) n'existe pas.
final offresApiProvider = Provider<OffresApi>((ref) {
  if (ref.watch(demoAutoriseeProvider)) return ref.watch(_fauxServeursProvider).$3;
  throw StateError('aucune OffresApi réelle — stories 9.4 et 9.5 serveur');
});

/// Vrai quand une OffresApi existe (ligne « Offres » de Profil).
final offresDisponiblesProvider = Provider<bool>((ref) => ref.watch(demoAutoriseeProvider));

/// Vrai quand le faux serveur de paiement est actif (« Mode démo : aucun
/// paiement réel »). Lit d'abord la règle de démo : jamais l'échec d'un
/// provider.
final modeDemoPaiementProvider = Provider<bool>(
  (ref) => ref.watch(demoAutoriseeProvider) && ref.watch(offresApiProvider) is FauxOffresApi,
);

/// Vrai quand une CompteApi existe (Profil accessible depuis Accueil).
/// Seule la démo en fournit une tant que le client réel n'existe pas.
final compteDisponibleProvider = Provider<bool>((ref) => ref.watch(demoAutoriseeProvider));

/// Vrai quand le faux serveur de démonstration est actif (« Mode démo »).
final modeDemoProvider = Provider<bool>((ref) => ref.watch(demoAutoriseeProvider));

/// Vrai quand le faux serveur de compte est actif (code email de démo).
final modeDemoCompteProvider = Provider<bool>((ref) => ref.watch(demoAutoriseeProvider));

/// Web : rien n'est persisté par l'app (le cookie de renouvellement viendra
/// avec la story 8.2).
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => kIsWeb ? MemorySessionStore() : SecureSessionStore(),
);

final pinHasherProvider = Provider<PinHasher>((ref) => PinHasher());

/// Web : pas de PIN ni de Déverrouillage (EXPERIENCE).
final estWebProvider = Provider<bool>((ref) => kIsWeb);

/// Horloge monotone (temps écoulé depuis le lancement), insensible aux
/// changements d'heure de l'appareil : sert au verrouillage automatique.
final horlogeMonotoneProvider = Provider<Duration Function()>((ref) {
  final chrono = Stopwatch()..start();
  return () => chrono.elapsed;
});

/// [appareilBloque] : code correct mais limite d'appareils atteinte ; aucune
/// session n'est ouverte, seul un jeton de gestion des appareils est tenu.
enum Porte { aucuneSession, choixPin, verrouillee, ouverte, appareilBloque }

class EtatAuth {
  final Porte porte;
  final String? numeroMasque;
  final int? pinLongueur;
  final int essaisPinRestants;

  /// Message à afficher sur Connexion (ex. session effacée).
  final String? message;

  /// Porte [Porte.appareilBloque] : jeton de gestion, limite et palier.
  final AppareilBloque? blocage;

  const EtatAuth(
    this.porte, {
    this.numeroMasque,
    this.pinLongueur,
    this.essaisPinRestants = essaisPinMax,
    this.message,
    this.blocage,
  });
}

class AuthNotifier extends AsyncNotifier<EtatAuth> {
  Duration? _arrierePlanDepuis;

  SessionStore get _store => ref.read(sessionStoreProvider);

  /// Faux serveur de compte, s'il est actif (crochets de démo).
  FauxCompteApi? get _fauxCompte {
    if (!ref.read(demoAutoriseeProvider)) return null;
    final compte = ref.read(compteApiProvider);
    return compte is FauxCompteApi ? compte : null;
  }

  bool get _estWeb => ref.read(estWebProvider);

  @override
  Future<EtatAuth> build() async {
    final session = await _store.lire();
    if (session == null) return const EtatAuth(Porte.aucuneSession);
    _fauxCompte?.restaurerSession(session.numeroMasque);
    if (_estWeb) return EtatAuth(Porte.ouverte, numeroMasque: session.numeroMasque);
    // Session sans PIN (app tuée avant le choix, clés PIN absentes) : le
    // choix du PIN n'est proposé qu'après un code reçu dans ce lancement.
    if (!session.pinDefini) {
      await _store.effacer();
      return const EtatAuth(Porte.aucuneSession);
    }
    if (session.echecsPin >= essaisPinMax) {
      await _store.effacer();
      return const EtatAuth(Porte.aucuneSession, message: messageSessionEffacee);
    }
    return _etatPin(session, Porte.verrouillee);
  }

  EtatAuth _etatPin(SessionLocale session, Porte porte) => EtatAuth(
        porte,
        numeroMasque: session.numeroMasque,
        pinLongueur: session.pinLongueur,
        essaisPinRestants: essaisPinMax - session.echecsPin,
      );

  Future<SessionLocale> _lireObligatoire() async {
    final session = await _store.lire();
    if (session == null) throw StateError('session locale illisible');
    return session;
  }

  /// Retire le message affiché sur Connexion (nouvelle demande, numéro modifié).
  void effacerMessage() {
    final etat = state.value;
    if (etat != null && etat.porte == Porte.aucuneSession && etat.message != null) {
      state = const AsyncData(EtatAuth(Porte.aucuneSession));
    }
  }

  Future<DemandeCodeResultat> demanderCode(String numero) =>
      ref.read(authApiProvider).demanderCode(numero, CGU_VERSION_PROVISOIRE);

  /// Sur succès, enregistre la session et passe au choix du PIN (appareil)
  /// ou directement à Accueil (web). Lève une erreur si la session ne peut
  /// pas être relue après écriture.
  Future<VerificationResultat> verifierCode(String numero, String code) async {
    final resultat = await ref.read(authApiProvider).verifierCode(numero, code);
    if (resultat is SessionOuverte) {
      await _store.enregistrerSession(
        accessToken: resultat.accessToken,
        refreshToken: resultat.refreshToken,
        numeroMasque: resultat.numeroMasque,
      );
      final session = await _lireObligatoire();
      state = AsyncData(EtatAuth(_estWeb ? Porte.ouverte : Porte.choixPin, numeroMasque: session.numeroMasque));
    } else if (resultat is AppareilBloque) {
      // Rien n'est enregistré : pas de session sur un appareil bloqué.
      state = AsyncData(EtatAuth(Porte.appareilBloque, blocage: resultat));
    }
    return resultat;
  }

  Future<void> definirPin(String pin) async {
    final hache = await ref.read(pinHasherProvider).hacher(pin);
    await _store.enregistrerPin(hache, pin.length);
    state = AsyncData(_etatPin(await _lireObligatoire(), Porte.ouverte));
  }

  /// Vrai si le PIN est correct. L'échec est compté et enregistré AVANT la
  /// vérification (couper l'app pendant le calcul ne rend pas l'essai) ; au
  /// 5e échec, la session locale est effacée.
  Future<bool> deverrouiller(String pin) async {
    final session = await _store.lire();
    if (session == null || !session.pinDefini) {
      await _store.effacer();
      state = const AsyncData(EtatAuth(Porte.aucuneSession, message: messageSessionEffacee));
      return false;
    }
    final echecs = session.echecsPin + 1;
    await _store.enregistrerEchecsPin(echecs);
    if (await ref.read(pinHasherProvider).verifier(pin, session.pin!)) {
      await _store.enregistrerEchecsPin(0);
      state = AsyncData(_etatPin(session.copier(echecsPin: 0), Porte.ouverte));
      return true;
    }
    if (echecs >= essaisPinMax) {
      await _store.effacer();
      state = const AsyncData(EtatAuth(Porte.aucuneSession, message: messageSessionEffacee));
    } else {
      state = AsyncData(_etatPin(session.copier(echecsPin: echecs), Porte.verrouillee));
    }
    return false;
  }

  /// « Code oublié ? » : efface la session locale et ouvre Connexion.
  Future<void> seReconnecter() async {
    await _store.effacer();
    state = const AsyncData(EtatAuth(Porte.aucuneSession));
  }

  /// Fin de l'accès limité (retrait fait, délai dépassé, autre numéro) :
  /// retour à Connexion, avec [message] si fourni.
  void quitterAppareilBloque({String? message}) {
    state = AsyncData(EtatAuth(Porte.aucuneSession, message: message));
  }

  /// « Se déconnecter » (Profil) : efface la session locale (jetons,
  /// empreinte du PIN) et ouvre Connexion. Pas d'appel serveur tant que la
  /// révocation (story 8.2) n'existe pas.
  Future<void> seDeconnecter() async {
    _fauxCompte?.deconnecter();
    await _store.effacer();
    state = const AsyncData(EtatAuth(Porte.aucuneSession));
  }

  void passerEnArrierePlan() {
    if (state.value?.porte == Porte.ouverte) {
      _arrierePlanDepuis ??= ref.read(horlogeMonotoneProvider)();
    }
  }

  void revenirAuPremierPlan() {
    final depuis = _arrierePlanDepuis;
    _arrierePlanDepuis = null;
    final etat = state.value;
    if (depuis == null || etat == null || etat.porte != Porte.ouverte) return;
    if (_estWeb || etat.pinLongueur == null) return;
    if (ref.read(horlogeMonotoneProvider)() - depuis >= DELAI_VERROUILLAGE) {
      state = AsyncData(EtatAuth(
        Porte.verrouillee,
        numeroMasque: etat.numeroMasque,
        pinLongueur: etat.pinLongueur,
        essaisPinRestants: etat.essaisPinRestants,
      ));
    }
  }
}

/// Pas de nouvel essai automatique (Riverpod 3) : un stockage illisible
/// mène tout de suite à Connexion au lieu d'un écran bloqué.
final authProvider = AsyncNotifierProvider<AuthNotifier, EtatAuth>(AuthNotifier.new, retry: (_, _) => null);
