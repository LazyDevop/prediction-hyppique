import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/offres_api.dart';
import '../providers/auth_provider.dart';
import '../providers/paiement_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/cadre_auth.dart';
import '../widgets/device_row.dart';
import '../widgets/offer_card.dart';
import '../widgets/settings_row.dart';
import 'paiement_screen.dart';

const messageChargementOffres = 'Impossible de charger les offres.';
const messageAucuneOffre = 'Aucune offre disponible pour le moment';
const messageModeDemoPaiement = 'Mode démo : aucun paiement réel';
const rappelJeuOffres =
    'Jeu responsable — un pronostic reste une estimation : aucun palier ne garantit un gain. '
    'Jouez uniquement ce que vous pouvez vous permettre de perdre.';

/// « Palier Turfiste actif jusqu'au 24/11 à 10 h 00. »
String libelleDroitActif(DroitActuel d, DateTime maintenant) =>
    "Palier ${d.palier} actif jusqu'au ${formaterJourMois(d.finDroit!, maintenant)} à ${formaterHeure(d.finDroit!)}.";

/// Offres (story 9.4), ouvert depuis Profil : offres groupées par palier
/// (`offer-card`), sélection écrite, « Continuer vers le paiement ». Un
/// paiement en attente bloque tout nouveau paiement et se rouvre d'ici.
class OffresScreen extends ConsumerStatefulWidget {
  /// Palier actif à l'ouverture (en-tête, avant lecture du droit).
  final String palier;

  const OffresScreen({super.key, required this.palier});

  @override
  ConsumerState<OffresScreen> createState() => _OffresScreenState();
}

class _OffresScreenState extends ConsumerState<OffresScreen> {
  List<Offre>? _offres;
  DroitActuel? _droit;
  bool _erreur = false;
  String? _selection;

  /// Ouverture de Paiement en cours : un double toucher n'agit qu'une fois.
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (_erreur) setState(() => _erreur = false);
    final api = ref.read(offresApiProvider);
    try {
      final offres = await api.listerOffres();
      if (mounted) setState(() => _offres = offres);
    } catch (_) {
      if (mounted) setState(() => _erreur = true);
    }
    await _chargerDroit();
  }

  /// Palier et fin du droit (en-tête) ; un échec garde l'affichage actuel.
  Future<void> _chargerDroit() async {
    final api = ref.read(offresApiProvider);
    try {
      final droit = await api.droitActuel();
      if (mounted) setState(() => _droit = droit);
    } catch (_) {
      // L'en-tête garde le palier connu.
    }
  }

  Future<void> _ouvrirPaiement(Offre offre, {bool suivre = false}) async {
    if (_occupe) return;
    _occupe = true;
    final navigateur = Navigator.of(context);
    final palier = _droit?.palier ?? widget.palier;
    bool? termine;
    try {
      termine = await navigateur.push<bool>(
        MaterialPageRoute<bool>(builder: (_) => PaiementScreen(offre: offre, palier: palier, suivre: suivre)),
      );
    } finally {
      _occupe = false;
    }
    // « Revenir au profil » depuis Paiement : Offres se ferme aussi.
    if (termine == true && mounted) navigateur.pop();
  }

  void _continuer() {
    final offre = _offres?.where((o) => o.id == _selection).firstOrNull;
    if (offre != null) _ouvrirPaiement(offre);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signalDroitProvider, (_, _) => _chargerDroit());
    final modeDemo = ref.watch(modeDemoPaiementProvider);
    final paiement = ref.watch(paiementEnCoursProvider);
    final enAttente = paiement != null && paiement.enCours;
    final nonAbouti = paiement != null &&
        (paiement.etape == EtapePaiement.echoue || paiement.etape == EtapePaiement.introuvable);
    final offres = _offres;
    final droit = _droit;
    final maintenant = ref.watch(horlogeMuraleProvider)();
    return CadreAuth(
      enfants: [
        Row(
          children: [
            Expanded(child: EnTeteAuth(titre: 'Offres', onRetour: () => Navigator.of(context).maybePop())),
            PastillePalier(droit?.palier ?? widget.palier),
          ],
        ),
        const Text('Paiement par MTN MoMo ou Orange Money.', style: JetonsAuth.meta),
        if (droit != null && droit.payant) ...[
          const SizedBox(height: 4),
          Text(libelleDroitActif(droit, maintenant), style: JetonsAuth.meta),
        ],
        if (modeDemo) ...[
          const SizedBox(height: 10),
          const BandeauStatut(child: Text(messageModeDemoPaiement)),
        ],
        if (enAttente || nonAbouti) ...[
          const SizedBox(height: 10),
          BandeauStatut(
            fort: nonAbouti,
            annonce: true,
            child: Row(
              children: [
                Expanded(child: Text(enAttente ? messagePaiementEnAttente : 'Paiement non confirmé')),
                LienAuth(
                  texte: 'Voir le paiement',
                  onPressed: () => _ouvrirPaiement(paiement.offre, suivre: true),
                ),
              ],
            ),
          ),
        ],
        if (offres == null && _erreur) ...[
          const SizedBox(height: 12),
          const BandeauStatut(fort: true, annonce: true, child: Text(messageChargementOffres)),
          const SizedBox(height: 10),
          CtaFantome(texte: 'Réessayer', onPressed: _charger),
        ] else if (offres == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (offres.isEmpty) ...[
          const SizedBox(height: 12),
          const BandeauStatut(annonce: true, child: Text(messageAucuneOffre)),
          const SizedBox(height: 10),
          CtaFantome(texte: 'Réessayer', onPressed: _charger),
        ] else ...[
          ..._groupe(offres, GroupeOffre.turfiste, 'Turfiste', 'instantanés H-60, H-30, H-15'),
          ..._groupe(offres, GroupeOffre.expert, 'Expert', '+ instantané H-10'),
          ..._groupe(offres, GroupeOffre.duo, 'Duo', 'chaque palier'),
          const SizedBox(height: 2),
          const BandeauStatut(child: Text('ℹ️ Les prix et les durées sont indiqués avant tout paiement.')),
        ],
        const RappelJeuResponsable(rappelJeuOffres),
      ],
      barre: [
        CtaPrimaire(
          texte: 'Continuer vers le paiement',
          onPressed: _selection == null || offres == null || enAttente ? null : _continuer,
        ),
      ],
    );
  }

  List<Widget> _groupe(List<Offre> offres, GroupeOffre groupe, String titre, String aparte) {
    final liste = offres.where((o) => o.groupe == groupe).toList();
    if (liste.isEmpty) return const [];
    return [
      TitreGroupe(titre, aparte: aparte),
      for (final o in liste)
        CarteOffre(
          offre: o,
          selectionnee: o.id == _selection,
          onTap: () => setState(() => _selection = o.id),
        ),
    ];
  }
}
