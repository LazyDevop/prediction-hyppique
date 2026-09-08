import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prediction_hippique/data/remote/api_client.dart';
import 'package:prediction_hippique/models/programme_extrait.dart';
import 'package:prediction_hippique/screens/import_photo_screen.dart';

/// Faux `ExtractionApi` (jamais de mock Dio, convention établie par
/// `CoursesApi`/spec-3-5) — piloté par un callback pour simuler un succès ou
/// n'importe laquelle des 4 erreurs documentées.
class _FakeExtractionApi implements ExtractionApi {
  final Future<ProgrammeExtrait> Function() onCall;
  int callCount = 0;

  _FakeExtractionApi(this.onCall);

  @override
  Future<ProgrammeExtrait> extractProgramme({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) {
    callCount++;
    return onCall();
  }
}

DioException _errorWithStatus(int statusCode) {
  final options = RequestOptions(path: '/extraction/programme');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: statusCode),
  );
}

Future<PickedUpload?> _samplePickedUpload() async => PickedUpload(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'programme.jpg',
      contentType: 'image/jpeg',
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ExtractionApi api,
  Future<PickedUpload?> Function()? pickFile,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: ImportPhotoScreen(api: api, pickFile: pickFile),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ImportPhotoScreen — I/O matrix (spec-4-3)', () {
    testWidgets('successful extraction renders the AI banner and every field read-only', (tester) async {
      final extrait = ProgrammeExtrait.fromJson({
        'hippo': 'Vincennes',
        'dist': 2100.0,
        'terr': 1.0,
        'niveau': 3.0,
        'partants': 2,
        'horses': [
          {'num': 3, 'name': 'Bolide', 'age': 5, 'poids': 58.5, 'cote': 6.5, 'perfs': []},
          {'num': 7, 'name': 'Éclair', 'age': 4, 'poids': 56.0, 'cote': 3.2, 'perfs': []},
        ],
      });
      final api = _FakeExtractionApi(() async => extrait);

      await _pumpScreen(tester, api: api, pickFile: _samplePickedUpload);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(api.callCount, 1);
      expect(find.textContaining('Rempli par l\'IA'), findsOneWidget);
      expect(find.textContaining('Vincennes'), findsOneWidget);
      expect(find.textContaining('2100'), findsOneWidget);
      expect(find.textContaining('Bolide'), findsOneWidget);
      expect(find.textContaining('Éclair'), findsOneWidget);
    });

    testWidgets('backend 400 (invalid type/file) shows a clear French message, no banner', (tester) async {
      final api = _FakeExtractionApi(() async => throw _errorWithStatus(400));

      await _pumpScreen(tester, api: api, pickFile: _samplePickedUpload);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rempli par l\'IA'), findsNothing);
      expect(find.textContaining('Type ou fichier invalide'), findsOneWidget);

      // L'utilisateur peut réessayer avec un autre fichier (I/O matrix).
      expect(find.widgetWithText(ElevatedButton, 'Galerie'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Galerie'));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('backend 429 shows the budget-exhausted message', (tester) async {
      final api = _FakeExtractionApi(() async => throw _errorWithStatus(429));

      await _pumpScreen(tester, api: api, pickFile: _samplePickedUpload);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rempli par l\'IA'), findsNothing);
      expect(find.textContaining('Budget quotidien épuisé, réessayez plus tard'), findsOneWidget);
    });

    testWidgets('backend 502 shows the extraction-failure message', (tester) async {
      final api = _FakeExtractionApi(() async => throw _errorWithStatus(502));

      await _pumpScreen(tester, api: api, pickFile: _samplePickedUpload);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rempli par l\'IA'), findsNothing);
      expect(find.textContaining("Échec de l'extraction, réessayez"), findsOneWidget);
    });

    testWidgets('user cancels the picker: screen stays idle, no request is made', (tester) async {
      final api = _FakeExtractionApi(() async => throw StateError('extractProgramme must not be called'));

      await _pumpScreen(tester, api: api, pickFile: () async => null);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(api.callCount, 0);
      expect(find.textContaining('Rempli par l\'IA'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Échec'), findsNothing);
      // Toujours en état idle : les 3 boutons de sélection restent actifs.
      expect(find.widgetWithText(ElevatedButton, 'Galerie'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Appareil photo'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'PDF'), findsOneWidget);
    });

    testWidgets('backend 413 (file too large) shows the size-limit message', (tester) async {
      final api = _FakeExtractionApi(() async => throw _errorWithStatus(413));

      await _pumpScreen(tester, api: api, pickFile: _samplePickedUpload);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rempli par l\'IA'), findsNothing);
      expect(find.textContaining('Fichier trop volumineux'), findsOneWidget);
    });

    testWidgets('buttons stay disabled for the whole picker phase, not just during upload', (tester) async {
      // blind-hunter + edge-case-hunter (revue de code) : `_loading` doit
      // passer à true AVANT même d'ouvrir le picker natif, pas seulement une
      // fois le fichier obtenu - sinon un second appui pendant que la feuille
      // caméra/galerie est ouverte déclenche une extraction concurrente.
      final pickerGate = Completer<PickedUpload?>();
      final api = _FakeExtractionApi(() async => throw StateError('ne doit jamais etre appele ici'));

      await _pumpScreen(tester, api: api, pickFile: () => pickerGate.future);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pump(); // laisse _pickAndExtract poser _loading=true et ouvrir "le picker"

      final bouton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Galerie'));
      expect(bouton.onPressed, isNull, reason: 'doit être désactivé pendant que le picker est ouvert, pas seulement pendant l\'upload');

      pickerGate.complete(null); // l'utilisateur annule, pour ne pas laisser un Future en attente
      await tester.pumpAndSettle();
    });

    testWidgets('un échec du picker natif affiche un message clair, pas un échec silencieux', (tester) async {
      final api = _FakeExtractionApi(() async => throw StateError('ne doit jamais etre appele ici'));

      await _pumpScreen(tester, api: api, pickFile: () async => throw Exception('permission refusée'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(api.callCount, 0);
      expect(find.textContaining("Impossible d'accéder"), findsOneWidget);
      final bouton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Galerie'));
      expect(bouton.onPressed, isNotNull, reason: 'l\'utilisateur doit pouvoir réessayer');
    });

    testWidgets('une extraction réussie efface un message d\'erreur précédent', (tester) async {
      var premierAppel = true;
      final extrait = ProgrammeExtrait.fromJson({
        'hippo': 'Auteuil', 'dist': 1800.0, 'terr': 1.0, 'niveau': 2.0, 'partants': 1,
        'horses': [
          {'num': 1, 'name': 'Second Essai', 'age': 6, 'poids': 60.0, 'cote': 4.0, 'perfs': []},
        ],
      });
      final api = _FakeExtractionApi(() async {
        if (premierAppel) {
          premierAppel = false;
          throw _errorWithStatus(502);
        }
        return extrait;
      });

      await _pumpScreen(tester, api: api, pickFile: _samplePickedUpload);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Échec de l'extraction"), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Échec de l'extraction"), findsNothing);
      expect(find.textContaining('Rempli par l\'IA'), findsOneWidget);
      expect(find.textContaining('Second Essai'), findsOneWidget);
    });

    testWidgets('une nouvelle extraction en échec efface le résultat précédent', (tester) async {
      var premierAppel = true;
      final extrait = ProgrammeExtrait.fromJson({
        'hippo': 'Auteuil', 'dist': 1800.0, 'terr': 1.0, 'niveau': 2.0, 'partants': 1,
        'horses': [
          {'num': 1, 'name': 'Premier Essai', 'age': 6, 'poids': 60.0, 'cote': 4.0, 'perfs': []},
        ],
      });
      final api = _FakeExtractionApi(() async {
        if (premierAppel) {
          premierAppel = false;
          return extrait;
        }
        throw _errorWithStatus(502);
      });

      await _pumpScreen(tester, api: api, pickFile: _samplePickedUpload);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Premier Essai'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rempli par l\'IA'), findsNothing);
      expect(find.textContaining('Premier Essai'), findsNothing);
      expect(find.textContaining("Échec de l'extraction"), findsOneWidget);
    });

    testWidgets('les performances extraites (musique) sont affichées, pas seulement l\'identité du cheval', (tester) async {
      // edge-case-hunter (revue de code) : perfs était parsé par le modèle
      // mais jamais rendu par l'écran.
      final extrait = ProgrammeExtrait.fromJson({
        'hippo': 'Vincennes', 'dist': 2100.0, 'terr': 1.0, 'niveau': 3.0, 'partants': 1,
        'horses': [
          {
            'num': 3, 'name': 'Bolide', 'age': 5, 'poids': 58.5, 'cote': 6.5,
            'perfs': [
              {'rank': 1, 'incident': ''},
              {'rank': null, 'incident': 'D'},
            ],
          },
        ],
      });
      final api = _FakeExtractionApi(() async => extrait);

      await _pumpScreen(tester, api: api, pickFile: _samplePickedUpload);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Galerie'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Musique'), findsOneWidget);
      expect(find.textContaining('1 · D'), findsOneWidget);
    });
  });
}
