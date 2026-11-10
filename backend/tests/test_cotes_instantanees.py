"""Tests de `jobs/cotes_instantanees.py` : une fonction par ligne de la
matrice I/O du spec (spec-cotes-instantanees.md). Horloge simulée
(`maintenant` passé au job) et `pmu_client.get_participants` mocké."""

import atexit
import json
import os
import tempfile
from datetime import date, datetime, timedelta
from unittest.mock import patch

import pytest
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from app.data import pmu_client
from app.data.models import CoteInstantanee, Course, Participation
from app.data.pmu_client import CourseInfo, PartantInfo
from app.data.repository import Repository
from app.jobs import cotes_instantanees

JOUR = date(2026, 11, 10)
DEPART = datetime(2026, 11, 10, 15, 0)


@pytest.fixture(autouse=True)
def pas_de_pause(monkeypatch):
    monkeypatch.setattr(pmu_client.time, "sleep", lambda _s: None)
    monkeypatch.setattr(cotes_instantanees.time, "sleep", lambda _s: None)


@pytest.fixture
def repo():
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_cotes_instantanees_")
    os.close(fd)

    def _cleanup() -> None:
        for suffixe in ("", "-wal", "-shm"):
            try:
                os.remove(path + suffixe)
            except OSError:
                pass

    atexit.register(_cleanup)
    repository = Repository(database_url=f"sqlite:///{path}")
    yield repository
    repository.engine.dispose()
    _cleanup()
    atexit.unregister(_cleanup)


def make_partant(num_pmu, **overrides) -> PartantInfo:
    defaults = dict(
        num_pmu=num_pmu, nom=f"Cheval {num_pmu}", age=5, sexe="M", statut="PARTANT",
        driver_jockey="J. Dupont", entraineur="P. Martin", musique="1p2p", nombre_courses=10,
        inedit=False, handicap_poids=57.5, cote_reference=4.5, cote_direct=4.2,
        ordre_arrivee=None, incident=None, raw={},
        cote_reference_le=datetime(2026, 11, 10, 13, 30), cote_direct_le=datetime(2026, 11, 10, 13, 40),
        rapports_bruts={
            "dernierRapportDirect": {"rapport": 4.2, "favoris": True, "grossePrise": False,
                                     "nombreIndicateurTendance": 2.0},
            "dernierRapportReference": {"rapport": 4.5},
        },
    )
    defaults.update(overrides)
    return PartantInfo(**defaults)


def creer_course(repo, numero_course=1, heure_depart=DEPART, nb=3, numero_reunion=1) -> Course:
    course = repo.upsert_course(CourseInfo(
        date=JOUR, numero_reunion=numero_reunion, numero_course=numero_course, hippodrome="VINCENNES",
        pays="FRA", libelle="Prix Test", discipline="trot", discipline_brute="ATTELE", distance=2700.0,
        allocation=30000.0, corde="gauche", nb_partants_declares=nb, arrivee_definitive=False,
        heure_depart=heure_depart,
    ))
    repo.save_partants(course.id, [make_partant(n) for n in range(1, nb + 1)])
    return course


def _lignes(repo):
    with Session(repo.engine) as session:
        return session.query(CoteInstantanee).order_by(CoteInstantanee.cible_minutes, CoteInstantanee.num_pmu).all()


def _participants(nb=3, **overrides):
    return lambda d, r, c: [make_partant(n, **overrides) for n in range(1, nb + 1)]


def test_cible_due_releve_une_ligne_par_partant(repo):
    course = creer_course(repo)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()) as part:
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=29))

    part.assert_called_once_with(JOUR, 1, 1)
    lignes = _lignes(repo)
    assert len(lignes) == 3
    assert {l.cible_minutes for l in lignes} == {30}
    assert bilan.pris == 3 and bilan.erreurs == 0 and bilan.ignores == 0
    # H-60 est passé hors fenêtre (fermée à départ - 55) : manqué.
    assert bilan.manques == 1
    ligne = lignes[0]
    with Session(repo.engine) as session:
        participation = session.query(Participation).filter_by(course_id=course.id, num_pmu=1).one()
    assert ligne.course_id == course.id and ligne.participation_id == participation.id
    assert (ligne.cote_direct, ligne.cote_reference) == (4.2, 4.5)
    assert ligne.cote_direct_le == datetime(2026, 11, 10, 13, 40)
    assert ligne.cote_reference_le == datetime(2026, 11, 10, 13, 30)
    assert ligne.statut == "PARTANT"
    assert ligne.pris_le is not None
    brut = json.loads(ligne.brut)
    assert brut["dernierRapportDirect"]["favoris"] is True
    assert brut["dernierRapportDirect"]["nombreIndicateurTendance"] == 2.0
    assert brut["dernierRapportReference"] == {"rapport": 4.5}


