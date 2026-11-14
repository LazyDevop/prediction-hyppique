"""Construit la table de features point-in-time (étape 1 de la feuille de
route du modèle prédictif).

Une ligne par partant effectif de chaque course française finalisée
(source turfinfo "pmu" ; jamais open-pmu) de la plage demandée. L'état
(historique des chevaux, des drivers, des entraîneurs, des pères) est
construit en un seul passage chronologique depuis la première course en
base : les jours antérieurs à --date-debut alimentent l'état sans produire
de lignes. Aucune requête par ligne.

Sortie : CSV gzip avec en-tête, trié par date, course et dossard, plus un
fichier `<sortie>.registry.json` qui décrit chaque colonne (groupe, type,
sources), les paramètres et les lignes écartées. Les deux fichiers sont
écrits de façon atomique.

    docker compose exec api python -m app.jobs.build_features \\
        --date-debut 2025-10-20 --date-fin 2026-09-19 \\
        --sortie /app/data/features_2025-26.csv.gz
"""

import argparse
import csv
import gzip
import json
import logging
import os
import subprocess
import sys
import time
from collections import Counter
from datetime import date, datetime, timezone
from typing import Any, Dict, Iterator, List, Optional, Tuple

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.data.models import Course, Participation
from app.data.repository import Repository
from app.model.features import (
    COLONNES, NOMS_COLONNES, NOTE_REGISTRE, PARAMETRES, ConstructeurFeatures, CourseRecord, PartantRecord,
    type_colonne,
)

logger = logging.getLogger(__name__)

TAILLE_LOT = 5000


_COLONNES_LECTURE = (
    Course.id, Course.date, Course.discipline, Course.distance, Course.allocation,
    Course.terrain, Course.hippodrome,
    Participation.num_pmu, Participation.cheval_id, Participation.driver, Participation.entraineur,
    Participation.rang_arrivee, Participation.incident, Participation.cote_reference,
    Participation.cote_direct, Participation.donnees_brutes,
)


def _course_record(row) -> CourseRecord:
    return CourseRecord(
        course_id=row.id, date=row.date, discipline=row.discipline, distance=row.distance,
        allocation=row.allocation, terrain=row.terrain, hippodrome=row.hippodrome,
    )


def _brut(row) -> Tuple[Dict[str, Any], bool]:
    """(donnees_brutes décodé, illisible). Illisible ou non objet JSON : brut vide."""
    if not row.donnees_brutes:
        return {}, False
    try:
        brut = json.loads(row.donnees_brutes)
    except (ValueError, TypeError):
        logger.warning("donnees_brutes illisibles (course %s, num %s)", row.id, row.num_pmu)
        return {}, True
    if not isinstance(brut, dict):
        logger.warning("donnees_brutes non objet (course %s, num %s)", row.id, row.num_pmu)
        return {}, True
    return brut, False


def lire_jours(
    repository: Repository, date_fin: date, compteurs: Optional[Counter] = None,
    date_debut: Optional[date] = None,
) -> Iterator[List[CourseRecord]]:
    """Courses finalisées jusqu'à date_fin, regroupées par jour, dans l'ordre.
    Les lignes dont donnees_brutes est illisible (ou n'est pas un objet JSON)
    sont gardées avec un brut vide, et comptées dans `compteurs` à partir de
    date_debut (la plage émise)."""
    compteurs = compteurs if compteurs is not None else Counter()
    requete = (
        select(*_COLONNES_LECTURE)
        .join(Participation, Participation.course_id == Course.id)
        .where(Course.finalisee.is_(True), Course.source == "pmu", Course.date <= date_fin)
        .order_by(Course.date, Course.id, Participation.num_pmu)
        .execution_options(yield_per=TAILLE_LOT)
    )
    jour: Optional[date] = None
    courses: List[CourseRecord] = []
    course: Optional[CourseRecord] = None
    with Session(repository.engine) as session:
        for row in session.execute(requete):
            if row.date != jour:
                if courses:
                    yield courses
                jour, courses, course = row.date, [], None
            if course is None or course.course_id != row.id:
                course = _course_record(row)
                courses.append(course)
            brut, illisible = _brut(row)
            if illisible and (date_debut is None or row.date >= date_debut):
                compteurs["brut_illisible"] += 1
            # Un dossard absent (num_pmu NULL) reste dans le champ et
            # l'historique : seule sa ligne de sortie est écartée, par le
            # constructeur, qui la compte.
            course.partants.append(PartantRecord(
                num_pmu=row.num_pmu, cheval_id=row.cheval_id, brut=brut,
                driver=row.driver, entraineur=row.entraineur, rang_arrivee=row.rang_arrivee,
                incident=row.incident, cote_reference=row.cote_reference, cote_direct=row.cote_direct,
            ))
    if courses:
        yield courses


