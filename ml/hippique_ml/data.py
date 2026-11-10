"""Chargement de la table de features (`build_features`) et découpage par date.

Garde-fous :
- les features sont exactement les colonnes du registre de groupe `feature` ;
  un registre qui marque comme feature une colonne d'identifiant, de label ou
  de marché est refusé avant tout entraînement ;
- le découpage se fait par date uniquement, sans mélange entre dates ;
- les courses sans gagnant ou à un seul partant sont écartées et comptées.
"""

import json
from dataclasses import asdict, dataclass, field
from datetime import date, timedelta
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

GROUPES = {"id", "label", "marche", "feature"}
TYPES = {"numeric", "categorical", "flag"}

# Colonnes hors features attendues dans toute table build_features.
IDENTIFIANTS = ("course_id", "date", "discipline", "num_pmu")
LABELS = ("rang", "gagnant", "place")
MARCHE = ("cote_reference", "cote_direct")
NON_FEATURES = frozenset(IDENTIFIANTS + LABELS + MARCHE)

# CatBoost exige des chaînes pour les catégories : une valeur absente devient
# cette modalité explicite (aucune imputation, la case reste "inconnue").
MODALITE_ABSENTE = "__absent__"

PERIODES = ("train", "validation", "test")


class ErreurDonnees(Exception):
    """Entrée refusée : registre fuyant, période vide, colonne manquante."""


@dataclass(frozen=True)
class Periodes:
    """train : date < train_fin ; validation : train_fin <= date <= valid_fin ;
    test : valid_fin < date <= test_fin."""
    train_fin: date = date(2025, 4, 20)
    valid_fin: date = date(2025, 10, 19)
    test_fin: date = date(2026, 9, 19)

    def __post_init__(self) -> None:
        if not self.train_fin <= self.valid_fin < self.test_fin:
            raise ErreurDonnees(
                f"périodes incohérentes : train_fin={self.train_fin}, valid_fin={self.valid_fin}, "
                f"test_fin={self.test_fin}"
            )

    def bornes(self) -> Dict[str, Dict[str, str]]:
        return {
            "train": {"debut": None, "fin_exclue": self.train_fin.isoformat()},
            "validation": {"debut": self.train_fin.isoformat(), "fin": self.valid_fin.isoformat()},
            "test": {"debut": (self.valid_fin + timedelta(days=1)).isoformat(), "fin": self.test_fin.isoformat()},
        }


@dataclass
class Exclusions:
    """Courses et partants écartés, par motif."""
    courses_sans_gagnant: int = 0
    partants_sans_gagnant: int = 0
    courses_un_partant: int = 0
    partants_un_partant: int = 0
    courses_ex_aequo: int = 0  # gardées : log-loss sur la somme des gagnants
    partants_apres_test: int = 0

    def to_dict(self) -> Dict[str, int]:
        return asdict(self)


@dataclass
class Registre:
    features: List[str]
    categoriques: List[str]
    git_sha: Optional[str] = None
    brut: dict = field(default_factory=dict)


def lire_registre(chemin: str) -> Registre:
    with open(chemin, encoding="utf-8") as fichier:
        try:
            brut = json.load(fichier)
        except json.JSONDecodeError as erreur:
            raise ErreurDonnees(f"registre illisible : {chemin} ({erreur})") from erreur
    if not isinstance(brut, dict):
        raise ErreurDonnees(f"registre illisible : {chemin} (objet JSON attendu)")
    colonnes = brut.get("colonnes")
    if not isinstance(colonnes, list) or not colonnes:
        raise ErreurDonnees(f"registre sans colonnes : {chemin}")
    return valider_registre(brut)