def test_cible_deja_prise_ne_redemande_rien(repo):
    creer_course(repo)
    maintenant = DEPART - timedelta(minutes=29)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        cotes_instantanees.prendre_instantanes(repo, maintenant)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()) as part:
        bilan = cotes_instantanees.prendre_instantanes(repo, maintenant + timedelta(seconds=30))

    part.assert_not_called()
    assert bilan.pris == 0
    assert len(_lignes(repo)) == 3


def test_cible_manquee_jamais_prise_en_retard(repo):
    creer_course(repo)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()) as part:
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=30) + timedelta(minutes=6))

    part.assert_not_called()
    assert _lignes(repo) == []
    assert bilan.manques == 2  # H-60 et H-30
    assert bilan.pris == 0


def test_manque_signale_une_seule_fois_par_la_boucle(repo):
    creer_course(repo)
    signales = set()
    maintenant = DEPART - timedelta(minutes=24)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        premier = cotes_instantanees.prendre_instantanes(repo, maintenant, signales)
        second = cotes_instantanees.prendre_instantanes(repo, maintenant + timedelta(seconds=30), signales)
    assert (premier.manques, second.manques) == (2, 0)


def test_reveil_tardif_prend_h10_et_manque_h60_h30(repo):
    creer_course(repo)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()) as part:
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=9))

    part.assert_called_once()
    assert {l.cible_minutes for l in _lignes(repo)} == {10}
    assert bilan.pris == 3
    assert bilan.manques == 2


def test_fenetre_h2_tolerance_deux_minutes(repo):
    creer_course(repo)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()) as part:
        cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=10) + timedelta(minutes=3))
    part.assert_not_called()
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(seconds=30))
    assert {l.cible_minutes for l in _lignes(repo)} == {2}
    assert bilan.pris == 3


def test_erreur_api_retentee_au_passage_suivant(repo):
    creer_course(repo)
    autre = creer_course(repo, numero_course=2)
    maintenant = DEPART - timedelta(minutes=29)

    def panne_sur_c1(d, r, c):
        if c == 1:
            raise ConnectionError("réseau coupé")
        return _participants()(d, r, c)

    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=panne_sur_c1):
        bilan = cotes_instantanees.prendre_instantanes(repo, maintenant)
    assert bilan.erreurs == 1
    # La panne d'une course n'empêche pas les autres.
    assert {l.course_id for l in _lignes(repo)} == {autre.id}

    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()) as part:
        bilan = cotes_instantanees.prendre_instantanes(repo, maintenant + timedelta(seconds=30))
    part.assert_called_once_with(JOUR, 1, 1)
    assert bilan.pris == 3 and bilan.erreurs == 0
    assert len(_lignes(repo)) == 6


def test_partant_inconnu_ignore_et_compte(repo):
    creer_course(repo)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants(nb=4)):
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=29))

    assert bilan.ignores == 1
    assert bilan.pris == 3
    assert {l.num_pmu for l in _lignes(repo)} == {1, 2, 3}
    with Session(repo.engine) as session:
        assert session.query(Participation).count() == 3


def test_non_partant_stocke_cotes_nulles_et_statut_brut(repo):
    creer_course(repo, nb=1)
    non_partant = lambda d, r, c: [make_partant(
        1, statut="NON_PARTANT", cote_direct=None, cote_reference=None,
        cote_direct_le=None, cote_reference_le=None, rapports_bruts={},
    )]
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=non_partant):
        cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=29))

    [ligne] = _lignes(repo)
    assert ligne.statut == "NON_PARTANT"
    assert (ligne.cote_direct, ligne.cote_reference, ligne.cote_direct_le, ligne.cote_reference_le) == (
        None, None, None, None,
    )
    assert ligne.brut is None  # aucune donnée brute : NULL, jamais "{}"


def test_courses_inutilisables_ignorees(repo):
    sans_heure = creer_course(repo, numero_course=1, heure_depart=None)
    autre_source = creer_course(repo, numero_course=2)
    sans_numero = creer_course(repo, numero_course=3)
    with Session(repo.engine) as session:
        session.get(Course, autre_source.id).source = "open_pmu_api"
        session.get(Course, sans_numero.id).numero_reunion = None
        session.commit()

    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()) as part:
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=29))

    part.assert_not_called()
    assert _lignes(repo) == []
    assert (bilan.pris, bilan.manques, bilan.ignores, bilan.erreurs) == (0, 0, 0, 0)
    assert sans_heure.id is not None