def lire_courses_du_jour(repository: Repository, jour: date) -> List[Tuple[CourseRecord, datetime]]:
    """Courses du jour à pronostiquer (source pmu, heure_depart renseignée),
    finalisées ou non, avec leur heure de départ, dans l'ordre (course,
    dossard). Aucun champ après course n'est lu : rang, cotes et incident
    restent vides, sauf l'incident NON_PARTANT, déclaré avant la course."""
    requete = (
        select(*_COLONNES_LECTURE, Course.heure_depart)
        .join(Participation, Participation.course_id == Course.id)
        .where(Course.source == "pmu", Course.date == jour, Course.heure_depart.isnot(None))
        .order_by(Course.id, Participation.num_pmu)
    )
    resultat: List[Tuple[CourseRecord, datetime]] = []
    course: Optional[CourseRecord] = None
    with Session(repository.engine) as session:
        for row in session.execute(requete):
            if course is None or course.course_id != row.id:
                course = _course_record(row)
                resultat.append((course, row.heure_depart))
            brut, _ = _brut(row)
            course.partants.append(PartantRecord(
                num_pmu=row.num_pmu, cheval_id=row.cheval_id, brut=brut,
                driver=row.driver, entraineur=row.entraineur,
                incident="NON_PARTANT" if row.incident == "NON_PARTANT" else None,
            ))
    return resultat


def formater(valeur: Any) -> str:
    if valeur is None:
        return ""
    if isinstance(valeur, bool):
        return "1" if valeur else "0"
    if isinstance(valeur, float):
        if valeur.is_integer() and abs(valeur) < 1e15:
            return str(int(valeur))
        return repr(round(valeur, 6))
    if isinstance(valeur, date):
        return valeur.isoformat()
    return str(valeur)


def chemin_registre(sortie: str) -> str:
    return f"{sortie}.registry.json"


def sha_git() -> Optional[str]:
    """SHA du commit du code, ou None hors dépôt git (image docker)."""
    try:
        resultat = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=os.path.dirname(os.path.abspath(__file__)),
            capture_output=True, text=True, timeout=5, check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    sha = resultat.stdout.strip()
    return sha if resultat.returncode == 0 and sha else None


def lignes_ecartees(repository: Repository, date_debut: date, date_fin: date) -> Dict[str, int]:
    """Participations de la plage jamais lues : course non finalisée (source
    pmu) ou course d'une autre source."""
    with Session(repository.engine) as session:
        def compter(*conditions) -> int:
            return session.execute(
                select(func.count(Participation.id))
                .join(Course, Participation.course_id == Course.id)
                .where(Course.date >= date_debut, Course.date <= date_fin, *conditions)
            ).scalar_one()

        return {
            "course_non_finalisee": compter(Course.source == "pmu", Course.finalisee.isnot(True)),
            "autre_source": compter(Course.source != "pmu"),
        }


def _supprimer(chemin: str) -> None:
    try:
        os.remove(chemin)
    except OSError:
        pass


def construire(repository: Repository, date_debut: date, date_fin: date, sortie: str) -> Dict[str, Any]:
    """Écrit la sortie et son registre dans des fichiers temporaires, puis
    les met en place par os.replace : un échec ne laisse aucun fichier
    partiel à la place d'une sortie existante."""
    debut = time.monotonic()
    os.makedirs(os.path.dirname(os.path.abspath(sortie)), exist_ok=True)
    tmp_sortie = f"{sortie}.tmp"
    tmp_registre = f"{chemin_registre(sortie)}.tmp"
    try:
        bilan = _construire(repository, date_debut, date_fin, tmp_sortie, tmp_registre, debut)
        os.replace(tmp_sortie, sortie)
        os.replace(tmp_registre, chemin_registre(sortie))
    except BaseException:
        _supprimer(tmp_sortie)
        _supprimer(tmp_registre)
        raise
    logger.info(
        "Features %s -> %s : %d course(s), %d ligne(s), %d jour(s) (+ %d jour(s) d'historique antérieur) "
        "en %.0f s -> %s | écartées ou signalées : %s",
        date_debut, date_fin, bilan["courses"], bilan["lignes"], bilan["jours"], bilan["jours_historique"],
        time.monotonic() - debut, sortie, bilan["ecartees"],
    )
    return bilan


