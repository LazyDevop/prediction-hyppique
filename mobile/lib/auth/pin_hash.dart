import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Empreinte Argon2id d'un code PIN et son sel. Seule cette empreinte est
/// conservée (stockage sécurisé), jamais le PIN, et rien n'est envoyé.
class PinHache {
  final List<int> empreinte;
  final List<int> sel;
  const PinHache({required this.empreinte, required this.sel});
}

/// Longueurs admises (FR-32).
const pinLongueurMin = 4;
const pinLongueurMax = 6;

bool pinValide(String pin) =>
    pin.length >= pinLongueurMin && pin.length <= pinLongueurMax && RegExp(r'^\d+$').hasMatch(pin);

/// Paramètres Argon2id, transmissibles à un isolat.
class ParametresArgon2 {
  final int memoire; // en Kio
  final int iterations;
  final int parallelisme;
  const ParametresArgon2({required this.memoire, required this.iterations, required this.parallelisme});

  /// Recommandation OWASP : m = 19 MiB, t = 2, p = 1.
  static const owasp = ParametresArgon2(memoire: 19456, iterations: 2, parallelisme: 1);
}

const _longueurEmpreinte = 32;

/// Calcul Argon2id ; fonction de premier niveau pour pouvoir tourner dans
/// un isolat (`Isolate.run`).
Future<List<int>> _deriver(ParametresArgon2 p, List<int> pin, List<int> sel) async {
  final algo = Argon2id(
    parallelism: p.parallelisme,
    memory: p.memoire,
    iterations: p.iterations,
    hashLength: _longueurEmpreinte,
  );
  final cle = await algo.deriveKey(secretKey: SecretKey(pin), nonce: sel);
  return cle.extractBytes();
}

/// Hachage / vérification Argon2id du PIN (sel aléatoire de 16 octets,
/// comparaison en temps constant). Le calcul tourne hors de l'isolat UI
/// (sauf sur le web, où les isolats ne sont pas disponibles).
class PinHasher {
  final ParametresArgon2 parametres;

  /// Faux seulement dans les tests widget (le temps y est simulé et un
  /// isolat ne répondrait jamais).
  final bool horsIsolatUi;
  final Random _aleatoire;

  PinHasher({this.parametres = ParametresArgon2.owasp, bool? horsIsolatUi, Random? aleatoire})
      : horsIsolatUi = horsIsolatUi ?? !kIsWeb,
        _aleatoire = aleatoire ?? Random.secure();

  Future<PinHache> hacher(String pin) async {
    if (!pinValide(pin)) throw ArgumentError('PIN invalide');
    final sel = List<int>.generate(16, (_) => _aleatoire.nextInt(256));
    return PinHache(empreinte: await _calculer(pin, sel), sel: sel);
  }

  Future<bool> verifier(String pin, PinHache attendu) async {
    final calculee = await _calculer(pin, attendu.sel);
    return egaliteTempsConstant(calculee, attendu.empreinte);
  }

  Future<List<int>> _calculer(String pin, List<int> sel) {
    final p = parametres;
    final octets = utf8.encode(pin);
    if (!horsIsolatUi) return _deriver(p, octets, sel);
    return Isolate.run(() => _deriver(p, octets, sel));
  }
}

/// Compare deux suites d'octets sans court-circuit sur la première différence.
bool egaliteTempsConstant(List<int> a, List<int> b) {
  var diff = a.length ^ b.length;
  final n = min(a.length, b.length);
  for (var i = 0; i < n; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
