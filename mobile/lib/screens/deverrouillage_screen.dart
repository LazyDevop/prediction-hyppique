import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/cadre_auth.dart';
import '../widgets/pin_pad.dart';
import 'connexion_screen.dart' show messageErreur;

/// Déverrouillage : démarrage à froid avec session, ou retour au premier
/// plan après `DELAI_VERROUILLAGE`. Fonctionne hors ligne (vérification
/// locale de l'empreinte du PIN).
class DeverrouillageScreen extends ConsumerStatefulWidget {
  const DeverrouillageScreen({super.key});

  @override
  ConsumerState<DeverrouillageScreen> createState() => _DeverrouillageScreenState();
}

class _DeverrouillageScreenState extends ConsumerState<DeverrouillageScreen> with RetourPorte {
  static const pinLongueurParDefaut = 4;

  String _saisie = '';
  bool _enCours = false;
  String? _erreur;

  int get _longueur => ref.read(authProvider).value?.pinLongueur ?? pinLongueurParDefaut;

  /// Retour système bloqué : rien derrière la porte ne doit être accessible.
  @override
  void surRetour() {}

  void _ajouter(String chiffre) {
    if (_enCours || _saisie.length >= _longueur) return;
    setState(() {
      _saisie += chiffre;
      _erreur = null;
    });
    if (_saisie.length == _longueur) _valider();
  }

  void _effacer() {
    if (_enCours || _saisie.isEmpty) return;
    setState(() => _saisie = _saisie.substring(0, _saisie.length - 1));
  }

  Future<void> _valider() async {
    final pin = _saisie;
    setState(() => _enCours = true);
    var ok = false;
    String? erreur;
    try {
      ok = await ref.read(authProvider.notifier).deverrouiller(pin);
    } catch (_) {
      erreur = messageErreur;
    }
    if (!mounted || ok) return;
    setState(() {
      _enCours = false;
      _saisie = '';
      _erreur = erreur;
    });
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(authProvider).value;
    final longueur = etat?.pinLongueur ?? pinLongueurParDefaut;
    final restants = etat?.essaisPinRestants ?? essaisPinMax;
    final n = _saisie.length;
    return CadreAuth(
      enfants: [
        const SizedBox(height: 24),
        const MarqueAuth(textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text('Saisissez votre code PIN', style: JetonsAuth.lead, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Compte ${etat?.numeroMasque ?? ''}',
          style: JetonsAuth.sub.copyWith(fontFeatures: JetonsAuth.tabulaire),
          textAlign: TextAlign.center,
        ),
        if (_erreur != null) ...[
          const SizedBox(height: 12),
          BandeauStatut(fort: true, annonce: true, child: Text(_erreur!)),
        ] else if (restants < essaisPinMax) ...[
          const SizedBox(height: 12),
          BandeauStatut(
            fort: true,
            annonce: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Code incorrect — ${essaisRestants(restants)}.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' Après $essaisPinMax essais, il faudra vous reconnecter par code SMS.'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        PinPoints(
          saisis: n,
          cases: longueur,
          texte: '${chiffresSaisis(n)} sur $longueur',
          semanticsLabel: '${nChiffres(n)} sur $longueur saisis',
        ),
        if (_enCours) const CalculPin(texte: 'Vérification du code…'),
        const SizedBox(height: 18),
        PinPad(onChiffre: _ajouter, onEffacer: _effacer, actif: !_enCours),
        const Spacer(),
        LienAuth(
          texte: 'Code oublié ? Se reconnecter par code SMS',
          onPressed: _enCours ? null : () => ref.read(authProvider.notifier).seReconnecter(),
        ),
      ],
    );
  }
}
