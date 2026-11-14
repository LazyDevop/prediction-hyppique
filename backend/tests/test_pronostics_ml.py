"""Tests de `jobs/pronostics_ml.py` et `model/inference.py` : une fonction
par ligne de la matrice I/O du spec (spec-predictions-horizon.md), plus
l'encodage des valeurs, la formule de combinaison, le chargement du modèle
et la parité avec la table d'entraînement. Un petit modèle CatBoost est
entraîné dans une fixture ; l'horloge est simulée."""

import csv
import gzip
import json
import math
import random
from datetime import date, datetime, timedelta

import numpy as np
import pytest
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from app.data.models import Cheval, CoteInstantanee, Course, Participation, PredictionRun
from app.data.repository import Repository
from app.jobs import build_features, pronostics_ml
from app.model import inference
from app.model.inference import MODALITE_ABSENTE, ErreurModele, charger, combiner

try:
    import catboost
except ImportError:  # pas de wheel catboost pour certaines versions de Python : tests du modèle ignorés
    catboost = None

JOUR = date(2026, 11, 14)
VEILLE = date(2026, 11, 13)
AVANT = date(2026, 11, 6)
FEATURES = ["f_nb_courses_connues", "f_taux_victoire_6", "f_age", "f_place_corde", "f_nb_partants", "f_sexe"]
CATEGORIQUES = ["f_sexe"]
TEMPERATURE = 0.9
ALPHA, BETA = 0.4, 0.8
MATIN_7H = datetime(2026, 11, 14, 7, 0)


# --- modèle --------------------------------------------------------------------

@pytest.fixture(scope="module")
def dossiers(tmp_path_factory):
    """Dossiers étape 2 (params.json, model.cbm) et étape 3 (report.json)."""
    pytest.importorskip("catboost")
    racine = tmp_path_factory.mktemp("modele")
    fond, comb = racine / "fondamental", racine / "combine"
    fond.mkdir()
    comb.mkdir()
    rng = random.Random(7)
    donnees, labels, groupes = [], [], []
    for course in range(60):
        n = rng.randint(4, 9)
        gagnant = rng.randrange(n)
        for i in range(n):
            donnees.append([
                float(rng.randint(0, 20)), rng.random() if rng.random() > 0.2 else math.nan,
                float(rng.randint(2, 10)), float(i + 1), float(n), rng.choice(["MALES", "FEMELLES", MODALITE_ABSENTE]),
            ])
            labels.append(1.0 if i == gagnant else 0.0)
            groupes.append(course)
    pool = catboost.Pool(data=donnees, label=labels, group_id=groupes, cat_features=CATEGORIQUES,
                         feature_names=FEATURES)
    modele = catboost.CatBoost({"loss_function": "QuerySoftMax", "iterations": 30, "depth": 3,
                                "random_seed": 1, "verbose": 0, "allow_writing_files": False})
    modele.fit(pool)
    modele.save_model(str(fond / "model.cbm"))
    (fond / "params.json").write_text(json.dumps({
        "features": FEATURES, "categoriques": CATEGORIQUES, "temperature": TEMPERATURE,
    }), encoding="utf-8")
    (comb / "report.json").write_text(json.dumps({"ajustement": {"alpha": ALPHA, "beta": BETA}}), encoding="utf-8")
    return str(fond), str(comb)


@pytest.fixture(scope="module")
def modele(dossiers):
    return charger(*dossiers)


# --- base ----------------------------------------------------------------------

@pytest.fixture
def repo(tmp_path):
    repository = Repository(database_url=f"sqlite:///{tmp_path / 'pronostics.db'}")
    yield repository
    repository.engine.dispose()


def ajouter_course(repo, jour, reunion, num_course, partants, finalisee=False, heure_depart=None):
    """partants : (num_pmu, nom, rang, statut)."""
    with Session(repo.engine) as session:
        c = Course(date=jour, numero_reunion=reunion, numero_course=num_course, hippodrome="DEAUVILLE",
                   discipline="plat", distance=2000.0, allocation=20000.0, finalisee=finalisee, source="pmu",
                   heure_depart=heure_depart)
        session.add(c)
        session.flush()
        for num, nom, rang, statut in partants:
            cheval = session.query(Cheval).filter_by(nom_normalise=nom).one_or_none()
            if cheval is None:
                cheval = Cheval(nom_normalise=nom)
                session.add(cheval)
                session.flush()
            session.add(Participation(
                course_id=c.id, cheval_id=cheval.id, num_pmu=num, rang_arrivee=rang,
                incident="NON_PARTANT" if statut == "NON_PARTANT" else None,
                cote_reference=3.5, cote_direct=3.0, driver=f"D {nom}", entraineur="E",
                donnees_brutes=json.dumps({"statut": statut, "age": 3 + num % 4, "placeCorde": num,
                                           "sexe": "FEMELLES" if num % 2 else "MALES", "nomPere": f"P {nom}"}),
            ))
        session.commit()
        return c.id


