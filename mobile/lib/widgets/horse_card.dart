import 'package:flutter/material.dart';

import '../models/horse.dart';

class HorseCard extends StatelessWidget {
  final Horse horse;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HorseCard({super.key, required this.horse, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final sousTitre = horse.inedit
        ? '🆕 Inédit'
        : horse.performances.isEmpty
            ? 'Données non saisies'
            : '${horse.performances.length} perf(s)';

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(horse.numPmu?.toString() ?? '?'),
        ),
        title: Text(horse.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${horse.age ?? '—'} ans · ${horse.poids ?? '—'} kg · ${horse.cote != null ? 'cote ${horse.cote}' : 'cote —'} · $sousTitre',
        ),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ),
    );
  }
}
