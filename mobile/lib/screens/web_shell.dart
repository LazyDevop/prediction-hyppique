import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course_summary.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/courses_suivies_provider.dart';
import '../providers/paiement_provider.dart';
import '../providers/programme_provider.dart';
import '../widgets/auth_styles.dart';
import '../widgets/contour_focus.dart';
import '../widgets/liste_programme.dart';
import '../widgets/settings_row.dart' show PastillePalier;
import 'appairage_screen.dart' show BandeauConnexionWeb, EnTeteWeb;
import 'home_screen.dart';
import 'import_photo_screen.dart';
import 'ouverture_course.dart';
import 'profil_screen.dart';
import 'race_config_screen.dart';
import 'settings_screen.dart';

/// Largeur à partir de laquelle la web app passe en deux colonnes.
/// Provisoire (EXPERIENCE.md `[ASSUMPTION: seuil de bascule]`).
const largeurWebLarge = 1024.0;

/// Hystérésis : en deux colonnes, retour à une colonne seulement sous cette
/// largeur (pas de bascule en boucle autour du seuil).
const largeurWebEtroite = 960.0;

/// Bandeau permanent de la web app connectée (maquette web-compagnon, état 1).
const bandeauConnexionApp = " — pas de mode hors ligne. Sur l'hippodrome sans réseau, utilisez l'app du téléphone.";

const messageColonneVide = 'Choisissez une course dans la liste.';
const messageEcranEnCours = "Terminez ou quittez l'écran en cours avant d'ouvrir une course.";

/// Accueil de la pile : deux colonnes sur le web à partir de
/// [largeurWebLarge] (jusqu'à [largeurWebEtroite] en rétrécissant), sinon
/// l'Accueil du téléphone, inchangé. À la bascule, les écrans ouverts
/// passent d'une pile à l'autre (mêmes providers, aucun rechargement).
class AccueilRacine extends ConsumerStatefulWidget {
  const AccueilRacine({super.key});

  @override
  ConsumerState<AccueilRacine> createState() => _AccueilRacineState();
}

class _AccueilRacineState extends ConsumerState<AccueilRacine> {
  final _cleShell = GlobalKey<_WebShellState>();
  bool? _large;

  @override
  Widget build(BuildContext context) {
    final largeur = MediaQuery.sizeOf(context).width;
    final precedent = _large;
    final large =
        ref.watch(estWebProvider) && (precedent == true ? largeur >= largeurWebEtroite : largeur >= largeurWebLarge);
    if (precedent != null && precedent != large) {
      if (large) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _versLarge());
      } else {
        // Lues avant que la coquille ne soit démontée.
        final routes = _cleShell.currentState?.routesOuvertes() ?? const <MaterialPageRoute<dynamic>>[];
        WidgetsBinding.instance.addPostFrameCallback((_) => _versEtroit(routes));
      }
    }
    _large = large;
    return large ? WebShell(key: _cleShell) : const HomeScreen();
  }

  /// Téléphone → deux colonnes : les écrans poussés sur la pile principale
  /// passent dans la colonne de droite.
  void _versLarge() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    final routes = <MaterialPageRoute<dynamic>>[];
    nav.popUntil((route) {
      if (route.isFirst) return true;
      if (route is MaterialPageRoute<dynamic>) routes.insert(0, route);
      return false;
    });
    _cleShell.currentState?.reprendre(routes);
  }

  /// Deux colonnes → téléphone : les écrans de la colonne de droite passent
  /// sur la pile principale, au-dessus de l'Accueil.
  void _versEtroit(List<MaterialPageRoute<dynamic>> routes) {
    if (!mounted) return;
    // Un dialogue ouvert depuis la colonne de droite n'a plus d'écran.
    final nav = Navigator.of(context)..popUntil((route) => route.isFirst);
    for (final r in routes) {
      nav.push(MaterialPageRoute<void>(settings: r.settings, builder: r.builder));
    }
  }
}

/// Web app compagnon, layout large (story 8.7, EXPERIENCE « Web app
/// compagnon », maquette `web-compagnon.html`) : en-tête, bandeau
/// « connexion requise », programme à gauche, course choisie à droite dans
/// un Navigator imbriqué (les écrans poussés restent dans la colonne).
class WebShell extends ConsumerStatefulWidget {
  const WebShell({super.key});

  @override
  ConsumerState<WebShell> createState() => _WebShellState();
}

class _WebShellState extends ConsumerState<WebShell> {
  final _cleDroite = GlobalKey<NavigatorState>();
  late final _observateur = _ObservateurColonne(_surRetourRacine);
  late DateTime _date;
  bool _chargement = false;
  bool _rafraichissement = false;
  int? _ouverteId;
  String? _palier;

