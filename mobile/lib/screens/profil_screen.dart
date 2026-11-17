import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/compte_api.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/cadre_auth.dart';
import '../widgets/device_row.dart';
import '../widgets/settings_row.dart';
import 'email_secours_screen.dart';
import 'mes_appareils_screen.dart';

const messageChargementProfil = 'Impossible de charger votre profil.';
const messageProfilNonActualise = 'Profil non actualisé — réessayez';

/// Profil (story 8.4), ouvert depuis l'icône de compte d'Accueil : numéro,
/// email de secours et son état, palier, CGU acceptées, Mes appareils,
/// « Se déconnecter ». Offres, Duo et QR code sont absents tant que leurs
/// stories ne sont pas livrées (jamais affichés désactivés).
class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  ProfilCompte? _profil;
  bool _erreur = false;

  /// Navigation ou déconnexion en cours : un double toucher n'agit qu'une fois.
  bool _occupe = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (_erreur) setState(() => _erreur = false);
    try {
      final profil = await ref.read(compteApiProvider).lireProfil();
      if (mounted) setState(() => _profil = profil);
    } catch (_) {
      if (mounted) setState(() => _erreur = true);
    }
  }

  Future<void> _ouvrir(Widget ecran) async {
    if (_occupe) return;
    _occupe = true;
    try {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran));
    } finally {
      _occupe = false;
    }
    if (mounted) _charger();
  }

  Future<void> _seDeconnecter() async {
    if (_occupe) return;
    _occupe = true;
    final notifier = ref.read(authProvider.notifier);
    final ok = await confirmer(
      context,
      titre: 'Se déconnecter de cet appareil ?',
      texte: 'Vous devrez recevoir un nouveau code pour vous reconnecter.',
      action: 'Se déconnecter',
    );
    if (!ok) {
      _occupe = false;
      return;
    }
    // La porte détruit la pile (routes poussées comprises) et ouvre Connexion.
    await notifier.seDeconnecter();
  }

  @override
  Widget build(BuildContext context) {
    final numero = ref.watch(authProvider).value?.numeroMasque ?? '';
    final profil = _profil;
    return CadreAuth(
      enfants: [
        Row(
          children: [
            Expanded(
              child: EnTeteAuth(titre: 'Profil', onRetour: () => Navigator.of(context).maybePop()),
            ),
            if (profil != null) _Palier(profil.palier),
          ],
        ),
        if (profil == null && _erreur) ...[
          const SizedBox(height: 12),
          const BandeauStatut(fort: true, annonce: true, child: Text(messageChargementProfil)),
          const SizedBox(height: 10),
          CtaFantome(texte: 'Réessayer', onPressed: _charger),
        ] else if (profil == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          // Rechargement raté : l'ancien profil reste, avec un avis non bloquant.
          if (_erreur) ...[
            const SizedBox(height: 10),
            BandeauStatut(
              annonce: true,
              child: Row(
                children: [
                  const Expanded(child: Text(messageProfilNonActualise)),
                  LienAuth(texte: 'Réessayer', onPressed: _charger),
                ],
              ),
            ),
          ],
          ..._contenu(profil, numero),
        ],
      ],
    );
  }

  List<Widget> _contenu(ProfilCompte p, String numero) {
    final email = p.email;
    return [
      // FR-34 : rappel non bloquant, seulement sur un palier payant.
      if (p.palierPayant && !(email != null && p.emailVerifie)) ...[
        const SizedBox(height: 10),
        BandeauStatut(
          fort: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Ajoutez un email de secours vérifié.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' Il permet de récupérer votre compte si vous perdez votre numéro.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              CtaFantome(
                texte: email == null ? 'Ajouter un email de secours' : "Vérifier l'email de secours",
                onPressed: () => _ouvrir(EmailSecoursScreen(emailActuel: email, emailVerifie: p.emailVerifie)),
              ),
            ],
          ),
        ),
      ],
      const TitreSection('Compte'),
      LigneReglage(libelle: 'Numéro', valeur: numero),
      LigneReglage(
        libelle: 'Email de secours',
        valeur: email ?? 'Non renseigné',
        detailWidget: email == null
            ? null
            : EtatEcrit(p.emailVerifie ? 'Vérifié' : 'Non vérifié', attenue: !p.emailVerifie),
        semanticsLabel:
            'Email de secours, ${email ?? 'non renseigné'}${email == null
                ? ''
                : p.emailVerifie
                ? ', vérifié'
                : ', non vérifié'}',
      ),
      LigneReglage(
        libelle: email == null ? 'Ajouter un email de secours' : "Changer d'email de secours",
        action: email == null ? 'Ajouter' : (p.emailVerifie ? 'Modifier' : 'Vérifier'),
        onTap: () => _ouvrir(EmailSecoursScreen(emailActuel: email, emailVerifie: p.emailVerifie)),
      ),
      LigneReglage(
        libelle: "Conditions d'utilisation",
        valeur: 'Version ${p.cguVersion}',
        detail: 'Acceptées le ${formaterDate(p.cguAccepteeLe)}',
      ),
      const TitreSection('Palier'),
      LigneReglage(libelle: 'Palier actif', valeur: p.palier),
      LigneReglage(
        libelle: 'Fin du droit',
        valeur: p.finDroit == null
            ? 'Sans date de fin'
            : '${formaterDate(p.finDroit!)} à ${formaterHeure(p.finDroit!)}',
        detail: p.finDroit == null ? null : 'Ensuite : palier Gratuit, données conservées',
      ),
      const TitreSection('Sécurité'),
      LigneReglage(
        libelle: 'Mes appareils',
        valeur: '${p.nbAppareils} sur ${p.limiteAppareils}',
        navigation: true,
        onTap: () => _ouvrir(const MesAppareilsScreen()),
      ),
      const SizedBox(height: 16),
      CtaFantome(texte: 'Se déconnecter', onPressed: _seDeconnecter),
    ];
  }
}

/// Pastille du palier dans l'en-tête (cadre `line-card`, capitales).
class _Palier extends StatelessWidget {
  final String palier;
  const _Palier(this.palier);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Palier $palier',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: JetonsAuth.lineCard),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          palier.toUpperCase(),
          style: const TextStyle(fontSize: 11, letterSpacing: .6, color: JetonsAuth.text),
        ),
      ),
    );
  }
}
