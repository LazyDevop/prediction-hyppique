import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/pin_hash.dart';

/// Session locale de l'appareil : jetons, numéro masqué, empreinte du PIN et
/// compteur d'échecs de déverrouillage. Jamais le PIN ni le code en clair.
class SessionLocale {
  final String accessToken;
  final String refreshToken;
  final String numeroMasque;
  final PinHache? pin;
  final int? pinLongueur;
  final int echecsPin;

  const SessionLocale({
    required this.accessToken,
    required this.refreshToken,
    required this.numeroMasque,
    this.pin,
    this.pinLongueur,
    this.echecsPin = 0,
  });

  bool get pinDefini => pin != null && pinLongueur != null;

  SessionLocale copier({PinHache? pin, int? pinLongueur, int? echecsPin}) => SessionLocale(
        accessToken: accessToken,
        refreshToken: refreshToken,
        numeroMasque: numeroMasque,
        pin: pin ?? this.pin,
        pinLongueur: pinLongueur ?? this.pinLongueur,
        echecsPin: echecsPin ?? this.echecsPin,
      );
}

abstract class SessionStore {
  Future<SessionLocale?> lire();

  /// Ouvre une nouvelle session : remplace toute session (et PIN) précédente.
  Future<void> enregistrerSession({
    required String accessToken,
    required String refreshToken,
    required String numeroMasque,
  });

  /// Enregistre l'empreinte du PIN et remet les échecs à zéro.
  Future<void> enregistrerPin(PinHache pin, int longueur);

  Future<void> enregistrerEchecsPin(int echecs);

  /// Efface la session locale (les données de courses en cache restent).
  Future<void> effacer();
}

/// Implémentation réelle : `flutter_secure_storage` (Keystore / Keychain /
/// DPAPI), jamais `shared_preferences` ni `hippique_cache.db`. Session et
/// PIN sont chacun UNE valeur JSON (écriture atomique par concept).
class SecureSessionStore implements SessionStore {
  static const _cleSession = 'auth.session';
  static const _clePin = 'auth.pin';
  static const _cleEchecs = 'auth.echecs_pin';

  final FlutterSecureStorage _stockage;

  SecureSessionStore([FlutterSecureStorage? stockage]) : _stockage = stockage ?? const FlutterSecureStorage();

  @override
  Future<SessionLocale?> lire() async {
    final brutSession = await _stockage.read(key: _cleSession);
    if (brutSession == null) return null;
    final brutPin = await _stockage.read(key: _clePin);
    final brutEchecs = await _stockage.read(key: _cleEchecs);
    try {
      final s = jsonDecode(brutSession) as Map<String, Object?>;
      PinHache? pin;
      int? longueur;
      if (brutPin != null) {
        final p = jsonDecode(brutPin) as Map<String, Object?>;
        longueur = p['longueur'] as int;
        if (longueur < pinLongueurMin || longueur > pinLongueurMax) {
          throw const FormatException('longueur de PIN hors limites');
        }
        pin = PinHache(
          empreinte: base64Decode(p['empreinte'] as String),
          sel: base64Decode(p['sel'] as String),
        );
      }
      final echecs = brutEchecs == null ? 0 : int.parse(brutEchecs);
      return SessionLocale(
        accessToken: s['accessToken'] as String,
        refreshToken: s['refreshToken'] as String,
        numeroMasque: s['numeroMasque'] as String,
        pin: pin,
        pinLongueur: longueur,
        echecsPin: echecs,
      );
    } on FormatException {
      await effacer();
      return null;
    } on TypeError {
      // Champ manquant ou de mauvais type : valeur corrompue.
      await effacer();
      return null;
    }
  }

  @override
  Future<void> enregistrerSession({
    required String accessToken,
    required String refreshToken,
    required String numeroMasque,
  }) async {
    await effacer();
    await _stockage.write(
      key: _cleSession,
      value: jsonEncode({
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'numeroMasque': numeroMasque,
      }),
    );
  }

  @override
  Future<void> enregistrerPin(PinHache pin, int longueur) async {
    await _stockage.write(
      key: _clePin,
      value: jsonEncode({
        'empreinte': base64Encode(pin.empreinte),
        'sel': base64Encode(pin.sel),
        'longueur': longueur,
      }),
    );
    await _stockage.write(key: _cleEchecs, value: '0');
  }

  @override
  Future<void> enregistrerEchecsPin(int echecs) => _stockage.write(key: _cleEchecs, value: '$echecs');

  @override
  Future<void> effacer() async {
    // PIN d'abord : une session sans PIN est effacée au démarrage.
    await _stockage.delete(key: _clePin);
    await _stockage.delete(key: _cleEchecs);
    await _stockage.delete(key: _cleSession);
  }
}

/// Implémentation en mémoire : tests, et web (aucun jeton persisté par
/// l'app côté navigateur — le cookie de renouvellement viendra avec 8.2).
class MemorySessionStore implements SessionStore {
  SessionLocale? _session;

  MemorySessionStore([this._session]);

  SessionLocale? get session => _session;

  @override
  Future<SessionLocale?> lire() async => _session;

  @override
  Future<void> enregistrerSession({
    required String accessToken,
    required String refreshToken,
    required String numeroMasque,
  }) async {
    _session = SessionLocale(accessToken: accessToken, refreshToken: refreshToken, numeroMasque: numeroMasque);
  }

  @override
  Future<void> enregistrerPin(PinHache pin, int longueur) async {
    _session = _session?.copier(pin: pin, pinLongueur: longueur, echecsPin: 0);
  }

  @override
  Future<void> enregistrerEchecsPin(int echecs) async {
    _session = _session?.copier(echecsPin: echecs);
  }

  @override
  Future<void> effacer() async => _session = null;
}