def test_jours_passes_jamais_demandes(repo):
    creer_course(repo)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()) as part:
        cotes_instantanees.prendre_instantanes(repo, DEPART + timedelta(days=1) - timedelta(minutes=29))
    part.assert_not_called()


def test_participations_jamais_modifiees(repo):
    creer_course(repo)
    with patch.object(cotes_instantanees.pmu_client, "get_participants",
                      side_effect=_participants(cote_direct=9.9, cote_reference=8.8)):
        cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=29))
    with Session(repo.engine) as session:
        assert {(p.cote_direct, p.cote_reference) for p in session.query(Participation)} == {(4.2, 4.5)}
    assert {l.cote_direct for l in _lignes(repo)} == {9.9}


def test_wal_et_busy_timeout(repo):
    with repo.engine.connect() as conn:
        assert conn.execute(text("PRAGMA journal_mode")).scalar() == "wal"
        assert conn.execute(text("PRAGMA busy_timeout")).scalar() == 30000


def test_table_et_index_unique_crees(repo):
    inspector = inspect(repo.engine)
    index = {i["name"]: i for i in inspector.get_indexes("cotes_instantanees")}
    assert index["uq_cotes_inst_participation_cible"]["unique"]
    assert index["uq_cotes_inst_participation_cible"]["column_names"] == ["participation_id", "cible_minutes"]


def test_migrate_cree_la_table_sur_une_base_existante(repo):
    with repo.engine.begin() as conn:
        conn.execute(text("DROP TABLE cotes_instantanees"))
    repo._migrate()
    index = {i["name"] for i in inspect(repo.engine).get_indexes("cotes_instantanees")}
    assert "uq_cotes_inst_participation_cible" in index


def test_get_participants_expose_les_rapports_bruts(monkeypatch):
    direct = {"rapport": 3.1, "dateRapport": 1762780000000, "favoris": True, "grossePrise": True,
              "nombreIndicateurTendance": 1.5}
    reponse = {"participants": [
        {"numPmu": 1, "nom": "A", "statut": "PARTANT", "dernierRapportDirect": direct,
         "dernierRapportReference": {"rapport": 3.5}},
        {"numPmu": 2, "nom": "B", "statut": "NON_PARTANT"},
    ]}
    monkeypatch.setattr(pmu_client, "_get", lambda _endpoint: reponse)
    a, b = pmu_client.get_participants(JOUR, 1, 1)
    assert a.rapports_bruts == {"dernierRapportDirect": direct, "dernierRapportReference": {"rapport": 3.5}}
    assert a.cote_direct == 3.1 and a.cote_reference == 3.5
    assert b.rapports_bruts == {}


# --- Review loop 1 -------------------------------------------------------------

@pytest.mark.parametrize("cible", [60, 30])
def test_tolerance_cinq_minutes_pour_h60_et_h30(repo, cible):
    creer_course(repo)
    maintenant = DEPART - timedelta(minutes=cible) + timedelta(minutes=4, seconds=30)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        bilan = cotes_instantanees.prendre_instantanes(repo, maintenant)
    assert bilan.pris == 3
    assert {l.cible_minutes for l in _lignes(repo)} == {cible}


def test_h2_ferme_au_depart(repo):
    creer_course(repo)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        cotes_instantanees.prendre_instantanes(repo, DEPART)  # borne incluse
    assert {l.cible_minutes for l in _lignes(repo)} == {2}
    creer_course(repo, numero_course=2)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()) as part:
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART + timedelta(seconds=1))
    part.assert_not_called()
    assert bilan.manques == 4 + 4 - 1  # course 2 : 4 cibles ; course 1 : H-60, H-30, H-10


def test_fenetre_revérifiee_au_retour_de_la_requete(repo):
    creer_course(repo)
    instants = iter([DEPART - timedelta(seconds=10), DEPART + timedelta(seconds=20)])
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        bilan = cotes_instantanees.prendre_instantanes(
            repo, DEPART - timedelta(seconds=30), horloge=lambda: next(instants))
    assert bilan.pris == 0 and bilan.manques == 1 + 3
    assert _lignes(repo) == []


