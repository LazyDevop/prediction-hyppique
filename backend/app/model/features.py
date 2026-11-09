"""Table de features point-in-time : une ligne par partant effectif.

Calcul pur, sans I/O : le job `jobs/build_features.py` lit la base et
alimente `ConstructeurFeatures` jour par jour, dans l'ordre chronologique.

Règle avant course (spec-features-modele.md) :
- une feature ne lit, de la ligne du partant, que les champs avant course de
  `donnees_brutes` (CHAMPS_PARTANT_AVANT_COURSE), passés par
  `vue_avant_course` ; de la course, que CHAMPS_COURSE_AVANT_COURSE ;
- l'historique ne vient que des jours strictement antérieurs : les lignes
  d'un jour sont calculées sur l'état construit avant ce jour, puis les
  résultats du jour mettent l'état à jour ;
- les labels (rang, gagnant, place) et le marché (cotes) ne sont jamais des
  features.

Une feature sans donnée vaut None (cellule vide), jamais 0 ni une moyenne ;
chaque taux est accompagné de son effectif.
"""

import logging
import re
from collections import Counter, deque
from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Any, Deque, Dict, Iterable, List, Optional, Set, Tuple

logger = logging.getLogger(__name__)

# --- Règle avant / après course --------------------------------------------

# Champs de `donnees_brutes` du partant connus avant la course. `driver` et
# `entraineur` sont aussi stockés en colonnes de Participation (même valeur).
CHAMPS_PARTANT_AVANT_COURSE = frozenset({
    "age", "sexe", "musique", "nombreCourses", "nombreVictoires", "nombrePlaces",
    "gainsParticipant", "driverChange", "deferre", "oeilleres", "handicapPoids",
    "handicapValeur", "handicapDistance", "placeCorde", "avisEntraineur",
    "indicateurInedit", "nomPere", "nomPereMere", "driver", "entraineur",
})

# Champs avant course de la course elle-même. `terrain` est le pénétromètre
# mesuré le matin de la course.
CHAMPS_COURSE_AVANT_COURSE = frozenset({
    "date", "discipline", "distance", "allocation", "terrain", "hippodrome", "partants",
})

# Jamais source d'une feature pour la course elle-même (permis pour les
# courses antérieures, via l'historique).
CHAMPS_INTERDITS = frozenset({
    "ordreArrivee", "incident", "tempsObtenu", "reductionKilometrique",
    "distanceChevalPrecedent", "commentaireApresCourse", "dernierRapportDirect",
    "dernierRapportReference", "rang_arrivee", "cote_direct", "cote_reference",
})

FENETRE_PERSONNES = timedelta(days=365)
DERNIERES_COURSES = 6


# --- Registre ---------------------------------------------------------------

@dataclass(frozen=True)
class Colonne:
    nom: str
    groupe: str  # "id" | "label" | "marche" | "feature"
    sources: Tuple[str, ...]  # "partant.X", "course.X" ou "historique.X"
    avant_course: bool
    description: str = ""


def _f(nom: str, sources: Tuple[str, ...], description: str) -> Colonne:
    return Colonne(nom, "feature", sources, True, description)


_H_RANG = ("historique.rang_arrivee", "historique.incident", "historique.partants")