NOMS = ["ALPHA", "BETA", "GAMMA", "DELTA", "EPSILON", "ZETA"]


def historique(repo):
    ajouter_course(repo, AVANT, 1, 1, [(i + 1, nom, i + 1, "PARTANT") for i, nom in enumerate(NOMS)], finalisee=True)
    ajouter_course(repo, VEILLE, 1, 1, [(i + 1, nom, len(NOMS) - i, "PARTANT") for i, nom in enumerate(NOMS)],
                   finalisee=True)


def course_du_jour(repo, numero=1, depart=datetime(2026, 11, 14, 15, 0), noms=NOMS):
    return ajouter_course(repo, JOUR, 2, numero, [(i + 1, nom, None, "PARTANT") for i, nom in enumerate(noms)],
                          heure_depart=depart)


def instantane(repo, course_id, cible, cotes, statuts=None):
    """cotes : {num_pmu: cote_direct} ; statuts : {num_pmu: statut}."""
    statuts = statuts or {}
    with Session(repo.engine) as session:
        for pid, num in session.query(Participation.id, Participation.num_pmu).filter_by(course_id=course_id):
            session.add(CoteInstantanee(
                course_id=course_id, participation_id=pid, num_pmu=num, cible_minutes=cible,
                pris_le=datetime(2026, 11, 14, 12, 0), cote_direct=cotes.get(num), statut=statuts.get(num, "PARTANT"),
            ))
        session.commit()


def runs(repo, course_id=None):
    with Session(repo.engine) as session:
        q = session.query(PredictionRun).filter(PredictionRun.variante == "ml")
        if course_id is not None:
            q = q.filter(PredictionRun.course_id == course_id)
        resultat = []
        for run in q.order_by(PredictionRun.id):
            resultat.append({
                "course_id": run.course_id, "horizon": run.horizon, "cree_le": run.cree_le,
                "manques": json.loads(run.manques), "degradee": run.degradee,
                "parametres": json.loads(run.parametres),
                "chevaux": {c.num_pmu: (c.probabilite, c.probabilite_fondamentale, c.cote) for c in run.chevaux},
            })
        return resultat


@pytest.fixture
def etat(repo):
    historique(repo)
    return pronostics_ml.construire_etat(repo, JOUR)


def _somme(run):
    return sum(p for p, _, _ in run["chevaux"].values())


# --- matrice I/O ----------------------------------------------------------------

def test_matin_un_pronostic_par_course(repo, modele, etat):
    ids = [course_du_jour(repo, numero=n, depart=datetime(2026, 11, 14, 13 + n, 0)) for n in range(1, 4)]
    bilan = pronostics_ml.passage(repo, modele, etat, MATIN_7H)
    assert bilan.publies == 3 and bilan.erreurs == 0
    publies = runs(repo)
    assert sorted(r["course_id"] for r in publies) == sorted(ids)
    for run in publies:
        assert run["horizon"] == "matin" and run["manques"] == [] and not run["degradee"]
        assert _somme(run) == pytest.approx(1.0, abs=1e-9)
        assert set(run["chevaux"]) == set(range(1, len(NOMS) + 1))
        assert all(p == pf and cote is None for p, pf, cote in run["chevaux"].values())
        assert run["parametres"] == dict(
            modele.parametres(), etat_jusqu_au=VEILLE.isoformat(), horizon="matin",
        )
        assert run["cree_le"] == MATIN_7H


def test_horizon_combine_les_cotes(repo, modele, etat):
    cid = course_du_jour(repo)
    pronostics_ml.passage(repo, modele, etat, MATIN_7H)
    cotes = {1: 2.5, 2: 4.0, 3: 6.0, 4: 8.0, 5: 12.0, 6: 20.0}
    instantane(repo, cid, 30, cotes)
    maintenant = datetime(2026, 11, 14, 14, 31)
    bilan = pronostics_ml.passage(repo, modele, etat, maintenant)
    assert bilan.publies == 1
    run = runs(repo, cid)[-1]
    assert run["horizon"] == "h30" and run["manques"] == [] and run["cree_le"] == maintenant
    nums = sorted(run["chevaux"])
    p_fond = [run["chevaux"][n][1] for n in nums]
    attendu = combiner(p_fond, [cotes[n] for n in nums], ALPHA, BETA)
    assert [run["chevaux"][n][0] for n in nums] == pytest.approx(list(attendu), abs=1e-12)
    assert [run["chevaux"][n][2] for n in nums] == [cotes[n] for n in nums]
    assert _somme(run) == pytest.approx(1.0, abs=1e-9)
    assert sum(p_fond) == pytest.approx(1.0, abs=1e-9)
    # Mêmes partants qu'au matin : le fondamental ne change pas.
    matin = runs(repo, cid)[0]
    assert p_fond == pytest.approx([matin["chevaux"][n][1] for n in nums], abs=1e-12)