def _construire(
    repository: Repository, date_debut: date, date_fin: date, tmp_sortie: str, tmp_registre: str, debut: float,
) -> Dict[str, Any]:
    constructeur = ConstructeurFeatures()
    compteurs: Counter = Counter()
    bilan: Dict[str, Any] = {"jours": 0, "courses": 0, "lignes": 0, "jours_historique": 0}
    with gzip.open(tmp_sortie, "wt", encoding="utf-8", newline="") as fichier:
        ecrivain = csv.writer(fichier)
        ecrivain.writerow(NOMS_COLONNES)
        for courses in lire_jours(repository, date_fin, compteurs, date_debut):
            emettre = courses[0].date >= date_debut
            lignes = constructeur.traiter_jour(courses, emettre=emettre)
            if not emettre:
                bilan["jours_historique"] += 1
                continue
            bilan["jours"] += 1
            bilan["courses"] += len({l["course_id"] for l in lignes})
            bilan["lignes"] += len(lignes)
            for ligne in lignes:
                ecrivain.writerow([formater(ligne[nom]) for nom in NOMS_COLONNES])
            if bilan["jours"] % 30 == 0:
                logger.info(
                    "%s : %d jour(s), %d course(s), %d ligne(s) (%.0f s)",
                    courses[0].date, bilan["jours"], bilan["courses"], bilan["lignes"], time.monotonic() - debut,
                )

    ecartees = lignes_ecartees(repository, date_debut, date_fin)
    ecartees["num_pmu_absent"] = constructeur.compteurs["num_pmu_absent"]
    ecartees["brut_illisible"] = compteurs["brut_illisible"]
    ecartees["statut_inconnu"] = constructeur.compteurs["statut_inconnu"]
    bilan["ecartees"] = ecartees

    registre = {
        "genere_le_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "git_sha": sha_git(),
        "date_debut": date_debut.isoformat(),
        "date_fin": date_fin.isoformat(),
        "lignes": bilan["lignes"],
        "courses": bilan["courses"],
        # Sur la plage demandée. Sans ligne de sortie : course_non_finalisee,
        # autre_source, num_pmu_absent. Ligne gardée mais signalée :
        # brut_illisible (champs avant course vides), statut_inconnu (compté
        # partant).
        "ecartees": ecartees,
        "parametres": PARAMETRES,
        "note": NOTE_REGISTRE,
        "colonnes": [
            {
                "nom": c.nom,
                "groupe": c.groupe,
                "type": type_colonne(c.nom),
                "sources": list(c.sources),
                "avant_course": c.avant_course,
                "description": c.description,
            }
            for c in COLONNES
        ],
    }
    with open(tmp_registre, "w", encoding="utf-8") as fichier:
        json.dump(registre, fichier, ensure_ascii=False, indent=2)
    return bilan


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Table de features point-in-time pour le modèle prédictif")
    parser.add_argument("--date-debut", type=date.fromisoformat, required=True)
    parser.add_argument("--date-fin", type=date.fromisoformat, required=True)
    parser.add_argument("--sortie", required=True, help="Fichier .csv.gz à écrire")
    args = parser.parse_args(argv)
    if args.date_fin < args.date_debut:
        parser.error("--date-fin doit être postérieure ou égale à --date-debut")
    return args


def main(argv: Optional[List[str]] = None) -> int:
    """Code de sortie 1 si la construction échoue (aucune sortie partielle)."""
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    args = parse_args(argv)
    try:
        construire(Repository(), args.date_debut, args.date_fin, args.sortie)
    except Exception:
        logger.exception("Echec de la construction des features")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
