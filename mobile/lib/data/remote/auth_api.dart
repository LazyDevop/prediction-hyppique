import 'dart:math';

/// Version des CGU acceptée, envoyée avec la demande de code. Provisoire
/// jusqu'à la story 7.9 (`CGU_VERSION` côté serveur).
// ignore: constant_identifier_names
const CGU_VERSION_PROVISOIRE = '2026-11-provisoire';

/// Règles du code à usage unique (FR-31), affichées par Connexion.
const otpDureeValidite = Duration(minutes: 5);
const otpEssaisMax = 5;
const otpLongueur = 6;

/// Résultat de `AuthApi.demanderCode`. Même réponse, que le numéro ait un
/// compte ou non (FR-31) : seul le dépassement de quota est distingué (429).
sealed class DemandeCodeResultat {
  const DemandeCodeResultat();
}

class CodeEnvoye extends DemandeCodeResultat {
  const CodeEnvoye();
}

class TropDeDemandes extends DemandeCodeResultat {
  const TropDeDemandes();
}

/// Résultat de `AuthApi.verifierCode`.
sealed class VerificationResultat {
  const VerificationResultat();
}

class SessionOuverte extends VerificationResultat {
  final String accessToken;
  final String refreshToken;

  /// Numéro tel qu'affiché par Déverrouillage, ex. « +237 6 •• •• •• 56 ».
  final String numeroMasque;

  const SessionOuverte({
    required this.accessToken,
    required this.refreshToken,
    required this.numeroMasque,
  });
}

class CodeIncorrect extends VerificationResultat {
  final int essaisRestants;
  const CodeIncorrect(this.essaisRestants);
}

/// `code_expire` côté serveur (ou aucun code en cours pour ce numéro).
class CodeExpire extends VerificationResultat {
  const CodeExpire();
}

/// `trop_d_essais` : le code en cours est invalidé.
class TropDEssais extends VerificationResultat {
  const TropDEssais();
}

/// Port d'authentification par numéro + code à usage unique (story 8.1).
/// Les écrans ne dépendent que de cette interface ; [FauxAuthApi] la
/// remplace tant que le client HTTP réel n'existe pas.
abstract class AuthApi {
  /// [numero] au format E.164 (`+2376XXXXXXXX`).
  Future<DemandeCodeResultat> demanderCode(String numero, String cguVersion);

  Future<VerificationResultat> verifierCode(String numero, String code);
}

/// Masque un numéro E.164 camerounais : `+237677123456` → « +237 6 •• •• •• 56 ».
String masquerNumero(String numero) {
  final local = numero.startsWith('+237') ? numero.substring(4) : numero;
  if (local.length != 9) return '+237 ••';
  return '+237 ${local[0]} •• •• •• ${local.substring(7)}';
}

class _DemandeEnCours {
  final DateTime expireLe;
  int essaisRestants;
  _DemandeEnCours(this.expireLe, this.essaisRestants);
}

/// Faux serveur local de démonstration : le code est toujours
/// [codeDemo], valable [dureeCode], [essaisMax] essais. Aucun envoi réel.
class FauxAuthApi implements AuthApi {
  static const codeDemo = '123456';
  static const essaisMax = otpEssaisMax;
  static const dureeCode = otpDureeValidite;

  /// Quota de demandes par numéro (simule le 429 de la story 7.4).
  static const demandesMax = 5;
  static const fenetreDemandes = Duration(minutes: 10);

  final DateTime Function() _horloge;
  final Map<String, _DemandeEnCours> _demandes = {};
  final Map<String, List<DateTime>> _historique = {};
  final Random _aleatoire = Random.secure();

  /// Dernière version des CGU reçue (contrôlée par les tests).
  String? derniereCguVersion;

  FauxAuthApi({DateTime Function()? horloge}) : _horloge = horloge ?? DateTime.now;

  @override
  Future<DemandeCodeResultat> demanderCode(String numero, String cguVersion) async {
    final maintenant = _horloge();
    final recentes = (_historique[numero] ?? [])
        .where((t) => maintenant.difference(t) < fenetreDemandes)
        .toList();
    if (recentes.length >= demandesMax) {
      _historique[numero] = recentes;
      return const TropDeDemandes();
    }
    _historique[numero] = [...recentes, maintenant];
    derniereCguVersion = cguVersion;
    _demandes[numero] = _DemandeEnCours(maintenant.add(dureeCode), essaisMax);
    return const CodeEnvoye();
  }

  @override
  Future<VerificationResultat> verifierCode(String numero, String code) async {
    final demande = _demandes[numero];
    if (demande == null || !_horloge().isBefore(demande.expireLe)) {
      _demandes.remove(numero);
      return const CodeExpire();
    }
    if (code == codeDemo) {
      _demandes.remove(numero);
      return SessionOuverte(
        accessToken: 'demo-acces-${_jeton()}',
        refreshToken: 'demo-renouvellement-${_jeton()}',
        numeroMasque: masquerNumero(numero),
      );
    }
    demande.essaisRestants--;
    if (demande.essaisRestants <= 0) {
      _demandes.remove(numero);
      return const TropDEssais();
    }
    return CodeIncorrect(demande.essaisRestants);
  }

  String _jeton() =>
      List.generate(16, (_) => _aleatoire.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