  static DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _date = ref.read(dateProgrammeWebProvider) ?? _jour(ref.read(horlogeMuraleProvider)());
    _chargerPalier();
  }

  Future<void> _chargerPalier() async {
    if (!ref.read(compteDisponibleProvider)) return;
    final api = ref.read(compteApiProvider);
    try {
      final profil = await api.lireProfil();
      if (mounted) setState(() => _palier = profil.palier);
    } catch (_) {
      // Pastille absente : Profil dit l'erreur.
    }
  }

  void _surRetourRacine() {
    if (mounted && _ouverteId != null) setState(() => _ouverteId = null);
  }

  /// Écrans ouverts dans la colonne de droite, de bas en haut (hors racine).
  List<MaterialPageRoute<dynamic>> routesOuvertes() =>
      _observateur.pile.skip(1).whereType<MaterialPageRoute<dynamic>>().toList();

  /// Bascule téléphone → deux colonnes : rouvre [routes] à droite.
  void reprendre(List<MaterialPageRoute<dynamic>> routes) {
    final nav = _cleDroite.currentState;
    if (nav == null || routes.isEmpty) return;
    for (final r in routes) {
      nav.push(MaterialPageRoute<void>(settings: r.settings, builder: r.builder));
    }
    final course = ref.read(courseCouranteProvider);
    final avecCourse = routes.any((r) => r.settings.name == routeCourse);
    setState(() => _ouverteId = avecCourse ? course?.id : null);
  }

  /// Vrai (et snackbar) si l'écran du dessus refuse d'être quitté
  /// (paiement en cours, retrait d'appareil en cours…).
  bool _dessusOccupe() {
    final pile = _observateur.pile;
    if (pile.length < 2) return false;
    if (pile.last.popDisposition != RoutePopDisposition.doNotPop) return false;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(messageEcranEnCours)));
    return true;
  }

  /// Même chemin que l'Accueil du téléphone ([chargerCourse]), puis la
  /// Configuration dans la colonne de droite, à la place de la course
  /// précédente. La course déjà ouverte : rien.
  Future<void> _ouvrirCourse(CourseSummary course) async {
    if (_chargement || course.id == _ouverteId) return;
    if (_dessusOccupe()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _chargement = true);
    try {
      final posee = await chargerCourse(ref, course, encoreValide: () => mounted && !_dessusOccupe());
      final nav = _cleDroite.currentState;
      if (!posee || !mounted || nav == null) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: routeCourse),
          builder: (_) => const RaceConfigScreen(),
        ),
        (route) => route.isFirst,
      );
      setState(() => _ouverteId = course.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Échec du chargement des partants : $e')));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  /// Remplace le contenu de la colonne de droite par [ecran] (saisie
  /// manuelle, import) ; plus aucune course du programme ouverte.
  void _remplacer(String nom, Widget ecran) {
    final nav = _cleDroite.currentState;
    if (nav == null || _chargement || _dessusOccupe()) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: nom),
        builder: (_) => ecran,
      ),
      (route) => route.isFirst,
    );
    setState(() => _ouverteId = null);
  }

  void _saisieManuelle() {
    if (_chargement || _dessusOccupe()) return;
    // Comme l'Accueil du téléphone : l'étoile de la course précédente ne
    // doit pas suivre (story 8.9).
    ref.read(courseCouranteProvider.notifier).effacer();
    _remplacer(routeCourse, const RaceConfigScreen());
  }

  /// Lien de l'en-tête : revient à [nom] s'il est déjà dans la colonne,
  /// sinon revient à la course (ou à la racine) puis ouvre [ecran].
  void _pousser(String nom, Widget ecran) {
    final nav = _cleDroite.currentState;
    if (nav == null) return;
    final pile = _observateur.pile;
    if (pile.isNotEmpty && pile.last.settings.name == nom) return;
    if (_dessusOccupe()) return;
    if (pile.any((r) => r.settings.name == nom)) {
      nav.popUntil((route) => route.settings.name == nom);
      return;
    }
    nav.popUntil((route) => route.isFirst || route.settings.name == routeCourse);
    nav.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: nom),
        builder: (_) => ecran,
      ),
    );
  }

  Future<void> _rafraichir() async {
    final repo = ref.read(courseRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final date = _date;
    setState(() => _rafraichissement = true);
    try {
      final result = await repo.rafraichirProgramme(date);
      if (result.refreshError != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossible de rafraîchir — dernières données affichées.')),
        );
      }
    } catch (_) {
      // Aucun cache de secours : l'état d'erreur habituel s'affiche.
    }
    if (!mounted) return;
    setState(() => _rafraichissement = false);
    ref.invalidate(programmeProvider(date));
  }

  Future<void> _choisirDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = _jour(picked));
    ref.read(dateProgrammeWebProvider.notifier).choisir(_date);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(signalDroitProvider, (_, _) => _chargerPalier());
    final palier = _palier;
    final compte = ref.watch(compteDisponibleProvider);

    return Scaffold(
      backgroundColor: JetonsAuth.bg,
      // Ordre de lecture : en-tête, colonne de gauche, puis colonne de droite.
      body: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FocusTraversalGroup(
              child: EnTeteWeb(
                enfants: [
                  const _OngletNav(texte: 'Programme du jour', courant: true),
                  const SizedBox(width: 8),
                  _OngletNav(texte: 'Réglages', onPressed: () => _pousser('reglages', const SettingsScreen())),
                  const Spacer(),
                  if (palier != null) PastillePalier(palier),
                  if (compte) ...[
                    const SizedBox(width: 12),
                    ContourFocus(
                      child: CtaFantome(texte: 'Profil', onPressed: () => _pousser('profil', const ProfilScreen())),
                    ),
                  ],
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: BandeauConnexionWeb(suite: bandeauConnexionApp),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FocusTraversalGroup(
                    child: Container(
                      key: const Key('colonne-gauche'),
                      width: 380,
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: JetonsAuth.lineCard)),
                      ),
                      child: _colonneGauche(context),
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: FocusTraversalGroup(
                      child: KeyedSubtree(key: const Key('colonne-droite'), child: _colonneDroite()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colonneGauche(BuildContext context) {
    final programme = ref.watch(programmeProvider(_date));
    final dateLabel =
        '${_date.day.toString().padLeft(2, '0')}/'
        '${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    // Pas d'or dans la colonne (DESIGN.md : or réservé à sa liste fermée,
    // focus excepté) : boutons, icônes, tuiles dépliées et indicateurs de
    // progression en `text` / `muted`.
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: JetonsAuth.text,
          onPrimary: JetonsAuth.bg,
          onSurfaceVariant: JetonsAuth.muted,
          secondary: JetonsAuth.muted,
          tertiary: JetonsAuth.muted,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: JetonsAuth.muted),
        expansionTileTheme: const ExpansionTileThemeData(
          iconColor: JetonsAuth.text,
          collapsedIconColor: JetonsAuth.muted,
          textColor: JetonsAuth.text,
          collapsedTextColor: JetonsAuth.text,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Expanded(child: Text(dateLabel, style: Theme.of(context).textTheme.titleMedium)),
                ContourFocus(
                  child: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    tooltip: 'Choisir la date',
                    onPressed: _choisirDate,
                  ),
                ),
                ContourFocus(
                  child: TextButton.icon(
                    onPressed: _rafraichissement ? null : _rafraichir,
                    icon: _rafraichissement
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: const Text('Rafraîchir'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            child: Row(
              children: [
                ContourFocus(
                  child: TextButton.icon(
                    onPressed: _saisieManuelle,
                    icon: const Icon(Icons.edit),
                    label: const Text('Saisie manuelle'),
                  ),
                ),
                const Spacer(),
                ContourFocus(
                  child: IconButton(
                    icon: const Icon(Icons.document_scanner_outlined),
                    tooltip: 'Importer un programme par photo/PDF',
                    onPressed: () => _remplacer('import', const ImportPhotoScreen()),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListeProgramme(
              programme: programme,
              chargement: _chargement,
              rafraichissement: _rafraichissement,
              onRafraichir: _rafraichir,
              onReessayer: () => ref.invalidate(programmeProvider(_date)),
              onSelect: _ouvrirCourse,
              courseOuverteId: _ouverteId,
              contourFocus: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colonneDroite() {
    return NavigatorPopHandler(
      onPopWithResult: (_) {
        // Retour du navigateur : seulement si l'Accueil est la route
        // courante et la porte ouverte.
        if (!(ModalRoute.isCurrentOf(context) ?? true)) return;
        if (ref.read(authProvider).value?.porte != Porte.ouverte) return;
        _cleDroite.currentState?.maybePop();
      },
      child: Navigator(
        key: _cleDroite,
        observers: [_observateur],
        routeTraversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(
            backgroundColor: JetonsAuth.bg,
            body: Center(child: Text(messageColonneVide, style: JetonsAuth.sub)),
          ),
        ),
      ),
    );
  }
}

/// Pile de la colonne de droite (de bas en haut) ; retour à la racine :
/// plus aucune course ouverte.
class _ObservateurColonne extends NavigatorObserver {
  final VoidCallback surRacine;
  final List<Route<dynamic>> pile = [];
  _ObservateurColonne(this.surRacine);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pile.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pile.remove(route);
    if (previousRoute?.isFirst ?? false) surRacine();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pile.remove(route);
    if (pile.length == 1) surRacine();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : pile.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      pile[i] = newRoute;
    } else if (newRoute != null) {
      pile.add(newRoute);
    }
  }
}

/// Entrée de navigation de l'en-tête. L'entrée courante est dite
/// « sélectionnée » et soulignée en `text` (jamais en or), sans action.
class _OngletNav extends StatelessWidget {
  final String texte;
  final bool courant;
  final VoidCallback? onPressed;
  const _OngletNav({required this.texte, this.courant = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (courant) {
      return Semantics(
        selected: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: JetonsAuth.text, width: 2)),
          ),
          child: Text(
            texte,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: JetonsAuth.text),
          ),
        ),
      );
    }
    return ContourFocus(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: JetonsAuth.muted, minimumSize: const Size(48, 48)),
        child: Text(texte, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
