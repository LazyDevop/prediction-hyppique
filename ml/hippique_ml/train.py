"""Entraîne le modèle fondamental et écrit rapport et artefacts.

    uv run python -m hippique_ml.train --features <csv.gz> --sortie <run_dir> \\
        [--train-fin 2025-04-20] [--valid-fin 2025-10-19] [--test-fin 2026-09-19]

Le test n'est utilisé qu'une fois, après l'ajustement, pour le rapport.
"""

import argparse
import json
import os
import platform
import sys
import time
from datetime import date, datetime, timezone
from importlib import metadata
from typing import Dict, List, Optional, Sequence, Tuple


from catboost import CatBoostError

from hippique_ml import evaluate
from hippique_ml.data import PERIODES, ErreurDonnees, Periodes, decouper, lire_registre, lire_table
from hippique_ml.model import GRAINE, GRILLE, ITERATIONS, entrainer

SEUIL_PORTE = 2.30
COLONNES_PREDICTIONS = [
    "course_id", "num_pmu", "date", "discipline", "proba_modele", "gagnant", "cote_reference", "cote_direct",
]


def versions() -> Dict[str, str]:
    paquets = {"python": platform.python_version()}
    for nom in ("hippique-ml", "catboost", "pandas", "numpy"):
        try:
            paquets[nom] = metadata.version(nom)
        except metadata.PackageNotFoundError:
            paquets[nom] = None
    return paquets


def executer(
    features: str,
    sortie: str,
    periodes: Periodes,
    graine: int = GRAINE,
    grille: Sequence[Tuple[int, float]] = GRILLE,
    iterations: int = ITERATIONS,
    journal=print,
) -> Dict:
    debut = time.monotonic()
    registre = lire_registre(f"{features}.registry.json")
    journal(f"Registre : {len(registre.features)} features ({len(registre.categoriques)} catégorielles)")
    table = lire_table(features, registre)
    decoupe, exclusions = decouper(table, periodes)
    preparer_sortie(sortie)  # avant l'entraînement : un dossier inutilisable ne coûte pas des heures
    for nom in PERIODES:
        journal(f"{nom} : {decoupe[nom]['course_id'].nunique()} courses, {len(decoupe[nom])} partants")

    modele = entrainer(decoupe["train"], decoupe["validation"], registre, graine=graine, grille=grille,
                       iterations=iterations, journal=journal)
    journal(f"Retenu : profondeur {modele.choisi.profondeur}, taux {modele.choisi.taux_apprentissage}, "
            f"{modele.choisi.iterations} arbres, température {modele.temperature:.4f}")

    periodes_rapport = {}
    predictions_test = None
    for nom in PERIODES:
        partie = decoupe[nom].copy()
        partie["proba_modele"] = modele.predire(partie)
        periodes_rapport[nom] = evaluate.evaluer_periode(partie)
        if nom == "test":
            predictions_test = partie[COLONNES_PREDICTIONS]

    test = periodes_rapport["test"]["global"]
    passe = test["log_loss_modele"] <= SEUIL_PORTE
    rapport = {
        "genere_le_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "features": os.path.abspath(features),
        "periodes": periodes.bornes(),
        "exclusions": {nom: exclusions[nom].to_dict() for nom in PERIODES},
        "modele": {
            "profondeur": modele.choisi.profondeur,
            "taux_apprentissage": modele.choisi.taux_apprentissage,
            "iterations": modele.choisi.iterations,
            "temperature": modele.temperature,
            "grille": [vars(e) for e in modele.essais],
        },
        "resultats": periodes_rapport,
        "importances": modele.importances(20),
        "porte": {
            "seuil": SEUIL_PORTE,
            "log_loss_test": test["log_loss_modele"],
            "passee": bool(passe),
            "verdict": verdict(test["log_loss_modele"], passe),
        },
    }
    params = {
        "graine": graine,
        "periodes": periodes.bornes(),
        "temperature": modele.temperature,
        "profondeur": modele.choisi.profondeur,
        "taux_apprentissage": modele.choisi.taux_apprentissage,
        "iterations": modele.choisi.iterations,
        "grille": [list(g) for g in grille],
        "iterations_max": iterations,
        "features": registre.features,
        "categoriques": registre.categoriques,
        "registre_git_sha": registre.git_sha,
        "versions": versions(),
    }

    modele.modele.save_model(os.path.join(sortie, "model.cbm"))
    _ecrire_json(os.path.join(sortie, "params.json"), params)
    _ecrire_json(os.path.join(sortie, "report.json"), rapport)
    with open(os.path.join(sortie, "report.md"), "w", encoding="utf-8") as fichier:
        fichier.write(rapport_markdown(rapport))
    predictions_test.to_csv(os.path.join(sortie, "test_predictions.csv.gz"), index=False, compression="gzip",
                            float_format="%.10g")
    journal(rapport["porte"]["verdict"])
    journal(f"Rapport : {os.path.join(sortie, 'report.md')} ({time.monotonic() - debut:.0f} s)")
    return rapport


