"""Tests de bout en bout de `jobs/build_features.py` sur une petite base
SQLite temporaire : en-tête, groupes, ordre, registre, gzip, filtres,
écriture atomique."""

import csv
import gzip
import json
from datetime import date

import pytest
from sqlalchemy.orm import Session

from app.data.models import Cheval, Course, Participation
from app.data.repository import Repository
from app.jobs import build_features
from app.model.features import COLONNES, NOMS_COLONNES, PARAMETRES, type_colonne

D0 = date(2025, 1, 5)
D1 = date(2025, 3, 2)
D2 = date(2025, 3, 9)
D3 = date(2025, 3, 16)


@pytest.fixture
def repo(tmp_path):
    repository = Repository(database_url=f"sqlite:///{tmp_path / 'features.db'}")
    yield repository
    # Libère le fichier avant que tmp_path ne soit nettoyé (Windows).
    repository.engine.dispose()


def _ajouter(repo, jour, reunion, num_course, partants, finalisee=True, source="pmu", discipline="plat"):
    """partants : (num_pmu, nom, rang, statut[, brut]) ; brut remplace le
    JSON par défaut (chaîne brute, éventuellement illisible)."""
    with Session(repo.engine) as session:
        c = Course(date=jour, numero_reunion=reunion, numero_course=num_course, hippodrome="DEAUVILLE",
                   discipline=discipline, distance=2000.0, allocation=20000.0, finalisee=finalisee, source=source)
        session.add(c)
        session.flush()
        for num, nom, rang, statut, *brut in partants:
            cheval = session.query(Cheval).filter_by(nom_normalise=nom).one_or_none()
            if cheval is None:
                cheval = Cheval(nom_normalise=nom)
                session.add(cheval)
                session.flush()
            donnees = brut[0] if brut else json.dumps(
                {"statut": statut, "age": 4, "placeCorde": num, "nomPere": f"PERE {nom}"}
            )
            session.add(Participation(
                course_id=c.id, cheval_id=cheval.id, num_pmu=num, rang_arrivee=rang,
                incident="NON_PARTANT" if statut == "NON_PARTANT" else None,
                cote_reference=3.5, cote_direct=3.0, driver=f"D {nom}", entraineur="E",
                donnees_brutes=donnees,
            ))
        session.commit()
        return c.id


def _lire(chemin):
    with gzip.open(chemin, "rt", encoding="utf-8", newline="") as f:
        return list(csv.reader(f))


def _registre(sortie):
    with open(build_features.chemin_registre(sortie), encoding="utf-8") as f:
        return json.load(f)


def test_bout_en_bout(repo, tmp_path):
    _ajouter(repo, D0, 1, 1, [(1, "ALPHA", 1, "PARTANT"), (2, "BETA", 2, "PARTANT")])  # avant la plage
    c2 = _ajouter(repo, D2, 1, 2, [(2, "BETA", 1, "PARTANT"), (1, "ALPHA", 2, "PARTANT")])
    c1 = _ajouter(repo, D1, 2, 1, [(3, "GAMMA", 1, "PARTANT"), (1, "ALPHA", 2, "PARTANT"),
                                   (2, "DELTA", None, "NON_PARTANT")])
    _ajouter(repo, D2, 3, 1, [(1, "OMEGA", 1, "PARTANT")], finalisee=False)
    _ajouter(repo, D2, 4, 1, [(1, "OPEN", 1, "PARTANT")], source="open_pmu_api")
    _ajouter(repo, D3, 1, 1, [(1, "ALPHA", 1, "PARTANT")])  # après la plage

    sortie = str(tmp_path / "sous" / "dossier" / "features.csv.gz")  # dossier créé
    bilan = build_features.construire(repo, D1, D2, sortie)

    lignes = _lire(sortie)
    assert lignes[0] == list(NOMS_COLONNES)
    donnees = [dict(zip(lignes[0], l)) for l in lignes[1:]]
    cles = [(d["date"], int(d["course_id"]), int(d["num_pmu"])) for d in donnees]
    assert cles == sorted(cles)
    assert cles == [(D1.isoformat(), c1, 1), (D1.isoformat(), c1, 3), (D2.isoformat(), c2, 1), (D2.isoformat(), c2, 2)]
    assert {k: bilan[k] for k in ("jours", "courses", "lignes", "jours_historique")} == {
        "jours": 2, "courses": 2, "lignes": 4, "jours_historique": 1,
    }
    assert bilan["ecartees"] == {
        "course_non_finalisee": 1, "autre_source": 1, "num_pmu_absent": 0, "brut_illisible": 0, "statut_inconnu": 0,
    }

    alpha_d1 = donnees[0]
    # L'historique antérieur à la plage compte : ALPHA a gagné le 5 janvier.
    assert alpha_d1["f_nb_courses_connues"] == "1"
    assert alpha_d1["f_taux_victoire_6"] == "1"
    assert alpha_d1["f_nb_partants"] == "2"  # le non-partant n'est pas compté
    assert alpha_d1["rang"] == "2" and alpha_d1["gagnant"] == "0"
    assert alpha_d1["cote_direct"] == "3" and alpha_d1["cote_reference"] == "3.5"
    gamma_d1 = donnees[1]
    assert gamma_d1["f_rang_rel_dernier"] == ""  # aucune donnée : cellule vide
    assert gamma_d1["f_nb_courses_connues"] == "0"

    registre = _registre(sortie)
    assert [c["nom"] for c in registre["colonnes"]] == list(NOMS_COLONNES)
    assert {c["nom"]: c["groupe"] for c in registre["colonnes"]} == {c.nom: c.groupe for c in COLONNES}
    assert {c["nom"]: c["type"] for c in registre["colonnes"]} == {n: type_colonne(n) for n in NOMS_COLONNES}
    assert {c["type"] for c in registre["colonnes"]} == {"numeric", "categorical", "flag"}
    assert all(c["sources"] for c in registre["colonnes"])
    assert registre["lignes"] == 4 and registre["courses"] == 2
    assert registre["parametres"] == PARAMETRES
    assert "97 %" in registre["note"] and "95 %" in registre["note"]
    assert registre["genere_le_utc"].endswith("+00:00")
    assert "git_sha" in registre
    assert registre["ecartees"] == bilan["ecartees"]
    assert not list((tmp_path / "sous" / "dossier").glob("*.tmp"))


