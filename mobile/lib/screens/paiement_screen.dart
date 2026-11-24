import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/offres_api.dart';
import '../providers/auth_provider.dart';
import '../providers/paiement_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/cadre_auth.dart';
import '../widgets/device_row.dart';
import '../widgets/offer_card.dart';
import '../widgets/payment_status.dart';
import '../widgets/settings_row.dart';
import 'connexion_screen.dart';
import 'offres_screen.dart';

const rappelJeuPaiement =
    'Jeu responsable — aucun palier ne garantit un gain. Jouez uniquement ce que vous pouvez vous permettre de perdre.';
const messageAucunCompte = 'Aucun compte connecté — reconnectez-vous pour payer.';
const messagePaiementEnAttente = 'Un paiement est en attente de confirmation';
const noteDuo = "L'invitation de vos proches arrivera dans une prochaine version.";

/// Clé de l'emplacement unique du `payment-status` : même position pour
/// « en attente », « confirmé » et « non confirmé », pour que la région live
/// n'annonce que le changement de texte.
const cleStatutPaiement = ValueKey('statut-paiement');

/// « Votre palier Expert est actif jusqu'au 24/11. »
String messagePalierSuperieur(PalierSuperieurActif r, DateTime maintenant) =>
    "Votre palier ${r.palier} est actif jusqu'au ${formaterJourMois(r.finDroit, maintenant)}.";

/// Paiement Mobile Money (story 9.5) : résumé, MTN MoMo / Orange Money,
/// numéro (proposé depuis le compte, modifiable), « Payer », puis
/// `payment-status`. Le paiement est suivi par [paiementEnCoursProvider]
/// (niveau app) : l'utilisateur peut partir, le sondage continue et une
/// confirmation tardive change quand même le palier.
///
/// Renvoie `true` quand l'utilisateur revient au profil (Offres se ferme).
class PaiementScreen extends ConsumerStatefulWidget {
  final Offre offre;

  /// Palier actif à l'ouverture (en-tête).
  final String palier;

  /// Rouvert depuis Offres pour suivre le paiement en cours de [offre].
  final bool suivre;

  /// Libellé du retour à l'écran qui a ouvert Offres.
  final String libelleRetour;

  const PaiementScreen({
    super.key,
    required this.offre,
    required this.palier,
    this.suivre = false,
    this.libelleRetour = libelleRetourProfil,
  });

  @override
  ConsumerState<PaiementScreen> createState() => _PaiementScreenState();
}

class _PaiementScreenState extends ConsumerState<PaiementScreen> {
  final _numeroCtrl = TextEditingController();
  late final PaiementEnCoursNotifier _paiements;
  MoyenPaiement? _moyen;
  String? _erreurNumero;
  String? _message;

  /// Clé du paiement suivi par cet écran (lancé ici, ou rouvert).
  String? _cleSuivie;

  /// Dernier paiement suivi affiché (lu au dispose, sans `ref`).
  PaiementEnCours? _suiviAffiche;

