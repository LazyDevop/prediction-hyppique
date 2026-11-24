import 'dart:math';

import 'auth_api.dart';

/// Durée de validité d'un QR code d'appairage (FR-37).
const dureeAppairage = Duration(minutes: 2);

/// Intervalle de sondage du statut d'un appairage.
const intervalleSondageAppairage = Duration(seconds: 2);

/// Appairage créé par le serveur : identifiant, contenu du QR code (usage
/// unique), durée de validité restante au moment de la réponse (le
/// décompte local part de la réception, sur l'horloge monotone : l'heure
/// de l'ordinateur n'y entre pas) et nom de ce navigateur tel que le
/// téléphone l'affichera.
class Appairage {
  final String id;
  final String contenuQr;
  final Duration validite;
  final String nomAppareil;
  const Appairage({
    required this.id,
    required this.contenuQr,
    required this.validite,
    required this.nomAppareil,
  });
}

/// Statut d'un appairage (`en_attente`, `approuve`, `refuse`, `expire`).
sealed class StatutAppairage {
  const StatutAppairage();
}

class AppairageEnAttente extends StatutAppairage {
  const AppairageEnAttente();
}

/// Le téléphone a approuvé : la session de ce navigateur est ouverte.
class AppairageApprouve extends StatutAppairage {
  final SessionOuverte session;
  const AppairageApprouve(this.session);
}

/// Approuvé, mais la limite d'appareils du palier est atteinte : aucune
/// session, seul un jeton de gestion des appareils (comme par code SMS).
class AppairageBloque extends StatutAppairage {
  final AppareilBloque blocage;
  const AppairageBloque(this.blocage);
}

class AppairageRefuse extends StatutAppairage {
  const AppairageRefuse();
}

class AppairageExpire extends StatutAppairage {
  const AppairageExpire();
}

/// Port d'appairage par QR code, côté web (story 8.7). Les écrans ne
/// dépendent que de cette interface ; [FauxAppairageApi] la remplace tant
/// que les routes serveur n'existent pas.
abstract class AppairageApi {
  Future<Appairage> creer();

  Future<StatutAppairage> statut(String id);
}

class _AppairageDemo {
  final DateTime expireLe;
  StatutAppairage statut = const AppairageEnAttente();
  _AppairageDemo(this.expireLe);
}

/// Faux serveur local de démonstration : un QR code expire après
/// [dureeAppairage] ; [approuverDemo] et [refuserDemo] simulent le
/// téléphone. Un appairage approuvé ne se lit qu'une fois (usage unique).
class FauxAppairageApi implements AppairageApi {
  /// Numéro du compte ouvert par une approbation de démonstration.
  static const numeroDemo = '+237677123456';

  /// Nom de ce navigateur côté faux serveur (même nom que dans Mes appareils).
  static const nomNavigateurDemo = 'Navigateur web';

  /// Compte rattaché par [approuverDemo] (E.164).
  final String numero;

  final DateTime Function() _horloge;
  /// Limite d'appareils (faux `FauxCompteApi`) ; sans lui, jamais de refus.
  final RattachementDemo? rattachement;
  final Map<String, _AppairageDemo> _appairages = {};
  final Random _aleatoire = Random.secure();

  FauxAppairageApi({DateTime Function()? horloge, this.rattachement, this.numero = numeroDemo})
    : _horloge = horloge ?? DateTime.now;

  /// Identifiant du dernier appairage créé (QR affiché).
  String? dernierId;

  @override
  Future<Appairage> creer() async {
    final id = 'demo-appairage-${_jeton(8)}';
    dernierId = id;
    final maintenant = _horloge();
    final expireLe = maintenant.add(dureeAppairage);
    _appairages[id] = _AppairageDemo(expireLe);
    return Appairage(
      id: id,
      contenuQr: 'analyseur-hippique:appairage:$id:${_jeton(16)}',
      validite: expireLe.difference(maintenant),
      nomAppareil: nomNavigateurDemo,
    );
  }

  @override
  Future<StatutAppairage> statut(String id) async {
    final a = _appairages[id];
    if (a == null) return const AppairageExpire();
    final statut = a.statut;
    if (statut is AppairageApprouve || statut is AppairageBloque) {
      _appairages.remove(id); // usage unique
      return statut;
    }
    if (statut is AppairageEnAttente && !_horloge().isBefore(a.expireLe)) {
      a.statut = const AppairageExpire();
    }
    return a.statut;
  }

  /// « Mode démo : simuler l'approbation du téléphone ». Sans effet sur un
  /// appairage inconnu, expiré ou déjà tranché. Limite d'appareils atteinte
  /// (faux compte) : [AppairageBloque].
  void approuverDemo(String id) {
    final a = _appairages[id];
    if (a == null || a.statut is! AppairageEnAttente || !_horloge().isBefore(a.expireLe)) return;
    final bloque = rattachement?.rattacher(numero, cguVersion: '');
    a.statut = bloque != null
        ? AppairageBloque(bloque)
        : AppairageApprouve(SessionOuverte(
            accessToken: 'demo-acces-${_jeton(16)}',
            refreshToken: 'demo-renouvellement-${_jeton(16)}',
            numeroMasque: masquerNumero(numero),
          ));
  }

  /// Le téléphone refuse (tests ; pas de lien de démo).
  void refuserDemo(String id) {
    final a = _appairages[id];
    if (a != null && a.statut is AppairageEnAttente) a.statut = const AppairageRefuse();
  }

  String _jeton(int octets) =>
      List.generate(octets, (_) => _aleatoire.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}
