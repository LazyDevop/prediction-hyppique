import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/auth_api.dart' show JetonGestionAppareils;
import '../data/remote/compte_api.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/cadre_auth.dart';
import 'mes_appareils_screen.dart';

/// Appareil bloqué (story 8.6), porte rendue au-dessus de la pile : code
/// correct mais limite d'appareils du palier atteinte. Aucune session
/// n'est ouverte et aucun appareil n'a été déconnecté. « Retirer un
/// appareil » ouvre Mes appareils en accès limité ; « Découvrir l'offre
/// Duo » ne montre que du texte (aucun paiement).
///
/// La porte n'a pas de Navigator au-dessus d'elle : celui-ci, local, porte
/// les écrans de l'accès limité et les dialogues de confirmation.
class AppareilBloqueScreen extends ConsumerStatefulWidget {
  const AppareilBloqueScreen({super.key});

  @override
  ConsumerState<AppareilBloqueScreen> createState() => _AppareilBloqueScreenState();
}

class _AppareilBloqueScreenState extends ConsumerState<AppareilBloqueScreen> with RetourPorte {
  final _navigateur = GlobalKey<NavigatorState>();

  /// Retour système : dépile l'écran local ; à la racine, rien.
  @override
  void surRetour() => _navigateur.currentState?.maybePop();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigateur,
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const _VueBloquee()),
    );
  }
}

class _VueBloquee extends ConsumerStatefulWidget {
  const _VueBloquee();

  @override
  ConsumerState<_VueBloquee> createState() => _VueBloqueeState();
}

class _VueBloqueeState extends ConsumerState<_VueBloquee> {
  ListeAppareils? _liste;

  /// Pris avant tout `await` (l'issue ne dépend pas du montage).
  late final AuthNotifier _porte = ref.read(authProvider.notifier);
  late final JetonGestionAppareils? _jeton = ref.read(authProvider).value?.blocage?.jeton;
  Timer? _expiration;

  /// Écran poussé en cours d'ouverture : un double toucher n'en ouvre qu'un.
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    final jeton = _jeton;
    if (jeton != null) {
      final reste = jeton.expireLe.difference(ref.read(horlogeMuraleProvider)());
      _expiration = Timer(reste.isNegative ? Duration.zero : reste, _delaiDepasse);
    }
    _charger();
  }

  @override
  void dispose() {
    _expiration?.cancel();
    super.dispose();
  }

  void _delaiDepasse() {
    _expiration?.cancel();
    _porte.quitterAppareilBloque(message: messageDelaiDepasse);
  }

  Future<void> _charger() async {
    final jeton = _jeton;
    if (jeton == null) return;
    final api = ref.read(compteApiProvider);
    try {
      final liste = await api.listerAppareilsRestreint(jeton);
      if (mounted) setState(() => _liste = liste);
    } on AccesRestreintRefuse {
      _delaiDepasse();
    } catch (_) {
      // Liste facultative ici : Mes appareils (accès limité) gère l'erreur.
    }
  }

  Future<void> _pousser(Widget ecran) async {
    if (_occupe) return;
    _occupe = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran));
    } finally {
      _occupe = false;
    }
    if (mounted) _charger();
  }

  @override
  Widget build(BuildContext context) {
    final blocage = ref.watch(authProvider).value?.blocage;
    final limite = blocage?.limite ?? LIMITE_APPAREILS_PROVISOIRE;
    final liste = _liste;
    return CadreAuth(
      enfants: [
        const EnTeteAuth(titre: 'Appareil bloqué'),
        const SizedBox(height: 14),
        Text('Limite de $limite appareils atteinte', style: JetonsAuth.lead),
        const SizedBox(height: 6),
        Text(
          'Votre palier permet $limite appareils, déjà utilisés. Cet appareil n\'a pas été rattaché.',
          style: JetonsAuth.sub,
        ),
        const SizedBox(height: 6),
        const Text(
          "Aucun appareil n'a été déconnecté.",
          style: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w700, color: JetonsAuth.text),
        ),
        if (liste != null) ListeAppareilsLecture(liste: liste, maintenant: ref.watch(horlogeMuraleProvider)()),
        const SizedBox(height: 10),
        const BandeauStatut(
          child: Text(
            "ℹ️ Pour utiliser cet appareil, retirez un appareil. L'offre Duo, elle, donne à un proche son propre compte et ses propres appareils.",
          ),
        ),
        const Spacer(),
        const SizedBox(height: 16),
        CtaPrimaire(
          texte: 'Retirer un appareil',
          onPressed: blocage == null ? null : () => _pousser(MesAppareilsScreen(jetonRestreint: blocage.jeton)),
        ),
        const SizedBox(height: 8),
        CtaFantome(texte: "Découvrir l'offre Duo", onPressed: () => _pousser(const _OffreDuo())),
        LienAuth(
          texte: 'Se connecter avec un autre numéro',
          onPressed: () => ref.read(authProvider.notifier).quitterAppareilBloque(),
        ),
      ],
    );
  }
}

/// Offre Duo, texte seul : aucun prix, aucun paiement (Epic 9).
class _OffreDuo extends StatelessWidget {
  const _OffreDuo();

  @override
  Widget build(BuildContext context) {
    return CadreAuth(
      enfants: [
        EnTeteAuth(titre: 'Offre Duo', onRetour: () => Navigator.of(context).maybePop()),
        const SizedBox(height: 14),
        const Text("L'offre Duo", style: JetonsAuth.lead),
        const SizedBox(height: 6),
        const Text(
          "L'offre Duo donne à un proche son propre compte et ses propres appareils, au même palier que vous.",
          style: JetonsAuth.sub,
        ),
        const SizedBox(height: 12),
        const BandeauStatut(child: Text('Souscrivez depuis un appareil déjà connecté.')),
      ],
    );
  }
}
