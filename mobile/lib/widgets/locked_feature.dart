import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/acces_paliers.dart';
import '../data/remote/compte_api.dart';
import '../providers/auth_provider.dart';
import '../providers/palier_provider.dart';
import '../screens/offres_screen.dart';
import 'auth_styles.dart';
import 'contour_focus.dart';

const messagePalierNonVerifie = 'Palier non vérifié';

/// `locked-feature` (DESIGN.md) : à la place du contenu au-dessus du palier,
/// dit ce qu'il débloque et pour quel palier. Jamais d'or ni de flou. Un
/// seul nœud TalkBack : « Combinaisons, palier Expert, bouton Voir les
/// offres ». « Voir les offres » est absent sans OffresApi.
class LockedFeature extends ConsumerStatefulWidget {
  final Fonction fonction;
  const LockedFeature(this.fonction, {super.key});

  @override
  ConsumerState<LockedFeature> createState() => _LockedFeatureState();
}

class _LockedFeatureState extends ConsumerState<LockedFeature> {
  /// Offres en cours d'ouverture : un double toucher n'agit qu'une fois.
  bool _occupe = false;

  Future<void> _voirOffres() async {
    if (_occupe) return;
    _occupe = true;
    final palier = ref.read(palierProvider).palier ?? palierGratuit;
    final besoin = palierRequis(widget.fonction);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OffresScreen(palier: palier, besoin: besoin, libelleRetour: libelleRetourVerrou),
        ),
      );
    } finally {
      _occupe = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palier = palierRequis(widget.fonction);
    final offres = ref.watch(offresDisponiblesProvider);
    return Semantics(
      container: true,
      label: '${widget.fonction.libelle}, palier $palier${offres ? ', bouton Voir les offres' : ''}',
      onTap: offres ? _voirOffres : null,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: JetonsAuth.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: JetonsAuth.lineCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 13, color: JetonsAuth.muted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: widget.fonction.libelle),
                          TextSpan(
                            text: ' — palier $palier',
                            style: const TextStyle(color: JetonsAuth.muted),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 13, height: 1.4, color: JetonsAuth.text),
                    ),
                  ),
                ],
              ),
              if (offres) ...[
                const SizedBox(height: 10),
                ContourFocus(child: CtaFantome(texte: 'Voir les offres', onPressed: _voirOffres)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dernière lecture du palier en échec : avis et « Réessayer ». Rien sinon.
class AvisPalier extends ConsumerWidget {
  const AvisPalier({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(palierProvider.select((e) => e.erreur))) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BandeauStatut(
        annonce: true,
        child: Row(
          children: [
            const Expanded(child: Text(messagePalierNonVerifie)),
            ContourFocus(
              child: LienAuth(
                texte: 'Réessayer',
                onPressed: () => ref.read(palierProvider.notifier).reessayer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Palier en cours de lecture : ni contenu ni verrou.
class ChargementPalier extends StatelessWidget {
  const ChargementPalier({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: CircularProgressIndicator(color: JetonsAuth.muted),
    ),
  );
}

/// Page d'une fonction entière : [contenu] si le palier l'ouvre, sinon une
/// page ne portant qu'un verrou. [contenu] n'est construit que s'il est
/// permis ; l'état de l'écran appelant, lui, est conservé.
class PageSelonPalier extends ConsumerWidget {
  final Fonction fonction;
  final String titre;
  final WidgetBuilder contenu;

  /// Action encore permise, sous le verrou.
  final Widget? sousVerrou;
  const PageSelonPalier({
    super.key,
    required this.fonction,
    required this.titre,
    required this.contenu,
    this.sousVerrou,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(palierProvider);
    if (etat.autorise(fonction)) return contenu(context);
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: etat.enChargement
          ? const ChargementPalier()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const AvisPalier(),
                LockedFeature(fonction),
                if (sousVerrou case final action?) ...[const SizedBox(height: 12), action],
              ],
            ),
    );
  }
}
