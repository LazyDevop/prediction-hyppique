import 'dart:math';

import '../models/horse.dart';

/// Toutes les permutations de longueur [depth] choisies parmi
/// range(0, n), équivalent de itertools.permutations(range(n), depth).
List<List<int>> _permutations(int n, int depth) {
  final result = <List<int>>[];
  if (depth <= 0 || depth > n) return result;

  void recurse(List<int> chosen, List<bool> used) {
    if (chosen.length == depth) {
      result.add(List<int>.from(chosen));
      return;
    }
    for (var x = 0; x < n; x++) {
      if (used[x]) continue;
      used[x] = true;
      chosen.add(x);
      recurse(chosen, used);
      chosen.removeLast();
      used[x] = false;
    }
  }

  recurse(<int>[], List<bool>.filled(n, false));
  return result;
}

/// Probabilité Plackett-Luce de chaque permutation exacte de longueur depth.
/// p_ordre = P_a · (P_b/(1-P_a)) · (P_c/(1-P_a-P_b)) · ... (section 7.12).
Map<List<int>, double> exactPermutationsProbabilities(
    List<double> probabilities, int depth) {
  final result = <List<int>, double>{};
  for (final perm in _permutations(probabilities.length, depth)) {
    var prob = 1.0;
    var remaining = 1.0;
    for (var position = 0; position < perm.length; position++) {
      final p = probabilities[perm[position]];
      if (position == 0) {
        prob *= p;
      } else {
        if (remaining <= 0) {
          prob = 0.0;
          break;
        }
        prob *= p / remaining;
      }
      remaining -= p;
      if (remaining < 0) remaining = 0.0;
    }
    result[perm] = prob;
  }
  return result;
}

class OrdreItem {
  final List<int> ordre;
  final double probabilite;
  OrdreItem(this.ordre, this.probabilite);
}

class EnsembleItem {
  final List<int> ensemble;
  final double probabilite;
  EnsembleItem(this.ensemble, this.probabilite);
}

List<OrdreItem> exactOrdered(List<double> probabilities, int depth) {
  if (depth <= 0) return [];
  final perms = exactPermutationsProbabilities(probabilities, depth);
  final items = perms.entries.map((e) => OrdreItem(e.key, e.value)).toList();
  items.sort((a, b) => b.probabilite.compareTo(a.probabilite));
  return items;
}

List<EnsembleItem> exactUnordered(List<double> probabilities, int depth) {
  final ordered = exactOrdered(probabilities, depth);
  final groups = <String, EnsembleItem>{};
  for (final item in ordered) {
    final sorted = List<int>.from(item.ordre)..sort();
    final key = sorted.join('-');
    final existing = groups[key];
    groups[key] = EnsembleItem(sorted, (existing?.probabilite ?? 0) + item.probabilite);
  }
  final items = groups.values.toList();
  items.sort((a, b) => b.probabilite.compareTo(a.probabilite));
  return items;
}

class PaireItem {
  final int a;
  final int b;
  final double probabilite;
  PaireItem(this.a, this.b, this.probabilite);
}

/// Tirage pondéré sans remise (clés d'Efraimidis-Spirakis), équivalent
/// vectorisé de la version numpy corrigée côté backend : trier par
/// u_i^(1/poids_i) reproduit un tirage séquentiel Plackett-Luce.
Map<String, int> _monteCarloTopIndices(
    List<double> probabilities, int topM, int trials, int seed) {
  final n = probabilities.length;
  final rng = Random(seed);
  final weights = probabilities.map((p) => p < 1e-12 ? 1e-12 : p).toList();
  final counts = <String, int>{};

  for (var t = 0; t < trials; t++) {
    final keys = List<double>.generate(
      n,
      (i) => pow(rng.nextDouble(), 1.0 / weights[i]).toDouble(),
    );
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) => keys[b].compareTo(keys[a]));
    final top = order.take(topM).toList()..sort();
    for (var i = 0; i < top.length; i++) {
      for (var j = i + 1; j < top.length; j++) {
        final key = '${top[i]}-${top[j]}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
  }
  return counts;
}

