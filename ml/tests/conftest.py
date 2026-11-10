"""Table de features synthétique au format build_features (CSV gzip + registre)."""

import copy
import gzip
import csv
import json
from datetime import date, timedelta

import numpy as np
import pytest

from hippique_ml.data import Periodes

COLONNES = [
    ("course_id", "id", "numeric"), ("date", "id", "categorical"), ("discipline", "id", "categorical"),
    ("num_pmu", "id", "numeric"),
    ("rang", "label", "numeric"), ("gagnant", "label", "flag"), ("place", "label", "flag"),
    ("cote_reference", "marche", "numeric"), ("cote_direct", "marche", "numeric"),
    ("f_force", "feature", "numeric"), ("f_bruit", "feature", "numeric"),
    ("f_inedit", "feature", "flag"), ("f_sexe", "feature", "categorical"),
]

REGISTRE = {
    "git_sha": "abc123",
    "colonnes": [{"nom": n, "groupe": g, "type": t, "sources": []} for n, g, t in COLONNES],
}

# Périodes de test : 2025-01-01 → 2025-01-20 train, → 2025-01-27 validation, → 2025-02-03 test.
PERIODES = Periodes(train_fin=date(2025, 1, 21), valid_fin=date(2025, 1, 27), test_fin=date(2025, 2, 3))
GRILLE_TEST = ((4, 0.1),)
ITERATIONS_TEST = 60


def lignes_synthetiques(jours=34, courses_par_jour=6, graine=0):
    rng = np.random.default_rng(graine)
    lignes, course_id = [], 0
    for j in range(jours):
        jour = date(2025, 1, 1) + timedelta(days=j)
        for _ in range(courses_par_jour):
            course_id += 1
            n = int(rng.integers(5, 12))
            force = rng.normal(size=n)
            gagnant = int(np.argmax(force + rng.gumbel(size=n)))
            for i in range(n):
                cote = round(float(np.exp(-force[i]) * 5 + 1.2), 1)
                lignes.append({
                    "course_id": course_id, "date": jour.isoformat(),
                    "discipline": "trot" if course_id % 2 else "plat", "num_pmu": i + 1,
                    "rang": 1 if i == gagnant else "", "gagnant": int(i == gagnant), "place": int(i == gagnant),
                    "cote_reference": cote, "cote_direct": cote,
                    "f_force": round(float(force[i]), 6), "f_bruit": "" if i == 0 else round(float(rng.normal()), 6),
                    "f_inedit": int(rng.integers(0, 2)), "f_sexe": "" if i == 1 else ("M" if i % 2 else "F"),
                })
    return lignes


def ecrire(dossier, lignes, registre=None, nom="features.csv.gz"):
    chemin = dossier / nom
    with gzip.open(chemin, "wt", encoding="utf-8", newline="") as fichier:
        ecrivain = csv.DictWriter(fichier, fieldnames=[c[0] for c in COLONNES])
        ecrivain.writeheader()
        ecrivain.writerows(lignes)
    with open(f"{chemin}.registry.json", "w", encoding="utf-8") as fichier:
        json.dump(registre or REGISTRE, fichier)
    return str(chemin)


@pytest.fixture
def registre():
    return copy.deepcopy(REGISTRE)


@pytest.fixture
def table_synthetique(tmp_path):
    return ecrire(tmp_path, lignes_synthetiques())