def test_deja_publie_aucun_nouveau_pronostic(repo, modele, etat):
    cid = course_du_jour(repo)
    instantane(repo, cid, 60, {n: 3.0 + n for n in range(1, 7)})
    maintenant = datetime(2026, 11, 14, 14, 1)
    assert pronostics_ml.passage(repo, modele, etat, maintenant).publies == 2  # matin + h60
    assert pronostics_ml.passage(repo, modele, etat, maintenant + timedelta(seconds=30)).publies == 0
    assert [r["horizon"] for r in runs(repo)] == ["matin", "h60"]


def test_non_partant_ecarte_et_renormalise(repo, modele, etat):
    cid = course_du_jour(repo)
    instantane(repo, cid, 15, {n: 3.0 + n for n in range(1, 7)}, statuts={5: "NON_PARTANT"})
    pronostics_ml.passage(repo, modele, etat, datetime(2026, 11, 14, 14, 46))
    h15 = [r for r in runs(repo, cid) if r["horizon"] == "h15"][0]
    assert 5 not in h15["chevaux"] and len(h15["chevaux"]) == 5
    assert _somme(h15) == pytest.approx(1.0, abs=1e-9)
    assert sum(pf for _, pf, _ in h15["chevaux"].values()) == pytest.approx(1.0, abs=1e-9)


@pytest.mark.parametrize("cote_manquante", [None, 1.0, float("inf")])
def test_cotes_incompletes_fondamental_seul(repo, modele, etat, cote_manquante):
    cid = course_du_jour(repo)
    cotes = {n: 3.0 + n for n in range(1, 7)}
    cotes[2] = cote_manquante
    instantane(repo, cid, 10, cotes)
    pronostics_ml.passage(repo, modele, etat, datetime(2026, 11, 14, 14, 51))
    h10 = [r for r in runs(repo, cid) if r["horizon"] == "h10"][0]
    assert h10["manques"] == ["cotes_incompletes"] and h10["degradee"]
    assert all(p == pf for p, pf, _ in h10["chevaux"].values())
    assert _somme(h10) == pytest.approx(1.0, abs=1e-9)
    assert h10["chevaux"][2][2] is None if cote_manquante != 1.0 else h10["chevaux"][2][2] == 1.0


def test_course_partie_rien_publie(repo, modele, etat):
    depart = datetime(2026, 11, 14, 15, 0)
    cid = course_du_jour(repo, depart=depart)
    instantane(repo, cid, 10, {n: 3.0 + n for n in range(1, 7)})
    assert pronostics_ml.passage(repo, modele, etat, depart).publies == 0
    # Départ atteint pendant la passe : l'horloge est relue avant l'écriture.
    assert pronostics_ml.passage(repo, modele, etat, depart - timedelta(minutes=1), horloge=lambda: depart).publies == 0
    assert runs(repo) == []


def test_reveil_tardif_etat_reconstruit(repo, modele):
    historique(repo)
    partie = course_du_jour(repo, numero=1, depart=datetime(2026, 11, 14, 14, 0))
    a_venir = course_du_jour(repo, numero=2, depart=datetime(2026, 11, 14, 16, 0))
    attentes = []
    etat = pronostics_ml.boucle(repo, modele, passages=1, horloge=lambda: datetime(2026, 11, 14, 15, 0),
                                attendre=attentes.append, heure=7)
    assert etat.jour == JOUR and etat.dernier_jour == VEILLE
    assert attentes == [pronostics_ml.POLL_SECONDS]
    assert [(r["course_id"], r["horizon"]) for r in runs(repo)] == [(a_venir, "matin")]
    assert runs(repo, partie) == []


