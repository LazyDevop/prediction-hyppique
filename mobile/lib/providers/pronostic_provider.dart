import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/api_client.dart';
import 'api_provider.dart';
import 'params_provider.dart';

/// D'où vient la course analysée : seule une course du programme (connue du
/// backend par son id) peut être comparée à son arrivée officielle. Une
/// course importée par photo ou saisie à la main n'a pas de courseId.
class PronosticContext {
  final int? courseId;
  final bool donneesModifiees;

  const PronosticContext({this.courseId, this.donneesModifiees = false});
}

class PronosticContextNotifier extends Notifier<PronosticContext> {
  @override
  PronosticContext build() => const PronosticContext();

  void courseChargee(int courseId) => state = PronosticContext(courseId: courseId);

  void sansReference() => state = const PronosticContext();

  /// Un partant ajouté, retiré ou corrigé après le chargement : le pronostic
  /// ne repose plus uniquement sur les données du programme.
  void marquerModification() {
    if (state.courseId == null || state.donneesModifiees) return;
    state = PronosticContext(courseId: state.courseId, donneesModifiees: true);
  }
}

final pronosticContextProvider =
    NotifierProvider<PronosticContextNotifier, PronosticContext>(PronosticContextNotifier.new);

const _installationIdKey = 'installation_id';

/// Identifiant anonyme et stable de cette installation : il permet de
/// suivre les pronostics par utilisateur avant l'existence de comptes.
final installationIdProvider = Provider<String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final existant = prefs.getString(_installationIdKey);
  if (existant != null) return existant;
  final random = Random.secure();
  final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  prefs.setString(_installationIdKey, id);
  return id;
});

final pronosticsApiProvider = Provider<PronosticsApi>((ref) => ref.watch(apiClientProvider));
