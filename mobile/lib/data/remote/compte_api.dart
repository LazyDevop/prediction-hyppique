import 'dart:math';

import 'auth_api.dart';

/// Limite d'appareils du palier. Provisoire (PRD OQ 14) :
/// `LIMITE_APPAREILS_<PALIER>` côté serveur.
// ignore: constant_identifier_names
const LIMITE_APPAREILS_PROVISOIRE = 2;

/// `palier_actif` provisoire (`PALIER_PAR_DEFAUT`) jusqu'à la story 9.1.
const palierGratuit = 'Gratuit';

// Même valeur que `palierExpert` (offres_api.dart, qui importe ce fichier).
const _palierExpertDemo = 'Expert';

enum TypeAppareil { telephone, navigateur }

class Appareil {
  final String id;
  final TypeAppareil type;

  /// Nom lisible : « Téléphone Android », « Chrome sur Windows ».
  final String nom;
  final DateTime derniereActivite;
  final DateTime rattacheLe;

  /// L'appareil qui fait la demande (« Cet appareil »).
  final bool estCourant;

  /// Rattaché récemment : « Nouveau » dans Mes appareils (FR-36).
  final bool nouveau;

  const Appareil({
    required this.id,
    required this.type,
    required this.nom,
    required this.derniereActivite,
    required this.rattacheLe,
    this.estCourant = false,
    this.nouveau = false,
  });
}

class ListeAppareils {
  /// Cet appareil en premier, puis par activité la plus récente.
  final List<Appareil> appareils;
  final int limite;
  final String palier;
  const ListeAppareils({required this.appareils, required this.limite, required this.palier});
}

/// Droit payant arrivé à son terme.
class DroitTermine {
  final String palier;
  final DateTime fin;
  const DroitTermine(this.palier, this.fin);
}

class ProfilCompte {
  /// Email de secours (vérifié ou non), null si non renseigné.
  final String? email;
  final bool emailVerifie;
  final String palier;

  /// Fin du droit payant ; null pour le palier Gratuit.
  final DateTime? finDroit;
  final String cguVersion;
  final DateTime cguAccepteeLe;
  final int nbAppareils;
  final int limiteAppareils;

  /// Dernier droit payant, une fois terminé (« Droit Turfiste terminé le … »).
  final DroitTermine? droitTermine;

  const ProfilCompte({
    required this.email,
    required this.emailVerifie,
    required this.palier,
    required this.finDroit,
    required this.cguVersion,
    required this.cguAccepteeLe,
    required this.nbAppareils,
    required this.limiteAppareils,
    this.droitTermine,
  });

  /// Profil à [maintenant] : un droit arrivé à son terme redevient Gratuit.
  ProfilCompte effectif(DateTime maintenant) {
    final fin = finDroit;
    if (!palierPayant || fin == null || fin.isAfter(maintenant)) return this;
    return ProfilCompte(
      email: email,
      emailVerifie: emailVerifie,
      palier: palierGratuit,
      finDroit: null,
      cguVersion: cguVersion,
      cguAccepteeLe: cguAccepteeLe,
      nbAppareils: nbAppareils,
      limiteAppareils: limiteAppareils,
      droitTermine: DroitTermine(palier, fin),
    );
  }

  bool get palierPayant => palier != palierGratuit;
}

/// Résultat de `CompteApi.definirEmail`.
sealed class DemandeEmailResultat {
  const DemandeEmailResultat();
}

class CodeEmailEnvoye extends DemandeEmailResultat {
  const CodeEmailEnvoye();
}

class EmailInvalide extends DemandeEmailResultat {
  const EmailInvalide();
}

/// Résultat de `CompteApi.verifierEmail`.
sealed class VerificationEmailResultat {
  const VerificationEmailResultat();
}

class EmailVerifie extends VerificationEmailResultat {
  const EmailVerifie();
}

class CodeEmailIncorrect extends VerificationEmailResultat {
  final int essaisRestants;
  const CodeEmailIncorrect(this.essaisRestants);
}

