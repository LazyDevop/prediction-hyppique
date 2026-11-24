import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/pin_hash.dart';
import '../data/remote/auth_api.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/cadre_auth.dart';
import '../widgets/otp_field.dart';
import '../widgets/pin_pad.dart';

const messageCodeExpire = 'Code expiré — demandez un nouveau code';
const messageTropDEssais = "Trop d'essais — demandez un nouveau code";
const messageTropDeDemandes = 'Trop de demandes — réessayez dans quelques minutes';
const messageNumeroInvalide = 'Numéro invalide : un mobile camerounais a 9 chiffres et commence par 6.';
const messageErreur = 'Une erreur est survenue — réessayez';

/// Délai avant de pouvoir redemander un code.
const delaiRenvoi = Duration(seconds: 60);

/// `+237` suivi de 9 chiffres commençant par 6 (mobile camerounais).
final numeroMobileLocal = RegExp(r'^6\d{8}$');

/// « 677123456 » → « 6 77 12 34 56 ».
String formaterNumeroLocal(String local) {
  if (local.length != 9) return local;
  return '${local[0]} ${local.substring(1, 3)} ${local.substring(3, 5)} ${local.substring(5, 7)} ${local.substring(7)}';
}

/// Normalise une saisie ou un collage vers les 9 chiffres locaux : retire
/// espaces et séparateurs, l'indicatif (`+237`, `00237`, `237` devant un
/// numéro complet) et le 0 initial, puis borne à 9 chiffres.
String normaliserNumero(String brut) {
  final avecPlus = brut.trimLeft().startsWith('+');
  var chiffres = brut.replaceAll(RegExp(r'\D'), '');
  if (avecPlus && chiffres.startsWith('237')) {
    chiffres = chiffres.substring(3);
  } else if (chiffres.startsWith('00237')) {
    chiffres = chiffres.substring(5);
  } else if (chiffres.startsWith('237') && chiffres.length >= 12) {
    chiffres = chiffres.substring(3);
  }
  chiffres = chiffres.replaceFirst(RegExp(r'^0+'), '');
  return chiffres.length > 9 ? chiffres.substring(0, 9) : chiffres;
}

class FormatNumero extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue ancien, TextEditingValue nouveau) {
    final local = normaliserNumero(nouveau.text);
    if (local == nouveau.text) return nouveau;
    return TextEditingValue(text: local, selection: TextSelection.collapsed(offset: local.length));
  }
}

enum _Etape { numero, code }

/// Connexion, étapes 1 (numéro + CGU) et 2 (code reçu). L'étape 3 (choix
/// du PIN) est [ChoixPinScreen], ouverte par la porte une fois la session
/// enregistrée.
class ConnexionScreen extends ConsumerStatefulWidget {
  /// Web (story 8.7) : retour à l'écran d'appairage par QR code ; absent
  /// sur le téléphone.
  final VoidCallback? onAppairage;

  const ConnexionScreen({super.key, this.onAppairage});