def test_erreur_sur_une_course_isolee(repo, modele, etat, monkeypatch):
    c1 = course_du_jour(repo, numero=1)
    c2 = course_du_jour(repo, numero=2)
    original = pronostics_ml.calculer

    def calculer(modele, etat, course, effectifs, cotes):
        if course.course_id == c1:
            raise RuntimeError("panne")
        return original(modele, etat, course, effectifs, cotes)

    monkeypatch.setattr(pronostics_ml, "calculer", calculer)
    bilan = pronostics_ml.passage(repo, modele, etat, MATIN_7H)
    assert bilan.publies == 1 and bilan.erreurs == 1
    assert [r["course_id"] for r in runs(repo)] == [c2]
    monkeypatch.setattr(pronostics_ml, "calculer", original)
    assert pronostics_ml.passage(repo, modele, etat, MATIN_7H + timedelta(seconds=30)).publies == 1
    assert sorted(r["course_id"] for r in runs(repo)) == sorted([c1, c2])


# --- horizons manqués, point-in-time, boucle ----------------------------------------

def test_horizon_manque_journalise_jamais_simule(repo, modele, etat):
    cid = course_du_jour(repo)
    # H-60 sans instantané, fenêtre passée (14 h 05 + 1 min) : manqué, signalé une fois.
    bilan = pronostics_ml.passage(repo, modele, etat, datetime(2026, 11, 14, 14, 6))
    assert bilan.manques == 1 and bilan.publies == 1
    assert pronostics_ml.passage(repo, modele, etat, datetime(2026, 11, 14, 14, 7)).manques == 0
    # H-30 et H-15 relevés pendant une panne : seul le plus récent est publié.
    instantane(repo, cid, 30, {n: 3.0 + n for n in range(1, 7)})
    instantane(repo, cid, 15, {n: 3.0 + n for n in range(1, 7)})
    bilan = pronostics_ml.passage(repo, modele, etat, datetime(2026, 11, 14, 14, 46))
    assert bilan.publies == 1 and bilan.manques == 1
    assert [r["horizon"] for r in runs(repo, cid)] == ["matin", "h15"]


def test_courses_du_jour_ne_nourrissent_pas_l_etat(repo):
    historique(repo)
    # Une course du jour déjà finalisée : jamais dans l'état du jour.
    ajouter_course(repo, JOUR, 1, 1, [(1, "ALPHA", 1, "PARTANT"), (2, "BETA", 2, "PARTANT")], finalisee=True,
                   heure_depart=datetime(2026, 11, 14, 12, 0))
    etat = pronostics_ml.construire_etat(repo, JOUR)
    assert etat.dernier_jour == VEILLE
    assert all(c.nb == 2 for c in etat.constructeur.chevaux.values())


def test_jour_programme():
    assert pronostics_ml.jour_programme(datetime(2026, 11, 14, 6, 59), 7) == VEILLE
    assert pronostics_ml.jour_programme(datetime(2026, 11, 14, 7, 0), 7) == JOUR


class ModeleFactice:
    """Suffit aux passes sans course (tests de la boucle sans catboost)."""

    def parametres(self):
        return {}


class Horloge:
    """Horloge simulée : avance de `pas` à chaque attente de la boucle."""

    def __init__(self, debut, pas=timedelta(seconds=30)):
        self.t, self.pas = debut, pas

    def __call__(self):
        return self.t

    def attendre(self, _secondes):
        self.t += self.pas


def test_boucle_reconstruit_au_changement_de_programme(repo):
    horloge = Horloge(datetime(2026, 11, 14, 6, 59))
    jours = []

    def construire(repository, jour):
        jours.append(jour)
        return pronostics_ml.Etat(jour=jour, constructeur=pronostics_ml.ConstructeurFeatures())

    pronostics_ml.boucle(repo, ModeleFactice(), passages=4, horloge=horloge, attendre=horloge.attendre,
                         heure=7, construire=construire)
    assert jours == [VEILLE, JOUR]


def test_boucle_survit_a_une_erreur(repo):
    def construire(repository, jour):
        raise RuntimeError("base indisponible")

    attentes = []
    pronostics_ml.boucle(repo, ModeleFactice(), passages=2, horloge=lambda: MATIN_7H, attendre=attentes.append,
                         construire=construire)
    assert len(attentes) == 2


def test_reconstruction_en_echec_retentee_toutes_les_5_minutes(repo, caplog):
    horloge = Horloge(MATIN_7H)
    essais = []

    def construire(repository, jour):
        essais.append(horloge())
        if len(essais) < 3:
            raise RuntimeError("base verrouillée")
        return pronostics_ml.Etat(jour=jour, constructeur=pronostics_ml.ConstructeurFeatures())

    # 25 passes de 30 s : 12 min 30.
    etat = pronostics_ml.boucle(repo, ModeleFactice(), passages=25, horloge=horloge, attendre=horloge.attendre,
                                heure=7, construire=construire)
    assert essais == [MATIN_7H, MATIN_7H + timedelta(minutes=5), MATIN_7H + timedelta(minutes=10)]
    assert etat is not None and etat.jour == JOUR
    assert sum("Echec de la reconstruction" in r.getMessage() for r in caplog.records) == 2