COLONNES: Tuple[Colonne, ...] = (
    Colonne("course_id", "id", ("course.id",), True, "Identifiant de la course en base"),
    Colonne("date", "id", ("course.date",), True, "Date de la course"),
    Colonne("discipline", "id", ("course.discipline",), True, "trot, plat ou obstacle"),
    Colonne("num_pmu", "id", ("partant.numPmu",), True, "Dossard"),
    Colonne("rang", "label", ("partant.ordreArrivee",), False, "Rang d'arrivée (vide si non classé ou incident)"),
    Colonne("gagnant", "label", ("partant.ordreArrivee", "partant.incident"), False, "1 si gagnant"),
    Colonne("place", "label", ("partant.ordreArrivee", "partant.incident", "course.partants"), False,
            "1 si placé : 3 premiers à 8 partants et plus, 2 premiers de 4 à 7, gagnant en dessous"),
    Colonne("cote_reference", "marche", ("partant.dernierRapportReference",), False, "Cote de référence (~H-30)"),
    Colonne("cote_direct", "marche", ("partant.dernierRapportDirect",), False, "Cote finale (repère de clôture)"),
    # Forme (historique en base)
    _f("f_nb_courses_connues", _H_RANG, "Nombre de courses antérieures connues en base"),
    _f("f_rang_rel_dernier", _H_RANG, "Rang relatif de la dernière course (0 = gagnant, 1 = dernier ou non classé)"),
    _f("f_rang_rel_moy3", _H_RANG, "Moyenne des rangs relatifs des 3 dernières courses"),
    _f("f_nb_rang_rel_3", _H_RANG, "Effectif de f_rang_rel_moy3 (rangs relatifs connus parmi les 3 dernières)"),
    _f("f_rang_rel_moy6", _H_RANG, "Moyenne des rangs relatifs des 6 dernières courses"),
    _f("f_nb_courses_6", _H_RANG, "Effectif des 6 dernières courses (≤ 6)"),
    _f("f_taux_victoire_6", _H_RANG, "Taux de victoire sur les 6 dernières courses"),
    _f("f_taux_place_6", _H_RANG, "Taux de place sur les 6 dernières courses"),
    _f("f_jours_depuis_derniere", ("course.date", "historique.date"), "Jours depuis la dernière course"),
    # Forme (champs avant course turfinfo)
    _f("f_nb_courses_carriere", ("partant.nombreCourses",), "Courses en carrière"),
    _f("f_taux_victoire_carriere", ("partant.nombreVictoires", "partant.nombreCourses"), "Taux de victoire en carrière"),
    _f("f_taux_place_carriere", ("partant.nombrePlaces", "partant.nombreCourses"), "Taux de place en carrière"),
    _f("f_musique_nb", ("partant.musique",), "Courses lues dans la musique"),
    _f("f_musique_moy", ("partant.musique",), "Place moyenne de la musique (0 et lettres = 10)"),
    _f("f_musique_victoires", ("partant.musique",), "Victoires dans la musique"),
    _f("f_inedit", ("partant.indicateurInedit",), "1 si inédit"),
    # Vitesse (trot), réduction kilométrique des courses antérieures, en s/km
    _f("f_rk_meilleure_disc", ("historique.reductionKilometrique", "historique.discipline", "course.discipline"),
       "Meilleure réduction km passée, même discipline (trot)"),
    _f("f_rk_moy_disc", ("historique.reductionKilometrique", "historique.discipline", "course.discipline"),
       "Réduction km moyenne passée, même discipline (trot)"),
    _f("f_rk_nb_disc", ("historique.reductionKilometrique", "historique.discipline", "course.discipline"),
       "Effectif des réductions km passées, même discipline"),
    _f("f_rk_meilleure_bande", ("historique.reductionKilometrique", "historique.distance", "course.distance"),
       "Meilleure réduction km passée, même discipline et bande de distance"),
    _f("f_rk_moy_bande", ("historique.reductionKilometrique", "historique.distance", "course.distance"),
       "Réduction km moyenne passée, même discipline et bande de distance"),
    _f("f_rk_nb_bande", ("historique.reductionKilometrique", "historique.distance", "course.distance"),
       "Effectif des réductions km passées, même discipline et bande de distance"),
    # Classe
    _f("f_allocation_rel", ("course.allocation", "historique.allocation"),
       "Allocation du jour / allocation moyenne des courses passées"),
    _f("f_nb_allocations", ("historique.allocation",), "Effectif des allocations passées"),
    _f("f_handicap_valeur", ("partant.handicapValeur",), "Valeur de handicap"),
    _f("f_gains_par_course", ("partant.gainsParticipant", "partant.nombreCourses"), "Gains de carrière par course (EUR)"),
    # Personnes (365 jours précédents)
    _f("f_driver_nb_365", ("partant.driver", "historique.driver") + _H_RANG, "Montes du driver/jockey sur 365 jours"),
    _f("f_driver_taux_victoire_365", ("partant.driver", "historique.driver") + _H_RANG, "Taux de victoire du driver/jockey"),
    _f("f_driver_taux_place_365", ("partant.driver", "historique.driver") + _H_RANG, "Taux de place du driver/jockey"),
    _f("f_entraineur_nb_365", ("partant.entraineur", "historique.entraineur") + _H_RANG, "Partants de l'entraîneur sur 365 jours"),
    _f("f_entraineur_taux_victoire_365", ("partant.entraineur", "historique.entraineur") + _H_RANG,
       "Taux de victoire de l'entraîneur"),
    _f("f_entraineur_taux_place_365", ("partant.entraineur", "historique.entraineur") + _H_RANG,
       "Taux de place de l'entraîneur"),
    _f("f_driver_change", ("partant.driverChange",), "1 si changement tardif de driver/jockey"),
    # Contexte
    _f("f_ecart_distance", ("course.distance", "historique.distance"), "Distance du jour - distance de la dernière course (m)"),
    _f("f_chgt_discipline", ("course.discipline", "historique.discipline"), "1 si discipline différente de la dernière course"),
    _f("f_chgt_hippodrome", ("course.hippodrome", "historique.hippodrome"), "1 si hippodrome différent de la dernière course"),
    _f("f_place_corde", ("partant.placeCorde",), "Place à la corde"),
    _f("f_handicap_poids", ("partant.handicapPoids",), "Poids (kg)"),
    _f("f_handicap_distance", ("partant.handicapDistance",), "Distance de départ du partant (m, trot)"),
    _f("f_recul", ("partant.handicapDistance", "course.distance"), "Recul : distance du partant - distance de la course (m)"),
    _f("f_deferre", ("partant.deferre",), "Ferrure (catégorie ; vide = ferré ou inconnu)"),
    _f("f_oeilleres", ("partant.oeilleres",), "Oeillères (catégorie)"),
    _f("f_avis_entraineur", ("partant.avisEntraineur",), "Avis de l'entraîneur (POSITIF, NEUTRE, NEGATIF)"),
    _f("f_age", ("partant.age",), "Âge"),
    _f("f_sexe", ("partant.sexe",), "Sexe (catégorie)"),
    _f("f_terrain", ("course.terrain", "course.discipline"), "Terrain du jour, galop seulement (catégorie)"),
    # Champ
    _f("f_nb_partants", ("course.partants",), "Nombre de partants effectifs"),
    _f("f_taux_victoire_6_ecart_champ", ("course.partants",) + _H_RANG,
       "f_taux_victoire_6 - moyenne du champ (partants ayant un taux)"),
    _f("f_taux_victoire_6_rang_champ", ("course.partants",) + _H_RANG,
       "Rang relatif de f_taux_victoire_6 dans la course (0 = meilleur)"),
    _f("f_nb_champ_taux_victoire_6", ("course.partants",) + _H_RANG,
       "Effectif des deux colonnes précédentes : partants du champ ayant un f_taux_victoire_6"),
    # Pedigree
    _f("f_pere_nb_disc", ("partant.nomPere", "course.discipline", "historique.nomPere") + _H_RANG,
       "Partants antérieurs du père dans la discipline"),
    _f("f_pere_taux_victoire_disc", ("partant.nomPere", "course.discipline", "historique.nomPere") + _H_RANG,
       "Taux de victoire antérieur des produits du père dans la discipline"),
)

