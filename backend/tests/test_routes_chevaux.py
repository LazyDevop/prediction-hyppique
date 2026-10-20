"""Tests de POST /chevaux/{id}/backfill : rafraîchissement de l'historique
depuis PMU turfinfo (performances-detaillees de la dernière participation),
une ligne par cas de la matrice I/O du spec spec-backfill-cheval-turfinfo."""

import atexit
import os
import tempfile
from datetime import date, datetime

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.api import routes_chevaux
from app.data.models import Cheval, PerformanceHistorique
from app.data.pmu_client import CourseInfo, PartantInfo, PerformancePassee
from app.data.repository import Repository
from app.main import app

client = TestClient(app)


@pytest.fixture
def repo(monkeypatch):
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_routes_chevaux_")
    os.close(fd)

    def _cleanup() -> None:
        try:
            os.remove(path)
        except OSError:
            pass

    atexit.register(_cleanup)
    repository = Repository(database_url=f"sqlite:///{path}")
    monkeypatch.setattr(routes_chevaux, "repository", repository)
    yield repository
    repository.engine.dispose()
    _cleanup()
    atexit.unregister(_cleanup)


@pytest.fixture
def appels(monkeypatch):
    """Remplace pmu_client.get_historique ; `reponse` est renvoyée (ou levée
    si c'est une exception), chaque appel est enregistré."""
    etat = {"appels": [], "reponse": {}}

    def faux_get_historique(target_date, reunion, course):
        etat["appels"].append((target_date, reunion, course))
        if isinstance(etat["reponse"], Exception):
            raise etat["reponse"]
        return etat["reponse"]

    monkeypatch.setattr(routes_chevaux.pmu_client, "get_historique", faux_get_historique)
    return etat


def ajouter_participation(repo, jour, reunion, numero, num_pmu=5, nom="Bucephale"):
    course = repo.upsert_course(CourseInfo(
        date=jour, numero_reunion=reunion, numero_course=numero, hippodrome="Vincennes", pays="FRA",
        libelle="Prix Test", discipline="trot", discipline_brute="ATTELE", distance=2700.0,
        allocation=20000.0, corde="gauche", nb_partants_declares=14, arrivee_definitive=False,
        heure_depart=datetime.combine(jour, datetime.min.time()),
    ))
    repo.save_partants(course.id, [PartantInfo(
        num_pmu=num_pmu, nom=nom, age=5, sexe="M", statut="PARTANT", driver_jockey="J. Dupont",
        entraineur="P. Martin", musique="1a", nombre_courses=10, inedit=False, handicap_poids=None,
        cote_reference=None, cote_direct=None, ordre_arrivee=None, incident=None, raw={},
    )])
    return course


def cheval_id(repo, nom="BUCEPHALE"):
    with Session(repo.engine) as session:
        return session.query(Cheval).filter(Cheval.nom_normalise == nom).one().id


def perf(jour, hippodrome, rang, rang_impute=False):
    return PerformancePassee(
        date=jour, hippodrome=hippodrome, discipline="trot", allocation=15000.0, distance=2700.0,
        nb_participants=14, rang=rang, rang_impute=rang_impute, terrain=None, incident=None,
    )


def test_cheval_avec_participation_rafraichit_et_renvoie_tout(repo, appels):
    course = ajouter_participation(repo, date(2026, 10, 18), 1, 4)
    appels["reponse"] = {
        5: [perf(date(2026, 9, 1), "Caen", 11, rang_impute=True), perf(date(2026, 9, 20), "Enghien", 2)],
        # Autre partant de la même course : sans participation en base, ignoré.
        8: [perf(date(2026, 9, 5), "Caen", 1)],
    }

    reponse = client.post(f"/chevaux/{cheval_id(repo)}/backfill")

    assert reponse.status_code == 200
    assert appels["appels"] == [(date(2026, 10, 18), 1, 4)]
    corps = reponse.json()
    assert [(p["date_course"], p["hippodrome"], p["rang"], p["rang_impute"]) for p in corps] == [
        ("2026-09-20", "Enghien", 2, False),
        ("2026-09-01", "Caen", 11, True),
    ]
    with Session(repo.engine) as session:
        lignes = session.query(PerformanceHistorique).all()
    assert {l.source for l in lignes} == {"pmu"}
    participation_id = repo.get_course_by_id(course.id).participations[0].id
    assert [l.participation_id for l in lignes] == [participation_id, participation_id]


def test_plusieurs_participations_seule_la_plus_recente_est_interrogee(repo, appels):
    ajouter_participation(repo, date(2026, 10, 18), 3, 7)
    ajouter_participation(repo, date(2026, 10, 1), 2, 5)

    reponse = client.post(f"/chevaux/{cheval_id(repo)}/backfill")

    assert reponse.status_code == 200
    assert appels["appels"] == [(date(2026, 10, 18), 3, 7)]


def test_sans_participation_aucun_appel_et_historique_en_base(repo, appels):
    with Session(repo.engine) as session:
        cheval = Cheval(nom_normalise="SANS COURSE")
        session.add(cheval)
        session.flush()
        session.add(PerformanceHistorique(
            cheval_id=cheval.id, date_course=date(2025, 5, 1), hippodrome="Caen", rang=3, source="pmu",
        ))
        session.commit()
        identifiant = cheval.id

    reponse = client.post(f"/chevaux/{identifiant}/backfill")

    assert reponse.status_code == 200
    assert appels["appels"] == []
    assert [(p["date_course"], p["rang"]) for p in reponse.json()] == [("2025-05-01", 3)]


def test_echec_api_renvoie_200_avec_historique_inchange(repo, appels, caplog):
    ajouter_participation(repo, date(2026, 10, 18), 1, 4)
    identifiant = cheval_id(repo)
    with Session(repo.engine) as session:
        session.add(PerformanceHistorique(
            cheval_id=identifiant, date_course=date(2025, 5, 1), hippodrome="Caen", rang=3, source="pmu",
        ))
        session.commit()
    appels["reponse"] = RuntimeError("turfinfo indisponible")

    reponse = client.post(f"/chevaux/{identifiant}/backfill")

    assert reponse.status_code == 200
    assert appels["appels"] == [(date(2026, 10, 18), 1, 4)]
    assert [(p["date_course"], p["rang"]) for p in reponse.json()] == [("2025-05-01", 3)]
    assert any(r.exc_info for r in caplog.records if r.name == routes_chevaux.logger.name)


def test_cheval_inconnu_404(repo, appels):
    reponse = client.post("/chevaux/999/backfill")

    assert reponse.status_code == 404
    assert reponse.json()["detail"] == "Cheval introuvable"
    assert appels["appels"] == []