@pytest.mark.parametrize("brut, attendu", [("8", 8), (" 0 ", 0), ("23", 23), ("7.5", 7), ("abc", 7),
                                           ("24", 7), ("-1", 7), ("", 7)])
def test_pronostics_heure(monkeypatch, brut, attendu):
    monkeypatch.setenv("PRONOSTICS_HEURE", brut)
    assert pronostics_ml._env_heure() == attendu


# --- encodage, combinaison, chargement ----------------------------------------------

def test_encodage_comme_le_csv_d_entrainement(modele):
    ligne = {"f_nb_courses_connues": 3, "f_taux_victoire_6": 0.1234567891, "f_age": None,
             "f_place_corde": True, "f_nb_partants": 7.0, "f_sexe": None, "course_id": 1}
    assert modele.matrice([ligne])[0][:2] == [3.0, 0.123457]
    valeurs = modele.matrice([ligne])[0]
    assert math.isnan(valeurs[2]) and valeurs[3] == 1.0 and valeurs[4] == 7.0
    assert valeurs[5] == MODALITE_ABSENTE
    assert modele.matrice([dict(ligne, f_sexe="MALES")])[0][5] == "MALES"
    assert all(isinstance(v, float) for v in valeurs[:5])


def test_probas_fondamentales_softmax_par_course_avec_temperature(modele):
    lignes = [{"course_id": c, "f_nb_courses_connues": i, "f_taux_victoire_6": None, "f_age": 4,
               "f_place_corde": i, "f_nb_partants": 3, "f_sexe": "MALES"} for c in (1, 2) for i in range(3)]
    p = modele.probas_fondamentales(lignes)
    assert p[:3].sum() == pytest.approx(1.0) and p[3:].sum() == pytest.approx(1.0)
    s = modele.scores(lignes[:3]) / TEMPERATURE
    attendu = np.exp(s - s.max()) / np.exp(s - s.max()).sum()
    assert p[:3] == pytest.approx(attendu, abs=1e-12)


def test_formule_de_combinaison():
    p_fond = [0.5, 0.3, 0.2]
    cotes = [2.0, 4.0, 8.0]
    inverse = np.array([1 / 2, 1 / 4, 1 / 8])
    p_mkt = inverse / inverse.sum()
    s = 0.4 * np.log(p_fond) + 0.8 * np.log(p_mkt)
    assert combiner(p_fond, cotes, 0.4, 0.8) == pytest.approx(np.exp(s) / np.exp(s).sum(), abs=1e-12)
    assert combiner(p_fond, cotes, 0.0, 1.0) == pytest.approx(p_mkt, abs=1e-12)
    assert combiner(p_fond, cotes, 1.0, 0.0) == pytest.approx(p_fond, abs=1e-12)
    # Plancher 1e-6 avant le log, comme ml/hippique_ml/combine.py.
    assert np.isfinite(combiner([1.0, 0.0, 0.0], cotes, 0.4, 0.8)).all()
    for invalide in (None, 1.0, 0.5, float("nan"), float("inf"), "3.0"):
        assert combiner(p_fond, [2.0, invalide, 8.0], 0.4, 0.8) is None


def test_chargement_valide(dossiers, modele):
    assert modele.features == FEATURES and modele.categoriques == CATEGORIQUES
    assert (modele.temperature, modele.alpha, modele.beta) == (TEMPERATURE, ALPHA, BETA)
    assert len(modele.sha_modele) == 64 and modele.sha_modele == inference.sha256_fichier(f"{dossiers[0]}/model.cbm")


def test_chargement_refuse(dossiers, tmp_path):
    fond, comb = dossiers
    with pytest.raises(ErreurModele, match="absent"):
        charger(str(tmp_path), comb)
    with pytest.raises(ErreurModele, match="absent"):
        charger(fond, str(tmp_path))
    autre = tmp_path / "fond"
    autre.mkdir()
    (autre / "model.cbm").write_bytes(open(f"{fond}/model.cbm", "rb").read())
    (autre / "params.json").write_text(json.dumps({
        "features": FEATURES[:-1] + ["f_inexistante"], "categoriques": [], "temperature": 1.0,
    }), encoding="utf-8")
    with pytest.raises(ErreurModele, match="NOMS_FEATURES"):
        charger(str(autre), comb)
    (autre / "params.json").write_text(json.dumps({
        "features": list(reversed(FEATURES)), "categoriques": CATEGORIQUES, "temperature": 1.0,
    }), encoding="utf-8")
    with pytest.raises(ErreurModele, match="features différentes"):
        charger(str(autre), comb)


