import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/auth_api.dart' show JetonGestionAppareils, dureeJetonGestion;
import '../data/remote/compte_api.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/cadre_auth.dart';
import '../widgets/device_row.dart';
import '../widgets/settings_row.dart';
import 'connexion_screen.dart' show messageErreur;

const messageChargementAppareils = 'Impossible de charger vos appareils.';
const messageDelaiDepasse = 'Délai dépassé — reconnectez-vous pour réessayer';
const messageTropDeTentatives =
    "Trop de tentatives aujourd'hui — réessayez demain, ou retirez un appareil depuis un appareil connecté";

String messageAppareilRetire(String nom) => '$nom a été retiré. Reconnectez-vous pour utiliser cet appareil.';

/// Mes appareils (story 8.6) : liste, « Cet appareil », « Nouveau »,
/// retrait des autres appareils avec confirmation.
///
/// Avec [jetonRestreint] (depuis Appareil bloqué) : accès limité — liste et
/// UN retrait pendant 10 minutes, rien d'autre ; après le retrait (ou à
/// l'expiration du jeton), retour à Connexion avec un message.
class MesAppareilsScreen extends ConsumerStatefulWidget {
  final JetonGestionAppareils? jetonRestreint;
  const MesAppareilsScreen({super.key, this.jetonRestreint});

  @override
  ConsumerState<MesAppareilsScreen> createState() => _MesAppareilsScreenState();
}

class _MesAppareilsScreenState extends ConsumerState<MesAppareilsScreen> {
  ListeAppareils? _liste;
  bool _erreurChargement = false;

  /// Vrai dès le premier toucher sur « Retirer » (avant la confirmation) :
  /// un double toucher n'ouvre qu'un dialogue, et le retour est bloqué
  /// pendant le retrait.
  bool _enCours = false;
  String? _message;

  /// Pris avant tout `await` : l'issue de l'accès limité ne dépend pas du
  /// montage de l'écran.
  late final AuthNotifier _porte = ref.read(authProvider.notifier);
  late final CompteApi _api = ref.read(compteApiProvider);
  Timer? _expiration;

  JetonGestionAppareils? get _jeton => widget.jetonRestreint;
  bool get _restreint => _jeton != null;

  @override
  void initState() {
    super.initState();
    final jeton = _jeton;
    if (jeton != null) {
      final reste = jeton.expireLe.difference(ref.read(horlogeMuraleProvider)());
      _expiration = Timer(reste.isNegative ? Duration.zero : reste, () => _quitter(messageDelaiDepasse));
    }
    _charger();
  }

  @override
  void dispose() {
    _expiration?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    if (_erreurChargement) setState(() => _erreurChargement = false);
    final jeton = _jeton;
    try {
      final liste = jeton == null ? await _api.listerAppareils() : await _api.listerAppareilsRestreint(jeton);
      if (mounted) setState(() => _liste = liste);
    } on AccesRestreintRefuse {
      _quitter(messageDelaiDepasse);
    } catch (_) {
      if (mounted) setState(() => _erreurChargement = true);
    }
  }

  void _quitter(String message) {
    _expiration?.cancel();
    _porte.quitterAppareilBloque(message: message);
  }

