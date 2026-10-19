import atexit
import json
import os
import tempfile
from datetime import date, datetime

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session, selectinload

from app.api import routes_pronostics
from app.data.models import PredictionRun
from app.data.pmu_client import CourseInfo
from app.data.repository import Repository
from app.main import app

client = TestClient(app)

DEPART = datetime(2026, 10, 19, 15, 0)


@pytest.fixture
def repo(monkeypatch):
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_routes_pronostics_")
    os.close(fd)

    def _cleanup() -> None:
        try:
            os.remove(path)
        except OSError:
            pass

    atexit.register(_cleanup)
    repository = Repository(database_url=f"sqlite:///{path}")
    monkeypatch.setattr(routes_pronostics, "repository", repository)
    yield repository
    repository.engine.dispose()
    _cleanup()
    atexit.unregister(_cleanup)


@pytest.fixture
def horloge(monkeypatch):
    def regler(instant):
        monkeypatch.setattr(routes_pronostics, "maintenant", lambda: instant)
    return regler


def ajouter_course(repo, terrain="Bon souple"):
    return repo.upsert_course(CourseInfo(
        date=date(2026, 10, 19), numero_reunion=1, numero_course=1, hippodrome="Deauville", pays="FRA",
        libelle="Prix", discipline="plat", discipline_brute="PLAT", distance=1600.0, allocation=None,
        corde=None, nb_partants_declares=2, arrivee_definitive=False, heure_depart=DEPART, terrain=terrain,
    ))


def pronostic(course_id, **surcharges):
    corps = {
        "course_id": course_id,
        "installation_id": "3f9a1c2e7b4d4e0f",
        "chevaux": [{"num_pmu": 1, "probabilite": 0.62, "cote": 2.5}, {"num_pmu": 2, "probabilite": 0.38}],
        "parametres": {"contraste": 3},
        "reglages_par_defaut": True,
        "donnees_modifiees": False,
        "terrain": 0.97,  # "Bon souple"
    }
    corps.update(surcharges)
    return corps


def runs(repo):
    with Session(repo.engine) as session:
        return session.query(PredictionRun).options(selectinload(PredictionRun.chevaux)).all()


def test_pronostic_avant_depart_enregistre_et_horodate_par_le_serveur(repo, horloge):
    course = ajouter_course(repo)
    horloge(datetime(2026, 10, 19, 12, 0))

    response = client.post("/pronostics", json=pronostic(course.id))

    assert response.status_code == 201
    [run] = runs(repo)
    assert (run.variante, run.cree_le, run.installation_id) == ("app", datetime(2026, 10, 19, 12, 0), "3f9a1c2e7b4d4e0f")
    assert (run.donnees_modifiees, run.reglages_par_defaut, run.terrain_modifie) == (False, True, False)
    assert json.loads(run.parametres) == {"contraste": 3}
    assert [(c.num_pmu, c.probabilite, c.cote) for c in sorted(run.chevaux, key=lambda c: c.num_pmu)] == [
        (1, 0.62, 2.5), (2, 0.38, None),
    ]


def test_pronostic_terrain_different_de_la_mesure_est_signale(repo, horloge):
    course = ajouter_course(repo)
    horloge(datetime(2026, 10, 19, 12, 0))

    client.post("/pronostics", json=pronostic(course.id, terrain=0.88))  # "Très souple"

    assert runs(repo)[0].terrain_modifie is True


def test_pronostic_apres_le_depart_refuse(repo, horloge):
    course = ajouter_course(repo)
    horloge(datetime(2026, 10, 19, 15, 1))

    response = client.post("/pronostics", json=pronostic(course.id))

    assert response.status_code == 409
    assert runs(repo) == []


def test_pronostic_course_inconnue(repo, horloge):
    horloge(datetime(2026, 10, 19, 12, 0))

    assert client.post("/pronostics", json=pronostic(999)).status_code == 404


@pytest.mark.parametrize("surcharge", [
    {"chevaux": []},
    {"chevaux": [{"num_pmu": 1, "probabilite": 1.5}]},
    {"installation_id": "court"},
])
def test_pronostic_invalide_rejete(repo, horloge, surcharge):
    course = ajouter_course(repo)
    horloge(datetime(2026, 10, 19, 12, 0))

    assert client.post("/pronostics", json=pronostic(course.id, **surcharge)).status_code == 422
    assert runs(repo) == []
