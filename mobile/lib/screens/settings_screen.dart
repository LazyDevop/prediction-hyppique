import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/acces_paliers.dart';
import '../models/engine_params.dart';
import '../providers/palier_provider.dart';
import '../providers/params_provider.dart';
import '../widgets/locked_feature.dart';
import '../widgets/option_lists.dart';

/// Réglages du moteur — mêmes défauts que backend/app/engine/constants.py
/// (section 7 du document backend, sections 7.3 à 7.11).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _bankCtrl = TextEditingController();
  final _kCtrl = TextEditingController();
  final _sensPoidsCtrl = TextEditingController();
  final _ageMinCtrl = TextEditingController();
  final _ageMaxCtrl = TextEditingController();
  final _shrinkCtrl = TextEditingController();
  final _coefIneditCtrl = TextEditingController();
  final _malusIncCtrl = TextEditingController();
  // Distingue une resynchronisation programmatique (reset, valeur chargée)
  // d'une frappe utilisateur : évite que _syncControllers ne re-déclenche
  // _update via un onChanged reçu pendant l'assignation de .text.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _syncControllers(ref.read(engineParamsProvider));
  }

  void _syncControllers(EngineParams p) {
    _syncing = true;
    _bankCtrl.text = p.bankroll.toString();
    _kCtrl.text = p.contraste.toString();
    _sensPoidsCtrl.text = p.sensibilitePoids.toString();
    _ageMinCtrl.text = p.ageMin.toString();
    _ageMaxCtrl.text = p.ageMax.toString();
    _shrinkCtrl.text = p.shrink.toString();
    _coefIneditCtrl.text = p.coefInedit.toString();
    _malusIncCtrl.text = p.malusIncident.toString();
    _syncing = false;
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _kCtrl.dispose();
    _sensPoidsCtrl.dispose();
    _ageMinCtrl.dispose();
    _ageMaxCtrl.dispose();
    _shrinkCtrl.dispose();
    _coefIneditCtrl.dispose();
    _malusIncCtrl.dispose();
    super.dispose();
  }

  void _update(EngineParams Function(EngineParams) f) {
    if (_syncing) return; // évite de re-persister une valeur qu'on vient de charger/réinitialiser
    ref.read(engineParamsProvider.notifier).update(f(ref.read(engineParamsProvider)));
  }

  /// Réinitialise seulement ce que le palier permet de régler : les
  /// coefficients enregistrés d'un ancien droit Expert sont conservés.
  Future<void> _confirmReset() async {
    final complet = ref.read(palierProvider).autorise(Fonction.coefficientsMoteur);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Réinitialiser les réglages ?'),
        content: Text(
          complet
              ? 'Tous les paramètres du moteur reviendront à leurs valeurs par défaut.'
              : 'La bankroll et la fraction de Kelly reviendront à leurs valeurs par défaut.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Réinitialiser')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Palier relu : il a pu changer pendant la confirmation.
    final palier = ref.read(palierProvider);
    final notifier = ref.read(engineParamsProvider.notifier);
    if (complet && palier.autorise(Fonction.coefficientsMoteur)) {
      notifier.reset();
    } else if (palier.autorise(Fonction.bankrollEtKelly)) {
      const defauts = EngineParams();
      notifier.update(
        ref.read(engineParamsProvider).copyWith(bankroll: defauts.bankroll, fractionKelly: defauts.fractionKelly),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(engineParamsProvider);
    final palier = ref.watch(palierProvider);
    final mise = palier.autorise(Fonction.bankrollEtKelly);
    // Resynchronise les champs texte après un changement externe (reset, ou
    // tout futur appel à update() hors de cet écran) — les TextField eux-
    // mêmes ne réagissent pas automatiquement aux changements de provider.
    ref.listen<EngineParams>(engineParamsProvider, (previous, next) => _syncControllers(next));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres du moteur'),
        actions: [
          if (mise) IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Réinitialiser aux valeurs par défaut',
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: palier.enChargement ? const ChargementPalier() : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AvisPalier(),
          if (!mise)
            const LockedFeature(Fonction.bankrollEtKelly)
          else ..._champsMise(params),
          const SizedBox(height: 12),
          if (!palier.autorise(Fonction.coefficientsMoteur))
            const LockedFeature(Fonction.coefficientsMoteur)
          else ..._champsMoteur(params),
        ],
      ),
    );
  }

  List<Widget> _champsMise(EngineParams params) => [
          TextField(
            controller: _bankCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Bankroll (unités)'),
            onChanged: (v) => _update((p) => p.copyWith(bankroll: double.tryParse(v))),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            initialValue: params.fractionKelly,
            decoration: const InputDecoration(labelText: 'Fraction de Kelly'),
            items: const [
              DropdownMenuItem(value: 0.1, child: Text('Prudent (10 %)')),
              DropdownMenuItem(value: 0.25, child: Text('Standard (25 %)')),
              DropdownMenuItem(value: 0.5, child: Text('Agressif (50 %)')),
            ],
            onChanged: (v) => _update((p) => p.copyWith(fractionKelly: v)),
          ),
        ];

  List<Widget> _champsMoteur(EngineParams params) => [
          DropdownButtonFormField<String>(
            initialValue: params.modeRecence,
            decoration: const InputDecoration(labelText: 'Pondération récence'),
            items: modeRecenceOptions.map((o) => DropdownMenuItem(value: o.key, child: Text(o.value))).toList(),
            onChanged: (v) => _update((p) => p.copyWith(modeRecence: v)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _kCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Contraste des probabilités (k)'),
            onChanged: (v) => _update((p) => p.copyWith(contraste: double.tryParse(v))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sensPoidsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Sensibilité au poids (%/kg)'),
            onChanged: (v) => _update((p) => p.copyWith(sensibilitePoids: double.tryParse(v))),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageMinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Âge optimal min'),
                  onChanged: (v) => _update((p) => p.copyWith(ageMin: double.tryParse(v))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ageMaxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Âge optimal max'),
                  onChanged: (v) => _update((p) => p.copyWith(ageMax: double.tryParse(v))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _shrinkCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Lissage petits historiques'),
            onChanged: (v) => _update((p) => p.copyWith(shrink: double.tryParse(v))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _coefIneditCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Coefficient inédit'),
            onChanged: (v) => _update((p) => p.copyWith(coefInedit: double.tryParse(v))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _malusIncCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Intensité malus incident'),
            onChanged: (v) => _update((p) => p.copyWith(malusIncident: double.tryParse(v))),
          ),
        ];
}