class CodeEmailExpire extends VerificationEmailResultat {
  const CodeEmailExpire();
}

class TropDEssaisEmail extends VerificationEmailResultat {
  const TropDEssaisEmail();
}

/// Résultat du retrait en accès limité (appareil bloqué).
sealed class RetraitRestreintResultat {
  const RetraitRestreintResultat();
}

class AppareilRetire extends RetraitRestreintResultat {
  final String nom;
  const AppareilRetire(this.nom);
}

/// Jeton expiré (10 min) ou déjà utilisé : 403 côté serveur.
class AccesRestreintExpire extends RetraitRestreintResultat {
  const AccesRestreintExpire();
}

/// Quota quotidien de jetons de gestion atteint (429).
class TropDeTentativesAujourdhui extends RetraitRestreintResultat {
  const TropDeTentativesAujourdhui();
}

/// Levée par `listerAppareilsRestreint` quand le jeton n'est plus valable.
class AccesRestreintRefuse implements Exception {
  const AccesRestreintRefuse();
}

/// Port Profil, email de secours et appareils (stories 8.4, 8.6). Les
/// écrans ne dépendent que de cette interface ; [FauxCompteApi] la remplace
/// tant que le client HTTP réel n'existe pas.
abstract class CompteApi {
  Future<ProfilCompte> lireProfil();

  /// Envoie un code à 6 chiffres à [email] (ajout ou changement).
  Future<DemandeEmailResultat> definirEmail(String email);

  Future<VerificationEmailResultat> verifierEmail(String code);

  Future<ListeAppareils> listerAppareils();

  /// Retire un autre appareil (jamais l'appareil courant).
  Future<void> retirerAppareil(String id);

  /// Accès limité de l'appareil bloqué : liste seule.
  Future<ListeAppareils> listerAppareilsRestreint(JetonGestionAppareils jeton);

  /// Accès limité : un seul retrait.
  Future<RetraitRestreintResultat> retirerAppareilRestreint(JetonGestionAppareils jeton, String id);
}

/// Forme minimale d'une adresse email (contrôle de saisie) : partie locale
/// non vide, domaine fait de libellés non vides, extension ≥ 2 caractères.
final formatEmail = RegExp(r'^[^\s@]+@(?:[^\s@.]+\.)+[^\s@.]{2,}$');

/// Adresse email normalisée : espaces retirés, minuscules.
String normaliserEmail(String brut) => brut.trim().toLowerCase();

class _CompteDemo {
  String? email;
  bool emailVerifie;
  String palier;
  DateTime? finDroit;
  String cguVersion;
  DateTime cguAccepteeLe;
  final List<Appareil> appareils;

  /// Numéro E.164 complet, connu seulement après une connexion dans ce
  /// lancement (la session locale ne garde que le masque).
  String? numero;

  _CompteDemo({required this.appareils, required this.cguVersion, required this.cguAccepteeLe})
    : emailVerifie = false,
      palier = palierGratuit;

  /// Palier à [maintenant] : un droit arrivé à son terme redevient Gratuit.
  String palierEffectif(DateTime maintenant) {
    final fin = finDroit;
    return fin != null && !fin.isAfter(maintenant) ? palierGratuit : palier;
  }
}

class _CodeEmail {
  final String email;
  final DateTime expireLe;
  int essaisRestants;
  _CodeEmail(this.email, this.expireLe, this.essaisRestants);
}

class _JetonDemo {
  final String numero;
  final DateTime expireLe;
  bool utilise = false;
  _JetonDemo(this.numero, this.expireLe);
}

/// Faux serveur local de démonstration, en mémoire. Le numéro
/// [numeroBloque] a déjà [LIMITE_APPAREILS_PROVISOIRE] appareils : s'y
/// connecter mène à Appareil bloqué. Code email : [codeDemo].
class FauxCompteApi implements CompteApi, RattachementDemo {
  static const codeDemo = '123456';
  static const numeroBloque = '+237699999999';
  static const idCourant = 'cet-appareil';

