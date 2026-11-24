import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/palier_provider.dart';
import '../providers/results_provider.dart';
import '../widgets/auth_styles.dart';
import 'appairage_screen.dart';
import 'appareil_bloque_screen.dart';
import 'connexion_screen.dart';
import 'deverrouillage_screen.dart';

/// Portes Connexion / Déverrouillage, rendues AVANT la pile de navigation
/// (branchée via `MaterialApp.builder`) : un verrouillage couvre aussi un
/// écran poussé (résultats, réglages…).
///
/// Aucune session → Connexion ; session sans PIN choisi dans ce lancement
/// → choix du PIN ; session verrouillée → Déverrouillage ; sinon
/// [application].
///
/// La pile (Accueil, appels réseau) n'est construite qu'à la première
/// ouverture, jamais derrière un Déverrouillage de démarrage à froid ; elle
/// est ensuite gardée hors écran (ni focus, ni animations) pendant les
/// re-verrouillages, pour conserver les écrans poussés.
class PorteScreen extends ConsumerStatefulWidget {
  final Widget application;

  /// Clé du Navigator de [application] : sert à bloquer le retour système
  /// vers la pile masquée pendant un re-verrouillage.
  final GlobalKey<NavigatorState>? navigatorKey;

  const PorteScreen({super.key, required this.application, this.navigatorKey});

  @override
  ConsumerState<PorteScreen> createState() => _PorteScreenState();
}

class _PorteScreenState extends ConsumerState<PorteScreen> {
  late final AppLifecycleListener _cycleDeVie;
  bool _applicationConstruite = false;
  final _blocage = _BlocageRetour();
  ModalRoute<Object?>? _routeBloquee;

  /// Web : Connexion par code SMS choisie à la place du QR code.
  bool _parSms = false;

  @override
  void initState() {
    super.initState();
    _cycleDeVie = AppLifecycleListener(
      onHide: () => ref.read(authProvider.notifier).passerEnArrierePlan(),
      onShow: () {
        ref.read(authProvider.notifier).revenirAuPremierPlan();
        // Sans effet si la porte vient de se verrouiller.
        ref.read(palierProvider.notifier).actualiser();
      },
    );
  }

  @override
  void dispose() {
    _debloquerRetour();
    _cycleDeVie.dispose();
    super.dispose();
  }

  /// La porte est au-dessus du Navigator : le retour système irait dépiler
  /// la pile masquée. On pose un `PopEntry` refusant le retour sur la route
  /// du dessus tant que la porte est affichée.
  ///
  /// Revérifié à chaque image : si la route bloquée n'est plus celle du
  /// dessus (dépilée ou recouverte pendant le verrouillage), le blocage
  /// passe sur la nouvelle route du dessus.
  void _bloquerRetour() {
    final nav = widget.navigatorKey?.currentState;
    if (nav == null) return;
    ModalRoute<Object?>? dessus;
    nav.popUntil((route) {
      if (route is ModalRoute<Object?>) dessus = route;
      return true; // ne dépile rien : lit seulement la route du dessus
    });
    final bloquee = _routeBloquee;
    if (bloquee != null && identical(bloquee, dessus) && bloquee.isActive) return;
    _debloquerRetour();
    dessus?.registerPopEntry(_blocage);
    _routeBloquee = dessus;
  }

  void _debloquerRetour() {
    final bloquee = _routeBloquee;
    if (bloquee != null && bloquee.isActive) bloquee.unregisterPopEntry(_blocage);
    _routeBloquee = null;
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(authProvider);
    // La porte est toujours visible : ces providers ne sont jamais en pause
    // (écran recouvert, pile masquée) et suivent compte et droit en continu.
    ref.listen(palierProvider, (_, _) {});
    ref.listen(resultsProvider, (_, _) {});
    // Stockage illisible : on repart de Connexion plutôt que de bloquer.
    final porte = etat.hasError && !etat.hasValue ? Porte.aucuneSession : etat.value?.porte;

    if (porte == Porte.ouverte) _applicationConstruite = true;
    if (porte == Porte.aucuneSession || porte == Porte.choixPin || porte == Porte.appareilBloque) {
      _applicationConstruite = false;
    }

    // Web (story 8.7) : appairage par QR code d'abord, Connexion par code
    // SMS en repli. Le choix vient de l'utilisateur seulement (jamais du
    // message de la porte, effacé pendant la saisie) ; un message (session
    // effacée, accès limité terminé) s'affiche sur l'écran d'appairage.
    if (porte != Porte.aucuneSession) _parSms = false;
    final appairagePossible = ref.watch(estWebProvider) && ref.watch(appairageDisponibleProvider);
    final parQr = appairagePossible && !_parSms;

    final Widget? ecranPorte = switch (porte) {
      null => const Scaffold(backgroundColor: JetonsAuth.bg),
      Porte.aucuneSession when parQr => AppairageScreen(onCodeSms: () => setState(() => _parSms = true)),
      Porte.aucuneSession => ConnexionScreen(
          onAppairage: appairagePossible
              ? () {
                  ref.read(authProvider.notifier).effacerMessage();
                  setState(() => _parSms = false);
                }
              : null,
        ),
      Porte.choixPin => const ChoixPinScreen(),
      Porte.verrouillee => const DeverrouillageScreen(),
      Porte.appareilBloque => const AppareilBloqueScreen(),
      Porte.ouverte => null,
    };
    final masquee = ecranPorte != null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_applicationConstruite) {
        // Pile détruite (session effacée) : sa route n'existe plus.
        _routeBloquee = null;
      } else if (masquee) {
        _bloquerRetour();
      } else {
        _debloquerRetour();
      }
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_applicationConstruite)
          KeyedSubtree(
            key: const ValueKey('application'),
            child: Offstage(
              offstage: masquee,
              child: TickerMode(
                enabled: !masquee,
                child: ExcludeFocus(excluding: masquee, child: widget.application),
              ),
            ),
          ),
        if (ecranPorte != null)
          KeyedSubtree(
            key: ValueKey(porte),
            // Overlay propre : la porte est au-dessus du Navigator, les
            // champs texte et infobulles en ont besoin.
            child: Overlay.wrap(child: ecranPorte),
          ),
      ],
    );
  }
}

class _BlocageRetour extends PopEntry<Object?> {
  static final _jamais = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get canPopNotifier => _jamais;

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {}
}