_CATEGORIELLES = frozenset({
    "date", "discipline", "f_deferre", "f_oeilleres", "f_avis_entraineur", "f_sexe", "f_terrain",
})
_DRAPEAUX = frozenset({
    "gagnant", "place", "f_inedit", "f_driver_change", "f_chgt_discipline", "f_chgt_hippodrome",
})


def type_colonne(nom: str) -> str:
    """"numeric", "categorical" ou "flag" (0/1)."""
    if nom in _CATEGORIELLES:
        return "categorical"
    if nom in _DRAPEAUX:
        return "flag"
    return "numeric"


BANDES_DISTANCE = (("courte", 2200), ("moyenne", 2700), ("longue", None))
DISCIPLINES_CONNUES = frozenset({"plat", "trot", "obstacle"})

PARAMETRES = {
    "fenetre_personnes_jours": FENETRE_PERSONNES.days,
    "dernieres_courses": DERNIERES_COURSES,
    "bandes_distance_m": "courte < 2200 <= moyenne < 2700 <= longue",
    "places_payees": "3 premiers si >= 8 partants, 2 premiers de 4 à 7, gagnant seul en dessous",
    "rang_relatif": "(rang - 1) / (partants - 1) ; non classé ou incident = 1 ; champ de 1 = vide",
}

