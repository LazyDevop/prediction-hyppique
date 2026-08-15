import '../models/horse.dart';

/// Probabilités de place (chaîne de Harville) — section 7.10 du document
/// backend. Top2 = P(1er)+P(2e), Top3 = Top2+P(3e), Top4 = Top3+P(4e) : les
/// accumulateurs partent bien du rang précédent, pas de la probabilité brute
/// (bug corrigé côté backend qui faisait la même erreur — ne pas la
/// réintroduire ici).
void computeHarville(List<Horse> horses) {
  final p = horses.map((h) => h.probabilite).toList();
  final n = p.length;

  for (var i = 0; i < n; i++) {
    horses[i].top1 = p[i];
    horses[i].top2 = p[i];
    horses[i].top3 = p[i];
    horses[i].top4 = p[i];
  }

  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      if (i == j) continue;
      final denom = 1 - p[j];
      if (denom <= 0) continue;
      horses[i].top2 += p[j] * p[i] / denom;
    }
  }

  for (var i = 0; i < n; i++) {
    var total = horses[i].top2;
    for (var j = 0; j < n; j++) {
      if (i == j) continue;
      for (var k = 0; k < n; k++) {
        if (k == i || k == j) continue;
        final denomJ = 1 - p[j];
        final denomK = 1 - p[j] - p[k];
        if (denomJ <= 0 || denomK <= 0) continue;
        total += p[j] * (p[k] / denomJ) * (p[i] / denomK);
      }
    }
    horses[i].top3 = total;
  }

  for (var i = 0; i < n; i++) {
    var total = horses[i].top3;
    for (var j = 0; j < n; j++) {
      if (i == j) continue;
      final denomJ = 1 - p[j];
      if (denomJ <= 0) continue;
      for (var k = 0; k < n; k++) {
        if (k == i || k == j) continue;
        final denomK = 1 - p[j] - p[k];
        if (denomK <= 0) continue;
        for (var l = 0; l < n; l++) {
          if (l == i || l == j || l == k) continue;
          final denomL = 1 - p[j] - p[k] - p[l];
          if (denomL <= 0) continue;
          total += p[j] * (p[k] / denomJ) * (p[l] / denomK) * (p[i] / denomL);
        }
      }
    }
    horses[i].top4 = total;
  }

  for (final horse in horses) {
    horse.top2 = horse.top2.clamp(0.0, 1.0);
    horse.top3 = horse.top3.clamp(0.0, 1.0);
    horse.top4 = horse.top4.clamp(0.0, 1.0);
  }
}
