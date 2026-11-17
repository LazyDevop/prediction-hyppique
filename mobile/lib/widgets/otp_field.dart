import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'auth_styles.dart';

/// `otp-field` : un seul champ de 6 chiffres affiché en 6 cases (surface,
/// line-card, rounded.sm, ≥ 48dp). Remplissage automatique du code SMS
/// (`AutofillHints.oneTimeCode`) et collage acceptés ; la case active est
/// signalée par le focus-indicator (contour or 2px, décalage 2px).
class OtpField extends StatefulWidget {
  static const longueur = 6;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool actif;

  const OtpField({super.key, required this.controller, this.focusNode, this.onChanged, this.actif = true});

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  String _precedent = '';

  @override
  void initState() {
    super.initState();
    _precedent = widget.controller.text;
    _focus.addListener(_rafraichir);
    widget.controller.addListener(_surControleur);
  }

  @override
  void didUpdateWidget(OtpField ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.controller != widget.controller) {
      ancien.controller.removeListener(_surControleur);
      widget.controller.addListener(_surControleur);
    }
    // Champ réactivé (fin d'une requête) : on rend le focus pour la saisie.
    if (!ancien.actif && widget.actif) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  /// Champ vidé par l'écran (code incorrect, renvoi) : la prochaine saisie
  /// complète d'un coup doit encore être reconnue comme auto-remplie.
  void _surControleur() {
    if (widget.controller.text.isEmpty && _precedent.isNotEmpty) {
      _precedent = '';
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_surControleur);
    _focus.removeListener(_rafraichir);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _rafraichir() => setState(() {});

  void _surChangement(String valeur) {
    // Plusieurs chiffres arrivés d'un coup jusqu'au code complet : SMS
    // auto-rempli ou collage.
    if (valeur.length == OtpField.longueur && valeur.length - _precedent.length > 1) {
      final vue = View.maybeOf(context);
      if (vue != null) {
        SemanticsService.sendAnnouncement(vue, 'Code rempli automatiquement', Directionality.of(context));
      }
    }
    _precedent = valeur;
    setState(() {});
    widget.onChanged?.call(valeur);
  }

  @override
  Widget build(BuildContext context) {
    final texte = widget.controller.text;
    final courante = _focus.hasFocus && texte.length < OtpField.longueur ? texte.length : -1;
    return Stack(children: [
      ExcludeSemantics(
        child: Row(children: [
          for (var i = 0; i < OtpField.longueur; i++)
            Expanded(
              // Anneau de 4px (2px de contour or + 2px d'écart) réservé
              // autour de chaque case : l'écart visuel entre cases reste 8px.
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: i == courante ? JetonsAuth.gold : Colors.transparent, width: 2),
                ),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: JetonsAuth.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: JetonsAuth.lineCard),
                  ),
                  child: Text(i < texte.length ? texte[i] : '', style: JetonsAuth.chiffres),
                ),
              ),
            ),
        ]),
      ),
      // Champ réel, invisible, posé sur les cases : un seul nœud TalkBack.
      Positioned.fill(
        child: Semantics(
          label: 'Code reçu par SMS, 6 chiffres',
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.actif,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(OtpField.longueur),
            ],
            onChanged: _surChangement,
            showCursor: false,
            enableInteractiveSelection: true,
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    ]);
  }
}