def _copie(dossiers, tmp_path, params=None, rapport=None, nom="copie"):
    """Copie du modèle de la fixture, params.json et report.json modifiables."""
    fond, comb = tmp_path / f"{nom}_fond", tmp_path / f"{nom}_comb"
    fond.mkdir()
    comb.mkdir()
    (fond / "model.cbm").write_bytes(open(f"{dossiers[0]}/model.cbm", "rb").read())
    base = {"features": FEATURES, "categoriques": CATEGORIQUES, "temperature": TEMPERATURE}
    (fond / "params.json").write_text(json.dumps(dict(base, **(params or {}))), encoding="utf-8")
    (comb / "report.json").write_text(json.dumps(
        rapport if rapport is not None else {"ajustement": {"alpha": ALPHA, "beta": BETA}}), encoding="utf-8")
    return str(fond), str(comb)


@pytest.mark.parametrize("temperature", [0, -1.0, float("nan"), None, "0.9"])
def test_chargement_refuse_temperature_invalide(dossiers, tmp_path, temperature):
    with pytest.raises(ErreurModele, match="température"):
        charger(*_copie(dossiers, tmp_path, params={"temperature": temperature}))


@pytest.mark.parametrize("rapport", [
    {}, {"ajustement": None}, {"ajustement": {"alpha": None, "beta": BETA}},
    {"ajustement": {"alpha": ALPHA, "beta": None}}, {"ajustement": {"alpha": float("nan"), "beta": BETA}},
    {"ajustement": {"alpha": ALPHA}},
])
def test_chargement_refuse_ajustement_invalide(dossiers, tmp_path, rapport):
    with pytest.raises(ErreurModele, match="ajustement|alpha"):
        charger(*_copie(dossiers, tmp_path, rapport=rapport))


def test_chargement_refuse_categories_differentes(dossiers, tmp_path):
    with pytest.raises(ErreurModele, match="catégorielles"):
        charger(*_copie(dossiers, tmp_path, params={"categoriques": []}))
    with pytest.raises(ErreurModele, match="catégorielles"):
        charger(*_copie(dossiers, tmp_path, params={"categoriques": ["f_sexe", "f_age"]}, nom="deux"))


def test_chargement_version_catboost(dossiers, tmp_path):
    with pytest.raises(ErreurModele, match="catboost"):
        charger(*_copie(dossiers, tmp_path, params={"versions": {"catboost": "0.0.1"}}))
    modele = charger(*_copie(dossiers, tmp_path, params={"versions": {"catboost": catboost.__version__}}, nom="ok"))
    assert modele.features == FEATURES


def test_main_refuse_de_demarrer_sans_modele(monkeypatch, tmp_path):
    monkeypatch.setattr(pronostics_ml, "DOSSIER_FONDAMENTAL", str(tmp_path))
    monkeypatch.setattr(pronostics_ml, "DOSSIER_COMBINE", str(tmp_path))
    assert pronostics_ml.main([]) == 1


# --- parité avec la table d'entraînement -------------------------------------------

def _lire_csv_comme_l_entrainement(chemin):
    """Même lecture que ml/hippique_ml/data.py : vide = NaN ou MODALITE_ABSENTE."""
    with gzip.open(chemin, "rt", encoding="utf-8", newline="") as f:
        lignes = list(csv.DictReader(f))
    matrice = [[(r[n] if r[n] != "" else MODALITE_ABSENTE) if n in CATEGORIQUES
                else (float(r[n]) if r[n] != "" else math.nan) for n in FEATURES] for r in lignes]
    return lignes, matrice


def _jour_a_verifier(repo, modele, tmp_path):
    """Jour finalisé et prédictions calculées comme à l'entraînement (table
    build_features relue comme ml/), écrites en test_predictions.csv.gz."""
    historique(repo)
    ajouter_course(repo, JOUR, 1, 1, [(i + 1, nom, i + 1, "PARTANT") for i, nom in enumerate(NOMS)]
                   + [(7, "ETA", None, "NON_PARTANT")], finalisee=True)
    ajouter_course(repo, JOUR, 1, 2, [(1, "THETA", 2, "PARTANT"), (2, "ALPHA", 1, "PARTANT")], finalisee=True)
    table = str(tmp_path / "features.csv.gz")
    build_features.construire(repo, JOUR, JOUR, table)
    lignes, matrice = _lire_csv_comme_l_entrainement(table)
    pool = catboost.Pool(data=matrice, cat_features=CATEGORIQUES, feature_names=FEATURES)
    scores = modele.modele.predict(pool, prediction_type="RawFormulaVal")
    probas = inference.softmax_par_course(scores, [r["course_id"] for r in lignes], TEMPERATURE)
    return [[r["course_id"], r["num_pmu"], r["date"], r["discipline"], float(p), r["gagnant"]]
            for r, p in zip(lignes, probas)]