def test_cible_la_plus_urgente_d_abord(repo):
    tot = creer_course(repo, numero_course=1, heure_depart=DEPART + timedelta(minutes=59))  # H-60 due, ferme à +4 min
    tard = creer_course(repo, numero_course=2, heure_depart=DEPART + timedelta(minutes=1))   # H-2 due
    ordre = []

    def participants(d, r, c):
        ordre.append(c)
        return [make_partant(n) for n in range(1, 4)]

    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=participants):
        cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(seconds=30))
    assert ordre == [2, 1]
    assert tot.id != tard.id


def test_reponse_vide_comptee_en_erreur_et_retentee(repo):
    creer_course(repo)
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=lambda d, r, c: []):
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=29))
    assert bilan.pris == 0 and bilan.erreurs == 1
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=28))
    assert bilan.pris == 3


def test_course_apres_minuit_ouverte_la_veille(repo):
    minuit = datetime(2026, 11, 11, 0, 5)
    course = repo.upsert_course(CourseInfo(
        date=JOUR, numero_reunion=9, numero_course=1, hippodrome="DEAUVILLE", pays="FRA",
        libelle="Prix Nuit", discipline="plat", discipline_brute="PLAT", distance=1600.0, allocation=20000.0,
        corde="droite", nb_partants_declares=3, arrivee_definitive=False, heure_depart=minuit,
    ))
    repo.save_partants(course.id, [make_partant(n) for n in range(1, 4)])
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        cotes_instantanees.prendre_instantanes(repo, minuit - timedelta(minutes=29))  # 23:36 la veille
    assert {l.cible_minutes for l in _lignes(repo)} == {30}
    with patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        cotes_instantanees.prendre_instantanes(repo, minuit - timedelta(minutes=1))  # 00:04 le jour même
    assert {l.cible_minutes for l in _lignes(repo)} == {30, 2}


def test_erreur_de_lecture_isolee_par_course(repo):
    creer_course(repo, numero_course=1)
    deuxieme = creer_course(repo, numero_course=2)
    reel = repo.instantanes_pris

    def lecture(course_id):
        if course_id != deuxieme.id:
            raise RuntimeError("database is locked")
        return reel(course_id)

    with patch.object(repo, "instantanes_pris", side_effect=lecture), \
            patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        bilan = cotes_instantanees.prendre_instantanes(repo, DEPART - timedelta(minutes=29))
    assert bilan.erreurs == 1 and bilan.pris == 3


def test_boucle_garde_les_manques_et_survit_aux_erreurs(repo):
    creer_course(repo)
    instants = iter([DEPART - timedelta(minutes=20)] * 3 + [DEPART + timedelta(days=1)] * 2)
    appels = []
    reel = cotes_instantanees.prendre_instantanes

    def passage(repository, maintenant, manques_signales, horloge=None):
        appels.append((id(manques_signales), len(manques_signales)))
        if len(appels) == 2:
            raise RuntimeError("panne")
        return reel(repository, maintenant, manques_signales)

    with patch.object(cotes_instantanees, "prendre_instantanes", side_effect=passage), \
            patch.object(cotes_instantanees.pmu_client, "get_participants", side_effect=_participants()):
        cotes_instantanees.boucle(repo, passages=3, horloge=lambda: next(instants), attendre=lambda _s: None)
    assert len({a[0] for a in appels}) == 1  # le même ensemble à chaque passage
    assert [a[1] for a in appels] == [0, 2, 2]  # H-60 et H-30 manqués, retenus ; la panne n'arrête rien


def test_boucle_oublie_les_manques_au_changement_de_jour(repo):
    jours = iter([DEPART, DEPART + timedelta(days=1)])
    tailles = []

    def passage(repository, maintenant, manques_signales, horloge=None):
        tailles.append(len(manques_signales))
        manques_signales.add((maintenant.day, 0))

    with patch.object(cotes_instantanees, "prendre_instantanes", side_effect=passage):
        cotes_instantanees.boucle(repo, passages=2, horloge=lambda: next(jours), attendre=lambda _s: None)
    assert tailles == [0, 0]


@pytest.mark.parametrize("valeur, attendu", [("abc", 30.0), ("0", 1.0), ("-5", 1.0), ("600", 60.0), ("15", 15.0)])
def test_poll_seconds_valide(monkeypatch, valeur, attendu):
    monkeypatch.setenv("COTES_POLL_SECONDS", valeur)
    assert cotes_instantanees._poll_seconds() == attendu