def preparer_sortie(sortie: str) -> None:
    """Crée le dossier du run avant l'entraînement ; refuse d'écraser un run."""
    if os.path.exists(os.path.join(sortie, "report.json")):
        raise ErreurDonnees(f"le dossier {sortie} contient déjà un run (report.json) : choisir un autre --sortie")
    try:
        os.makedirs(sortie, exist_ok=True)
    except OSError as erreur:
        raise ErreurDonnees(f"dossier de sortie inutilisable : {sortie} ({erreur})") from erreur
    if not os.access(sortie, os.W_OK):
        raise ErreurDonnees(f"dossier de sortie non inscriptible : {sortie}")


def verdict(log_loss_test: float, passe: bool) -> str:
    etat = "PASSED" if passe else "FAILED"
    return f"Gate {etat}: test log-loss {log_loss_test:.4f} (threshold <= {SEUIL_PORTE:.2f})"


def _ecrire_json(chemin: str, contenu: Dict) -> None:
    with open(chemin, "w", encoding="utf-8") as fichier:
        json.dump(contenu, fichier, ensure_ascii=False, indent=2, default=str)


def _f(valeur: Optional[float], chiffres: int = 3) -> str:
    return "–" if valeur is None else f"{valeur:.{chiffres}f}"


def _pct(valeur: Optional[float]) -> str:
    return "–" if valeur is None else f"{100 * valeur:.1f}%"


def _ic(ic: Optional[Dict]) -> str:
    if not ic:
        return "–"
    return f"{ic['moyenne']:+.3f} [{ic['ic95_bas']:+.3f}, {ic['ic95_haut']:+.3f}]"


def _ligne(nom: str, r: Dict) -> str:
    m = r["marche"]
    return (
        f"| {nom} | {r['courses']} | {r['partants']} | {_f(r['log_loss_modele'])} | {_f(r['log_loss_uniforme'])} "
        f"| {_ic(r['modele_moins_uniforme'])} | {m['courses']} ({m['courses_cotes_incompletes']} excl.) "
        f"| {_f(m['log_loss_modele'])} | {_f(m['log_loss_marche'])} | {_ic(m['modele_moins_marche'])} "
        f"| {_pct(r['taux_top_modele'])} | {_pct(m['taux_top_modele'])} | {_pct(m['taux_favori'])} "
        f"| {_pct(r['taux_hasard'])} |"
    )