NOTE_REGISTRE = (
    "Les champs de carrière turfinfo (nombreCourses, nombreVictoires, nombrePlaces, gainsParticipant) "
    "et la musique sont des instantanés avant course, vérifiés sur le T1 2025 : le premier caractère de "
    "la musique est le rang de la course précédente dans 97 % des cas, et nombreCourses vaut la valeur "
    "précédente + 1 dans 95 % des cas. Les lignes et f_nb_partants reflètent la liste finale des partants "
    "(non-partants tardifs retirés), contrairement à un pronostic en direct qui voit la liste déclarée. "
    "f_driver_nb_365 et f_entraineur_nb_365 sont vides (et non 0) quand le nom du driver/jockey ou de "
    "l'entraîneur est absent ; ils valent 0 quand le nom est connu sans course sur 365 jours."
)

COLONNES_PAR_NOM = {c.nom: c for c in COLONNES}
NOMS_COLONNES = tuple(c.nom for c in COLONNES)
NOMS_FEATURES = tuple(c.nom for c in COLONNES if c.groupe == "feature")


# --- Enregistrements en entrée ----------------------------------------------

@dataclass
class PartantRecord:
    # None : dossard absent en base. Le partant compte dans le champ et
    # l'historique, mais ne produit pas de ligne.
    num_pmu: Optional[int]
    cheval_id: int
    brut: Dict[str, Any] = field(default_factory=dict)
    driver: Optional[str] = None
    entraineur: Optional[str] = None
    # Après course : labels, marché, mise à jour de l'historique.
    rang_arrivee: Optional[int] = None
    incident: Optional[str] = None
    cote_reference: Optional[float] = None
    cote_direct: Optional[float] = None

    @property
    def statut(self) -> Any:
        return self.brut.get("statut")

    @property
    def est_partant(self) -> bool:
        """Partant sauf NON_PARTANT, que l'indique le statut ou l'incident
        (les deux sources se contredisent parfois : la plus prudente gagne)."""
        return self.statut != "NON_PARTANT" and self.incident != "NON_PARTANT"

    @property
    def classe(self) -> bool:
        """Classé sans incident, à un rang valide : seul cas où le rang compte."""
        rang = self.rang_arrivee
        return (
            isinstance(rang, int) and not isinstance(rang, bool) and rang >= 1 and not self.incident
        )


@dataclass
class CourseRecord:
    course_id: int
    date: date
    discipline: str
    distance: Optional[float] = None
    allocation: Optional[float] = None
    terrain: Optional[str] = None
    hippodrome: Optional[str] = None
    partants: List[PartantRecord] = field(default_factory=list)

    def partants_effectifs(self) -> List[PartantRecord]:
        return [p for p in self.partants if p.est_partant]


def vue_avant_course(partant: PartantRecord) -> Dict[str, Any]:
    """Seule vue du partant offerte au calcul des features."""
    vue = {k: partant.brut.get(k) for k in CHAMPS_PARTANT_AVANT_COURSE}
    vue["driver"] = partant.driver or vue.get("driver")
    vue["entraineur"] = partant.entraineur or vue.get("entraineur")
    return vue


# --- Petites fonctions ------------------------------------------------------

def nb_places_payees(nb_partants: int) -> int:
    if nb_partants >= 8:
        return 3
    if nb_partants >= 4:
        return 2
    return 1


def rang_relatif(rang: Optional[int], classe: bool, nb_partants: int) -> Optional[float]:
    """(rang - 1) / (champ - 1) ; non classé ou incident = 1 ; champ de 1 = None."""
    if nb_partants <= 1:
        return None
    if not classe or rang is None:
        return 1.0
    return min(1.0, max(0.0, (rang - 1) / (nb_partants - 1)))


def bande_distance(distance: Optional[float]) -> Optional[str]:
    if distance is None:
        return None
    for nom, borne in BANDES_DISTANCE:
        if borne is None or distance < borne:
            return nom
    return None


def _ratio(num: Optional[float], den: Optional[float]) -> Optional[float]:
    if num is None or den is None or den == 0:
        return None
    return num / den


def _nombre(valeur: Any) -> Optional[float]:
    if isinstance(valeur, bool) or not isinstance(valeur, (int, float)):
        return None
    return valeur


_VRAI = frozenset({"true", "1", "oui", "yes"})
_FAUX = frozenset({"false", "0", "non", "no"})


def _drapeau(valeur: Any) -> Optional[int]:
    """Booléen JSON, entier 0/1 ou chaîne ("true", "false", "0", "1") ;
    toute autre valeur est inconnue (None), jamais devinée."""
    if valeur is None:
        return None
    if isinstance(valeur, bool):
        return int(valeur)
    if isinstance(valeur, (int, float)):
        return int(valeur) if valeur in (0, 1) else None
    if isinstance(valeur, str):
        texte = valeur.strip().casefold()
        if texte in _VRAI:
            return 1
        if texte in _FAUX:
            return 0
    return None


