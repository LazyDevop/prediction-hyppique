import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/horse.dart';
import '../providers/horses_provider.dart';
import '../providers/race_provider.dart';
import '../providers/results_provider.dart';
import '../widgets/combo_block.dart';
import '../widgets/option_lists.dart';
import '../widgets/probability_gauge.dart';
import '../widgets/transparency_label.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  String _reco(Horse h, int index) {
    if (h.nbPerfs == 0 && !h.inedit) return 'Données non saisies';
    if (h.value == null) return 'Cote manquante';
    if (h.value! >= 0.15 && h.probabilite >= 0.07) return '🔥 Value forte — jouable';
    if (h.value! > 0.05) return 'Léger avantage';
    if (h.value! > 0) return 'Avantage marginal';
    if (index < 2) return 'Favori du modèle, cote trop courte';
    return 'Pas d\'avantage';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(resultsProvider);
    final race = ref.watch(raceConfigProvider);
    final horses = ref.watch(horsesProvider);

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultats')),
        body: const Center(child: Text('Aucun calcul effectué.')),
      );
    }

    final reels = result.resultats.take(result.nbReels).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final nVirtuels = result.resultats.length - result.nbReels;
    final maxProb = result.resultats
        .map((h) => h.probabilite)
        .fold(0.0, (a, b) => a > b ? a : b);

    final terrainLabel = terrainOptions
        .firstWhere(
          (o) => o.key == race.terrain,
          orElse: () => const MapEntry(1.0, '—'),
        )
        .value;
    final niveauLabel = niveauOptions
        .firstWhere(
          (o) => o.key == race.niveau,
          orElse: () => const MapEntry(1.0, '—'),
        )
        .value;

    return Scaffold(
      appBar: AppBar(title: const Text('Classement & recommandations')),
      body: Column(
        children: [
          // Pinné hors de la zone défilante : le rappel de péremption doit
          // rester visible même une fois l'utilisateur scrollé dans le
          // classement, pas seulement en haut de la ListView (voir revue).
          if (result.isStale)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Ambre, pas rouge : périmé est un état attendu et bénin
                // ("les partants ont changé"), pas une erreur.
                color: Colors.amber.withValues(alpha: 0.15),
                border: const Border(bottom: BorderSide(color: Colors.amber)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Recalcul nécessaire — les partants ont changé depuis ce calcul.',
                      style: TextStyle(color: Colors.amber),
                    ),
                  ),
                  TextButton(
                    // Pas de recalcul possible sur un effectif vide, comme le
                    // FAB "Calculer" de horse_list_screen.dart.
                    onPressed: horses.isEmpty
                        ? null
                        : () => ref.read(resultsProvider.notifier).calculer(),
                    child: const Text('Recalculer'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text(
                        race.hippodrome,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('${race.distance?.toStringAsFixed(0) ?? '—'} m'),
                      Text(terrainLabel),
                      Text(niveauLabel),
                      Text(
                        '${result.resultats.length} partants${nVirtuels > 0 ? ' (dont $nVirtuels non analysés)' : ''}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'PARIS COMBINÉS',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    ComboBlock(
                      title: 'Couplé gagnant',
                      combos: result.combinaisons.couple.desordre,
                    ),
                    ComboBlock(
                      title: 'Couplé ordre',
                      combos: result.combinaisons.couple.ordre,
                    ),
                    ComboBlock(
                      title: 'Couplé placé',
                      combos: result.combinaisons.couplePlace,
                    ),
                    ComboBlock(
                      title: '2 sur 4',
                      combos: result.combinaisons.deuxSurQuatre,
                    ),
                    ComboBlock(
                      title: 'Trio désordre',
                      combos: result.combinaisons.trio.desordre,
                    ),
                    ComboBlock(
                      title: 'Tiercé ordre',
                      combos: result.combinaisons.trio.ordre,
                    ),
                    ComboBlock(
                      title: 'Quarté désordre',
                      combos: result.combinaisons.quarte.desordre,
                    ),
                    ComboBlock(
                      title: 'Quarté ordre',
                      combos: result.combinaisons.quarte.ordre,
                    ),
                    ComboBlock(
                      title: 'Quinté désordre',
                      combos: result.combinaisons.quinte.desordre,
                    ),
                    ComboBlock(
                      title: 'Quinté ordre',
                      combos: result.combinaisons.quinte.ordre,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'CLASSEMENT',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                ...reels.asMap().entries.map((entry) {
                  final i = entry.key;
                  final h = entry.value;
                  final label = transparencyLabel(h, h.nbPerfs);
                  return Card(
                    color: i == 0
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.25)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(child: Text('${i + 1}')),
                              const SizedBox(width: 8),
                              if (h.numPmu != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${h.numPmu}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      h.nom,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${h.age ?? '—'} ans · ${h.poids ?? '—'} kg · ${h.nbPerfs} perfs'
                                      '${label != null ? ' · $label' : ''}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                h.score.toStringAsFixed(3),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ProbabilityGauge(
                            modele: h.probabilite,
                            marche: h.cote != null ? 1 / h.cote! : null,
                            maxProb: maxProb,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '1er ${(h.top1 * 100).toStringAsFixed(1)}% · T2 ${(h.top2 * 100).toStringAsFixed(1)}% · '
                                'T3 ${(h.top3 * 100).toStringAsFixed(1)}% · T4 ${(h.top4 * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cote : ${h.cote?.toStringAsFixed(1) ?? '—'}',
                              ),
                              Text(
                                h.value != null
                                    ? '${h.value! > 0 ? '+' : ''}${(h.value! * 100).toStringAsFixed(1)} %'
                                    : '—',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: h.value == null
                                      ? Colors.grey
                                      : (h.value! > 0
                                            ? Colors.greenAccent
                                            : Colors.redAccent),
                                ),
                              ),
                              Text(
                                h.mise != null && h.mise! > 0.01
                                    ? '${h.mise!.toStringAsFixed(1)} u'
                                    : '—',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _reco(h, i),
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Text(
                  "Outil d'aide à la décision — aucun modèle ne garantit un gain. "
                  'Jouez uniquement ce que vous pouvez vous permettre de perdre.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
