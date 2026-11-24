import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/remote/appairage_api.dart';
import '../data/remote/auth_api.dart' show SessionOuverte;
import '../providers/auth_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/contour_focus.dart';
import 'connexion_screen.dart' show messageErreur;

const messageQrExpire = 'Code expiré';
const messageAppairageRefuse = 'Connexion refusée sur le téléphone';
const messageCreationAppairage = "Impossible d'afficher un QR code — vérifiez votre connexion.";
const libelleSimulerApprobation = "Mode démo : simuler l'approbation du téléphone";

/// Bandeau permanent de la porte web (maquette web-compagnon, état 2).
const bandeauConnexionPorte =
    " — pas de mode hors ligne. Elle propose les mêmes fonctions que l'app du téléphone, aucune de plus.";

/// « 2 min », « 1 min 05 s », « 45 s » (secondes arrondies au-dessus).
String formaterRestant(Duration restant) {
  final s = restant.isNegative ? 0 : (restant.inMilliseconds + 999) ~/ 1000;
  final m = s ~/ 60;
  final r = s % 60;
  if (m == 0) return '$r s';
  if (r == 0) return '$m min';
  return '$m min ${r.toString().padLeft(2, '0')} s';
}

enum _Fin { expire, refuse }

/// Connexion web par QR code (story 8.7, FR-37, `qr-pairing`) : le
/// téléphone déjà connecté scanne et approuve ; [onCodeSms] ouvre la
/// Connexion par code SMS. Le statut est sondé toutes les
/// [intervalleSondageAppairage] ; le temps restant est écrit et mis à jour.
class AppairageScreen extends ConsumerStatefulWidget {
  final VoidCallback onCodeSms;
  const AppairageScreen({super.key, required this.onCodeSms});

  @override
  ConsumerState<AppairageScreen> createState() => _AppairageScreenState();
}

class _AppairageScreenState extends ConsumerState<AppairageScreen> {
  late final Duration Function() _monotone;
  late final AppairageApi _api;
  late final AuthNotifier _auth;

  Appairage? _appairage;

  /// Instant (horloge monotone) de réception de [_appairage] : le temps
  /// restant est sa validité moins le temps écoulé depuis.
  Duration _recuA = Duration.zero;
  bool _creation = false;
  bool _erreurCreation = false;
  _Fin? _fin;
  bool _sondageEnVol = false;
  bool _ouverture = false;

  /// Échec de l'ouverture de session : message affiché avec le nouveau QR.
  String? _erreurOuverture;

  /// Incrémentée à chaque nouveau QR : un refus ou une expiration d'un
  /// ancien QR est ignoré (jamais une approbation, voir [_sonder]).
  int _generation = 0;
  Timer? _sondage;
  Timer? _decompte;

  @override
  void initState() {
    super.initState();
    _monotone = ref.read(horlogeMonotoneProvider);
    _api = ref.read(appairageApiProvider);
    _auth = ref.read(authProvider.notifier);
    _creer();
  }

  @override
  void dispose() {
    _arreter();
    super.dispose();
  }

  void _arreter() {
    _sondage?.cancel();
    _decompte?.cancel();
    _sondage = null;
    _decompte = null;
  }

