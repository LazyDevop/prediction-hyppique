import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/acces_paliers.dart';
import '../engine/constants.dart';
import '../models/race_config.dart';
import '../providers/courses_suivies_provider.dart';
import '../providers/palier_provider.dart';
import '../providers/race_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/locked_feature.dart';
import 'horse_list_screen.dart';

/// Configuration de la course cible (cahier des charges mobile §7.2 ;
/// EXPERIENCE.md Information Architecture "Configuration course" et
/// Component Patterns "Sélecteur de terrain groupé Gazon/PSF" — jamais une
/// liste plate mélangeant les deux échelles). Préremplie automatiquement si
/// la course vient du backend (voir home_screen.dart, qui pousse cet écran
/// après avoir mis à jour raceConfigProvider), modifiable à la main sinon.
///
/// Terrain et niveau sont sélectionnés par leur libellé canonique (jamais un
/// float deviné, Architecture Spine AD-5) puis résolus en coefficient au
/// moment de la confirmation via terrainCoefficient()/niveauCoefficient() —
/// seul le coefficient résolu est porté par RaceConfig, comme pour
/// HorseAnalysis côté moteur.
class RaceConfigScreen extends ConsumerStatefulWidget {
  /// Ouvert depuis la Liste des partants : « Voir les partants » y revient.
  final bool depuisPartants;

  /// Ouvert par « Saisie manuelle » : remplace la course courante à la
  /// confirmation (elle reste en place tant que l'écran est verrouillé).
  final bool saisieManuelle;

  const RaceConfigScreen({super.key, this.depuisPartants = false, this.saisieManuelle = false});

  @override
  ConsumerState<RaceConfigScreen> createState() => _RaceConfigScreenState();
}

class _RaceConfigScreenState extends ConsumerState<RaceConfigScreen> {
  late TextEditingController _hippodromeCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _partantsCtrl;
  String? _terrainLabel;
  String? _niveauLabel;

  @override
  void initState() {
    super.initState();
    final config = ref.read(raceConfigProvider);
    _hippodromeCtrl = TextEditingController(text: config.hippodrome);
    _distanceCtrl = TextEditingController(text: config.distance?.toStringAsFixed(0) ?? '');
    _partantsCtrl = TextEditingController(text: config.nbPartantsCourse?.toString() ?? '');
    _terrainLabel = _reverseLookupTerrain(config.terrain);
    _niveauLabel = _reverseLookup(niveauCoefficients, config.niveau);
  }

  @override
  void dispose() {
    _hippodromeCtrl.dispose();
    _distanceCtrl.dispose();
    _partantsCtrl.dispose();
    super.dispose();
  }

  // Le modèle RaceConfig ne porte que le coefficient déjà résolu (voir
  // docstring de la classe) — retrouver le libellé à afficher pour une
  // valeur préremplie nécessite donc de relire les tables dans l'autre sens.
  String? _reverseLookup(Map<String, double> table, double? value) {
    if (value == null) return null;
    for (final entry in table.entries) {
      if (entry.value == value) return entry.key;
    }
    return null;
  }

  String? _reverseLookupTerrain(double? value) {
    if (value == null) return null;
    return _reverseLookup(terrainCoefficientsGazon, value) ?? _reverseLookup(terrainCoefficientsPsf, value);
  }

  Widget _optionTile(BuildContext sheetContext, String label, double value, String? selectedLabel) {
    final isSelected = label == selectedLabel;
    return ListTile(
      title: Text('$label (${value.toStringAsFixed(3)})'),
      selected: isSelected,
      trailing: isSelected ? Icon(Icons.check, color: Theme.of(sheetContext).colorScheme.primary) : null,
      onTap: () => Navigator.pop(sheetContext, label),
    );
  }

  Future<void> _pickTerrain() async {
    // Sélecteur de terrain groupé Gazon/PSF (EXPERIENCE.md Component
    // Patterns) : deux échelles de coefficients non comparables, jamais
    // fusionnées en une seule liste plate.
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'TERRAIN',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Theme.of(sheetContext).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Gazon — échelle officielle (10 niveaux)', style: Theme.of(sheetContext).textTheme.labelSmall),
              ),
              for (final entry in terrainCoefficientsGazon.entries)
                _optionTile(sheetContext, entry.key, entry.value, _terrainLabel),
              const Divider(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Sable fibré (PSF) — échelle distincte', style: Theme.of(sheetContext).textTheme.labelSmall),
              ),
              for (final entry in terrainCoefficientsPsf.entries)
                _optionTile(sheetContext, entry.key, entry.value, _terrainLabel),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _terrainLabel = selected);
    }
  }

  Future<void> _pickNiveau() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'NIVEAU',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Theme.of(sheetContext).colorScheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
              for (final entry in niveauCoefficients.entries)
                _optionTile(sheetContext, entry.key, entry.value, _niveauLabel),
            ],
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _niveauLabel = selected);
    }
  }

  void _confirm() {
    if (!ref.read(palierProvider).autorise(Fonction.configuration)) return;
    final config = RaceConfig(
      hippodrome: _hippodromeCtrl.text.trim(),
      distance: double.tryParse(_distanceCtrl.text),
      terrain: terrainCoefficient(_terrainLabel),
      niveau: niveauCoefficient(_niveauLabel),
      nbPartantsCourse: int.tryParse(_partantsCtrl.text),
    );
    if (widget.saisieManuelle) ref.read(courseCouranteProvider.notifier).effacer();
    ref.read(raceConfigProvider.notifier).update(config);
    if (widget.depuisPartants) {
      if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.pop(context);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HorseListScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final duProgramme = !widget.saisieManuelle && ref.watch(courseCouranteProvider) != null;
    return PageSelonPalier(
      fonction: duProgramme ? Fonction.configuration : Fonction.saisieManuelle,
      titre: duProgramme ? 'Configuration course' : 'Saisie manuelle',
      contenu: _contenu,
      // Les partants restent consultables sans la configuration.
      sousVerrou: duProgramme && !widget.depuisPartants
          ? CtaFantome(texte: 'Voir les partants', onPressed: _voirPartants)
          : null,
    );
  }

  void _voirPartants() {
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HorseListScreen()));
  }

  Widget _contenu(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration course')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _hippodromeCtrl,
            decoration: const InputDecoration(labelText: 'Hippodrome'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _distanceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Distance (m)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _partantsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Partants (auto si vide)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Terrain'),
            subtitle: Text(_terrainLabel ?? 'Non renseigné'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickTerrain,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Niveau'),
            subtitle: Text(_niveauLabel ?? 'Non renseigné'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickNiveau,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _confirm,
            child: const Text('Voir les partants'),
          ),
        ],
      ),
    );
  }
}
