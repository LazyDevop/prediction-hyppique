import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/historique_performance.dart';
import '../models/horse.dart';
import '../models/performance.dart';
import '../providers/api_provider.dart';
import '../providers/horses_provider.dart';
import '../widgets/performance_row.dart';

/// Fiche cheval éditable. index == null → nouveau cheval, sinon édition d'un
/// cheval existant du lot. Section 7.4 du document mobile : la case "inédit"
/// est distincte d'une simple ligne vide — ne jamais les confondre.
class HorseEditScreen extends ConsumerStatefulWidget {
  final int? index;

  const HorseEditScreen({super.key, required this.index});

  @override
  ConsumerState<HorseEditScreen> createState() => _HorseEditScreenState();
}

class _HorseEditScreenState extends ConsumerState<HorseEditScreen> {
  late TextEditingController _numCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _poidsCtrl;
  late TextEditingController _coteCtrl;
  late bool _inedit;
  late List<Performance> _perfs;
  int? _chevalId;

  // Historique complet (bouton "Voir tout l'historique", section 7.4) :
  // distinct des 6 lignes ci-dessus, jamais éditable, ne remplace rien côté
  // moteur.
  List<HistoriquePerformance>? _historique;
  bool _loadingHistorique = false;
  String? _historiqueError;
  bool _historiqueOffline = false;

  @override
  void initState() {
    super.initState();
    final horse = widget.index != null ? ref.read(horsesProvider)[widget.index!] : null;
    _numCtrl = TextEditingController(text: horse?.numPmu?.toString() ?? '');
    _nameCtrl = TextEditingController(text: horse?.nom ?? '');
    _ageCtrl = TextEditingController(text: horse?.age?.toString() ?? '5');
    _poidsCtrl = TextEditingController(text: horse?.poids?.toString() ?? '58');
    _coteCtrl = TextEditingController(text: horse?.cote?.toString() ?? '');
    _inedit = horse?.inedit ?? false;
    _chevalId = horse?.chevalId;
    _perfs = List<Performance>.generate(6, (i) {
      if (horse != null && i < horse.performances.length) return horse.performances[i];
      return const Performance(partants: 0);
    });
  }

  Future<void> _loadHistorique({bool forceRefresh = false}) async {
    final chevalId = _chevalId;
    if (chevalId == null) return;
    setState(() {
      _loadingHistorique = true;
      _historiqueError = null;
    });
    try {
      final result = await ref
          .read(courseRepositoryProvider)
          .historiqueComplet(chevalId, forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _historique = result;
        _historiqueOffline = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Une réponse serveur (404, 500...) n'est pas un problème réseau : on
      // ne grise pas le bouton dans ce cas, seul un vrai échec de connexion
      // déclenche l'affichage "hors ligne" (section 4 du document mobile).
      final isOffline = e is DioException && e.response == null;
      setState(() {
        _historiqueOffline = isOffline;
        _historiqueError = isOffline
            ? "Connexion réseau requise pour charger l'historique complet."
            : "Échec du chargement de l'historique : $e";
      });
    } finally {
      if (mounted) setState(() => _loadingHistorique = false);
    }
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _poidsCtrl.dispose();
    _coteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    // Une ligne de perf "vide" (ni rang ni incident) est ignorée par le
    // moteur — pas besoin de la filtrer ici, computeForme s'en charge déjà.
    final performances = _perfs.where((p) => p.rang != null || p.partants > 0 || p.incident != null).toList();

    final horse = Horse(
      nom: _nameCtrl.text.trim().isEmpty ? 'Sans nom' : _nameCtrl.text.trim(),
      numPmu: int.tryParse(_numCtrl.text),
      age: int.tryParse(_ageCtrl.text),
      poids: double.tryParse(_poidsCtrl.text),
      cote: double.tryParse(_coteCtrl.text),
      inedit: _inedit,
      performances: performances,
      chevalId: _chevalId,
    );

    final notifier = ref.read(horsesProvider.notifier);
    if (widget.index != null) {
      notifier.replaceAt(widget.index!, horse);
    } else {
      notifier.add(horse);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.index != null ? 'Modifier le cheval' : 'Nouveau cheval'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Importer une photo (bientôt disponible)',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Import photo pas encore disponible — nécessite l'étape 4 (backend vision).")),
            ),
          ),
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _numCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'N°'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Âge'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _poidsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Poids (kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _coteCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cote', hintText: 'ex. 6.5'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _inedit,
            onChanged: (v) => setState(() => _inedit = v ?? false),
            title: const Text('Cheval inédit'),
            subtitle: const Text("N'a jamais couru — à cocher seulement si c'est un fait, pas un oubli de saisie"),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const Divider(height: 32),
          Text('Historique (C1 = course la plus récente)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < 6; i++)
            PerformanceRow(
              label: 'C${i + 1}',
              value: _perfs[i],
              onChanged: (p) => setState(() => _perfs[i] = p),
            ),
          const SizedBox(height: 12),
          Text(
            'Ligne vide = ignorée par le moteur.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const Divider(height: 32),
          _buildHistoriqueSection(context),
        ],
      ),
    );
  }

  Widget _buildHistoriqueSection(BuildContext context) {
    if (_chevalId == null) {
      return Row(
        children: [
          const Icon(Icons.history_toggle_off, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Historique complet indisponible : ce cheval n'est pas rattaché au backend "
              "(saisie manuelle, ou pas encore chargé depuis le programme du jour).",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historique complet (lecture seule)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Ne remplace pas les 6 lignes ci-dessus : le calcul reste basé sur elles uniquement.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: (_loadingHistorique || _historiqueOffline)
              ? null
              : () => _loadHistorique(forceRefresh: _historique != null),
          icon: _loadingHistorique
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.history),
          label: Text(_historique == null ? "Voir tout l'historique" : "Rafraîchir l'historique complet"),
        ),
        if (_historiqueError != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_historiqueOffline ? Icons.wifi_off : Icons.error_outline, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_historiqueError!, style: const TextStyle(color: Colors.grey))),
            ],
          ),
          if (_historiqueOffline) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _loadHistorique(forceRefresh: _historique != null),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ],
        if (_historique != null) ...[
          const SizedBox(height: 8),
          if (_historique!.isEmpty)
            const Text('Aucune course supplémentaire trouvée.', style: TextStyle(color: Colors.grey))
          else
            Column(
              children: _historique!.map((p) {
                final d = p.dateCourse;
                final dateLabel = d == null
                    ? '—'
                    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                final rangLabel = p.incident ?? (p.rang != null ? '${p.rang}${p.nbParticipants != null ? '/${p.nbParticipants}' : ''}' : '—');
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: SizedBox(width: 70, child: Text(dateLabel)),
                  title: Text('${p.hippodrome ?? '—'} · ${p.discipline ?? '—'}'),
                  subtitle: p.distance != null ? Text('${p.distance!.toStringAsFixed(0)} m') : null,
                  trailing: Text(rangLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }
}