  Future<void> _creer({String? message}) async {
    if (_creation || _ouverture) return;
    _arreter();
    final generation = ++_generation;
    setState(() {
      _creation = true;
      _erreurCreation = false;
      _erreurOuverture = message;
      _fin = null;
      _appairage = null;
    });
    Appairage? appairage;
    try {
      appairage = await _api.creer();
    } catch (_) {
      appairage = null;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _creation = false;
      _appairage = appairage;
      _recuA = _monotone();
      _erreurCreation = appairage == null;
    });
    if (appairage == null) return;
    _sondage = Timer.periodic(intervalleSondageAppairage, (_) => _sonder());
    _decompte = Timer.periodic(const Duration(seconds: 1), (_) => _tic());
  }

  Duration _restant() {
    final a = _appairage;
    return a == null ? Duration.zero : a.validite - (_monotone() - _recuA);
  }

  void _tic() {
    if (!mounted || _fin != null || _ouverture) return;
    if (_restant() <= Duration.zero) {
      _terminer(_Fin.expire);
    } else {
      setState(() {});
    }
  }

  void _terminer(_Fin fin) {
    _arreter();
    setState(() => _fin = fin);
  }

  Future<void> _sonder() async {
    final a = _appairage;
    if (a == null || _sondageEnVol || _fin != null || _ouverture) return;
    final generation = _generation;
    _sondageEnVol = true;
    StatutAppairage? statut;
    try {
      statut = await _api.statut(a.id);
    } catch (_) {
      statut = null; // nouvel essai au prochain intervalle
    } finally {
      _sondageEnVol = false;
    }
    // Une approbation n'est jamais perdue : le téléphone a déjà rattaché ce
    // navigateur, même si l'écran a été quitté (code SMS) ou un nouveau QR
    // demandé entre-temps.
    switch (statut) {
      case AppairageApprouve(:final session):
        await _ouvrir(session);
        return;
      case AppairageBloque(:final blocage):
        _arreter();
        _auth.bloquerAppairage(blocage);
        return;
      default:
        break;
    }
    if (!mounted || generation != _generation || _fin != null || _ouverture) return;
    switch (statut) {
      case AppairageRefuse():
        _terminer(_Fin.refuse);
      case AppairageExpire():
        _terminer(_Fin.expire);
      default:
        break;
    }
  }

  Future<void> _ouvrir(SessionOuverte session) async {
    _arreter();
    // Un nouveau QR demandé entre-temps ne doit plus rien lancer.
    _generation++;
    if (mounted) {
      setState(() {
        _creation = false;
        _ouverture = true;
      });
    }
    try {
      await _auth.ouvrirSessionAppairee(session);
      // La porte remplace cet écran par l'Accueil.
    } catch (_) {
      if (!mounted) return;
      setState(() => _ouverture = false);
      // Un seul état : le message et un nouveau QR (l'ancien a servi).
      await _creer(message: messageErreur);
    }
  }

  void _simulerApprobation() {
    final a = _appairage;
    final api = _api;
    if (a == null || _fin != null || _ouverture || api is! FauxAppairageApi) return;
    api.approuverDemo(a.id);
    _sonder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JetonsAuth.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EnTeteWeb(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: BandeauConnexionWeb(suite: bandeauConnexionPorte),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: JetonsAuth.surface,
                        border: Border.all(color: JetonsAuth.lineCard),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final large = c.maxWidth >= 640;
                          final qr = _blocQr();
                          final texte = _blocTexte();
                          return large
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    qr,
                                    const SizedBox(width: 32),
                                    Expanded(child: texte),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Center(child: qr),
                                    const SizedBox(height: 22),
                                    texte,
                                  ],
                                );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _tailleQr = 240.0;

  Widget _cadreQr(Widget child) => Container(
    key: const Key('cadre-qr'),
    width: _tailleQr,
    height: _tailleQr,
    decoration: BoxDecoration(
      border: Border.all(color: JetonsAuth.lineCard),
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
    alignment: Alignment.center,
    child: child,
  );

  Widget _blocQr() {
    final a = _appairage;
    if (_erreurCreation) {
      return _cadreQr(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(messageCreationAppairage, style: JetonsAuth.sub, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ContourFocus(
                child: CtaFantome(texte: 'Réessayer', onPressed: _creer),
              ),
            ],
          ),
        ),
      );
    }
    if (a == null || _creation) {
      return _cadreQr(
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: JetonsAuth.muted),
        ),
      );
    }
    if (_fin != null) {
      // Plus de QR lisible : un code expiré ou refusé ne doit pas être scanné.
      return _cadreQr(
        Text(
          _fin == _Fin.refuse ? messageAppairageRefuse : messageQrExpire,
          style: JetonsAuth.sub,
          textAlign: TextAlign.center,
        ),
      );
    }
    // `qr-pairing` : modules `bg` sur zone calme `text` (DESIGN.md Colors),
    // zone calme d'au moins 4 modules de chaque côté.
    final validation = QrValidator.validate(
      data: a.contenuQr,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    );
    final code = validation.qrCode;
    if (code == null) return _cadreQr(const Text(messageCreationAppairage, style: JetonsAuth.sub));
    const cote = _tailleQr - 2; // dans le cadre bordé
    final zoneCalme = (4 * cote / (code.moduleCount + 8)).ceilToDouble();
    return _cadreQr(
      Container(
        key: const Key('zone-calme-qr'),
        width: cote,
        height: cote,
        color: JetonsAuth.text,
        padding: EdgeInsets.all(zoneCalme),
        child: QrImageView.withQr(
          key: const Key('qr-appairage'),
          qr: code,
          padding: EdgeInsets.zero,
          backgroundColor: JetonsAuth.text,
          semanticsLabel: 'QR code de connexion, valable ${dureeAppairage.inMinutes} minutes',
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: JetonsAuth.bg),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: JetonsAuth.bg),
        ),
      ),
    );
  }

  Widget _blocTexte() {
    final fin = _fin;
    final enCours = _appairage != null && fin == null && !_creation && !_erreurCreation;
    final demo = ref.watch(modeDemoAppairageProvider);
    // Échec d'ouverture de session, ou message de la porte (session
    // effacée, accès limité terminé).
    final message = _erreurOuverture ?? ref.watch(authProvider).value?.message;
    final nom = _appairage?.nomAppareil ?? 'ce navigateur';
    const gras = TextStyle(fontWeight: FontWeight.w700, color: JetonsAuth.text);
    Widget etape(int n, InlineSpan texte) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: JetonsAuth.lineCard),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$n', style: const TextStyle(fontSize: 12, color: JetonsAuth.text)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text.rich(texte, style: JetonsAuth.sub)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: const Text('Connecter cet ordinateur', style: JetonsAuth.lead)),
        const SizedBox(height: 6),
        if (message != null) ...[
          BandeauStatut(fort: true, annonce: true, child: Text(message)),
          const SizedBox(height: 8),
        ],
        if (fin != null)
          BandeauStatut(
            fort: true,
            annonce: true,
            child: Text(fin == _Fin.refuse ? messageAppairageRefuse : messageQrExpire),
          )
        else
          Text(
            // Sans QR (création en cours ou en échec) : pas de temps restant.
            enCours
                ? "Scannez avec l'app sur votre téléphone · expire dans ${formaterRestant(_restant())}"
                : "Scannez avec l'app sur votre téléphone",
            key: const Key('temps-restant'),
            style: JetonsAuth.sub.copyWith(fontFeatures: JetonsAuth.tabulaire),
          ),
        const SizedBox(height: 6),
        etape(
          1,
          const TextSpan(
            children: [
              TextSpan(text: "Ouvrez l'app sur votre téléphone, déjà connectée, puis "),
              TextSpan(text: 'Profil → Scanner un QR code', style: gras),
              TextSpan(text: '.'),
            ],
          ),
        ),
        etape(2, const TextSpan(text: 'Visez ce QR code.')),
        etape(
          3,
          TextSpan(
            children: [
              TextSpan(text: 'Sur le téléphone, vérifiez le nom « $nom », puis appuyez sur '),
              TextSpan(text: 'Autoriser', style: gras),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "Le QR code ne sert qu'une fois. Cet ordinateur comptera parmi vos appareils.",
          style: JetonsAuth.meta,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ContourFocus(
              child: CtaFantome(
                texte: 'Afficher un nouveau QR code',
                onPressed: _creation || _ouverture ? null : _creer,
              ),
            ),
            ContourFocus(
              child: LienAuth(texte: 'Se connecter avec un code SMS', onPressed: _ouverture ? null : widget.onCodeSms),
            ),
          ],
        ),
        if (demo && enCours) ...[
          const SizedBox(height: 8),
          ContourFocus(
            child: LienAuth(texte: libelleSimulerApprobation, onPressed: _ouverture ? null : _simulerApprobation),
          ),
        ],
      ],
    );
  }
}

/// En-tête de la web app : « Analyseur Hippique », puis [enfants] (nav,
/// palier, Profil) quand une session est ouverte.
class EnTeteWeb extends StatelessWidget {
  final List<Widget> enfants;
  const EnTeteWeb({super.key, this.enfants = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        color: JetonsAuth.bg,
        border: Border(bottom: BorderSide(color: JetonsAuth.line)),
      ),
      child: Row(
        children: [
          Semantics(header: true, child: const MarqueAuth()),
          const SizedBox(width: 24),
          ...enfants,
        ],
      ),
    );
  }
}

/// `status-banner` neutre, permanent : « La web app nécessite une
/// connexion » puis [suite].
class BandeauConnexionWeb extends StatelessWidget {
  final String suite;
  const BandeauConnexionWeb({super.key, required this.suite});

  @override
  Widget build(BuildContext context) {
    return BandeauStatut(
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'ℹ️ '),
            const TextSpan(
              text: 'La web app nécessite une connexion',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: suite),
          ],
        ),
      ),
    );
  }
}
