import 'package:flutter/material.dart';

import '../engine/combinatoire.dart';

String _fmtPctFine(double x) => x >= 0.01 ? '${(x * 100).toStringAsFixed(1)} %' : '${(x * 100).toStringAsFixed(3)} %';

/// Un bloc de combinaison de paris (couplé, tiercé, quarté, quinté...) —
/// reprise du ComboBlock du prototype React.
class ComboBlock extends StatelessWidget {
  final String title;
  final List<ComboLabel> combos;
  final String? note;

  const ComboBlock({super.key, required this.title, required this.combos, this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          if (combos.isEmpty)
            const Text('Pas assez de partants', style: TextStyle(fontSize: 11, color: Colors.grey))
          else
            ...combos.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.dossards.map((d) => d?.toString() ?? '?').join(' → '),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          Text(_fmtPctFine(c.probabilite), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      Text(c.noms.join(' · '), style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                )),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
