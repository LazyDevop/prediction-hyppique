import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/acces_paliers.dart';
import '../providers/horses_provider.dart';
import '../providers/palier_provider.dart';
import '../providers/pronostic_provider.dart';
import '../providers/results_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/contour_focus.dart';
import '../widgets/followed_race.dart';
import '../widgets/horse_card.dart';
import '../widgets/locked_feature.dart';
import 'horse_edit_screen.dart';
import 'race_config_screen.dart';
import 'results_screen.dart';

/// Liste des partants. Sous le palier Turfiste : lecture seule, un verrou et
/// « VOIR LE PRONOSTIC DU MATIN » à la place de l'édition et de « Calculer ».
/// Palier en cours de lecture : la liste seule.
class HorseListScreen extends ConsumerStatefulWidget {
  /// Ouverte sans passer par Configuration (palier Gratuit).
  final bool directe;

  const HorseListScreen({super.key, this.directe = false});

  @override
  ConsumerState<HorseListScreen> createState() => _HorseListScreenState();
}

class _HorseListScreenState extends ConsumerState<HorseListScreen> {
  /// Écran en cours d'ouverture : un double toucher n'agit qu'une fois.
  bool _occupe = false;

  Future<void> _ouvrir(Widget ecran) async {
    if (_occupe) return;
    _occupe = true;
    try {
      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ecran));
    } finally {
      _occupe = false;
    }
  }

  void _calculer() {
    if (_occupe || !ref.read(palierProvider).autorise(Fonction.calculLocal)) return;
    ref.read(resultsProvider.notifier).calculer();
    _ouvrir(const ResultsScreen());
  }

  @override
  Widget build(BuildContext context) {
    final horses = ref.watch(horsesProvider);
    final palier = ref.watch(palierProvider);
    final modifiable = palier.autorise(Fonction.modifierPartants);
    final calculable = palier.autorise(Fonction.calculLocal);
    // Un pronostic publié n'existe que pour une course du programme.
    final duProgramme = ref.watch(pronosticContextProvider.select((p) => p.courseId != null));
    final lectureSeule = !palier.enChargement && !modifiable;

    return Scaffold(
      appBar: AppBar(
        title: Text('Partants (${horses.length})'),
        actions: [
          if (widget.directe && palier.autorise(Fonction.configuration))
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Configuration course',
              onPressed: () => _ouvrir(const RaceConfigScreen(depuisPartants: true)),
            ),
          const EtoileSuiviCourse(),
        ],
      ),
      body: horses.isEmpty && !lectureSeule
          ? Center(
              child: modifiable
                  ? const Text('Aucun cheval saisi — appuyez sur + pour en ajouter un.')
                  : const SizedBox.shrink(),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: horses.length + (lectureSeule ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == horses.length) return _verrou(vide: horses.isEmpty);
                final horse = horses[index];
                return HorseCard(
                  horse: horse,
                  onTap: modifiable ? () => _ouvrir(HorseEditScreen(index: index)) : null,
                  onDelete: modifiable ? () => ref.read(horsesProvider.notifier).removeAt(index) : null,
                );
              },
            ),
      bottomNavigationBar: lectureSeule && !calculable && duProgramme
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: ContourFocus(
                  child: CtaPrimaire(
                    texte: 'Voir le pronostic du matin',
                    onPressed: horses.isEmpty ? null : () => _ouvrir(const ResultsScreen()),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButton: !modifiable || !calculable ? null : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => _ouvrir(const HorseEditScreen(index: null)),
            icon: const Icon(Icons.add),
            label: const Text('Cheval'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'calc',
            backgroundColor: horses.isEmpty ? Colors.grey : null,
            onPressed: horses.isEmpty ? null : _calculer,
            icon: const Icon(Icons.calculate),
            label: const Text('Calculer'),
          ),
        ],
      ),
    );
  }

  Widget _verrou({required bool vide}) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vide) ...[
          const Text('Aucun partant pour cette course.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
        ],
        const AvisPalier(),
        const LockedFeature(Fonction.modifierPartants),
      ],
    ),
  );
}
