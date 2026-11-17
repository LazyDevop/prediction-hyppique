import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/auth/pin_hash.dart';

import 'auth_test_helpers.dart';

void main() {
  // Paramètres réduits pour la vitesse ; l'algorithme reste Argon2id, et le
  // calcul passe par un isolat (chemin par défaut hors web).
  final hasher = PinHasher(parametres: parametresRapides);

  test('hacher puis verifier : bon PIN accepté, mauvais refusé', () async {
    final h = await hasher.hacher('4821');
    expect(h.empreinte, hasLength(32));
    expect(h.sel, hasLength(16));
    expect(await hasher.verifier('4821', h), isTrue);
    expect(await hasher.verifier('4822', h), isFalse);
    expect(await hasher.verifier('48210', h), isFalse);
  });

  test("le sel est aléatoire : deux empreintes du même PIN diffèrent", () async {
    final a = await hasher.hacher('123456');
    final b = await hasher.hacher('123456');
    expect(a.sel, isNot(equals(b.sel)));
    expect(a.empreinte, isNot(equals(b.empreinte)));
  });

  test("l'empreinte ne contient pas le PIN en clair", () async {
    final h = await hasher.hacher('1234');
    expect(String.fromCharCodes(h.empreinte).contains('1234'), isFalse);
  });

  test('PIN hors 4 à 6 chiffres refusé', () async {
    expect(pinValide('123'), isFalse);
    expect(pinValide('1234567'), isFalse);
    expect(pinValide('12a4'), isFalse);
    expect(pinValide('1234'), isTrue);
    expect(pinValide('123456'), isTrue);
    expect(() => hasher.hacher('123'), throwsArgumentError);
  });

  test('egaliteTempsConstant', () {
    expect(egaliteTempsConstant([1, 2, 3], [1, 2, 3]), isTrue);
    expect(egaliteTempsConstant([1, 2, 3], [1, 2, 4]), isFalse);
    expect(egaliteTempsConstant([1, 2], [1, 2, 3]), isFalse);
    expect(egaliteTempsConstant([], []), isTrue);
  });

  test('paramètres par défaut : OWASP (m = 19 MiB, t = 2, p = 1), hors isolat UI', () {
    final defaut = PinHasher();
    expect(defaut.parametres.memoire, 19456);
    expect(defaut.parametres.iterations, 2);
    expect(defaut.parametres.parallelisme, 1);
    expect(defaut.horsIsolatUi, isTrue);
  });

  test('isolat et appel direct donnent la même empreinte', () async {
    final h = await hasher.hacher('4821');
    expect(hasher.horsIsolatUi, isTrue);
    expect(await pinHasherRapide().verifier('4821', h), isTrue);
  });
}