  Future<void> _retirer(Appareil a) async {
    if (_enCours) return;
    setState(() {
      _enCours = true;
      _message = null;
    });
    final ok = await confirmer(
      context,
      titre: 'Retirer ${a.nom} ?',
      texte: 'Il sera déconnecté et une alerte partira vers votre numéro.',
      action: 'Retirer',
    );
    if (!ok) {
      if (mounted) setState(() => _enCours = false);
      return;
    }
    final jeton = _jeton;
    if (jeton != null) return _retirerRestreint(jeton, a);
    try {
      await _api.retirerAppareil(a.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _message = messageErreur;
        });
      }
      return;
    }
    // Retrait fait : un échec du rechargement ne l'annule pas.
    ListeAppareils? liste;
    try {
      liste = await _api.listerAppareils();
    } catch (_) {
      liste = null;
    }
    if (!mounted) return;
    setState(() {
      final avant = _liste;
      _liste =
          liste ??
          (avant == null
              ? null
              : ListeAppareils(
                  appareils: avant.appareils.where((x) => x.id != a.id).toList(),
                  limite: avant.limite,
                  palier: avant.palier,
                ));
      _message = '${a.nom} a été retiré.';
      _enCours = false;
    });
  }

  Future<void> _retirerRestreint(JetonGestionAppareils jeton, Appareil a) async {
    RetraitRestreintResultat r;
    try {
      r = await _api.retirerAppareilRestreint(jeton, a.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _message = messageErreur;
        });
      }
      return;
    }
    switch (r) {
      case AppareilRetire(nom: final nom):
        _quitter(messageAppareilRetire(nom));
      case AccesRestreintExpire():
        _quitter(messageDelaiDepasse);
      case TropDeTentativesAujourdhui():
        _quitter(messageTropDeTentatives);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = _liste;
    final maintenant = ref.watch(horlogeMuraleProvider)();
    return PopScope(
      canPop: !_enCours,
      child: CadreAuth(
        enfants: [
          EnTeteAuth(titre: 'Mes appareils', onRetour: _enCours ? null : () => Navigator.of(context).maybePop()),
          if (_restreint) ...[
            const SizedBox(height: 14),
            const Text('Retirez un appareil pour connecter celui-ci', style: JetonsAuth.lead),
            const SizedBox(height: 6),
            Text(
              'Accès limité : un seul retrait, pendant ${dureeJetonGestion.inMinutes} minutes.',
              style: JetonsAuth.sub,
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 10),
            BandeauStatut(fort: true, annonce: true, child: Text(_message!)),
          ],
          if (liste == null && _erreurChargement) ...[
            const SizedBox(height: 12),
            const BandeauStatut(fort: true, annonce: true, child: Text(messageChargementAppareils)),
            const SizedBox(height: 10),
            CtaFantome(texte: 'Réessayer', onPressed: _charger),
          ] else if (liste == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._contenu(liste, maintenant),
        ],
      ),
    );
  }

  List<Widget> _contenu(ListeAppareils liste, DateTime maintenant) {
    final nouveaux = _restreint ? const <Appareil>[] : liste.appareils.where((a) => a.nouveau && !a.estCourant);
    return [
      const SizedBox(height: 10),
      Semantics(
        container: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text('Appareils rattachés'.toUpperCase(), style: JetonsAuth.label)),
            const SizedBox(width: 10),
            Flexible(
              flex: 2,
              child: Text.rich(
                textAlign: TextAlign.right,
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${liste.appareils.length}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' sur ${liste.limite} · limite du palier ${liste.palier}'),
                  ],
                ),
                style: const TextStyle(fontSize: 13, color: JetonsAuth.text, fontFeatures: JetonsAuth.tabulaire),
              ),
            ),
          ],
        ),
      ),
      for (final a in nouveaux) ...[
        const SizedBox(height: 10),
        BandeauStatut(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'ℹ️ Nouvel appareil rattaché : '),
                TextSpan(
                  text: a.nom,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ', ${formaterJourHeure(a.rattacheLe, maintenant)}. Ce n\'est pas vous ? Retirez-le.'),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 4),
      for (final a in liste.appareils)
        LigneAppareil(
          appareil: a,
          maintenant: maintenant,
          // L'appareil courant ne se retire pas ici (« Se déconnecter »).
          onRetirer: a.estCourant || _enCours ? null : () => _retirer(a),
        ),
      if (!_restreint) ...[
        const SizedBox(height: 12),
        const Text(
          'Chaque navigateur connecté compte comme un appareil. Retirer un appareil le déconnecte tout de suite ; '
          'il devra se reconnecter par code SMS.',
          style: JetonsAuth.meta,
        ),
      ],
    ];
  }
}

/// Section « Appareils rattachés » en lecture seule (Appareil bloqué).
class ListeAppareilsLecture extends StatelessWidget {
  final ListeAppareils liste;
  final DateTime maintenant;
  const ListeAppareilsLecture({super.key, required this.liste, required this.maintenant});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TitreSection('Appareils rattachés'),
        for (final a in liste.appareils) LigneAppareil(appareil: a, maintenant: maintenant, marques: false),
      ],
    );
  }
}