  /// Compte de démonstration Expert (décision du 2026-11-24) ; les autres
  /// numéros sont Gratuit jusqu'au premier paiement. Reconnu par son numéro
  /// complet à la connexion ; une session restaurée n'a que le masque.
  static const numeroExpert = '+237677123456';
  static const dureeDroitExpertDemo = Duration(days: 30);

  final DateTime Function() _horloge;
  final Random _aleatoire = Random.secure();
  final TypeAppareil _typeCourant;
  final String _nomCourant;

  /// Comptes connus du faux serveur, par numéro MASQUÉ (« +237 6 •• •• •• 56 ») :
  /// la session locale ne garde que cette forme, ce qui permet de retrouver
  /// le compte au redémarrage. Démo seulement (deux numéros de même masque
  /// partagent un compte).
  ///
  /// Un numéro connecté qui partage ce masque avec un autre a pour clé son
  /// numéro complet.
  final Map<String, _CompteDemo> _comptes = {};

  /// Dernière clé connectée, par masque (session restaurée).
  final Map<String, String> _clesParMasque = {};

  /// Modèle du compte d'une session restaurée (constructeur).
  final String? _palierSession;
  final DateTime? _finDroitSession;
  final String? _emailSession;
  final bool _emailVerifieSession;
  final Map<String, _JetonDemo> _jetons = {};
  String? _numeroCourant;
  _CodeEmail? _codeEmail;

  /// Crochet du faux serveur de paiement lié : applique les paiements
  /// confirmés depuis la dernière lecture (confirmation tardive, écran
  /// Paiement quitté).
  void Function()? regularisation;

  /// [palier], [email], [emailVerifie] : compte de la session déjà ouverte
  /// au lancement (aucun numéro connu du faux serveur). Sans [palier] :
  /// Expert pour [numeroExpert], Gratuit sinon.
  FauxCompteApi({
    DateTime Function()? horloge,
    bool web = false,
    String? palier,
    DateTime? finDroit,
    String? email,
    bool emailVerifie = false,
  }) : _horloge = horloge ?? DateTime.now,
       _palierSession = palier,
       _finDroitSession = finDroit,
       _emailSession = email,
       _emailVerifieSession = email != null && emailVerifie,
       _typeCourant = web ? TypeAppareil.navigateur : TypeAppareil.telephone,
       _nomCourant = web ? 'Navigateur web' : 'Téléphone Android' {
    final maintenant = _horloge();
    final hier = DateTime(maintenant.year, maintenant.month, maintenant.day - 1, 23, 12);
    _comptes[masquerNumero(numeroBloque)] = _CompteDemo(
      cguVersion: CGU_VERSION_PROVISOIRE,
      cguAccepteeLe: maintenant.subtract(const Duration(days: 30)),
      appareils: [
        Appareil(
          id: 'samsung-a14',
          type: TypeAppareil.telephone,
          nom: 'Samsung Galaxy A14',
          derniereActivite: maintenant.subtract(const Duration(minutes: 5)),
          rattacheLe: maintenant.subtract(const Duration(days: 30)),
        ),
        Appareil(
          id: 'chrome-windows',
          type: TypeAppareil.navigateur,
          nom: 'Chrome sur Windows',
          derniereActivite: hier,
          rattacheLe: maintenant.subtract(const Duration(days: 10)),
        ),
      ],
    )..numero = numeroBloque;
  }

  /// Compte d'une session ouverte avant ce lancement : modèle du constructeur.
  _CompteDemo _compteSession(String cle) {
    final maintenant = _horloge();
    final compte = _nouveauCompte(maintenant, expert: cle == masquerNumero(numeroExpert));
    final palier = _palierSession;
    if (palier != null) {
      compte
        ..palier = palier
        ..finDroit = _finDroitSession;
    }
    return compte
      ..email = _emailSession
      ..emailVerifie = _emailVerifieSession
      ..appareils.add(_appareilCourant(maintenant));
  }

