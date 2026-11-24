import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course_suivie.dart';
import '../models/course_summary.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/courses_suivies_provider.dart';
import '../providers/programme_provider.dart';
import '../repository/course_repository.dart';
import '../widgets/followed_race.dart';
import '../widgets/liste_programme.dart';
import 'import_photo_screen.dart';
import 'profil_screen.dart';
import 'ouverture_course.dart';
import 'race_config_screen.dart';

/// Programme du jour (section 7.1 du document mobile). Sélectionner une
/// course préremplit la config course + les partants depuis le backend,
/// puis enchaîne sur l'écran de config pour ajuster terrain/niveau (que le
/// backend ne fournit pas encore — section 10 du document backend) avant de
/// continuer vers les partants et le calcul, exactement comme en saisie
/// manuelle.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  /// Toujours à minuit : c'est la clé de `programmeProvider`, partagée avec
  /// l'ouverture d'une course suivie.
  late DateTime _date;
  bool _loadingPartants = false;
  bool _refreshing = false;

  /// Recalcule « Courses suivies » à minuit (une course passée sort le
  /// lendemain), en plus du retour au premier plan.
  Timer? _minuit;

  static DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _date = ref.read(dateProgrammeWebProvider) ?? _jour(ref.read(horlogeMuraleProvider)());
    WidgetsBinding.instance.addObserver(this);
    _programmerMinuit();
  }

  @override
  void dispose() {
    _minuit?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _programmerMinuit();
    }
  }

  void _programmerMinuit() {
    _minuit?.cancel();
    final maintenant = ref.read(horlogeMuraleProvider)();
    final demain = DateTime(maintenant.year, maintenant.month, maintenant.day + 1);
    _minuit = Timer(demain.difference(maintenant) + const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {});
      _programmerMinuit();
    });
  }

  // Rafraîchissement explicite uniquement (bouton), jamais automatique en
  // arrière-plan (EXPERIENCE.md Interaction Primitives). Le programme est
  // cache-first (CourseRepository.programmeDuJour) : le cache s'affiche
  // immédiatement au premier build, sans geste requis — voir State Patterns
  // "Cold start, programme en cache".
  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final result = await ref.read(courseRepositoryProvider).rafraichirProgramme(_date);
      if (result.refreshError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de rafraîchir — dernières données affichées.')),
        );
      }
    } catch (_) {
      // Aucun cache de secours : laisser le provider ré-échouer normalement
      // ci-dessous pour afficher l'état d'erreur habituel.
    } finally {
      if (mounted) setState(() => _refreshing = false);
      ref.invalidate(programmeProvider(_date));
    }
  }

  Future<void> _pickDate() async {
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

  Future<void> _selectCourse(CourseSummary course) async {
    setState(() => _loadingPartants = true);
    try {
      await chargerCourse(ref, course, encoreValide: () => mounted);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: routeCourse),
          builder: (_) => const RaceConfigScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec du chargement des partants : $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingPartants = false);
    }
  }

  /// Ligne de « Courses suivies » : retrouve la course par sa clé PMU dans
  /// le programme de sa date (cache-first, comme l'Accueil), puis l'ouvre
  /// par le même chemin qu'une ligne du programme. Clé absente ou lecture en
  /// échec : un rafraîchissement de ce jour, puis nouvelle recherche, avant
  /// le snackbar ; l'entrée du provider est invalidée pour qu'aucun échec
  /// ne reste en cache.
  Future<void> _ouvrirCourseSuivie(CourseSuivie suivie) async {
    if (_loadingPartants) return;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(courseRepositoryProvider);
    final jour = _jour(suivie.date);
    setState(() => _loadingPartants = true);

    CourseSummary? trouver(ProgrammeResult r) {
      for (final c in r.courses) {
        if (c.cleCourse == suivie.cleCourse) return c;
      }
      return null;
    }

    CourseSummary? course;
    Object? erreur;
    try {
      // Le dépôt directement (même cache-first que programmeProvider) : un
      // provider en échec réessaie et ferait attendre son `.future`.
      course = trouver(await repo.programmeDuJour(jour));
    } catch (e) {
      erreur = e;
    }
    if (!mounted) return;
    if (course == null) {
      try {
        final frais = await repo.rafraichirProgramme(jour);
        course = trouver(frais);
        erreur = course == null ? frais.refreshError : null;
        if (mounted) ref.read(coursesSuiviesProvider.notifier).actualiserInstantanes(frais.courses);
      } catch (e) {
        erreur = e;
      }
      if (!mounted) return;
      ref.invalidate(programmeProvider(jour));
    }
    setState(() => _loadingPartants = false);
    if (course != null) {
      await _selectCourse(course);
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(erreur == null
          ? 'Course introuvable dans le programme'
          : 'Échec du chargement du programme : $erreur'),
    ));
  }

  /// Section « Courses suivies » (story 8.9) : masquée si vide et sur le web.
  Widget _sectionCoursesSuivies() {
    if (!ref.watch(suiviDisponibleProvider)) return const SizedBox.shrink();
    final etat = ref.watch(coursesSuiviesProvider);
    final lignes = coursesSuiviesAVenir(etat.lignes.values, ref.read(horlogeMuraleProvider)());
    if (lignes.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      key: const Key('section-courses-suivies'),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Courses suivies', style: Theme.of(context).textTheme.titleSmall),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in lignes)
                  LigneCourseSuivie(
                    key: ValueKey('suivie-${s.cleCourse}'),
                    course: s,
                    onTap: _loadingPartants ? null : () => _ouvrirCourseSuivie(s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_date.day.toString().padLeft(2, '0')}/'
        '${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    // Cache-first (CourseRepository.programmeDuJour) : pas de porte manuelle
    // avant le premier watch, le cache (s'il existe) s'affiche dès le
    // premier build sans geste requis — EXPERIENCE.md "Cold start, programme
    // en cache : affiche le cache immédiatement, pas d'écran de chargement
    // bloquant."
    final programmeAsync = ref.watch(programmeProvider(_date));
    // Programme (re)chargé : instantanés des courses suivies remis à jour.
    ref.listen<AsyncValue<ProgrammeResult>>(programmeProvider(_date), (_, suivant) {
      final resultat = suivant.value;
      if (resultat != null) ref.read(coursesSuiviesProvider.notifier).actualiserInstantanes(resultat.courses);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Programme du jour'),
        actions: [
          // Point d'entrée unique vers l'import photo/PDF d'un programme
          // complet (section 7.5 du document mobile, spec-4-3) — le seul
          // ajout autorisé à ce fichier par cette story.
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Importer un programme par photo/PDF',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportPhotoScreen())),
          ),
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
          // Icône de compte → Profil (story 8.4), seul ajout de cette story ;
          // absente tant qu'aucune CompteApi n'existe (release sans démo).
          if (ref.watch(compteDisponibleProvider))
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Profil',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilScreen())),
            ),
        ],
      ),
      body: Column(
        children: [
          _sectionCoursesSuivies(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateLabel, style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: const Text('Rafraîchir'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListeProgramme(
              programme: programmeAsync,
              chargement: _loadingPartants,
              rafraichissement: _refreshing,
              onRafraichir: _refresh,
              onReessayer: () => ref.invalidate(programmeProvider(_date)),
              onSelect: _selectCourse,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Saisie manuelle : l'étoile de la course précédente ne doit pas
          // suivre (story 8.9).
          ref.read(courseCouranteProvider.notifier).effacer();
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: routeCourse),
              builder: (_) => const RaceConfigScreen(),
            ),
          );
        },
        icon: const Icon(Icons.edit),
        label: const Text('Saisie manuelle'),
      ),
    );
  }
}