def _texte(valeur: Any) -> Optional[str]:
    if valeur is None:
        return None
    texte = str(valeur).strip()
    return texte or None


_ANNEE_MUSIQUE = re.compile(r"\(\d+\)")
_COURSE_MUSIQUE = re.compile(r"([0-9A-Z])[a-z]")


def lire_musique(musique: Optional[str]) -> Tuple[int, Optional[float], Optional[int]]:
    """(courses lues, place moyenne, victoires). 0 (au-delà de la 9e) et les
    lettres (disqualifié, arrêté, tombé…) comptent 10."""
    if not musique:
        return 0, None, None
    places = []
    for car in _COURSE_MUSIQUE.findall(_ANNEE_MUSIQUE.sub("", musique)):
        places.append(int(car) if car.isdigit() and car != "0" else 10)
    if not places:
        return 0, None, None
    return len(places), sum(places) / len(places), sum(1 for p in places if p == 1)


def reduction_km_secondes(valeur: Any) -> Optional[float]:
    """turfinfo donne la réduction kilométrique en millisecondes par km."""
    v = _nombre(valeur)
    if v is None or v <= 0:
        return None
    return v / 1000.0


# --- État -------------------------------------------------------------------

@dataclass
class CoursePassee:
    date: date
    discipline: str
    distance: Optional[float]
    hippodrome: Optional[str]
    rang_rel: Optional[float]
    gagne: bool
    place: bool


class _Agregat:
    __slots__ = ("n", "somme", "meilleur")

    def __init__(self) -> None:
        self.n = 0
        self.somme = 0.0
        self.meilleur: Optional[float] = None

    def ajouter(self, valeur: float) -> None:
        self.n += 1
        self.somme += valeur
        if self.meilleur is None or valeur < self.meilleur:
            self.meilleur = valeur

    @property
    def moyenne(self) -> Optional[float]:
        return self.somme / self.n if self.n else None


class _Cheval:
    __slots__ = ("nb", "dernieres", "allocations", "rk_disc", "rk_bande")

    def __init__(self) -> None:
        self.nb = 0
        self.dernieres: Deque[CoursePassee] = deque(maxlen=DERNIERES_COURSES)
        self.allocations = _Agregat()
        self.rk_disc: Dict[str, _Agregat] = {}
        self.rk_bande: Dict[Tuple[str, str], _Agregat] = {}


class _Fenetre:
    """Courses d'une personne sur une fenêtre glissante, sommes tenues à jour."""
    __slots__ = ("evenements", "n", "victoires", "places")

    def __init__(self) -> None:
        self.evenements: Deque[Tuple[date, int, int]] = deque()
        self.n = 0
        self.victoires = 0
        self.places = 0

    def ajouter(self, jour: date, gagne: bool, place: bool) -> None:
        self.evenements.append((jour, int(gagne), int(place)))
        self.n += 1
        self.victoires += int(gagne)
        self.places += int(place)

    def stats(self, jour: date) -> Tuple[int, int, int]:
        # 365 jours précédents : un événement daté d'exactement jour - 365
        # est sorti de la fenêtre.
        limite = jour - FENETRE_PERSONNES
        while self.evenements and self.evenements[0][0] <= limite:
            _, g, p = self.evenements.popleft()
            self.n -= 1
            self.victoires -= g
            self.places -= p
        return self.n, self.victoires, self.places


def _taux_personne(fenetre: Optional[_Fenetre], jour: date) -> Tuple[int, Optional[float], Optional[float]]:
    if fenetre is None:
        return 0, None, None
    n, v, p = fenetre.stats(jour)
    if n == 0:
        return 0, None, None
    return n, v / n, p / n


def _moyenne(valeurs: Iterable[Optional[float]]) -> Optional[float]:
    vals = [v for v in valeurs if v is not None]
    return sum(vals) / len(vals) if vals else None


# --- Constructeur -----------------------------------------------------------

