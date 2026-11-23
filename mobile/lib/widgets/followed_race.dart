import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course_suivie.dart';
import '../providers/courses_suivies_provider.dart';
import 'auth_styles.dart';

/// `followed-race` (DESIGN.md, story 8.9). Étoile ★ pleine (`text`) si
/// suivie, contour (`muted`) sinon, jamais en or ; l'état est aussi écrit
/// (« Suivre » / « Suivie ») et porté par la sémantique d'interrupteur.

String _heureLocale(DateTime? heureDepart) {
  final h = heureDepart?.toLocal();
  if (h == null) return '—:—';
  return '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
}

/// « 15 heures 05 » pour la lecture d'écran (EXPERIENCE.md Accessibility).
String? _heureParlee(DateTime? heureDepart) {
  final h = heureDepart?.toLocal();
  if (h == null) return null;
  return '${h.hour} heures ${h.minute.toString().padLeft(2, '0')}';
}

/// « Suivre la course, {heure}, {hippodrome}, course {n} » ; les segments
/// inconnus sont omis.
String libelleSuivi({DateTime? heureDepart, required String hippodrome, int? numeroCourse}) {
  return [
    'Suivre la course',
    ?_heureParlee(heureDepart),
    hippodrome,
    if (numeroCourse != null) 'course $numeroCourse',
  ].join(', ');
}

int? _numeroCourseDeCle(String cle) => int.tryParse(RegExp(r'-C(\d+)$').firstMatch(cle)?.group(1) ?? '');

/// Interrupteur étoile : une seule cible ≥ 48dp, sémantique d'interrupteur.
/// L'état n'est dit qu'une fois, par l'interrupteur (« activé » / « non
/// activé », epics 8.9) ; le libellé visible « Suivre » / « Suivie » est
/// décoratif pour TalkBack. [onTap] nul : inactive (cache pas encore lu).
class _Etoile extends StatelessWidget {
  final bool suivie;
  final bool avecLibelle;
  final String libelle;
  final VoidCallback? onTap;

  const _Etoile({super.key, required this.suivie, required this.avecLibelle, required this.libelle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final couleur = suivie ? JetonsAuth.text : JetonsAuth.muted;
    return Semantics(
      container: true,
      toggled: suivie,
      enabled: onTap != null,
      label: libelle,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(suivie ? Icons.star : Icons.star_border, color: couleur, size: 22),
                  if (avecLibelle) ...[
                    const SizedBox(width: 4),
                    Text(suivie ? 'Suivie' : 'Suivre', style: TextStyle(color: couleur, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Étoile de l'en-tête (Liste des partants, Résultats). Rien quand la course
/// ouverte n'a pas de clé PMU (saisie manuelle, import photo) ou sur le web.
class EtoileSuiviCourse extends ConsumerWidget {
  const EtoileSuiviCourse({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseSuivableProvider);
    if (course == null) return const SizedBox.shrink();
    final etat = ref.watch(coursesSuiviesProvider);
    return _Etoile(
      key: const Key('etoile-suivi-course'),
      suivie: etat[course.cleCourse!]?.suivie ?? false,
      avecLibelle: true,
      libelle: libelleSuivi(
        heureDepart: course.heureDepart,
        hippodrome: course.hippodrome,
        numeroCourse: course.numeroCourse ?? _numeroCourseDeCle(course.cleCourse!),
      ),
      onTap: etat.charge ? () => ref.read(coursesSuiviesProvider.notifier).basculerCourse(course) : null,
    );
  }
}

/// Libellé TalkBack d'une ligne de la section : « 14 heures 05, R1 C4,
/// VINCENNES » (segments inconnus omis).
String libelleLigneSuivie(CourseSuivie course) {
  final reunion = course.numeroReunion;
  final numero = course.numeroCourse;
  return [
    ?_heureParlee(course.heureDepart),
    if (reunion != null && numero != null) 'R$reunion C$numero',
    course.hippodrome,
  ].join(', ');
}

/// Ligne de la section « Courses suivies » de l'Accueil.
class LigneCourseSuivie extends ConsumerWidget {
  final CourseSuivie course;
  final VoidCallback? onTap;

  const LigneCourseSuivie({super.key, required this.course, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reunion = course.numeroReunion;
    final numero = course.numeroCourse;
    final meta = [
      if (reunion != null && numero != null) 'R$reunion C$numero',
      course.hippodrome,
    ].join(' · ');
    final charge = ref.watch(coursesSuiviesProvider.select((e) => e.charge));
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: JetonsAuth.line))),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              button: true,
              label: libelleLigneSuivie(course),
              onTap: onTap,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 52,
                            child: Text(
                              _heureLocale(course.heureDepart),
                              style: const TextStyle(
                                color: JetonsAuth.text,
                                fontWeight: FontWeight.w600,
                                fontFeatures: JetonsAuth.tabulaire,
                              ),
                            ),
                          ),
                          Expanded(child: Text(meta, style: const TextStyle(color: JetonsAuth.muted, fontSize: 13))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _Etoile(
              suivie: course.suivie,
              avecLibelle: false,
              libelle: libelleSuivi(
                heureDepart: course.heureDepart,
                hippodrome: course.hippodrome,
                numeroCourse: numero,
              ),
              onTap: charge ? () => ref.read(coursesSuiviesProvider.notifier).nePlusSuivre(course.cleCourse) : null,
            ),
          ),
        ],
      ),
    );
  }
}