  /// « Payer » / « Réessayer » en cours : un double toucher n'agit qu'une fois.
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _paiements = ref.read(paiementEnCoursProvider.notifier);
    final p = ref.read(paiementEnCoursProvider);
    if (p != null && p.offre.id == widget.offre.id && (p.enCours || widget.suivre)) {
      _cleSuivie = p.cleIdempotence;
      // Sondage arrêté (10 min) : une lecture à la réouverture.
      _paiements.actualiser();
    }
    _numeroCtrl.addListener(_surNumero);
    _proposerNumero();
  }

  @override
  void dispose() {
    final cle = _cleSuivie;
    final p = _suiviAffiche;
    // Issue vue : oubliée (hors construction de l'arbre).
    if (cle != null && p != null && p.cleIdempotence == cle && p.termine) {
      final paiements = _paiements;
      scheduleMicrotask(() => paiements.oublier(cle));
    }
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _proposerNumero() async {
    final api = ref.read(offresApiProvider);
    String? numero;
    try {
      numero = await api.numeroPropose();
    } catch (_) {
      numero = null;
    }
    if (!mounted || numero == null || _numeroCtrl.text.isNotEmpty) return;
    _numeroCtrl.text = normaliserNumero(numero);
  }

  String _dernierNumero = '';
  void _surNumero() {
    if (_numeroCtrl.text == _dernierNumero) return;
    _dernierNumero = _numeroCtrl.text;
    setState(() {
      _erreurNumero = null;
      _message = null;
    });
  }

  String get _local => _numeroCtrl.text;
  bool get _numeroValide => numeroMobileLocal.hasMatch(_local);

  /// Erreur en ligne : numéro complet mais pas un mobile camerounais.
  String? get _erreurAffichee =>
      _erreurNumero ?? (_local.length == 9 && !_numeroValide ? messageNumeroInvalide : null);

  PaiementEnCours? _suivi(PaiementEnCours? p) =>
      p != null && _cleSuivie != null && p.cleIdempotence == _cleSuivie ? p : null;

  /// « Payer » (formulaire) ou « Réessayer » (mêmes moyen et numéro).
  Future<void> _payer(MoyenPaiement moyen, String numero) async {
    if (_occupe) return;
    if (!numeroMobileLocal.hasMatch(numero)) return;
    // Toucher arrivé avant la reconstruction : un paiement est déjà parti.
    if (ref.read(paiementEnCoursProvider)?.enCours ?? false) return;
    _occupe = true;
    final paiements = _paiements;
    final maintenant = ref.read(horlogeMuraleProvider)();
    // L'état passe à « initiation » avant le premier `await` de payer().
    final future = paiements.payer(offre: widget.offre, moyen: moyen, numero: numero);
    final cle = ref.read(paiementEnCoursProvider)?.cleIdempotence;
    setState(() {
      _cleSuivie = cle;
      _message = null;
    });
    final resultat = await future;
    _occupe = false;
    if (!mounted) return;
    setState(() {
      switch (resultat) {
        case PaiementInitie():
          break;
        case NumeroPaiementInvalide():
          _cleSuivie = null;
          _erreurNumero = messageNumeroInvalide;
        case final PalierSuperieurActif r:
          _cleSuivie = null;
          _message = messagePalierSuperieur(r, maintenant);
        case AucunCompte():
          _cleSuivie = null;
          _message = messageAucunCompte;
        case PaiementDejaEnCours():
          _cleSuivie = null;
          _message = messagePaiementEnAttente;
        case null:
          _cleSuivie = null;
          _message = messageErreur;
      }
    });
  }

  void _changerDeMoyen() {
    final cle = _cleSuivie;
    if (cle != null) _paiements.oublier(cle);
    setState(() {
      _cleSuivie = null;
      _moyen = null;
    });
  }

  void _revenirAuProfil() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    final suivi = _suivi(ref.watch(paiementEnCoursProvider));
    _suiviAffiche = suivi;
    final etape = suivi?.etape;
    final confirme = etape == EtapePaiement.confirme;
    return PopScope(
      // Pendant l'envoi de la demande, le retour perdrait son résultat ;
      // une fois confirmé, le retour mène au profil.
      canPop: etape != EtapePaiement.initiation && !confirme,
      onPopInvokedWithResult: (aDepile, _) {
        if (aDepile || !confirme) return;
        // Jamais derrière une porte (verrouillage) ni sous une autre route.
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (ref.read(authProvider).value?.porte != Porte.ouverte) return;
        _revenirAuProfil();
      },
      child: CadreAuth(enfants: _contenu(suivi), barre: _barre(suivi)),
    );
  }

  List<Widget> _contenu(PaiementEnCours? suivi) {
    final modeDemo = ref.watch(modeDemoPaiementProvider);
    final etape = suivi?.etape;
    final palier = suivi?.confirmation?.palier ?? widget.palier;
    final retourPossible = etape != EtapePaiement.initiation && etape != EtapePaiement.confirme;
    final statut = suivi == null ? null : _statut(suivi);
    final saisieOuverte = suivi == null;
    return [
      Row(
        children: [
          Expanded(
            child: EnTeteAuth(
              titre: 'Paiement',
              onRetour: retourPossible ? () => Navigator.of(context).maybePop() : null,
            ),
          ),
          PastillePalier(palier),
        ],
      ),
      if (modeDemo) ...[
        const SizedBox(height: 6),
        const BandeauStatut(child: Text(messageModeDemoPaiement)),
      ],
      const SizedBox(height: 10),
      if (statut != null) ...[statut, const SizedBox(height: 10)],
      if (suivi != null && suivi.nonActualise && suivi.etape == EtapePaiement.enAttente) ...[
        const BandeauStatut(annonce: true, child: Text(messageStatutNonActualise)),
        const SizedBox(height: 10),
      ],
      if (etape == EtapePaiement.confirme)
        ..._apresConfirmation(suivi!)
      else ...[
        _Resume(widget.offre),
        const TitreGroupe('Moyen de paiement'),
        for (final m in MoyenPaiement.values)
          _OptionMoyen(
            moyen: m,
            selectionne: saisieOuverte ? _moyen == m : suivi.moyen == m,
            onTap: saisieOuverte ? () => setState(() => _moyen = m) : null,
          ),
        const SizedBox(height: 6),
        Text('Numéro Mobile Money'.toUpperCase(), style: JetonsAuth.label),
        const SizedBox(height: 6),
        if (saisieOuverte) _champNumero() else _numeroPaye(suivi.numero),
        const SizedBox(height: 6),
        const Text(
          'Le numéro de votre compte est proposé ; vous pouvez en saisir un autre.',
          style: JetonsAuth.meta,
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          BandeauStatut(fort: true, annonce: true, child: Text(_message!)),
        ],
      ],
      const RappelJeuResponsable(rappelJeuPaiement),
    ];
  }

  Widget _indicatif() => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: JetonsAuth.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: JetonsAuth.lineCard),
    ),
    child: Semantics(
      label: 'Indicatif Cameroun, plus 2 3 7',
      excludeSemantics: true,
      child: const Text('🇨🇲 +237', style: TextStyle(fontSize: 17, color: JetonsAuth.text)),
    ),
  );

  Widget _champNumero() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _indicatif(),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: 'Numéro Mobile Money',
            child: TextField(
              controller: _numeroCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FormatNumero()],
              style: const TextStyle(
                fontSize: 17,
                letterSpacing: .5,
                color: JetonsAuth.text,
                fontFeatures: JetonsAuth.tabulaire,
              ),
              decoration: decorationChampNumero(erreur: _erreurAffichee),
            ),
          ),
        ),
      ],
    );
  }

  /// Numéro du paiement suivi : lecture seule (ce qui est affiché est ce
  /// qui est payé).
  Widget _numeroPaye(String numero) {
    final lisible = '+237 ${formaterNumeroLocal(numero)}';
    return Semantics(
      label: 'Numéro Mobile Money, $lisible',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: JetonsAuth.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: JetonsAuth.lineCard),
        ),
        child: Text(
          lisible,
          style: const TextStyle(fontSize: 16, color: JetonsAuth.muted, fontFeatures: JetonsAuth.tabulaire),
        ),
      ),
    );
  }

  /// L'emplacement unique du `payment-status`, ou rien pendant l'envoi.
  Widget? _statut(PaiementEnCours p) {
    final moyen = libelleMoyen(p.moyen);
    switch (p.etape) {
      case EtapePaiement.initiation:
        return null;
      case EtapePaiement.enAttente:
        const titre = 'Paiement en attente de confirmation — validez sur votre téléphone';
        final texte =
            "Une demande $moyen vient d'arriver sur le +237 ${formaterNumeroLocal(p.numero)}. "
            'Saisissez votre code Mobile Money pour la valider.';
        final note = "Le pass s'active dès que $moyen confirme, même si vous quittez cet écran.";
        return StatutPaiementBloc(
          key: cleStatutPaiement,
          etat: EtatPaiement.enAttente,
          titre: titre,
          texte: texte,
          note: note,
          lu: '$titre. $texte $note',
        );
      case EtapePaiement.confirme:
        final c = p.confirmation!;
        final maintenant = ref.read(horlogeMuraleProvider)();
        final actif = "${p.offre.libelleActif} jusqu'au ${formaterJourMois(c.finDroit, maintenant)}";
        return StatutPaiementBloc(
          key: cleStatutPaiement,
          etat: EtatPaiement.confirme,
          etiquette: 'Paiement confirmé',
          titre: '✓ $actif',
          texte: p.offre.debloqueConfirme,
          lu: 'Paiement confirmé. $actif. ${p.offre.debloqueConfirme}',
        );
      case EtapePaiement.echoue:
      case EtapePaiement.introuvable:
        const titre = "Aucun droit activé";
        final cause = p.etape == EtapePaiement.echoue
            ? "$moyen n'a pas confirmé le paiement."
            : 'Le statut de ce paiement est introuvable.';
        final texte =
            '$cause Si un montant a été débité, le pass s\'activera dès la confirmation, sans action de votre part.';
        return StatutPaiementBloc(
          key: cleStatutPaiement,
          etat: EtatPaiement.echoue,
          etiquette: 'Paiement non confirmé',
          titre: titre,
          texte: texte,
          lu: 'Paiement non confirmé. $titre. $texte',
        );
    }
  }

  List<Widget> _apresConfirmation(PaiementEnCours p) {
    final c = p.confirmation!;
    final maintenant = ref.read(horlogeMuraleProvider)();
    final fin =
        'Fin du pass : ${formaterJourHeure(c.finDroit, maintenant)}. Ensuite, retour au palier Gratuit ; '
        'vos courses et réglages sont conservés.';
    return [
      Text(fin, style: JetonsAuth.meta),
      if (p.offre.duo) ...[const SizedBox(height: 6), const Text(noteDuo, style: JetonsAuth.meta)],
    ];
  }

  List<Widget> _barre(PaiementEnCours? suivi) {
    switch (suivi?.etape) {
      case null:
        final autreEnCours = ref.watch(paiementEnCoursProvider)?.enCours ?? false;
        final moyen = _moyen;
        final peutPayer = moyen != null && _numeroValide && _erreurNumero == null && !autreEnCours;
        return [CtaPrimaire(texte: 'Payer', onPressed: peutPayer ? () => _payer(moyen, _local) : null)];
      case EtapePaiement.initiation:
        return const [CtaPrimaire(texte: 'Paiement en cours…')];
      case EtapePaiement.enAttente:
        return [
          const CtaPrimaire(texte: 'Paiement en cours…'),
          CtaFantome(texte: widget.libelleRetour, onPressed: _revenirAuProfil),
        ];
      case EtapePaiement.confirme:
        return [CtaPrimaire(texte: widget.libelleRetour, onPressed: _revenirAuProfil)];
      case EtapePaiement.echoue:
      case EtapePaiement.introuvable:
        final p = suivi!;
        return [
          Row(
            children: [
              Expanded(child: CtaPrimaire(texte: 'Réessayer', onPressed: () => _payer(p.moyen, p.numero))),
              const SizedBox(width: 8),
              Expanded(child: CtaFantome(texte: 'Changer de moyen', onPressed: _changerDeMoyen)),
            ],
          ),
        ];
    }
  }
}

