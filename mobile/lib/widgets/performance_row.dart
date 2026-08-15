import 'package:flutter/material.dart';

import '../models/performance.dart';
import 'option_lists.dart';

/// Une ligne des 6 dernières performances, éditable — C1 (label) = la plus
/// récente. Ligne vide = ignorée par le moteur (aucun champ requis ici).
class PerformanceRow extends StatefulWidget {
  final String label;
  final Performance value;
  final ValueChanged<Performance> onChanged;

  const PerformanceRow({super.key, required this.label, required this.value, required this.onChanged});

  @override
  State<PerformanceRow> createState() => _PerformanceRowState();
}

class _PerformanceRowState extends State<PerformanceRow> {
  late TextEditingController _rangCtrl;
  late TextEditingController _partantsCtrl;
  late TextEditingController _distCtrl;

  @override
  void initState() {
    super.initState();
    _rangCtrl = TextEditingController(text: widget.value.rang?.toString() ?? '');
    _partantsCtrl = TextEditingController(text: widget.value.partants > 0 ? widget.value.partants.toString() : '');
    _distCtrl = TextEditingController(text: widget.value.distance?.toString() ?? '');
  }

  @override
  void dispose() {
    _rangCtrl.dispose();
    _partantsCtrl.dispose();
    _distCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(Performance(
      partants: int.tryParse(_partantsCtrl.text) ?? 0,
      rang: int.tryParse(_rangCtrl.text),
      distance: double.tryParse(_distCtrl.text),
      terrain: widget.value.terrain,
      niveau: widget.value.niveau,
      incident: widget.value.incident,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // 6 champs par ligne ne tiennent pas sur la largeur d'un téléphone :
    // défilement horizontal, comme le fait déjà le prototype HTML sur mobile
    // (table.perfs { min-width:500px } dans un conteneur overflow-x:auto).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(width: 28, child: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold))),
            SizedBox(
              width: 70,
              child: TextField(
                controller: _rangCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rang', isDense: true),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _partantsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Partants', isDense: true),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 340,
              child: DropdownButtonFormField<String>(
                initialValue: widget.value.incident ?? '',
                decoration: const InputDecoration(labelText: 'Incident', isDense: true),
                items: incidentOptions
                    .map((o) => DropdownMenuItem(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => widget.onChanged(Performance(
                  partants: int.tryParse(_partantsCtrl.text) ?? 0,
                  rang: int.tryParse(_rangCtrl.text),
                  distance: double.tryParse(_distCtrl.text),
                  terrain: widget.value.terrain,
                  niveau: widget.value.niveau,
                  incident: (v == null || v.isEmpty) ? null : v,
                )),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<double>(
                initialValue: widget.value.niveau ?? 2.0,
                decoration: const InputDecoration(labelText: 'Niveau', isDense: true),
                items: niveauOptions
                    .map((o) => DropdownMenuItem(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => widget.onChanged(Performance(
                  partants: int.tryParse(_partantsCtrl.text) ?? 0,
                  rang: int.tryParse(_rangCtrl.text),
                  distance: double.tryParse(_distCtrl.text),
                  terrain: widget.value.terrain,
                  niveau: v,
                  incident: widget.value.incident,
                )),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _distCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dist (m)', isDense: true),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<double>(
                initialValue: widget.value.terrain ?? 1.0,
                decoration: const InputDecoration(labelText: 'Terrain', isDense: true),
                items: terrainOptions
                    .map((o) => DropdownMenuItem(value: o.key, child: Text(o.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => widget.onChanged(Performance(
                  partants: int.tryParse(_partantsCtrl.text) ?? 0,
                  rang: int.tryParse(_rangCtrl.text),
                  distance: double.tryParse(_distCtrl.text),
                  terrain: v,
                  niveau: widget.value.niveau,
                  incident: widget.value.incident,
                )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