def _ecrire_predictions(chemin, lignes):
    with gzip.open(chemin, "wt", encoding="utf-8", newline="") as f:
        ecrivain = csv.writer(f)
        ecrivain.writerow(["course_id", "num_pmu", "date", "discipline", "proba_modele", "gagnant"])
        for ligne in lignes:
            ecrivain.writerow(ligne[:4] + [repr(ligne[4])] + ligne[5:])
    return str(chemin)


def test_verifier_parite_avec_build_features(repo, modele, tmp_path):
    predictions = _ecrire_predictions(tmp_path / "test_predictions.csv.gz", _jour_a_verifier(repo, modele, tmp_path))
    bilan = pronostics_ml.verifier(repo, modele, JOUR, predictions)
    assert bilan["attendus"] == 8 and bilan["compares"] == 8
    assert bilan["manquants"] == 0 and bilan["en_plus"] == 0
    assert bilan["ecart_max"] < 1e-12


@pytest.mark.parametrize("alteration, code", [
    ("aucune", 0),
    ("ecart", 1),       # une probabilité décalée de 1e-5
    ("manquant", 1),    # un partant attendu inconnu du backend
    ("en_plus", 1),     # un partant calculé absent des prédictions
])
def test_main_verifier_code_de_sortie(repo, modele, dossiers, tmp_path, monkeypatch, alteration, code):
    lignes = _jour_a_verifier(repo, modele, tmp_path)
    if alteration == "ecart":
        lignes[0][4] += 1e-5
    elif alteration == "manquant":
        lignes.append([lignes[0][0], 99] + lignes[0][2:])
    elif alteration == "en_plus":
        lignes = lignes[1:]
    predictions = _ecrire_predictions(tmp_path / "predictions.csv.gz", lignes)
    monkeypatch.setattr(pronostics_ml, "DOSSIER_FONDAMENTAL", dossiers[0])
    monkeypatch.setattr(pronostics_ml, "DOSSIER_COMBINE", dossiers[1])
    monkeypatch.setattr(pronostics_ml, "Repository", lambda: repo)
    assert pronostics_ml.main(["--verifier", JOUR.isoformat(), "--predictions", predictions]) == code


def test_main_refuse_sans_catboost(monkeypatch, tmp_path):
    def charger(*_args):
        raise ImportError("No module named 'catboost'")

    monkeypatch.setattr(pronostics_ml, "charger", charger)
    assert pronostics_ml.main([]) == 1


# --- stockage ------------------------------------------------------------------------

def test_migration_ajoute_les_colonnes(tmp_path):
    url = f"sqlite:///{tmp_path / 'ancienne.db'}"
    repository = Repository(database_url=url)
    with repository.engine.begin() as conn:
        conn.execute(text("DROP INDEX uq_prediction_runs_ml_horizon"))
        conn.execute(text("ALTER TABLE prediction_runs DROP COLUMN horizon"))
        conn.execute(text("ALTER TABLE prediction_chevaux DROP COLUMN probabilite_fondamentale"))
    repository.engine.dispose()
    repository = Repository(database_url=url)
    assert "horizon" in {c["name"] for c in inspect(repository.engine).get_columns("prediction_runs")}
    assert "probabilite_fondamentale" in {
        c["name"] for c in inspect(repository.engine).get_columns("prediction_chevaux")}
    assert "uq_prediction_runs_ml_horizon" in {i["name"] for i in inspect(repository.engine).get_indexes("prediction_runs")}
    repository.engine.dispose()


def _course_seule(repo):
    with Session(repo.engine) as session:
        c = Course(date=JOUR, hippodrome="X", discipline="plat", source="pmu")
        session.add(c)
        session.commit()
        return c.id


def test_un_seul_pronostic_ml_par_course_et_horizon(repo):
    cid = _course_seule(repo)
    chevaux = [{"num_pmu": 1, "probabilite": 1.0, "probabilite_fondamentale": 1.0, "cote": None}]
    assert repo.enregistrer_pronostic_ml(cid, "h30", MATIN_7H, chevaux, [], {}) is not None
    assert repo.enregistrer_pronostic_ml(cid, "h30", MATIN_7H, chevaux, [], {}) is None
    assert repo.enregistrer_pronostic_ml(cid, "h10", MATIN_7H, chevaux, [], {}) is not None
    # Index partiel : les autres variantes ne sont pas concernées.
    with Session(repo.engine) as session:
        for _ in range(2):
            session.add(PredictionRun(course_id=cid, cree_le=MATIN_7H, variante="live", horizon="h30"))
        session.commit()
    with Session(repo.engine) as session:
        assert session.query(PredictionRun).filter_by(variante="ml").count() == 2
    assert repo.horizons_publies(cid) == {"h30", "h10"}


