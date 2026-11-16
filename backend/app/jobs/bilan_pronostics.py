"""Bilan des pronostics ML publiés face au marché, sur des courses arrivées.

Pour chaque pronostic `ml` d'une course à gagnant unique, compare la
probabilité donnée au gagnant par :
- le modèle publié (`probabilite`, combiné aux cotes pour H-60…H-10) ;
- le modèle fondamental seul (`probabilite_fondamentale`) ;
- le marché : 1/cote_direct normalisé, pris dans l'instantané de la cible
  de l'horizon (H-60 pour le pronostic du matin, qui n'a pas de cote : cette
  comparaison avantage le marché, et le rapport le signale).

Score : log-loss moyenne par course (−log p du gagnant), plus bas = mieux,
avec un IC 95 % bootstrap sur l'écart modèle − marché, apparié par course.
Une course sans instantané de la cible, ou dont le gagnant n'a pas de cote
valide (> 1) dans l'instantané, est écartée pour cet horizon.

Usage :
    python -m app.jobs.bilan_pronostics --debut 2026-11-14 --fin 2026-11-15
    python -m app.jobs.bilan_pronostics --jours 7 --sortie /app/data/bilans

Le service `pronostics` écrit aussi, une fois par jour à partir de
BILAN_HEURE (10 h par défaut, après l'ingestion des arrivées de la veille),
/app/data/bilans/bilan_<veille>.md : la veille, les 7 derniers jours et le
cumul depuis le premier pronostic ML. Si des arrivées de la veille manquent,
il attend jusqu'à BILAN_HEURE + 4 h, puis écrit quand même.
"""

import argparse
import logging
import math
import os
import random
import sys
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Dict, List, Optional, Tuple

from sqlalchemy import text

from app.data.repository import Repository

logger = logging.getLogger(__name__)

HORIZONS: Tuple[Tuple[str, int], ...] = (("matin", 60), ("h60", 60), ("h30", 30), ("h15", 15), ("h10", 10))
DESACCORD_HORIZON = "h10"
DOSSIER_BILANS = os.environ.get("BILAN_DOSSIER", "/app/data/bilans")
TIRAGES_BOOTSTRAP = 2000
ATTENTE_ARRIVEES_HEURES = 4


@dataclass
class Ligne:
    """Une course arrivée, pour un horizon."""
    course: str
    ll_modele: float
    ll_fondamental: Optional[float]
    ll_marche: float
    modele_juste: bool
    marche_juste: bool
    numero_modele: int
    numero_marche: int
    gagnant: int


@dataclass
class Bilan:
    debut: date
    fin: date
    lignes: Dict[str, List[Ligne]] = field(default_factory=dict)
    sans_arrivee: int = 0


def _ll(p: Optional[float]) -> Optional[float]:
    if p is None or not p > 0:
        return None
    return -math.log(p)


def _favori(probas: Dict[int, float]) -> int:
    return min(probas, key=lambda num: (-probas[num], num))


def calculer(repository: Repository, debut: date, fin: date) -> Bilan:
    bilan = Bilan(debut, fin, {nom: [] for nom, _ in HORIZONS})
    cibles = dict(HORIZONS)
    with repository.engine.connect() as conn:
        courses = conn.execute(text(
            "SELECT DISTINCT c.id, c.date, c.numero_reunion, c.numero_course FROM courses c "
            "JOIN prediction_runs pr ON pr.course_id = c.id AND pr.variante = 'ml' "
            "WHERE c.date >= :debut AND c.date <= :fin ORDER BY c.date, c.heure_depart"
        ), {"debut": debut.isoformat(), "fin": fin.isoformat()}).fetchall()
        for course_id, jour, reunion, numero in courses:
            gagnants = [r[0] for r in conn.execute(text(
                "SELECT num_pmu FROM participations WHERE course_id = :c AND rang_arrivee = 1"
            ), {"c": course_id})]
            if len(gagnants) != 1:
                bilan.sans_arrivee += 1
                continue
            gagnant = gagnants[0]
            marches: Dict[int, Dict[int, float]] = {}
            for num, cible, cote in conn.execute(text(
                "SELECT num_pmu, cible_minutes, cote_direct FROM cotes_instantanees WHERE course_id = :c"
            ), {"c": course_id}):
                if cote is not None and math.isfinite(cote) and cote > 1:
                    marches.setdefault(cible, {})[num] = 1.0 / cote
            libelle = f"{str(jour)[:10]} R{reunion}C{numero}"
            for run_id, horizon in conn.execute(text(
                "SELECT id, horizon FROM prediction_runs WHERE course_id = :c AND variante = 'ml'"
            ), {"c": course_id}).fetchall():
                if horizon not in cibles:
                    continue
                marche = marches.get(cibles[horizon])
                if not marche or gagnant not in marche:
                    continue
                total = sum(marche.values())
                marche = {num: v / total for num, v in marche.items()}
                probas = {num: (p, pf) for num, p, pf in conn.execute(text(
                    "SELECT num_pmu, probabilite, probabilite_fondamentale FROM prediction_chevaux WHERE run_id = :r"
                ), {"r": run_id})}
                ll_modele = _ll(probas.get(gagnant, (None, None))[0])
                if ll_modele is None:
                    continue
                num_modele = _favori({num: p for num, (p, _) in probas.items()})
                num_marche = _favori(marche)
                bilan.lignes[horizon].append(Ligne(
                    course=libelle,
                    ll_modele=ll_modele,
                    ll_fondamental=_ll(probas[gagnant][1]),
                    ll_marche=-math.log(marche[gagnant]),
                    modele_juste=num_modele == gagnant,
                    marche_juste=num_marche == gagnant,
                    numero_modele=num_modele,
                    numero_marche=num_marche,
                    gagnant=gagnant,
                ))
    return bilan