class ConstructeurFeatures:
    """Machine à états jour par jour. Appeler `traiter_jour` dans l'ordre
    chronologique strict ; `emettre=False` ne fait que construire l'état
    (jours antérieurs à la plage demandée)."""

    def __init__(self) -> None:
        self.chevaux: Dict[int, _Cheval] = {}
        self.drivers: Dict[str, _Fenetre] = {}
        self.entraineurs: Dict[str, _Fenetre] = {}
        self.peres: Dict[Tuple[str, str], List[int]] = {}
        self.dernier_jour: Optional[date] = None
        # Comptés sur les jours émis seulement (plage demandée).
        self.compteurs: Counter = Counter()
        self._statuts_signales: Set[Any] = set()
        self._disciplines_signalees: Set[Any] = set()

    def traiter_jour(self, courses: List[CourseRecord], emettre: bool = True) -> List[Dict[str, Any]]:
        if not courses:
            return []
        jour = courses[0].date
        if any(c.date != jour for c in courses):
            raise ValueError("traiter_jour attend les courses d'un seul jour")
        if self.dernier_jour is not None and jour <= self.dernier_jour:
            raise ValueError(f"jour {jour} non postérieur au précédent {self.dernier_jour}")
        self.dernier_jour = jour

        effectifs = [self._effectifs(course, emettre) for course in courses]
        lignes: List[Dict[str, Any]] = []
        if emettre:
            # Toutes les lignes du jour sur l'état d'avant ce jour…
            for course, partants in zip(courses, effectifs):
                lignes.extend(self.lignes_course(course, partants))
        # … puis les résultats du jour mettent l'état à jour.
        for course, partants in zip(courses, effectifs):
            self._mettre_a_jour(course, partants)
        lignes.sort(key=lambda l: (l["date"], l["course_id"], l["num_pmu"]))
        return lignes

    # -- lignes

    def _effectifs(self, course: CourseRecord, compter: bool) -> List[PartantRecord]:
        if course.discipline not in DISCIPLINES_CONNUES and course.discipline not in self._disciplines_signalees:
            self._disciplines_signalees.add(course.discipline)
            logger.warning("discipline inconnue : %r (course %s)", course.discipline, course.course_id)
        effectifs = []
        for partant in course.partants:
            statut = partant.statut
            if statut not in ("PARTANT", "NON_PARTANT"):
                if compter:
                    self.compteurs["statut_inconnu"] += 1
                if statut not in self._statuts_signales:
                    self._statuts_signales.add(statut)
                    logger.warning(
                        "statut inconnu : %r (course %s, num %s), compté partant sauf incident NON_PARTANT",
                        statut, course.course_id, partant.num_pmu,
                    )
            if partant.est_partant:
                effectifs.append(partant)
        return effectifs

    def lignes_course(self, course: CourseRecord, effectifs: Optional[List[PartantRecord]] = None) -> List[Dict[str, Any]]:
        if effectifs is None:
            effectifs = course.partants_effectifs()
        nb_partants = len(effectifs)
        nb_places = nb_places_payees(nb_partants)
        lignes = []
        for partant in effectifs:
            ligne: Dict[str, Any] = {
                "course_id": course.course_id,
                "date": course.date,
                "discipline": course.discipline,
                "num_pmu": partant.num_pmu,
                "rang": partant.rang_arrivee if partant.classe else None,
                "gagnant": int(partant.classe and partant.rang_arrivee == 1),
                "place": int(partant.classe and partant.rang_arrivee <= nb_places),
                "cote_reference": partant.cote_reference,
                "cote_direct": partant.cote_direct,
            }
            ligne.update(self._features(course, nb_partants, partant.cheval_id, vue_avant_course(partant)))
            lignes.append(ligne)
        # Le champ compte aussi les partants sans dossard, écartés ensuite.
        self._features_champ(lignes)
        sans_dossard = sum(1 for l in lignes if l["num_pmu"] is None)
        if sans_dossard:
            self.compteurs["num_pmu_absent"] += sans_dossard
            lignes = [l for l in lignes if l["num_pmu"] is not None]
        return lignes

    def _features(self, course: CourseRecord, nb_partants: int, cheval_id: int, vue: Dict[str, Any]) -> Dict[str, Any]:
        """Ne reçoit que la vue avant course : aucun label ni cote."""
        jour = course.date
        f: Dict[str, Any] = {}
        etat = self.chevaux.get(cheval_id)
        dernieres = list(etat.dernieres) if etat else []

        # Forme (base)
        f["f_nb_courses_connues"] = etat.nb if etat else 0
        f["f_rang_rel_dernier"] = dernieres[-1].rang_rel if dernieres else None
        f["f_rang_rel_moy3"] = _moyenne(c.rang_rel for c in dernieres[-3:])
        f["f_nb_rang_rel_3"] = sum(1 for c in dernieres[-3:] if c.rang_rel is not None)
        f["f_rang_rel_moy6"] = _moyenne(c.rang_rel for c in dernieres)
        f["f_nb_courses_6"] = len(dernieres)
        f["f_taux_victoire_6"] = sum(c.gagne for c in dernieres) / len(dernieres) if dernieres else None
        f["f_taux_place_6"] = sum(c.place for c in dernieres) / len(dernieres) if dernieres else None
        derniere = dernieres[-1] if dernieres else None
        f["f_jours_depuis_derniere"] = (jour - derniere.date).days if derniere else None

        # Forme (turfinfo)
        nb_carriere = _nombre(vue["nombreCourses"])
        f["f_nb_courses_carriere"] = nb_carriere
        f["f_taux_victoire_carriere"] = _ratio(_nombre(vue["nombreVictoires"]), nb_carriere)
        f["f_taux_place_carriere"] = _ratio(_nombre(vue["nombrePlaces"]), nb_carriere)
        nb_musique, moy_musique, vict_musique = lire_musique(vue["musique"])
        f["f_musique_nb"] = nb_musique
        f["f_musique_moy"] = moy_musique
        f["f_musique_victoires"] = vict_musique
        f["f_inedit"] = _drapeau(vue["indicateurInedit"])

        # Vitesse (trot)
        rk_disc = rk_bande = None
        if course.discipline == "trot" and etat:
            rk_disc = etat.rk_disc.get(course.discipline)
            bande = bande_distance(course.distance)
            if bande is not None:
                rk_bande = etat.rk_bande.get((course.discipline, bande))
        f["f_rk_meilleure_disc"] = rk_disc.meilleur if rk_disc else None
        f["f_rk_moy_disc"] = rk_disc.moyenne if rk_disc else None
        f["f_rk_nb_disc"] = rk_disc.n if rk_disc else (0 if course.discipline == "trot" else None)
        f["f_rk_meilleure_bande"] = rk_bande.meilleur if rk_bande else None
        f["f_rk_moy_bande"] = rk_bande.moyenne if rk_bande else None
        f["f_rk_nb_bande"] = rk_bande.n if rk_bande else (
            0 if course.discipline == "trot" and course.distance is not None else None
        )

        # Classe
        alloc_moy = etat.allocations.moyenne if etat else None
        f["f_allocation_rel"] = _ratio(course.allocation, alloc_moy)
        f["f_nb_allocations"] = etat.allocations.n if etat else 0
        f["f_handicap_valeur"] = _nombre(vue["handicapValeur"])
        gains = vue["gainsParticipant"]
        gains_carriere = _nombre(gains.get("gainsCarriere")) if isinstance(gains, dict) else None
        f["f_gains_par_course"] = _ratio(gains_carriere / 100.0 if gains_carriere is not None else None, nb_carriere)

        # Personnes
        driver = _texte(vue["driver"])
        n, tv, tp = _taux_personne(self.drivers.get(driver) if driver else None, jour)
        f["f_driver_nb_365"] = n if driver else None
        f["f_driver_taux_victoire_365"] = tv
        f["f_driver_taux_place_365"] = tp
        entraineur = _texte(vue["entraineur"])
        n, tv, tp = _taux_personne(self.entraineurs.get(entraineur) if entraineur else None, jour)
        f["f_entraineur_nb_365"] = n if entraineur else None
        f["f_entraineur_taux_victoire_365"] = tv
        f["f_entraineur_taux_place_365"] = tp
        f["f_driver_change"] = _drapeau(vue["driverChange"])

        # Contexte
        if derniere is not None:
            f["f_ecart_distance"] = (
                course.distance - derniere.distance
                if course.distance is not None and derniere.distance is not None else None
            )
            f["f_chgt_discipline"] = int(course.discipline != derniere.discipline)
            f["f_chgt_hippodrome"] = (
                int(course.hippodrome != derniere.hippodrome)
                if course.hippodrome and derniere.hippodrome else None
            )
        else:
            f["f_ecart_distance"] = f["f_chgt_discipline"] = f["f_chgt_hippodrome"] = None
        f["f_place_corde"] = _nombre(vue["placeCorde"])
        poids = _nombre(vue["handicapPoids"])
        f["f_handicap_poids"] = poids / 10.0 if poids is not None else None
        dist_partant = _nombre(vue["handicapDistance"])
        f["f_handicap_distance"] = dist_partant
        f["f_recul"] = (
            dist_partant - course.distance if dist_partant is not None and course.distance is not None else None
        )
        f["f_deferre"] = _texte(vue["deferre"])
        f["f_oeilleres"] = _texte(vue["oeilleres"])
        f["f_avis_entraineur"] = _texte(vue["avisEntraineur"])
        f["f_age"] = _nombre(vue["age"])
        f["f_sexe"] = _texte(vue["sexe"])
        f["f_terrain"] = _texte(course.terrain) if course.discipline in ("plat", "obstacle") else None

        # Champ (les colonnes relatives sont remplies par _features_champ)
        f["f_nb_partants"] = nb_partants
        f["f_taux_victoire_6_ecart_champ"] = None
        f["f_taux_victoire_6_rang_champ"] = None
        f["f_nb_champ_taux_victoire_6"] = 0

        # Pedigree
        pere = _texte(vue["nomPere"])
        stats_pere = self.peres.get((pere, course.discipline)) if pere else None
        f["f_pere_nb_disc"] = (stats_pere[0] if stats_pere else 0) if pere else None
        f["f_pere_taux_victoire_disc"] = stats_pere[1] / stats_pere[0] if stats_pere and stats_pere[0] else None
        return f

    @staticmethod
    def _features_champ(lignes: List[Dict[str, Any]]) -> None:
        taux = [l["f_taux_victoire_6"] for l in lignes if l["f_taux_victoire_6"] is not None]
        for ligne in lignes:
            ligne["f_nb_champ_taux_victoire_6"] = len(taux)
        if not taux:
            return
        moyenne = sum(taux) / len(taux)
        for ligne in lignes:
            t = ligne["f_taux_victoire_6"]
            if t is None:
                continue
            ligne["f_taux_victoire_6_ecart_champ"] = t - moyenne
            if len(taux) > 1:
                meilleurs = sum(1 for x in taux if x > t)
                egaux = sum(1 for x in taux if x == t) - 1
                # Rang moyen en cas d'égalité, ramené à [0, 1].
                ligne["f_taux_victoire_6_rang_champ"] = (meilleurs + egaux / 2) / (len(taux) - 1)

    # -- mise à jour après la journée

    def _mettre_a_jour(self, course: CourseRecord, effectifs: Optional[List[PartantRecord]] = None) -> None:
        if effectifs is None:
            effectifs = course.partants_effectifs()
        nb_partants = len(effectifs)
        nb_places = nb_places_payees(nb_partants)
        bande = bande_distance(course.distance)
        for partant in effectifs:
            gagne = partant.classe and partant.rang_arrivee == 1
            place = partant.classe and partant.rang_arrivee <= nb_places
            etat = self.chevaux.get(partant.cheval_id)
            if etat is None:
                etat = self.chevaux[partant.cheval_id] = _Cheval()
            etat.nb += 1
            etat.dernieres.append(CoursePassee(
                date=course.date,
                discipline=course.discipline,
                distance=course.distance,
                hippodrome=course.hippodrome,
                rang_rel=rang_relatif(partant.rang_arrivee, partant.classe, nb_partants),
                gagne=bool(gagne),
                place=bool(place),
            ))
            if course.allocation is not None:
                etat.allocations.ajouter(course.allocation)
            # Réduction km de cette course : historique pour les suivantes.
            rk = reduction_km_secondes(partant.brut.get("reductionKilometrique")) if partant.classe else None
            if rk is not None:
                etat.rk_disc.setdefault(course.discipline, _Agregat()).ajouter(rk)
                if bande is not None:
                    etat.rk_bande.setdefault((course.discipline, bande), _Agregat()).ajouter(rk)

            vue = vue_avant_course(partant)
            for nom, registre in ((_texte(vue["driver"]), self.drivers), (_texte(vue["entraineur"]), self.entraineurs)):
                if nom:
                    fenetre = registre.get(nom)
                    if fenetre is None:
                        fenetre = registre[nom] = _Fenetre()
                    fenetre.ajouter(course.date, bool(gagne), bool(place))
            pere = _texte(vue["nomPere"])
            if pere:
                stats = self.peres.setdefault((pere, course.discipline), [0, 0])
                stats[0] += 1
                stats[1] += int(bool(gagne))