  /// Démarrage avec une session déjà enregistrée : le compte courant est
  /// celui du numéro masqué de la session.
  void restaurerSession(String numeroMasque) {
    final cle = _clesParMasque[numeroMasque] ?? numeroMasque;
    _numeroCourant = cle;
    _codeEmail = null;
    final compte = _compteDe(cle);
    if (!compte.appareils.any((a) => a.id == idCourant)) compte.appareils.add(_appareilCourant(_horloge()));
  }

  /// « Se déconnecter » : plus de compte courant ni de code email en cours.
  void deconnecter() {
    _numeroCourant = null;
    _codeEmail = null;
  }

  _CompteDemo _nouveauCompte(DateTime maintenant, {required bool expert}) {
    final compte = _CompteDemo(
      cguVersion: CGU_VERSION_PROVISOIRE,
      cguAccepteeLe: maintenant,
      appareils: [
        // Rattaché il y a 2 h : montre « Nouveau » et son bandeau.
        Appareil(
          id: 'chrome-windows',
          type: TypeAppareil.navigateur,
          nom: 'Chrome sur Windows',
          derniereActivite: maintenant.subtract(const Duration(hours: 1)),
          rattacheLe: maintenant.subtract(const Duration(hours: 2)),
          nouveau: true,
        ),
      ],
    );
    if (expert) {
      compte
        ..palier = _palierExpertDemo
        ..finDroit = maintenant.toUtc().add(dureeDroitExpertDemo);
    }
    return compte;
  }

  Appareil _appareilCourant(DateTime maintenant) => Appareil(
    id: idCourant,
    type: _typeCourant,
    nom: _nomCourant,
    derniereActivite: maintenant,
    rattacheLe: maintenant,
    estCourant: true,
  );

  _CompteDemo get _compte => _compteDe(_numeroCourant ?? '');

  _CompteDemo _compteDe(String cle) => _comptes.putIfAbsent(cle, () => _compteSession(cle));

  /// Clé du compte de [numero] : son masque, sauf s'il désigne déjà un
  /// autre numéro (ou la session Expert restaurée, pour un autre numéro).
  String _cleDe(String numero) {
    final masque = masquerNumero(numero);
    final occupant = _comptes[masque];
    if (occupant == null || occupant.numero == numero) return masque;
    if (occupant.numero != null) return numero;
    return masque == masquerNumero(numeroExpert) && numero != numeroExpert ? numero : masque;
  }

  @override
  AppareilBloque? rattacher(String numero, {required String cguVersion}) {
    final maintenant = _horloge();
    final cle = _cleDe(numero);
    final compte = _comptes.putIfAbsent(cle, () => _nouveauCompte(maintenant, expert: numero == numeroExpert));
    final autres = compte.appareils.where((a) => a.id != idCourant).length;
    if (autres >= LIMITE_APPAREILS_PROVISOIRE) {
      final valeur = 'demo-gestion-${_jeton()}';
      final expireLe = maintenant.add(dureeJetonGestion);
      _jetons[valeur] = _JetonDemo(cle, expireLe);
      return AppareilBloque(
        jeton: JetonGestionAppareils(valeur: valeur, expireLe: expireLe),
        limite: LIMITE_APPAREILS_PROVISOIRE,
        palier: compte.palierEffectif(maintenant),
      );
    }
    compte.appareils
      ..removeWhere((a) => a.id == idCourant)
      ..add(_appareilCourant(maintenant));
    if (cguVersion.isNotEmpty) compte.cguVersion = cguVersion;
    compte.cguAccepteeLe = maintenant;
    compte.numero = numero;
    _numeroCourant = cle;
    _clesParMasque[masquerNumero(numero)] = cle;
    _codeEmail = null;
    return null;
  }

  /// Clé (numéro masqué) du compte courant ; null sans compte ouvert.
  String? get cleCompteCourant => _numeroCourant;

  /// Numéro E.164 complet du compte courant, s'il est connu.
  String? get numeroCourant => _comptes[_numeroCourant]?.numero;

