// Story 7.8 : l'en-tête d'accès restreint n'est posé que si un secret est
// fourni (build de dev via --dart-define). Aucun appel réseau ici.

import 'package:flutter_test/flutter_test.dart';

import 'package:prediction_hippique/data/remote/api_client.dart';

void main() {
  test('avec un secret, Authorization: Bearer est posé sur les en-têtes de base', () {
    final client = ApiClient(baseUrl: 'http://localhost:8000', accesRestreintSecret: 'secret-de-test');

    expect(client.enTetesDeBase['Authorization'], 'Bearer secret-de-test');
  });

  test('sans secret, aucun en-tête Authorization', () {
    final client = ApiClient(baseUrl: 'http://localhost:8000', accesRestreintSecret: '');

    expect(client.enTetesDeBase.containsKey('Authorization'), isFalse);
  });

  test('en release, le secret est ignoré : aucun en-tête Authorization', () {
    final client = ApiClient(
      baseUrl: 'http://localhost:8000',
      accesRestreintSecret: 'secret-de-test',
      releaseMode: true,
    );

    expect(client.enTetesDeBase.containsKey('Authorization'), isFalse);
  });

  test('par défaut (aucun --dart-define sous flutter test), aucun en-tête Authorization', () {
    final client = ApiClient(baseUrl: 'http://localhost:8000');

    expect(client.enTetesDeBase.containsKey('Authorization'), isFalse);
  });
}