List<PaireItem> monteCarloPlaceProbabilities(
    List<double> probabilities, int topM,
    {int trials = 20000, int seed = 0}) {
  final n = probabilities.length;
  if (n == 0 || topM <= 0) return [];
  final m = min(topM, n);
  final counts = _monteCarloTopIndices(probabilities, m, trials, seed);
  return counts.entries.map((e) {
    final parts = e.key.split('-');
    return PaireItem(int.parse(parts[0]), int.parse(parts[1]), e.value / trials);
  }).toList();
}

class ComboLabel {
  final List<int?> dossards;
  final List<String> noms;
  final double probabilite;
  ComboLabel(this.dossards, this.noms, this.probabilite);
}

class ComboOrdreDesordre {
  final List<ComboLabel> ordre;
  final List<ComboLabel> desordre;
  ComboOrdreDesordre(this.ordre, this.desordre);
}

class Combinaisons {
  final ComboOrdreDesordre couple;
  final ComboOrdreDesordre trio;
  final ComboOrdreDesordre quarte;
  final ComboOrdreDesordre quinte;
  final List<ComboLabel> couplePlace;
  final List<ComboLabel> deuxSurQuatre;

  Combinaisons({
    required this.couple,
    required this.trio,
    required this.quarte,
    required this.quinte,
    required this.couplePlace,
    required this.deuxSurQuatre,
  });
}

ComboLabel _label(List<Horse> reels, List<int> indices) {
  return ComboLabel(
    indices.map((i) => reels[i].numPmu).toList(),
    indices.map((i) => reels[i].nom).toList(),
    0,
  );
}

ComboOrdreDesordre _comboOrdreDesordre(List<Horse> reels, int nbReels,
    List<int> ordreFavoris, int depth, int poolSize) {
  final pool = ordreFavoris.take(min(poolSize, nbReels)).toList();
  if (nbReels < depth || pool.length < depth) {
    return ComboOrdreDesordre([], []);
  }

  final poolProbs = pool.map((i) => reels[i].probabilite).toList();
  final ordered = exactOrdered(poolProbs, depth).take(3);
  final unordered = exactUnordered(poolProbs, depth).take(3);

  final ordreOut = ordered.map((item) {
    final indices = item.ordre.map((localI) => pool[localI]).toList();
    final label = _label(reels, indices);
    return ComboLabel(label.dossards, label.noms, item.probabilite);
  }).toList();

  final desordreOut = unordered.map((item) {
    final indices = item.ensemble.map((localI) => pool[localI]).toList();
    final label = _label(reels, indices);
    return ComboLabel(label.dossards, label.noms, item.probabilite);
  }).toList();

  return ComboOrdreDesordre(ordreOut, desordreOut);
}

List<ComboLabel> _comboPlace(List<Horse> reels, int nbReels,
    List<double> probabilitesChamp, int topM) {
  final counts = monteCarloPlaceProbabilities(probabilitesChamp, topM);
  final reelsPairs = counts.where((p) => p.a < nbReels && p.b < nbReels).toList()
    ..sort((a, b) => b.probabilite.compareTo(a.probabilite));
  return reelsPairs.take(3).map((p) {
    final label = _label(reels, [p.a, p.b]);
    return ComboLabel(label.dossards, label.noms, p.probabilite);
  }).toList();
}

/// Combinaisons calculées sur le résultat complet d'analyseCourse (réels +
/// outsiders virtuels). nbReels est le nombre de chevaux réellement saisis :
/// seuls eux peuvent être nommés dans une combinaison, mais la probabilité de
/// chaque ordre reste calculée sur le champ complet (section 7.12).
Combinaisons buildCombinaisons(List<Horse> horses, int nbReels) {
  final probabilitesChamp = horses.map((h) => h.probabilite).toList();
  final reels = horses.take(nbReels).toList();
  final ordreFavoris = List<int>.generate(nbReels, (i) => i)
    ..sort((a, b) => reels[b].probabilite.compareTo(reels[a].probabilite));

  return Combinaisons(
    couple: _comboOrdreDesordre(reels, nbReels, ordreFavoris, 2, 8),
    trio: _comboOrdreDesordre(reels, nbReels, ordreFavoris, 3, 7),
    quarte: _comboOrdreDesordre(reels, nbReels, ordreFavoris, 4, 7),
    quinte: _comboOrdreDesordre(reels, nbReels, ordreFavoris, 5, 7),
    couplePlace: _comboPlace(reels, nbReels, probabilitesChamp, 3),
    deuxSurQuatre: _comboPlace(reels, nbReels, probabilitesChamp, 4),
  );
}
