import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/constants.dart';
import '../models/course_summary.dart';
import '../models/race_config.dart';
import '../providers/api_provider.dart';
import '../providers/horses_provider.dart';
import '../providers/programme_provider.dart';
import '../providers/race_provider.dart';
import 'race_config_screen.dart';

/// Programme du jour (section 7.1 du document mobile). Sélectionner une
/// course préremplit la config course + les partants depuis le backend,
/// puis enchaîne sur l'écran de config pour ajuster terrain/niveau (que le
/// backend ne fournit pas encore — section 10 du document backend) avant de
/// continuer vers les partants et le calcul, exactement comme en saisie
/// manuelle.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _date = DateTime.now();
  bool _loadingPartants = false;
  // Le chargement du programme est déclenché explicitement par un bouton,
  // pas automatiquement à l'ouverture de l'écran (section 6.2 du document
  // mobile : "au chargement de l'app OU sur action explicite 'rafraîchir'").
  bool _loaded = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _selectCourse(CourseSummary course) async {
    setState(() => _loadingPartants = true);
    try {
      final horses = await ref.read(courseRepositoryProvider).partants(course.id);

      ref.read(horsesProvider.notifier).clear();
      for (final horse in horses) {
        ref.read(horsesProvider.notifier).add(horse);
      }
      ref.read(raceConfigProvider.notifier).update(RaceConfig(
            hippodrome: course.hippodrome,
            distance: course.distance,
            terrain: terrainCoefficient(course.terrain),
            niveau: null,
            nbPartantsCourse: course.nbPartants,
          ));

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RaceConfigScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec du chargement des partants : $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingPartants = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_date.day.toString().padLeft(2, '0')}/'
        '${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    final programmeAsync = _loaded ? ref.watch(programmeProvider(_date)) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Programme du jour'),
        actions: [IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateLabel, style: Theme.of(context).textTheme.titleMedium),
                if (_loaded)
                  TextButton.icon(
                    onPressed: () => ref.invalidate(programmeProvider(_date)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rafraîchir'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: programmeAsync == null
                ? Center(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _loaded = true),
                      icon: const Icon(Icons.download),
                      label: const Text('Charger le programme'),
                    ),
                  )
                : programmeAsync.when(
                    data: (courses) {
                      if (courses.isEmpty) {
                        return const Center(child: Text('Aucune course en base pour cette date.'));
                      }
                      final parReunion = <String, List<CourseSummary>>{};
                      for (final c in courses) {
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
                            initiallyExpanded: parReunion.length == 1,
                            children: entry.value.map((c) {
                              final heure = c.heureDepart?.toLocal();
                              final heureLabel = heure == null
                                  ? '—:—'
                                  : '${heure.hour.toString().padLeft(2, '0')}:'
                                      '${heure.minute.toString().padLeft(2, '0')}';
                              return ListTile(
                                leading: SizedBox(
                                  width: 44,
                                  child: Text(heureLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                title: Text('${c.discipline} · ${c.distance?.toStringAsFixed(0) ?? '—'} m'),
                                subtitle: Text(
                                  '${c.nbPartants ?? '—'} partants'
                                  '${c.finalisee ? ' · Résultat connu' : ''}',
                                ),
                                trailing: _loadingPartants
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.chevron_right),
                                onTap: _loadingPartants ? null : () => _selectCourse(c),
                              );
                            }).toList(),
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
                              onPressed: () => ref.invalidate(programmeProvider(_date)),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RaceConfigScreen())),
        icon: const Icon(Icons.edit),
        label: const Text('Saisie manuelle'),
      ),
    );
  }
}