  @override
  ConsumerState<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends ConsumerState<ConnexionScreen> with RetourPorte {
  _Etape _etape = _Etape.numero;
  final _numeroCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String _dernierNumeroSaisi = '';
  bool _cguAcceptees = false;
  bool _enCours = false;
  String? _erreurNumero;
  String? _messageNumero;
  String? _erreurCode;

  /// Numéro E.164 de la demande en cours, figé au moment de la demande.
  String? _numeroDemande;
  int _renvoiDans = 0;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _numeroCtrl.addListener(_surNumero);
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _numeroCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Retour système : étape 2 → étape 1 ; étape 1 → QR code (web) ou rien
  /// (pas de pile).
  @override
  void surRetour() {
    if (_enCours) return;
    if (_etape == _Etape.code) {
      setState(_retourNumero);
    } else {
      widget.onAppairage?.call();
    }
  }

  void _surNumero() {
    if (_numeroCtrl.text == _dernierNumeroSaisi) return;
    _dernierNumeroSaisi = _numeroCtrl.text;
    setState(() {
      _erreurNumero = null;
      _messageNumero = null;
    });
    ref.read(authProvider.notifier).effacerMessage();
  }

  String get _local => _numeroCtrl.text;

  void _lancerMinuteur() {
    _minuteur?.cancel();
    _renvoiDans = delaiRenvoi.inSeconds;
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _renvoiDans--);
      if (_renvoiDans <= 0) t.cancel();
    });
  }

  Future<void> _demanderCode({bool renvoi = false}) async {
    if (!renvoi && !numeroMobileLocal.hasMatch(_local)) {
      setState(() => _erreurNumero = messageNumeroInvalide);
      return;
    }
    final numero = renvoi ? _numeroDemande! : '+237$_local';
    setState(() {
      _enCours = true;
      _messageNumero = null;
      _erreurCode = null;
    });
    ref.read(authProvider.notifier).effacerMessage();
    DemandeCodeResultat? resultat;
    try {
      resultat = await ref.read(authProvider.notifier).demanderCode(numero);
    } catch (_) {
      resultat = null;
    }
    if (!mounted) return;
    setState(() {
      _enCours = false;
      switch (resultat) {
        case CodeEnvoye():
          _etape = _Etape.code;
          _numeroDemande = numero;
          _codeCtrl.clear();
          _lancerMinuteur();
        case TropDeDemandes():
          _afficher(messageTropDeDemandes, renvoi: renvoi);
        case null:
          _afficher(messageErreur, renvoi: renvoi);
      }
    });
  }

  void _afficher(String message, {required bool renvoi}) {
    if (renvoi) {
      _erreurCode = message;
    } else {
      _messageNumero = message;
    }
  }

  Future<void> _verifierCode() async {
    final numero = _numeroDemande!;
    final code = _codeCtrl.text;
    setState(() {
      _enCours = true;
      _erreurCode = null;
    });
    VerificationResultat? resultat;
    try {
      resultat = await ref.read(authProvider.notifier).verifierCode(numero, code);
    } catch (_) {
      resultat = null;
    }
    if (!mounted) return;
    setState(() {
      _enCours = false;
      switch (resultat) {
        case SessionOuverte():
          // La porte affiche la suite (choix du PIN, ou Accueil sur le web).
          break;
        case AppareilBloque():
          // La porte affiche Appareil bloqué.
          break;
        case CodeIncorrect(essaisRestants: final n):
          _erreurCode = 'Code incorrect — ${essaisRestants(n)}';
          _codeCtrl.clear();
        case CodeExpire():
          _retourNumero(messageCodeExpire);
        case TropDEssais():
          _retourNumero(messageTropDEssais);
        case null:
          // Y compris une session écrite mais illisible ensuite.
          _erreurCode = messageErreur;
      }
    });
  }

  void _retourNumero([String? message]) {
    _minuteur?.cancel();
    _renvoiDans = 0;
    _etape = _Etape.numero;
    _messageNumero = message;
    _erreurCode = null;
    _codeCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_etape) {
      _Etape.numero => _construireNumero(context),
      _Etape.code => _construireCode(context),
    };
  }

  Widget _construireNumero(BuildContext context) {
    final messagePorte = ref.watch(authProvider).value?.message;
    final message = _messageNumero ?? messagePorte;
    final peutDemander = _cguAcceptees && _local.length == 9 && !_enCours;
    return CadreAuth(
      enfants: [
        const SizedBox(height: 24),
        const MarqueAuth(),
        const SizedBox(height: 18),
        const Text('Votre numéro de téléphone', style: JetonsAuth.lead),
        const SizedBox(height: 6),
        const Text(
          'Il sert à créer votre compte ou à vous reconnecter. Pas de mot de passe : vous recevrez un code par SMS.',
          style: JetonsAuth.sub,
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          BandeauStatut(fort: true, annonce: true, child: Text(message)),
        ],
        const SizedBox(height: 20),
        Text('Numéro de téléphone'.toUpperCase(), style: JetonsAuth.label),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                label: 'Numéro de téléphone',
                child: TextField(
                  controller: _numeroCtrl,
                  enabled: !_enCours,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  // Normalisation AVANT la borne à 9 chiffres (collage
                  // « +237 6 77 12 34 56 », « 0677123456 »…).
                  inputFormatters: [FormatNumero()],
                  style: const TextStyle(
                    fontSize: 17,
                    letterSpacing: .5,
                    color: JetonsAuth.text,
                    fontFeatures: JetonsAuth.tabulaire,
                  ),
                  decoration: decorationChampNumero(erreur: _erreurNumero),
                  onSubmitted: (_) {
                    if (peutDemander) _demanderCode();
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('9 chiffres, sans le 0 initial.', style: JetonsAuth.meta),
        const SizedBox(height: 12),
        _LigneCgu(cochee: _cguAcceptees, onChanged: (v) => setState(() => _cguAcceptees = v)),
        const Spacer(),
        const SizedBox(height: 16),
        CtaPrimaire(texte: 'Recevoir le code par SMS', onPressed: peutDemander ? _demanderCode : null),
        if (widget.onAppairage != null) ...[
          const SizedBox(height: 4),
          LienAuth(texte: 'Se connecter avec un QR code', onPressed: _enCours ? null : widget.onAppairage),
        ],
        const SizedBox(height: 14),
        const Divider(height: 1, color: JetonsAuth.lineDisclaimer),
        const SizedBox(height: 10),
        const Text(
          "Outil d'aide à la décision — l'outil ne place aucun pari et aucun modèle ne garantit un gain.",
          style: JetonsAuth.meta,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _construireCode(BuildContext context) {
    final modeDemo = ref.watch(modeDemoProvider);
    final saisis = _codeCtrl.text.length;
    final complet = saisis == OtpField.longueur;
    final local = normaliserNumero(_numeroDemande ?? '');
    return CadreAuth(
      enfants: [
        EnTeteAuth(
          titre: 'Code reçu',
          avecRetour: true,
          onRetour: _enCours ? null : () => setState(_retourNumero),
        ),
        const SizedBox(height: 18),
        Text('Saisissez le code à ${OtpField.longueur} chiffres', style: JetonsAuth.lead),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: "Si ce numéro peut recevoir un code, il vient d'être envoyé au "),
              TextSpan(
                text: '+237 ${formaterNumeroLocal(local)}',
                style: const TextStyle(color: JetonsAuth.text, fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: JetonsAuth.sub,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: LienAuth(
            texte: 'Modifier le numéro',
            onPressed: _enCours ? null : () => setState(_retourNumero),
          ),
        ),
        if (modeDemo) ...[
          const BandeauStatut(child: Text('Mode démo : le code est ${FauxAuthApi.codeDemo}')),
          const SizedBox(height: 8),
        ],
        Text('Code'.toUpperCase(), style: JetonsAuth.label),
        const SizedBox(height: 6),
        OtpField(controller: _codeCtrl, actif: !_enCours, onChanged: (_) => setState(() => _erreurCode = null)),
        const SizedBox(height: 8),
        const Text(
          '📩 Le code se remplit tout seul à la réception du SMS, si votre téléphone le permet. Sinon, tapez-le.',
          style: TextStyle(fontSize: 11.5, height: 1.4, color: JetonsAuth.muted),
        ),
        const SizedBox(height: 6),
        Text(
          'Code valable ${otpDureeValidite.inMinutes} minutes · $otpEssaisMax essais au maximum.',
          style: JetonsAuth.meta,
        ),
        if (_erreurCode != null) ...[
          const SizedBox(height: 12),
          BandeauStatut(fort: true, annonce: true, child: Text(_erreurCode!)),
        ],
        const SizedBox(height: 12),
        BandeauStatut(
          child: Text(
            _renvoiDans > 0
                ? 'ℹ️ Pas reçu ? Vérifiez le numéro et votre réseau. Le renvoi est possible dans $_renvoiDans s.'
                : 'ℹ️ Pas reçu ? Vérifiez le numéro et votre réseau, puis renvoyez le code.',
          ),
        ),
        const Spacer(),
        const SizedBox(height: 16),
        CtaPrimaire(
          texte: complet ? 'Valider' : 'Valider · ${nChiffres(saisis)} sur ${OtpField.longueur}',
          onPressed: complet && !_enCours ? _verifierCode : null,
        ),
        const SizedBox(height: 8),
        CtaFantome(
          texte: _renvoiDans > 0 ? 'Renvoyer le code · dans $_renvoiDans s' : 'Renvoyer le code',
          onPressed: _renvoiDans > 0 || _enCours ? null : () => _demanderCode(renvoi: true),
        ),
      ],
    );
  }
}

InputDecoration decorationChampNumero({String? erreur}) {
  OutlineInputBorder bord(Color c, [double l = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c, width: l));
  return InputDecoration(
    filled: true,
    fillColor: JetonsAuth.surface,
    hintText: '6 77 12 34 56',
    hintStyle: const TextStyle(color: JetonsAuth.muted),
    counterText: '',
    errorText: erreur,
    errorMaxLines: 3,
    // Jamais de rouge pour un état système : l'erreur reste en `text`.
    errorStyle: const TextStyle(color: JetonsAuth.text, fontSize: 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
    enabledBorder: bord(JetonsAuth.lineCard),
    disabledBorder: bord(JetonsAuth.lineCard),
    focusedBorder: bord(JetonsAuth.gold, 2),
    errorBorder: bord(JetonsAuth.text, 2),
    focusedErrorBorder: bord(JetonsAuth.gold, 2),
  );
}

/// Case d'acceptation des CGU : toute la ligne (≥ 48dp) est la cible,
/// décochée par défaut.
class _LigneCgu extends StatelessWidget {
  final bool cochee;
  final ValueChanged<bool> onChanged;
  const _LigneCgu({required this.cochee, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const souligne = TextStyle(
      color: JetonsAuth.text,
      decoration: TextDecoration.underline,
      decorationColor: JetonsAuth.text,
    );
    return Semantics(
      checked: cochee,
      onTap: () => onChanged(!cochee),
      label: "J'accepte les conditions générales d'utilisation et la politique de confidentialité.",
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!cochee),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: JetonsAuth.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: JetonsAuth.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: JetonsAuth.lineCard),
                ),
                child: cochee
                    ? const Text('✓', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: JetonsAuth.text))
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: "J'accepte les "),
                      TextSpan(text: "conditions générales d'utilisation", style: souligne),
                      TextSpan(text: ' et la '),
                      TextSpan(text: 'politique de confidentialité', style: souligne),
                      TextSpan(text: '.'),
                    ],
                  ),
                  style: TextStyle(fontSize: 12.5, height: 1.45, color: JetonsAuth.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Connexion, étape 3 : choix puis confirmation du code PIN (appareil
/// seulement). Le PIN ne quitte jamais l'appareil ; seule son empreinte
/// Argon2id est enregistrée.
class ChoixPinScreen extends ConsumerStatefulWidget {
  const ChoixPinScreen({super.key});

  @override
  ConsumerState<ChoixPinScreen> createState() => _ChoixPinScreenState();
}

class _ChoixPinScreenState extends ConsumerState<ChoixPinScreen> with RetourPorte {
  String _saisie = '';
  String? _premier;
  String? _message;
  bool _enCours = false;

  bool get _confirmation => _premier != null;

  /// Retour système : confirmation → choix ; choix → rien.
  @override
  void surRetour() {
    if (_confirmation && !_enCours) _recommencer();
  }

  void _ajouter(String chiffre) {
    final max = _premier?.length ?? pinLongueurMax;
    if (_enCours || _saisie.length >= max) return;
    setState(() {
      _saisie += chiffre;
      _message = null;
    });
    if (_confirmation && _saisie.length == _premier!.length) _confirmer();
  }

  void _effacer() {
    if (_enCours || _saisie.isEmpty) return;
    setState(() => _saisie = _saisie.substring(0, _saisie.length - 1));
  }

  void _continuer() => setState(() {
        _premier = _saisie;
        _saisie = '';
      });

  void _recommencer([String? message]) => setState(() {
        _premier = null;
        _saisie = '';
        _message = message;
      });

  Future<void> _confirmer() async {
    final pin = _saisie;
    if (pin != _premier) {
      _recommencer('Les deux codes ne correspondent pas. Choisissez à nouveau votre code PIN.');
      return;
    }
    setState(() => _enCours = true);
    try {
      await ref.read(authProvider.notifier).definirPin(pin);
      // La porte ouvre Accueil.
    } catch (_) {
      if (!mounted) return;
      setState(() => _enCours = false);
      _recommencer(messageErreur);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _saisie.length;
    final String texte;
    final String semantique;
    if (_confirmation) {
      final l = _premier!.length;
      texte = '${chiffresSaisis(n)} sur $l';
      semantique = '${nChiffres(n)} sur $l saisis';
    } else {
      texte = n < pinLongueurMin ? '${chiffresSaisis(n)} · encore ${pinLongueurMin - n} au minimum' : chiffresSaisis(n);
      semantique = texte;
    }
    return CadreAuth(
      enfants: [
        EnTeteAuth(
          titre: 'Code PIN',
          avecRetour: _confirmation,
          onRetour: _confirmation && !_enCours ? () => _recommencer() : null,
          retourLabel: 'Choisir un autre code',
        ),
        const SizedBox(height: 18),
        Text(_confirmation ? 'Confirmez votre code PIN' : 'Choisissez un code PIN', style: JetonsAuth.lead),
        const SizedBox(height: 6),
        Text(
          _confirmation
              ? 'Saisissez le même code une seconde fois.'
              : "$pinLongueurMin à $pinLongueurMax chiffres. Il déverrouille l'app sur ce téléphone. Il reste sur ce téléphone et n'est jamais envoyé.",
          style: JetonsAuth.sub,
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          BandeauStatut(fort: true, annonce: true, child: Text(_message!)),
        ],
        const SizedBox(height: 22),
        PinPoints(
          saisis: n,
          cases: _confirmation ? _premier!.length : pinLongueurMin,
          optionnelles: _confirmation ? 0 : pinLongueurMax - pinLongueurMin,
          texte: texte,
          semanticsLabel: semantique,
        ),
        if (_enCours) const CalculPin(texte: 'Enregistrement du code…'),
        const SizedBox(height: 18),
        PinPad(onChiffre: _ajouter, onEffacer: _effacer, actif: !_enCours),
        const Spacer(),
        if (!_confirmation) ...[
          const SizedBox(height: 16),
          CtaPrimaire(texte: 'Continuer', onPressed: n >= pinLongueurMin ? _continuer : null),
          const SizedBox(height: 6),
          const Text("Vous le confirmerez à l'étape suivante.", style: JetonsAuth.meta, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
