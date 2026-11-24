import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:prediction_hippique/auth/pin_hash.dart';
import 'package:prediction_hippique/data/local/session_store.dart';
import 'package:prediction_hippique/data/remote/auth_api.dart';
import 'package:prediction_hippique/data/remote/compte_api.dart';
import 'package:prediction_hippique/data/remote/offres_api.dart';
import 'package:prediction_hippique/providers/auth_provider.dart';

/// Argon2id à paramètres réduits : même code, rapide.
const parametresRapides = ParametresArgon2(memoire: 64, iterations: 1, parallelisme: 1);

/// Dans l'isolat UI : les tests widget simulent le temps, un isolat n'y
/// répondrait jamais.
PinHasher pinHasherRapide() => PinHasher(parametres: parametresRapides, horsIsolatUi: false);

/// Horloge murale (FauxAuthApi) et monotone (verrouillage) pilotées ensemble.
class Horloge {
  static final _origine = DateTime(2026, 11, 17, 10);
  DateTime maintenant = _origine;
  DateTime call() => maintenant;
  Duration monotone() => maintenant.difference(_origine);
  void avancer(Duration d) => maintenant = maintenant.add(d);
}

/// Session déjà ouverte, PIN défini ([pin]) si fourni.
Future<MemorySessionStore> storeAvecSession({String? pin, int echecs = 0}) async {
  final store = MemorySessionStore();
  await store.enregistrerSession(accessToken: 'a', refreshToken: 'r', numeroMasque: '+237 6 •• •• •• 56');
  if (pin != null) {
    await store.enregistrerPin(await pinHasherRapide().hacher(pin), pin.length);
    if (echecs > 0) await store.enregistrerEchecsPin(echecs);
  }
  return store;
}

/// Sans [api] ni [compte] : FauxAuthApi et FauxCompteApi partagent l'état
/// (limite d'appareils du numéro 699999999), comme dans l'app. Sans
/// [offres] : FauxOffresApi lié au faux compte (palier après paiement).
List<Override> overridesAuth({
  required SessionStore store,
  AuthApi? api,
  CompteApi? compte,
  OffresApi? offres,
  PinHasher? hasher,
  bool web = false,
  Horloge? horloge,
  bool appairage = false,
}) {
  final faux = compte ?? FauxCompteApi(horloge: horloge?.call, web: web);
  return [
    sessionStoreProvider.overrideWithValue(store),
    compteApiProvider.overrideWithValue(faux),
    offresApiProvider.overrideWithValue(
      offres ?? FauxOffresApi(compte: faux is FauxCompteApi ? faux : null, horloge: horloge?.call),
    ),
    authApiProvider.overrideWithValue(
      api ?? FauxAuthApi(horloge: horloge?.call, rattachement: faux is FauxCompteApi ? faux : null),
    ),
    pinHasherProvider.overrideWithValue(hasher ?? pinHasherRapide()),
    estWebProvider.overrideWithValue(web),
    // Appairage par QR code (story 8.7) : désactivé par défaut, ces tests
    // visent la Connexion par code SMS ; test/web/ l'active.
    appairageDisponibleProvider.overrideWithValue(appairage),
    if (horloge != null) horlogeMonotoneProvider.overrideWithValue(horloge.monotone),
    if (horloge != null) horlogeMuraleProvider.overrideWithValue(horloge.call),
  ];
}

ProviderContainer conteneur({
  required SessionStore store,
  AuthApi? api,
  CompteApi? compte,
  PinHasher? hasher,
  bool web = false,
  Horloge? horloge,
}) =>
    ProviderContainer(
      overrides: overridesAuth(store: store, api: api, compte: compte, hasher: hasher, web: web, horloge: horloge),
    );

/// Stockage dont la lecture échoue toujours.
class StoreEnPanne extends MemorySessionStore {
  @override
  Future<SessionLocale?> lire() async => throw Exception('stockage sécurisé indisponible');
}

/// Hasher dont la vérification échoue (exception), pour tester l'ordre
/// « échec compté avant la vérification ».
class HasherEnPanne implements PinHasher {
  final _vrai = pinHasherRapide();

  @override
  ParametresArgon2 get parametres => parametresRapides;

  @override
  bool get horsIsolatUi => false;

  @override
  Future<PinHache> hacher(String pin) => _vrai.hacher(pin);

  @override
  Future<bool> verifier(String pin, PinHache attendu) async => throw Exception('calcul interrompu');
}

/// AuthApi scriptée : renvoie [demandes] dans l'ordre, puis le dernier.
class ApiScriptee implements AuthApi {
  final List<DemandeCodeResultat> demandes;
  int appelsDemande = 0;
  ApiScriptee(this.demandes);

  @override
  Future<DemandeCodeResultat> demanderCode(String numero, String cguVersion) async {
    final r = demandes[appelsDemande.clamp(0, demandes.length - 1)];
    appelsDemande++;
    return r;
  }

  @override
  Future<VerificationResultat> verifierCode(String numero, String code) async => const CodeIncorrect(4);
}