def intervalle(ecarts: List[float], tirages: int = TIRAGES_BOOTSTRAP, graine: int = 0) -> Tuple[float, float]:
    """IC 95 % bootstrap de la moyenne (tirage avec remise, graine fixe)."""
    if len(ecarts) < 2:
        return (math.nan, math.nan)
    alea = random.Random(graine)
    n = len(ecarts)
    moyennes = sorted(sum(alea.choice(ecarts) for _ in range(n)) / n for _ in range(tirages))
    return moyennes[int(0.025 * tirages)], moyennes[int(0.975 * tirages) - 1]


def _moyenne(valeurs: List[float]) -> float:
    return sum(valeurs) / len(valeurs) if valeurs else math.nan


def _f(x: float, signe: bool = False) -> str:
    if x is None or math.isnan(x):
        return "–"
    return f"{x:+.3f}" if signe else f"{x:.3f}"


def tableau(bilan: Bilan) -> List[str]:
    lignes = [
        "| Horizon | Courses | Modèle | Fondamental | Marché | Modèle − marché (IC 95 %) | N°1 gagnant modèle / marché |",
        "|---|---|---|---|---|---|---|",
    ]
    for horizon, _ in HORIZONS:
        donnees = bilan.lignes.get(horizon, [])
        if not donnees:
            lignes.append(f"| {horizon} | 0 | – | – | – | – | – |")
            continue
        n = len(donnees)
        ecarts = [l.ll_modele - l.ll_marche for l in donnees]
        bas, haut = intervalle(ecarts)
        fond = [l.ll_fondamental for l in donnees if l.ll_fondamental is not None]
        etoile = "*" if horizon == "matin" else ""
        lignes.append(
            f"| {horizon} | {n} | {_f(_moyenne([l.ll_modele for l in donnees]))} | {_f(_moyenne(fond))} "
            f"| {_f(_moyenne([l.ll_marche for l in donnees]))}{etoile} "
            f"| {_f(_moyenne(ecarts), True)} [{_f(bas, True)} ; {_f(haut, True)}] "
            f"| {sum(l.modele_juste for l in donnees) / n:.0%} / {sum(l.marche_juste for l in donnees) / n:.0%} |"
        )
    return lignes


def desaccords(bilan: Bilan) -> List[str]:
    donnees = [l for l in bilan.lignes.get(DESACCORD_HORIZON, []) if l.numero_modele != l.numero_marche]
    if not donnees:
        return [f"Aucun désaccord à {DESACCORD_HORIZON} (n°1 du modèle ≠ favori du marché)."]
    modele = sum(l.modele_juste for l in donnees)
    marche = sum(l.marche_juste for l in donnees)
    sortie = [
        f"Désaccords à {DESACCORD_HORIZON} (n°1 du modèle ≠ favori du marché) : {len(donnees)} — "
        f"modèle juste {modele}, marché juste {marche}, aucun des deux {len(donnees) - modele - marche}.",
        "",
        "| Course | N°1 modèle | Favori marché | Gagnant |",
        "|---|---|---|---|",
    ]
    sortie += [f"| {l.course} | {l.numero_modele} | {l.numero_marche} | {l.gagnant} |" for l in donnees]
    return sortie


def rapport(sections: List[Tuple[str, Bilan]], details: Optional[Bilan] = None) -> str:
    sortie = [
        "# Bilan des pronostics ML face au marché",
        "",
        "Log-loss moyenne par course (−log p du gagnant) : plus bas = mieux. Écart négatif = le modèle bat "
        "le marché. Marché = 1/cote_direct normalisé de l'instantané de l'horizon.",
        "\\* Le pronostic du matin n'a pas de cote : il est comparé au marché H-60, connu plus tard.",
    ]
    for titre, bilan in sections:
        sortie += ["", f"## {titre} ({bilan.debut} → {bilan.fin})", ""]
        sortie += tableau(bilan)
        if bilan.sans_arrivee:
            sortie += ["", f"{bilan.sans_arrivee} course(s) écartée(s) : arrivée absente ou ex-aequo en tête."]
    if details is not None:
        sortie += ["", f"## Désaccords ({details.debut} → {details.fin})", ""]
        sortie += desaccords(details)
    return "\n".join(sortie) + "\n"


