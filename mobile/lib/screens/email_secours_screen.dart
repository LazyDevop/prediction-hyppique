import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/auth_api.dart' show otpDureeValidite, otpEssaisMax;
import '../data/remote/compte_api.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/cadre_auth.dart';
import '../widgets/otp_field.dart';
import 'connexion_screen.dart' show messageCodeExpire, messageErreur, messageTropDEssais;

const messageEmailInvalide = 'Adresse email invalide.';
const messageEmailDejaVerifie = 'Cette adresse est déjà votre email de secours vérifié.';

enum _Etape { email, code }

/// Email de secours (story 8.4) : ajout ou changement → code à 6 chiffres
/// envoyé à l'adresse → « vérifié ». Renvoie `true` une fois vérifié.
class EmailSecoursScreen extends ConsumerStatefulWidget {
  /// Adresse actuelle (pré-remplie), null si aucune.
  final String? emailActuel;

  /// [emailActuel] est déjà vérifié : le ressaisir ne relance rien.
  final bool emailVerifie;
  const EmailSecoursScreen({super.key, this.emailActuel, this.emailVerifie = false});

  @override
  ConsumerState<EmailSecoursScreen> createState() => _EmailSecoursScreenState();
}

class _EmailSecoursScreenState extends ConsumerState<EmailSecoursScreen> {
  _Etape _etape = _Etape.email;
  late final _emailCtrl = TextEditingController(text: widget.emailActuel ?? '');
  final _codeCtrl = TextEditingController();
  bool _enCours = false;
  String? _erreurEmail;
  String? _messageEmail;
  String? _erreurCode;
  String _emailDemande = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_enCours) return;
    final email = normaliserEmail(_emailCtrl.text);
    if (!formatEmail.hasMatch(email)) {
      setState(() => _erreurEmail = messageEmailInvalide);
      return;
    }
    final actuel = widget.emailActuel;
    if (widget.emailVerifie && actuel != null && normaliserEmail(actuel) == email) {
      setState(() => _messageEmail = messageEmailDejaVerifie);
      return;
    }
    setState(() {
      _enCours = true;
      _erreurEmail = null;
      _messageEmail = null;
    });
    DemandeEmailResultat? r;
    try {
      r = await ref.read(compteApiProvider).definirEmail(email);
    } catch (_) {
      r = null;
    }
    if (!mounted) return;
    setState(() {
      _enCours = false;
      switch (r) {
        case CodeEmailEnvoye():
          _emailDemande = email;
          _codeCtrl.clear();
          _erreurCode = null;
          _etape = _Etape.code;
        case EmailInvalide():
          _erreurEmail = messageEmailInvalide;
        case null:
          _messageEmail = messageErreur;
      }
    });
  }

  Future<void> _verifier() async {
    setState(() {
      _enCours = true;
      _erreurCode = null;
    });
    VerificationEmailResultat? r;
    try {
      r = await ref.read(compteApiProvider).verifierEmail(_codeCtrl.text);
    } catch (_) {
      r = null;
    }
    if (!mounted) return;
    if (r is EmailVerifie) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _enCours = false;
      switch (r) {
        case CodeEmailIncorrect(essaisRestants: final n):
          _erreurCode = 'Code incorrect — ${essaisRestants(n)}';
          _codeCtrl.clear();
        case CodeEmailExpire():
          _retourEmail(messageCodeExpire);
        case TropDEssaisEmail():
          _retourEmail(messageTropDEssais);
        case EmailVerifie():
          break;
        case null:
          _erreurCode = messageErreur;
      }
    });
  }

  void _retourEmail([String? message]) {
    _etape = _Etape.email;
    _messageEmail = message;
    _erreurCode = null;
    _codeCtrl.clear();
  }

  /// Retour système : étape code → étape email ; bloqué pendant une requête.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _etape == _Etape.email && !_enCours,
    onPopInvokedWithResult: (aDepile, _) {
      if (!aDepile && !_enCours && _etape == _Etape.code) setState(_retourEmail);
    },
    child: switch (_etape) {
      _Etape.email => _construireEmail(),
      _Etape.code => _construireCode(),
    },
  );

  Widget _construireEmail() {
    return CadreAuth(
      enfants: [
        EnTeteAuth(titre: 'Email de secours', onRetour: _enCours ? null : () => Navigator.of(context).maybePop()),
        const SizedBox(height: 18),
        const Text('Votre email de secours', style: JetonsAuth.lead),
        const SizedBox(height: 6),
        const Text(
          'Il permet de récupérer votre compte si vous perdez votre numéro. '
          'Vous recevrez un code à 6 chiffres pour le vérifier.',
          style: JetonsAuth.sub,
        ),
        if (_messageEmail != null) ...[
          const SizedBox(height: 12),
          BandeauStatut(fort: true, annonce: true, child: Text(_messageEmail!)),
        ],
        const SizedBox(height: 20),
        Text('Adresse email'.toUpperCase(), style: JetonsAuth.label),
        const SizedBox(height: 6),
        Semantics(
          label: 'Adresse email',
          child: TextField(
            controller: _emailCtrl,
            enabled: !_enCours,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            style: const TextStyle(fontSize: 16, color: JetonsAuth.text),
            onChanged: (_) => setState(() {
              _erreurEmail = null;
              _messageEmail = null;
            }),
            onSubmitted: (_) => _enCours ? null : _envoyer(),
            decoration: _decoration(_erreurEmail),
          ),
        ),
        const Spacer(),
        const SizedBox(height: 16),
        CtaPrimaire(
          texte: 'Recevoir le code par email',
          onPressed: _enCours || _emailCtrl.text.trim().isEmpty ? null : _envoyer,
        ),
      ],
    );
  }

  Widget _construireCode() {
    final modeDemo = ref.watch(modeDemoCompteProvider);
    final saisis = _codeCtrl.text.length;
    final complet = saisis == OtpField.longueur;
    return CadreAuth(
      enfants: [
        EnTeteAuth(titre: 'Code reçu', avecRetour: true, onRetour: _enCours ? null : () => setState(_retourEmail)),
        const SizedBox(height: 18),
        Text('Saisissez le code à ${OtpField.longueur} chiffres', style: JetonsAuth.lead),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: "Un code vient d'être envoyé à "),
              TextSpan(
                text: _emailDemande,
                style: const TextStyle(color: JetonsAuth.text, fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: JetonsAuth.sub,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: LienAuth(texte: "Modifier l'adresse", onPressed: _enCours ? null : () => setState(_retourEmail)),
        ),
        if (modeDemo) ...[
          const BandeauStatut(child: Text('Mode démo : le code est ${FauxCompteApi.codeDemo}')),
          const SizedBox(height: 8),
        ],
        Text('Code'.toUpperCase(), style: JetonsAuth.label),
        const SizedBox(height: 6),
        OtpField(
          controller: _codeCtrl,
          actif: !_enCours,
          semanticsLabel: 'Code reçu par email, 6 chiffres',
          onChanged: (_) => setState(() => _erreurCode = null),
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
        const Spacer(),
        const SizedBox(height: 16),
        CtaPrimaire(
          texte: complet ? 'Valider' : 'Valider · ${nChiffres(saisis)} sur ${OtpField.longueur}',
          onPressed: complet && !_enCours ? _verifier : null,
        ),
      ],
    );
  }
}

InputDecoration _decoration(String? erreur) {
  OutlineInputBorder bord(Color c, [double l = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: c, width: l),
  );
  return InputDecoration(
    filled: true,
    fillColor: JetonsAuth.surface,
    hintText: 'nom@exemple.cm',
    hintStyle: const TextStyle(color: JetonsAuth.muted),
    errorText: erreur,
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