def valider_registre(brut: dict) -> Registre:
    """Features = colonnes de groupe `feature`, dans l'ordre du registre.
    Refuse toute feature qui est une colonne d'un autre groupe."""
    vus: Dict[str, str] = {}
    features: List[str] = []
    categoriques: List[str] = []
    for colonne in brut["colonnes"]:
        if not isinstance(colonne, dict):
            raise ErreurDonnees(f"entrée de registre invalide : {colonne!r}")
        nom, groupe, type_ = colonne.get("nom"), colonne.get("groupe"), colonne.get("type")
        if not isinstance(nom, str) or not nom:
            raise ErreurDonnees(f"entrée de registre sans nom : {colonne!r}")
        if groupe not in GROUPES:
            raise ErreurDonnees(f"colonne {nom!r} : groupe inconnu {groupe!r}")
        if type_ not in TYPES:
            raise ErreurDonnees(f"colonne {nom!r} : type inconnu {type_!r}")
        if nom in vus:
            raise ErreurDonnees(f"colonne {nom!r} déclarée deux fois ({vus[nom]}, {groupe})")
        vus[nom] = groupe
        if groupe == "feature":
            features.append(nom)
            if type_ == "categorical":
                categoriques.append(nom)

    fuites = sorted(nom for nom in features if nom in NON_FEATURES or not nom.startswith("f_"))
    if fuites:
        raise ErreurDonnees(
            "registre refusé : colonnes d'identifiant, de label ou de marché marquées feature : "
            + ", ".join(fuites)
        )
    for nom in NON_FEATURES:
        if nom not in vus:
            raise ErreurDonnees(f"registre sans la colonne {nom!r}")
        attendu = "id" if nom in IDENTIFIANTS else "label" if nom in LABELS else "marche"
        if vus[nom] != attendu:
            raise ErreurDonnees(f"colonne {nom!r} : groupe {vus[nom]!r}, attendu {attendu!r}")
    if not features:
        raise ErreurDonnees("registre sans feature")
    return Registre(features=features, categoriques=categoriques, git_sha=brut.get("git_sha"), brut=brut)


def _numerique(table: pd.DataFrame, nom: str) -> pd.Series:
    try:
        return pd.to_numeric(table[nom], errors="raise").astype(float)
    except (ValueError, TypeError) as erreur:
        raise ErreurDonnees(f"colonne {nom!r} : valeur non numérique ({erreur})") from erreur


def lire_table(chemin: str, registre: Registre) -> pd.DataFrame:
    """Lit le CSV gzip. Numériques en float (vide = NaN), catégories en
    chaînes (vide = MODALITE_ABSENTE).

    Refuse (ErreurDonnees) toute ligne qui fausserait les courses en silence :
    date ou identifiant vide, label absent ou hors {0, 1}, dossard en double,
    course répartie sur plusieurs dates ou disciplines, cote infinie."""
    types = {nom: str for nom in registre.categoriques}
    types.update({"discipline": str, "date": str})
    try:
        table = pd.read_csv(chemin, dtype=types, keep_default_na=False, na_values=[""], compression="infer")
    except (ValueError, UnicodeDecodeError, EOFError, OSError) as erreur:
        if isinstance(erreur, FileNotFoundError):
            raise
        raise ErreurDonnees(f"CSV illisible : {chemin} ({erreur})") from erreur
    manquantes = [c for c in list(NON_FEATURES) + registre.features if c not in table.columns]
    if manquantes:
        raise ErreurDonnees(f"colonnes absentes du CSV : {', '.join(sorted(manquantes))}")
    for nom in registre.categoriques:
        table[nom] = table[nom].fillna(MODALITE_ABSENTE).astype(str)
    numeriques = [c for c in registre.features if c not in registre.categoriques] + ["cote_reference", "cote_direct"]
    for nom in numeriques:
        table[nom] = _numerique(table, nom)
    for nom in ("cote_reference", "cote_direct"):
        if np.isinf(table[nom]).any():
            raise ErreurDonnees(f"colonne {nom!r} : cote infinie")

    for nom in ("course_id", "num_pmu"):
        valeurs = _numerique(table, nom)
        if valeurs.isna().any():
            raise ErreurDonnees(f"colonne {nom!r} : {int(valeurs.isna().sum())} ligne(s) sans valeur")
        table[nom] = valeurs.astype("int64")
    gagnant = _numerique(table, "gagnant")
    if gagnant.isna().any() or not gagnant.isin([0.0, 1.0]).all():
        raise ErreurDonnees("colonne 'gagnant' : valeurs attendues 0 ou 1, sans case vide")
    table["gagnant"] = gagnant.astype(int)
    try:
        table["date"] = pd.to_datetime(table["date"], format="%Y-%m-%d").dt.date
    except (ValueError, TypeError) as erreur:
        raise ErreurDonnees(f"colonne 'date' : format AAAA-MM-JJ attendu ({erreur})") from erreur
    if table["date"].isna().any():
        raise ErreurDonnees(f"colonne 'date' : {int(table['date'].isna().sum())} ligne(s) sans date")
    table["discipline"] = table["discipline"].fillna(MODALITE_ABSENTE)

    doublons = table.duplicated(["course_id", "num_pmu"])
    if doublons.any():
        raise ErreurDonnees(f"{int(doublons.sum())} partant(s) en double (course_id, num_pmu)")
    par_course = table.groupby("course_id")[["date", "discipline"]].nunique()
    incoherentes = par_course[(par_course["date"] > 1) | (par_course["discipline"] > 1)]
    if len(incoherentes):
        raise ErreurDonnees(
            f"{len(incoherentes)} course(s) sur plusieurs dates ou disciplines, ex. course_id "
            f"{incoherentes.index[0]}"
        )
    # Ordre stable : date, course, dossard (les groupes CatBoost doivent être contigus).
    return table.sort_values(["date", "course_id", "num_pmu"], kind="mergesort").reset_index(drop=True)


