import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/engine_params.dart';
import '../providers/params_provider.dart';
import '../widgets/option_lists.dart';

/// Réglages du moteur — mêmes défauts que backend/app/engine/constants.py
/// (section 7 du document backend, sections 7.3 à 7.11).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _bankCtrl;
  late TextEditingController _kCtrl;
  late TextEditingController _sensPoidsCtrl;
  late TextEditingController _ageMinCtrl;
  late TextEditingController _ageMaxCtrl;
  late TextEditingController _shrinkCtrl;
  late TextEditingController _coefIneditCtrl;
  late TextEditingController _malusIncCtrl;

  @override
  void initState() {
    super.initState();
    final p = ref.read(engineParamsProvider);
    _bankCtrl = TextEditingController(text: p.bankroll.toString());
    _kCtrl = TextEditingController(text: p.contraste.toString());
    _sensPoidsCtrl = TextEditingController(text: p.sensibilitePoids.toString());
    _ageMinCtrl = TextEditingController(text: p.ageMin.toString());
    _ageMaxCtrl = TextEditingController(text: p.ageMax.toString());
    _shrinkCtrl = TextEditingController(text: p.shrink.toString());
    _coefIneditCtrl = TextEditingController(text: p.coefInedit.toString());
    _malusIncCtrl = TextEditingController(text: p.malusIncident.toString());
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
    ref.read(engineParamsProvider.notifier).update(f(ref.read(engineParamsProvider)));
  }

  @override
  Widget build(BuildContext context) {
    final params = ref.watch(engineParamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres du moteur')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }
}