def premier_jour(repository: Repository) -> Optional[date]:
    with repository.engine.connect() as conn:
        valeur = conn.execute(text(
            "SELECT MIN(c.date) FROM courses c JOIN prediction_runs pr ON pr.course_id = c.id AND pr.variante = 'ml'"
        )).scalar()
    return date.fromisoformat(str(valeur)[:10]) if valeur else None


def rapport_quotidien(repository: Repository, veille: date) -> str:
    """La veille, les 7 jours se terminant la veille, et le cumul."""
    debut = premier_jour(repository) or veille
    jour = calculer(repository, veille, veille)
    semaine = calculer(repository, max(debut, veille - timedelta(days=6)), veille)
    cumul = calculer(repository, debut, veille)
    return rapport([("Veille", jour), ("7 derniers jours", semaine), ("Cumul", cumul)], details=jour)


def chemin_rapport(dossier: str, veille: date) -> str:
    return os.path.join(dossier, f"bilan_{veille.isoformat()}.md")


def arrivees_manquantes(repository: Repository, jour: date) -> int:
    """Courses du jour ayant un pronostic ML mais aucun rang d'arrivée."""
    with repository.engine.connect() as conn:
        return conn.execute(text(
            "SELECT COUNT(DISTINCT c.id) FROM courses c "
            "JOIN prediction_runs pr ON pr.course_id = c.id AND pr.variante = 'ml' "
            "WHERE c.date = :jour AND NOT EXISTS ("
            "SELECT 1 FROM participations p WHERE p.course_id = c.id AND p.rang_arrivee IS NOT NULL)"
        ), {"jour": jour.isoformat()}).scalar() or 0


def ecrire_si_du(repository: Repository, maintenant: datetime, heure: int, dossier: str = DOSSIER_BILANS) -> Optional[str]:
    """Écrit le bilan de la veille une fois, à partir de `heure`. Tant que des
    arrivées de la veille manquent, attend jusqu'à `heure` + ATTENTE_ARRIVEES
    puis écrit quand même (courses écartées et comptées). Un fichier déjà
    présent n'est jamais réécrit (survit aux redémarrages)."""
    if maintenant.hour < heure:
        return None
    veille = maintenant.date() - timedelta(days=1)
    chemin = chemin_rapport(dossier, veille)
    if os.path.exists(chemin):
        return None
    limite = min(heure + ATTENTE_ARRIVEES_HEURES, 23)
    if maintenant.hour < limite and arrivees_manquantes(repository, veille):
        return None
    contenu = rapport_quotidien(repository, veille)
    os.makedirs(dossier, exist_ok=True)
    temporaire = chemin + ".tmp"
    with open(temporaire, "w", encoding="utf-8") as f:
        f.write(contenu)
    os.replace(temporaire, chemin)
    logger.info("Bilan des pronostics du %s écrit : %s", veille, chemin)
    return chemin


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Bilan des pronostics ML face au marché")
    parser.add_argument("--debut", type=date.fromisoformat, help="Premier jour (inclus)")
    parser.add_argument("--fin", type=date.fromisoformat, help="Dernier jour (inclus), veille par défaut")
    parser.add_argument("--jours", type=int, help="Les N jours se terminant à --fin (au lieu de --debut)")
    parser.add_argument("--sortie", help="Dossier où écrire bilan_<fin>.md (sinon affichage seul)")
    args = parser.parse_args(argv)
    if args.debut is not None and args.jours is not None:
        parser.error("--debut et --jours sont exclusifs")
    if args.jours is not None and args.jours < 1:
        parser.error("--jours doit valoir au moins 1")
    return args


def main(argv: Optional[List[str]] = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    args = parse_args(argv)
    repository = Repository()
    fin = args.fin or (date.today() - timedelta(days=1))
    if args.jours is not None:
        debut = fin - timedelta(days=args.jours - 1)
    else:
        debut = args.debut or premier_jour(repository) or fin
    if debut > fin:
        logger.error("Période vide : %s après %s", debut, fin)
        return 1
    bilan = calculer(repository, debut, fin)
    contenu = rapport([("Période", bilan)], details=bilan)
    print(contenu)
    if args.sortie:
        os.makedirs(args.sortie, exist_ok=True)
        chemin = chemin_rapport(args.sortie, fin)
        with open(chemin, "w", encoding="utf-8") as f:
            f.write(contenu)
        logger.info("Bilan écrit : %s", chemin)
    return 0


if __name__ == "__main__":
    sys.exit(main())