def test_non_finalisee_et_open_pmu_ne_nourrissent_pas_l_historique(repo, tmp_path):
    # Même cheval, même driver, même père : seule la course finalisée pmu compte.
    _ajouter(repo, D0, 1, 1, [(1, "ALPHA", 1, "PARTANT"), (2, "BETA", 2, "PARTANT")], finalisee=False)
    _ajouter(repo, D0, 2, 1, [(1, "ALPHA", 1, "PARTANT"), (2, "BETA", 2, "PARTANT")], source="open_pmu_api")
    _ajouter(repo, D1, 1, 1, [(1, "ALPHA", None, "PARTANT"), (2, "BETA", 1, "PARTANT")])
    sortie = str(tmp_path / "f.csv.gz")
    build_features.construire(repo, D1, D1, sortie)
    alpha = dict(zip(*_lire(sortie)[:2]))
    assert alpha["num_pmu"] == "1"
    assert alpha["f_nb_courses_connues"] == "0"
    assert alpha["f_driver_nb_365"] == "0"
    assert alpha["f_pere_nb_disc"] == "0"


def test_brut_illisible_garde_sa_ligne(repo, tmp_path):
    _ajouter(repo, D1, 1, 1, [
        (1, "ALPHA", 1, "PARTANT", "{pas du json"),
        (2, "BETA", 2, "PARTANT", "[1, 2]"),
        (3, "GAMMA", 3, "PARTANT"),
    ])
    sortie = str(tmp_path / "f.csv.gz")
    bilan = build_features.construire(repo, D1, D1, sortie)
    donnees = [dict(zip(_lire(sortie)[0], l)) for l in _lire(sortie)[1:]]
    assert [d["num_pmu"] for d in donnees] == ["1", "2", "3"]
    assert donnees[0]["f_age"] == "" and donnees[0]["rang"] == "1"
    assert bilan["ecartees"]["brut_illisible"] == 2
    # Brut vide, donc statut absent : compté partant et signalé.
    assert bilan["ecartees"]["statut_inconnu"] == 2


def test_dossard_absent_compte(repo, tmp_path):
    _ajouter(repo, D1, 1, 1, [(1, "ALPHA", 2, "PARTANT"), (None, "BETA", 1, "PARTANT")])
    sortie = str(tmp_path / "f.csv.gz")
    bilan = build_features.construire(repo, D1, D1, sortie)
    donnees = [dict(zip(_lire(sortie)[0], l)) for l in _lire(sortie)[1:]]
    assert [d["num_pmu"] for d in donnees] == ["1"]
    assert donnees[0]["f_nb_partants"] == "2"
    assert bilan["ecartees"]["num_pmu_absent"] == 1


def test_plage_vide_ecrit_entete_et_registre(repo, tmp_path):
    _ajouter(repo, D0, 1, 1, [(1, "ALPHA", 1, "PARTANT")])
    sortie = str(tmp_path / "vide.csv.gz")
    bilan = build_features.construire(repo, D1, D2, sortie)
    assert _lire(sortie) == [list(NOMS_COLONNES)]
    assert bilan["lignes"] == 0
    registre = _registre(sortie)
    assert registre["lignes"] == 0 and registre["courses"] == 0


def test_echec_ne_laisse_pas_de_sortie_partielle(repo, tmp_path, monkeypatch):
    _ajouter(repo, D1, 1, 1, [(1, "ALPHA", 1, "PARTANT")])
    sortie = tmp_path / "f.csv.gz"
    sortie.write_bytes(b"ancienne")

    def panne(*args, **kwargs):
        raise RuntimeError("panne")

    monkeypatch.setattr(build_features, "lignes_ecartees", panne)
    with pytest.raises(RuntimeError):
        build_features.construire(repo, D1, D1, str(sortie))
    assert sortie.read_bytes() == b"ancienne"
    assert not list(tmp_path.glob("*.tmp"))


def test_main_code_de_sortie_en_echec(monkeypatch, tmp_path):
    def panne(*args, **kwargs):
        raise RuntimeError("panne")

    monkeypatch.setattr(build_features, "Repository", lambda: None)
    monkeypatch.setattr(build_features, "construire", panne)
    code = build_features.main(["--date-debut", "2025-03-02", "--date-fin", "2025-03-09",
                                "--sortie", str(tmp_path / "f.csv.gz")])
    assert code == 1


def test_dates_inversees_refusees():
    with pytest.raises(SystemExit):
        build_features.parse_args(["--date-debut", "2025-03-09", "--date-fin", "2025-03-02", "--sortie", "x.csv.gz"])


def test_formater():
    assert build_features.formater(None) == ""
    assert build_features.formater(True) == "1"
    assert build_features.formater(2.0) == "2"
    assert build_features.formater(1 / 3) == "0.333333"
    assert build_features.formater(D1) == "2025-03-02"