/// Résumé de l'offre : Offre, Durée, Prix (carte surface-2).
class _Resume extends StatelessWidget {
  final Offre offre;
  const _Resume(this.offre);

  @override
  Widget build(BuildContext context) {
    Widget ligne(String cle, String valeur, {bool derniere = false}) => Semantics(
      label: '$cle, $valeur',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          border: derniere ? null : const Border(bottom: BorderSide(color: JetonsAuth.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cle, style: const TextStyle(fontSize: 12.5, color: JetonsAuth.muted)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                valeur,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12.5, color: JetonsAuth.text, fontFeatures: JetonsAuth.tabulaire),
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: JetonsAuth.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: JetonsAuth.lineCard),
      ),
      child: Column(
        children: [
          ligne('Offre', offre.nom),
          ligne('Durée', offre.libelleDuree),
          ligne('Prix', formaterPrix(offre.prixFcfa), derniere: true),
        ],
      ),
    );
  }
}

/// Choix du moyen : toute la ligne (≥ 56dp) est la cible ; sélection
/// écrite « Sélectionné » + bordure 2px `text`, jamais d'or. Sans [onTap]
/// (paiement suivi), lecture seule.
class _OptionMoyen extends StatelessWidget {
  final MoyenPaiement moyen;
  final bool selectionne;
  final VoidCallback? onTap;
  const _OptionMoyen({required this.moyen, required this.selectionne, this.onTap});

  @override
  Widget build(BuildContext context) {
    final nom = libelleMoyen(moyen);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: onTap != null,
        selected: selectionne,
        label: selectionne ? '$nom, sélectionné' : nom,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: JetonsAuth.surface2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: selectionne ? JetonsAuth.text : JetonsAuth.lineCard, width: selectionne ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  RepereSelection(selectionne: selectionne),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nom,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: selectionne || onTap != null ? JetonsAuth.text : JetonsAuth.muted,
                      ),
                    ),
                  ),
                  if (selectionne)
                    Text(
                      'Sélectionné'.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: .6,
                        fontWeight: FontWeight.w700,
                        color: JetonsAuth.text,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
