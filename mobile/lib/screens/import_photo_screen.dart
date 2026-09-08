import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../data/remote/api_client.dart';
import '../models/programme_extrait.dart';
import '../providers/api_provider.dart';

/// Fichier choisi par l'utilisateur (photo ou PDF), normalisé pour l'appel
/// à `/extraction/programme` indépendamment du plugin qui l'a produit
/// (`image_picker` vs `file_picker`). Point d'injection central pour les
/// tests widget (Design Notes de spec-4-3) : jamais de mock des canaux de
/// plateforme, un `PickedUpload` déjà construit suffit.
class PickedUpload {
  final Uint8List bytes;
  final String filename;
  final String contentType;

  const PickedUpload({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });
}

enum _ImportSource { gallery, camera, pdf }

/// Import photo/PDF d'un programme complet — section 7.5 du document
/// mobile, `POST /extraction/programme` (Story 4.2). Portée de cette story :
/// choisir un fichier, appeler le backend, AFFICHER le résultat marqué
/// "à vérifier" (bandeau "✨ Rempli par l'IA", repris du prototype React).
/// Appliquer les champs confirmés dans `raceConfigProvider`/`horsesProvider`
/// est explicitement hors scope (voir Intent de spec-4-3 et
/// `deferred-work.md`) : ce screen ne doit jamais écrire dans ces
/// providers, seulement les lire serait déjà hors scope — il ne fait
/// qu'afficher la réponse brute de l'API.
class ImportPhotoScreen extends ConsumerStatefulWidget {
  /// Permet d'injecter un faux `ExtractionApi` en test. Hors test,
  /// `ref.read(apiClientProvider)` fournit l'implémentation réelle (même
  /// convention que `CoursesApi` ailleurs dans ce repo).
  final ExtractionApi? api;

  /// Permet d'injecter directement le fichier "choisi" en test, en
  /// contournant `image_picker`/`file_picker` (canaux de plateforme non
  /// testables ici). `null` renvoyé par ce callback simule une annulation
  /// du picker par l'utilisateur.
  final Future<PickedUpload?> Function()? pickFile;

  const ImportPhotoScreen({super.key, this.api, this.pickFile});

  @override
  ConsumerState<ImportPhotoScreen> createState() => _ImportPhotoScreenState();
}

class _ImportPhotoScreenState extends ConsumerState<ImportPhotoScreen> {
  bool _loading = false;
  String? _error;
  ProgrammeExtrait? _result;

  ExtractionApi _api() => widget.api ?? ref.read(apiClientProvider);