def test_ecriture_refusee_comptee_deja_publie(repo, modele, etat, monkeypatch):
    course_du_jour(repo)
    # Une autre écriture concurrente a déjà publié le matin entre la lecture et l'écriture.
    monkeypatch.setattr(repo, "horizons_publies", lambda _cid: set())
    assert pronostics_ml.passage(repo, modele, etat, MATIN_7H).publies == 1
    bilan = pronostics_ml.passage(repo, modele, etat, MATIN_7H + timedelta(seconds=30))
    assert (bilan.publies, bilan.deja_publies, bilan.erreurs) == (0, 1, 0)
    assert len(runs(repo)) == 1


def test_course_sans_partant_restant_signalee_une_fois(repo, modele, etat):
    cid = course_du_jour(repo, noms=NOMS[:2])
    instantane(repo, cid, 30, {1: 3.0, 2: 4.0}, statuts={1: "NON_PARTANT", 2: "NON_PARTANT"})
    maintenant = datetime(2026, 11, 14, 14, 31)
    bilan = pronostics_ml.passage(repo, modele, etat, maintenant)
    assert (bilan.publies, bilan.sans_partant, bilan.erreurs) == (1, 1, 0)  # le matin seulement
    bilan = pronostics_ml.passage(repo, modele, etat, maintenant + timedelta(seconds=30))
    assert (bilan.publies, bilan.sans_partant, bilan.erreurs) == (0, 0, 0)
    assert [r["horizon"] for r in runs(repo, cid)] == ["matin"]
    # Tous non partants en base aussi : rien au matin, signalé une fois.
    autre = ajouter_course(repo, JOUR, 3, 1, [(1, "ALPHA", None, "NON_PARTANT")],
                           heure_depart=datetime(2026, 11, 14, 16, 0))
    bilan = pronostics_ml.passage(repo, modele, etat, maintenant + timedelta(minutes=1))
    assert (bilan.sans_partant, bilan.erreurs) == (1, 0) and runs(repo, autre) == []


def test_h60_puis_h30_au_fil_du_temps(repo, modele, etat):
    cid = course_du_jour(repo)
    instantane(repo, cid, 60, {n: 3.0 + n for n in range(1, 7)})
    assert pronostics_ml.passage(repo, modele, etat, datetime(2026, 11, 14, 14, 1)).publies == 2
    assert pronostics_ml.passage(repo, modele, etat, datetime(2026, 11, 14, 14, 20)).publies == 0
    instantane(repo, cid, 30, {n: 10.0 - n for n in range(1, 7)}, statuts={4: "NON_PARTANT"})
    bilan = pronostics_ml.passage(repo, modele, etat, datetime(2026, 11, 14, 14, 31))
    assert bilan.publies == 1 and bilan.manques == 0
    publies = runs(repo, cid)
    assert [r["horizon"] for r in publies] == ["matin", "h60", "h30"]
    h60, h30 = publies[1], publies[2]
    assert h60["chevaux"][1][2] == 4.0 and h30["chevaux"][1][2] == 9.0
    assert 4 not in h30["chevaux"] and 4 in h60["chevaux"]
    assert h30["parametres"]["non_partants"] == [4] and h60["parametres"]["non_partants"] == []
    assert h30["parametres"]["instantane_pris_le"] == "2026-11-14T12:00:00"


def test_course_sans_heure_de_depart_ignoree(repo, modele, etat):
    ajouter_course(repo, JOUR, 2, 1, [(1, "ALPHA", None, "PARTANT"), (2, "BETA", None, "PARTANT")])
    assert build_features.lire_courses_du_jour(repo, JOUR) == []
    bilan = pronostics_ml.passage(repo, modele, etat, MATIN_7H)
    assert (bilan.publies, bilan.erreurs) == (0, 0) and runs(repo) == []


def test_runs_ml_hors_du_tableau_de_bord(repo, modele, etat):
    course_du_jour(repo)
    pronostics_ml.passage(repo, modele, etat, MATIN_7H)
    assert repo.courses_evaluables("live") == [] and len(repo.courses_evaluables("ml")) == 1
    assert repo.horizons_publies(runs(repo)[0]["course_id"]) == {"matin"}
