import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/horses_provider.dart';
import '../providers/results_provider.dart';
import '../widgets/horse_card.dart';
import 'horse_edit_screen.dart';
import 'results_screen.dart';

class HorseListScreen extends ConsumerWidget {
  const HorseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final horses = ref.watch(horsesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Partants (${horses.length})')),
      body: horses.isEmpty
          ? const Center(child: Text('Aucun cheval saisi — appuyez sur + pour en ajouter un.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: horses.length,
              itemBuilder: (context, index) {
                final horse = horses[index];
                return HorseCard(
                  horse: horse,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HorseEditScreen(index: index)),
                  ),
                  onDelete: () => ref.read(horsesProvider.notifier).removeAt(index),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HorseEditScreen(index: null)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Cheval'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'calc',
            backgroundColor: horses.isEmpty ? Colors.grey : null,
            onPressed: horses.isEmpty
                ? null
                : () {
                    ref.read(resultsProvider.notifier).calculer();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultsScreen()));
                  },
            icon: const Icon(Icons.calculate),
            label: const Text('Calculer'),
          ),
        ],
      ),
    );
  }
}
