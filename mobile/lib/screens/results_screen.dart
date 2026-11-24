import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/acces_paliers.dart';
import '../models/horse.dart';
import '../providers/horses_provider.dart';
import '../providers/palier_provider.dart';
import '../providers/race_provider.dart';
import '../providers/results_provider.dart';
import '../widgets/combo_block.dart';
import '../widgets/followed_race.dart';
import '../widgets/locked_feature.dart';
import '../widgets/option_lists.dart';
import '../widgets/probability_gauge.dart';
import '../widgets/transparency_label.dart';

const messagePronosticIndisponible = 'Pronostic du matin indisponible';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  // Lu une fois : le palier peut monter écran ouvert, le résultat est alors
  // calculé sans action (verrou remplacé en place).
  late final ResultsNotifier _resultats;

  @override
  void initState() {
    super.initState();
    _resultats = ref.read(resultsProvider.notifier)..ecranOuvert();
  }

  @override
  void dispose() {
    _resultats.ecranFerme();
    super.dispose();
  }

  /// Consultation (palier Gratuit) : le pronostic publié n'existe pas encore
  /// dans l'app (Epic 11) ; aucun chiffre inventé.
  Widget _consultation() => Scaffold(
    appBar: AppBar(title: const Text('Résultats'), actions: const [EtoileSuiviCourse()]),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        AvisPalier(),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(messagePronosticIndisponible, textAlign: TextAlign.center),
        ),
        LockedFeature(Fonction.valueEtMise),
        SizedBox(height: 12),
        LockedFeature(Fonction.combinaisons),
      ],
    ),
  );

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
  Widget build(BuildContext context) {
    final palier = ref.watch(palierProvider);
    final result = ref.watch(resultsProvider);
    final race = ref.watch(raceConfigProvider);
    final horses = ref.watch(horsesProvider);

    if (palier.enChargement) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultats'), actions: const [EtoileSuiviCourse()]),
        body: const ChargementPalier(),
      );
    }
    if (!palier.autorise(Fonction.calculLocal)) return _consultation();

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultats'), actions: const [EtoileSuiviCourse()]),
        body: const Center(child: Text('Aucun calcul effectué.')),
      );
    }

    final combinaisonsPermises = palier.autorise(Fonction.combinaisons);
    final combinaisons = combinaisonsPermises ? result.combinaisons : null;

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
      appBar: AppBar(
        title: const Text('Classement & recommandations'),
        actions: const [EtoileSuiviCourse()],
      ),
      body: Column(
        children: [
          // Pinné hors de la zone défilante : le rappel de péremption doit
          // rester visible même une fois l'utilisateur scrollé dans le
          // classement, pas seulement en haut de la ListView (voir revue).
          if (result.isStale)
            // liveRegion : un utilisateur de lecteur d'écran doit être notifié
            // proactivement qu'un classement affiché vient de devenir périmé,
            // pas seulement un utilisateur voyant qui balaie l'écran.
            Semantics(
              key: const Key('stale-banner-semantics'),
              liveRegion: true,
              container: true,
              child: Container(
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
                      // Une fois périmé, l'effectif figé du calcul n'a plus de
                      // sens à afficher tel quel : bascule sur l'effectif
                      // réel courant, stylé comme le bandeau (jamais color-only
                      // : le suffixe "recalcul nécessaire" porte le même signal).
                      result.isStale
                          ? Text(
                              '${horses.length} partants actuellement — recalcul nécessaire',
                              style: const TextStyle(color: Colors.amber),
                            )
                          : Text(
                              '${result.resultats.length} partants${nVirtuels > 0 ? ' (dont $nVirtuels non analysés)' : ''}',
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const AvisPalier(),
                Text(
                  'PARIS COMBINÉS',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                if (!combinaisonsPermises)
                  const LockedFeature(Fonction.combinaisons)
                else if (combinaisons == null)
                  const Text('Recalculez pour afficher les combinaisons.')
                else GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    ComboBlock(
                      title: 'Couplé gagnant',
                      combos: combinaisons.couple.desordre,
                    ),
                    ComboBlock(
                      title: 'Couplé ordre',
                      combos: combinaisons.couple.ordre,
                    ),
                    ComboBlock(
                      title: 'Couplé placé',
                      combos: combinaisons.couplePlace,
                    ),
                    ComboBlock(
                      title: '2 sur 4',
                      combos: combinaisons.deuxSurQuatre,
                    ),
                    ComboBlock(
                      title: 'Trio désordre',
                      combos: combinaisons.trio.desordre,
                    ),
                    ComboBlock(
                      title: 'Tiercé ordre',
                      combos: combinaisons.trio.ordre,
                    ),
                    ComboBlock(
                      title: 'Quarté désordre',
                      combos: combinaisons.quarte.desordre,
                    ),
                    ComboBlock(
                      title: 'Quarté ordre',
                      combos: combinaisons.quarte.ordre,
                    ),
                    ComboBlock(
                      title: 'Quinté désordre',
                      combos: combinaisons.quinte.desordre,
                    ),
                    ComboBlock(
                      title: 'Quinté ordre',
                      combos: combinaisons.quinte.ordre,
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