def nettoyer(table: pd.DataFrame, exclusions: Exclusions) -> pd.DataFrame:
    """Écarte (et compte) les courses sans gagnant et celles à un partant."""
    par_course = table.groupby("course_id", sort=False)
    nb = par_course["gagnant"].transform("size")
    gagnants = par_course["gagnant"].transform("sum")
    un_partant = nb < 2
    sans_gagnant = (gagnants == 0) & ~un_partant
    exclusions.courses_un_partant += int(table.loc[un_partant, "course_id"].nunique())
    exclusions.partants_un_partant += int(un_partant.sum())
    exclusions.courses_sans_gagnant += int(table.loc[sans_gagnant, "course_id"].nunique())
    exclusions.partants_sans_gagnant += int(sans_gagnant.sum())
    gardee = ~(un_partant | sans_gagnant)
    exclusions.courses_ex_aequo += int(table.loc[gardee & (gagnants > 1), "course_id"].nunique())
    return table.loc[gardee].reset_index(drop=True)


def decouper(table: pd.DataFrame, periodes: Periodes) -> Tuple[Dict[str, pd.DataFrame], Dict[str, Exclusions]]:
    """Découpe par date, puis nettoie chaque période (exclusions comptées par
    période). Refuse une période (train, validation ou test) sans course."""
    exclusions = {nom: Exclusions() for nom in PERIODES}
    dates = table["date"]
    masques = {
        "train": dates < periodes.train_fin,
        "validation": (dates >= periodes.train_fin) & (dates <= periodes.valid_fin),
        "test": (dates > periodes.valid_fin) & (dates <= periodes.test_fin),
    }
    exclusions["test"].partants_apres_test = int((dates > periodes.test_fin).sum())
    decoupe = {}
    for nom in PERIODES:
        partie = nettoyer(table.loc[masques[nom]].reset_index(drop=True), exclusions[nom])
        if partie.empty:
            raise ErreurDonnees(f"période {nom!r} sans course exploitable ({periodes.bornes()[nom]})")
        decoupe[nom] = partie
    # Une course est d'un seul jour (vérifié par lire_table) : aucune course
    # ne chevauche deux périodes. Vérification explicite, jamais un assert.
    ids = [set(decoupe[n]["course_id"]) for n in PERIODES]
    if ids[0] & ids[1] or ids[0] & ids[2] or ids[1] & ids[2]:
        raise ErreurDonnees("une course apparaît dans deux périodes")
    return decoupe, exclusions


def matrice(partie: pd.DataFrame, registre: Registre) -> pd.DataFrame:
    return partie[registre.features]


def groupes(partie: pd.DataFrame) -> np.ndarray:
    return partie["course_id"].to_numpy()