  /// Palier et fin du droit du compte [cle] (Gratuit s'il est inconnu).
  (String, DateTime?) droitDe(String cle) {
    final c = _comptes[cle];
    return c == null ? (palierGratuit, null) : (c.palier, c.finDroit);
  }

  /// Paiement confirmé (faux serveur de paiement) : nouveau palier et fin
  /// du droit du compte [cle].
  void activerPass(String cle, {required String palier, required DateTime finDroit}) {
    _compteDe(cle)
      ..palier = palier
      ..finDroit = finDroit;
  }

  @override
  Future<ProfilCompte> lireProfil() async {
    regularisation?.call();
    final c = _compte;
    return ProfilCompte(
      email: c.email,
      emailVerifie: c.emailVerifie,
      palier: c.palier,
      finDroit: c.finDroit,
      cguVersion: c.cguVersion,
      cguAccepteeLe: c.cguAccepteeLe,
      nbAppareils: c.appareils.length,
      limiteAppareils: LIMITE_APPAREILS_PROVISOIRE,
    ).effectif(_horloge());
  }

  @override
  Future<DemandeEmailResultat> definirEmail(String email) async {
    final propre = normaliserEmail(email);
    if (!formatEmail.hasMatch(propre)) return const EmailInvalide();
    _codeEmail = _CodeEmail(propre, _horloge().add(otpDureeValidite), otpEssaisMax);
    return const CodeEmailEnvoye();
  }

  @override
  Future<VerificationEmailResultat> verifierEmail(String code) async {
    final demande = _codeEmail;
    if (demande == null || !_horloge().isBefore(demande.expireLe)) {
      _codeEmail = null;
      return const CodeEmailExpire();
    }
    if (code == codeDemo) {
      _codeEmail = null;
      _compte
        ..email = demande.email
        ..emailVerifie = true;
      return const EmailVerifie();
    }
    demande.essaisRestants--;
    if (demande.essaisRestants <= 0) {
      _codeEmail = null;
      return const TropDEssaisEmail();
    }
    return CodeEmailIncorrect(demande.essaisRestants);
  }

  ListeAppareils _liste(_CompteDemo c) {
    final tries = [...c.appareils]
      ..sort((a, b) {
        if (a.estCourant != b.estCourant) return a.estCourant ? -1 : 1;
        return b.derniereActivite.compareTo(a.derniereActivite);
      });
    return ListeAppareils(appareils: tries, limite: LIMITE_APPAREILS_PROVISOIRE, palier: c.palierEffectif(_horloge()));
  }

  @override
  Future<ListeAppareils> listerAppareils() async {
    regularisation?.call();
    return _liste(_compte);
  }

  @override
  Future<void> retirerAppareil(String id) async {
    if (id == idCourant) throw StateError("l'appareil courant ne se retire pas ici");
    _compte.appareils.removeWhere((a) => a.id == id);
  }

  _JetonDemo? _jetonValide(JetonGestionAppareils jeton) {
    final j = _jetons[jeton.valeur];
    if (j == null || j.utilise || !_horloge().isBefore(j.expireLe)) return null;
    return j;
  }

  @override
  Future<ListeAppareils> listerAppareilsRestreint(JetonGestionAppareils jeton) async {
    final j = _jetonValide(jeton);
    if (j == null) throw const AccesRestreintRefuse();
    return _liste(_comptes[j.numero]!);
  }

  @override
  Future<RetraitRestreintResultat> retirerAppareilRestreint(JetonGestionAppareils jeton, String id) async {
    final j = _jetonValide(jeton);
    if (j == null) return const AccesRestreintExpire();
    final appareils = _comptes[j.numero]!.appareils;
    final index = appareils.indexWhere((a) => a.id == id);
    if (index < 0) return const AccesRestreintExpire();
    j.utilise = true;
    return AppareilRetire(appareils.removeAt(index).nom);
  }

  String _jeton() => List.generate(16, (_) => _aleatoire.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
