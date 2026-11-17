import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, kProfileMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/pin_hash.dart';
import '../data/local/session_store.dart';
import '../data/remote/auth_api.dart';

/// Inactivité (temps passé en arrière-plan) au-delà de laquelle l'app se
/// verrouille au retour au premier plan. Provisoire (PRD OQ 14).
// ignore: constant_identifier_names
const DELAI_VERROUILLAGE = Duration(minutes: 5);

/// Échecs de PIN avant effacement de la session locale (FR-32).
const essaisPinMax = 5;

const messageSessionEffacee = 'Session effacée — reconnectez-vous par code SMS';

/// `--dart-define=AUTH_DEMO=true` autorise le faux serveur dans un build release.
const _authDemo = bool.fromEnvironment('AUTH_DEMO');

/// FauxAuthApi seulement en debug/profile ou avec `AUTH_DEMO=true` : un
/// build release sans client réel échoue clairement au lieu d'accepter
/// le code de démonstration.
final authApiProvider = Provider<AuthApi>((ref) {
  if (kDebugMode || kProfileMode || _authDemo) return FauxAuthApi();
  throw StateError('aucune AuthApi réelle — story 8.1 serveur');
});

/// Vrai seulement quand le faux serveur de démonstration est actif.
final modeDemoProvider = Provider<bool>((ref) {
  try {
    return ref.watch(authApiProvider) is FauxAuthApi;
  } on StateError {
    return false;
  }
});

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

enum Porte { aucuneSession, choixPin, verrouillee, ouverte }

class EtatAuth {
  final Porte porte;
  final String? numeroMasque;
  final int? pinLongueur;
  final int essaisPinRestants;

  /// Message à afficher sur Connexion (ex. session effacée).
  final String? message;

  const EtatAuth(
    this.porte, {
    this.numeroMasque,
    this.pinLongueur,
    this.essaisPinRestants = essaisPinMax,
    this.message,
  });
}

class AuthNotifier extends AsyncNotifier<EtatAuth> {
  Duration? _arrierePlanDepuis;

  SessionStore get _store => ref.read(sessionStoreProvider);
  bool get _estWeb => ref.read(estWebProvider);

  @override
  Future<EtatAuth> build() async {
    final session = await _store.lire();
    if (session == null) return const EtatAuth(Porte.aucuneSession);
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