def rapport_markdown(rapport: Dict) -> str:
    l: List[str] = []
    porte = rapport["porte"]
    l += ["# Fundamental model report (roadmap stage 2)", "", f"**{porte['verdict']}**", ""]
    l += [f"Generated {rapport['genere_le_utc']} from `{rapport['features']}`.", ""]
    l += ["## Periods", ""]
    for nom, bornes in rapport["periodes"].items():
        l.append(f"- {nom}: {json.dumps(bornes)}")
    l += ["", "Excluded or flagged, per period:", ""]
    for nom, exclu in rapport["exclusions"].items():
        l.append(f"- {nom}: {json.dumps(exclu)}")
    l.append("")
    m = rapport["modele"]
    l += ["## Model", "",
          f"CatBoost QuerySoftMax, depth {m['profondeur']}, learning rate {m['taux_apprentissage']}, "
          f"{m['iterations']} trees, temperature {m['temperature']:.4f} (fitted on validation).", "",
          "| depth | learning rate | trees | validation log-loss (T=1) |", "|---|---|---|---|"]
    for e in m["grille"]:
        l.append(f"| {e['profondeur']} | {e['taux_apprentissage']} | {e['iterations']} "
                 f"| {e['log_loss_validation']:.4f} |")
    l += ["", "## Results", "",
          "Log-loss is −log p(winner), mean per race. Differences are model minus benchmark "
          "(negative = model better), with a 1,000-resample race bootstrap 95% CI. Market = H-30 odds "
          "(`cote_reference`), normalised per race, on races where every runner has odds; informative only, "
          "not the gate. Train figures are in-sample. Validation figures are optimistic: validation chose the "
          "early stop, the grid point and the temperature. Only test figures are out of sample. Top pick and "
          "favourite ties count 1/k per tied runner.", ""]
    entete = ("| scope | races | runners | model LL | uniform LL | model − uniform | market races "
              "| model LL (mkt races) | market LL | model − market | top pick | top pick (mkt races) "
              "| favourite | chance |")
    for nom in PERIODES:
        res = rapport["resultats"][nom]
        l += [f"### {nom}", "", entete, "|" + "---|" * 14, _ligne("all", res["global"])]
        for discipline, r in res["disciplines"].items():
            l.append(_ligne(discipline, r))
        l += ["", "Calibration (all disciplines):", "", "| bucket | runners | mean p | win rate |", "|---|---|---|---|"]
        for t in res["global"]["calibration"]:
            l.append(f"| [{t['borne_basse']}, {t['borne_haute']}) | {t['chevaux']} | {_f(t['proba_moyenne'])} "
                     f"| {_f(t['taux_victoire'])} |")
        l.append("")
    l += ["## Top 20 features (PredictionValuesChange)", "", "| feature | importance |", "|---|---|"]
    for i in rapport["importances"]:
        l.append(f"| {i['feature']} | {i['importance']:.3f} |")
    test = rapport["resultats"]["test"]["global"]
    l += ["", "## Gate", "", porte["verdict"], "",
          f"Test model − uniform: {_ic(test['modele_moins_uniforme'])} (the threshold alone depends on field "
          "size; this interval shows the gain over chance on the same races).", ""]
    return "\n".join(l)


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    defaut = Periodes()
    parser = argparse.ArgumentParser(description="Entraîne le modèle fondamental (étape 2)")
    parser.add_argument("--features", required=True, help="CSV gzip de build_features (registre à côté)")
    parser.add_argument("--sortie", required=True, help="Répertoire du run")
    parser.add_argument("--train-fin", type=date.fromisoformat, default=defaut.train_fin,
                        help="Premier jour hors train (début de la validation)")
    parser.add_argument("--valid-fin", type=date.fromisoformat, default=defaut.valid_fin,
                        help="Dernier jour de la validation")
    parser.add_argument("--test-fin", type=date.fromisoformat, default=defaut.test_fin,
                        help="Dernier jour du test")
    parser.add_argument("--graine", type=int, default=GRAINE)
    return parser.parse_args(argv)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    try:
        periodes = Periodes(args.train_fin, args.valid_fin, args.test_fin)
        executer(args.features, args.sortie, periodes, graine=args.graine)
    except (ErreurDonnees, OSError, CatBoostError) as erreur:
        print(f"Erreur : {erreur}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
