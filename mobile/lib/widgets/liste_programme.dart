import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course_summary.dart';
import '../repository/course_repository.dart';
import 'auth_styles.dart';
import 'contour_focus.dart';

/// Programme du jour par réunion (Accueil du téléphone, colonne de gauche
/// de la web app). [courseOuverteId] marque la course ouverte dans la
/// colonne de droite par le texte « Ouverte » (jamais par l'or) ;
/// [contourFocus] pose le `focus-indicator` sur les lignes (web).
class ListeProgramme extends StatelessWidget {
  final AsyncValue<ProgrammeResult> programme;
  final bool chargement;
  final bool rafraichissement;
  final VoidCallback onRafraichir;
  final VoidCallback onReessayer;
  final ValueChanged<CourseSummary> onSelect;
  final int? courseOuverteId;
  final bool contourFocus;

  const ListeProgramme({
    super.key,
    required this.programme,
    required this.chargement,
    required this.rafraichissement,
    required this.onRafraichir,
    required this.onReessayer,
    required this.onSelect,
    this.courseOuverteId,
    this.contourFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return programme.when(
      data: (result) {
        if (result.courses.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Aucune course chargée — rafraîchissez ou ajoutez une course manuellement.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: rafraichissement ? null : onRafraichir,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rafraîchir'),
                  ),
                ],
              ),
            ),
          );
        }
        final parReunion = <String, List<CourseSummary>>{};
        for (final c in result.courses) {
          parReunion.putIfAbsent(c.hippodrome, () => []).add(c);
        }
        for (final list in parReunion.values) {
          list.sort((a, b) {
            if (a.heureDepart == null || b.heureDepart == null) return 0;
            return a.heureDepart!.compareTo(b.heureDepart!);
          });
        }
        return ListView(
          children: parReunion.entries.map((entry) {
            return ExpansionTile(
              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
              initiallyExpanded: parReunion.length == 1 || entry.value.any((c) => c.id == courseOuverteId),
              children: entry.value.map(_ligne).toList(),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text('Connexion au backend impossible.\n$err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onReessayer,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligne(CourseSummary c) {
    final heure = c.heureDepart?.toLocal();
    final heureLabel = heure == null
        ? '—:—'
        : '${heure.hour.toString().padLeft(2, '0')}:'
            '${heure.minute.toString().padLeft(2, '0')}';
    final ouverte = courseOuverteId != null && c.id == courseOuverteId;
    final Widget tuile = ListTile(
      key: ValueKey('course-${c.id}'),
      leading: SizedBox(
        width: 44,
        child: Text(heureLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text('${c.discipline} · ${c.distance?.toStringAsFixed(0) ?? '—'} m'),
      subtitle: Text(
        '${c.nbPartants ?? '—'} partants'
        '${c.finalisee ? ' · Résultat connu' : ''}',
      ),
      trailing: chargement
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : ouverte
              ? const Text('Ouverte', style: TextStyle(fontWeight: FontWeight.w700, color: JetonsAuth.text))
              : const Icon(Icons.chevron_right),
      onTap: chargement ? null : () => onSelect(c),
    );
    if (!contourFocus) return tuile; // téléphone : arbre inchangé
    // Arbre stable (le focus clavier reste sur la ligne quand elle s'ouvre).
    return ContourFocus(rayon: 4, interieur: true, child: Semantics(selected: ouverte, child: tuile));
  }
}