  Future<PickedUpload?> _pickReal(_ImportSource source) async {
    switch (source) {
      case _ImportSource.gallery:
      case _ImportSource.camera:
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: source == _ImportSource.camera ? ImageSource.camera : ImageSource.gallery,
        );
        if (xfile == null) return null;
        final bytes = await xfile.readAsBytes();
        return PickedUpload(bytes: bytes, filename: xfile.name, contentType: xfile.mimeType ?? 'image/jpeg');
      case _ImportSource.pdf:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return null;
        final picked = result.files.single;
        final bytes = picked.bytes;
        if (bytes == null) return null;
        return PickedUpload(bytes: bytes, filename: picked.name, contentType: 'application/pdf');
    }
  }

  Future<void> _pickAndExtract(_ImportSource source) async {
    // `_loading` passe à true ICI, avant même d'ouvrir le picker natif (pas
    // seulement pendant l'upload) : sinon les 3 boutons restent actifs
    // pendant toute la durée où la feuille caméra/galerie est ouverte, et un
    // second appui pendant ce délai déclenche une extraction concurrente qui
    // course avec la première pour écraser _result/_error (revue de code,
    // blind-hunter + edge-case-hunter).
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    PickedUpload? upload;
    try {
      upload = widget.pickFile != null ? await widget.pickFile!() : await _pickReal(source);
    } catch (_) {
      // Un échec du picker natif (permission refusée, plugin en erreur, I/O)
      // ne doit jamais laisser le bouton "ne rien faire" silencieusement -
      // revue de code, blind-hunter.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Impossible d'accéder à la caméra/galerie/fichier. Réessayez.";
      });
      return;
    }

    // Annulation du picker (I/O matrix "User cancels the picker") : l'écran
    // revient à son état idle, aucune requête n'est faite.
    if (upload == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    await _handlePicked(upload);
  }

  /// Handler post-pick, séparé de `_pickAndExtract` pour être directement
  /// invocable en test (Design Notes de spec-4-3) : pilote l'appel réseau
  /// et les états error/success à partir d'un `PickedUpload` déjà résolu.
  /// `_loading` est déjà à true (posé par `_pickAndExtract` avant le pick) —
  /// ne le repositionne pas ici pour ne pas rouvrir une fenêtre où les
  /// boutons seraient réactivés entre la fin du pick et le début de l'appel
  /// réseau.
  Future<void> _handlePicked(PickedUpload upload) async {
    if (!mounted) return;
    try {
      final extrait = await _api().extractProgramme(
        bytes: upload.bytes,
        filename: upload.filename,
        contentType: upload.contentType,
      );
      if (!mounted) return;
      setState(() => _result = extrait);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageForStatus(e.response?.statusCode));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Échec de l'extraction, réessayez.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Mapping des 4 codes d'erreur documentés par le backend (Story 4.2,
  // backend/app/api/routes_analyse.py::_run_extraction) vers des messages
  // français distincts (I/O matrix de spec-4-3).
  String _messageForStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Type ou fichier invalide.';
      case 413:
        return 'Fichier trop volumineux.';
      case 429:
        return 'Budget quotidien épuisé, réessayez plus tard.';
      case 502:
        return "Échec de l'extraction, réessayez.";
      default:
        return "Échec de l'extraction, réessayez.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import photo / PDF — programme')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Photographiez ou importez le programme complet d'une course "
            "(image ou PDF) : hippodrome, distance, terrain, niveau et "
            "partants seront préremplis automatiquement, à vérifier.",
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : () => _pickAndExtract(_ImportSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galerie'),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : () => _pickAndExtract(_ImportSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Appareil photo'),
              ),
              ElevatedButton.icon(
                onPressed: _loading ? null : () => _pickAndExtract(_ImportSource.pdf),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Vous pouvez réessayer avec un autre fichier, ou continuer en saisie manuelle.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
          if (_result != null) _buildResult(context, _result!),
        ],
      ),
    );
  }

  /// Une performance en musique compacte : le rang si connu, sinon le code
  /// incident brut (ex. "D" pour disqualifié), jamais les deux à la fois —
  /// même convention que les prompts d'extraction (docs/analyse_hippique_ia.jsx).
  String _describePerf(PerfProgrammeExtrait perf) {
    if (perf.rank != null) return '${perf.rank}';
    if (perf.incident.isNotEmpty) return perf.incident;
    return '?';
  }

  Widget _buildResult(BuildContext context, ProgrammeExtrait extrait) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: Border.all(color: Colors.amber),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            '✨ Rempli par l\'IA — vérifiez les champs',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),
        Text('Course cible', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('Hippodrome : ${extrait.hippo ?? '—'}'),
        Text('Distance : ${extrait.dist?.toStringAsFixed(0) ?? '—'} m'),
        Text('Terrain : ${extrait.terr?.toString() ?? '—'}'),
        Text('Niveau : ${extrait.niveau?.toString() ?? '—'}'),
        Text('Partants : ${extrait.partants?.toString() ?? '—'}'),
        const SizedBox(height: 16),
        Text('Partants extraits (${extrait.horses.length})', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final horse in extrait.horses)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${horse.num != null ? 'N°${horse.num} · ' : ''}${horse.name ?? 'Nom inconnu'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Âge : ${horse.age?.toString() ?? '—'} · '
                      'Poids : ${horse.poids?.toString() ?? '—'} · '
                      'Cote : ${horse.cote?.toString() ?? '—'}'),
                  if (horse.perfs.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    // "vérifiez les champs" (bandeau IA) doit inclure les
                    // performances extraites, pas seulement l'identité du
                    // cheval - sinon rien ne permet à l'utilisateur de les
                    // vérifier avant de s'en servir (revue de code,
                    // edge-case-hunter).
                    Text(
                      'Musique : ${horse.perfs.map(_describePerf).join(' · ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
