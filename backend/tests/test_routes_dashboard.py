import atexit
import os
import tempfile
from datetime import date, datetime

import pytest
from fastapi.testclient import TestClient

from app.api import routes_dashboard
from app.data.pmu_client import CourseInfo, PartantInfo
from app.data.repository import Repository
from app.engine.scoring import HorseAnalysis
from app.main import app

client = TestClient(app)


@pytest.fixture
def repo(monkeypatch):
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_routes_dashboard_")
    os.close(fd)

    def _cleanup() -> None:
        try:
            os.remove(path)
        except OSError:
            pass

    atexit.register(_cleanup)
    repository = Repository(database_url=f"sqlite:///{path}")
    monkeypatch.setattr(routes_dashboard, "repository", repository)
    yield repository
    repository.engine.dispose()
    _cleanup()
    atexit.unregister(_cleanup)


def course_pronostiquee(repo, numero, discipline, gagnant, manques=()):
    depart = datetime(2026, 10, 18, 15, 0)
    course = repo.upsert_course(CourseInfo(
        date=date(2026, 10, 18), numero_reunion=1, numero_course=numero, hippodrome="X", pays="FRA",
        libelle="Prix", discipline=discipline, discipline_brute=discipline.upper(), distance=1600.0,
        allocation=None, corde=None, nb_partants_declares=2, arrivee_definitive=True, heure_depart=depart,
    ))
    partants = [
        PartantInfo(num_pmu=n, nom=f"C{numero}-{n}", age=4, sexe=None, statut="PARTANT", driver_jockey=None,
                    entraineur=None, musique=None, nombre_courses=1, inedit=False, handicap_poids=None,
                    cote_reference=None, cote_direct=None, ordre_arrivee=None, incident=None)
        for n in (1, 2)
    ]
    repo.save_partants(course.id, partants)
    repo.save_prediction_run(
        course.id,
        [HorseAnalysis(nom="a", num_pmu=1, probabilite=0.7, cote=2.0),
         HorseAnalysis(nom="b", num_pmu=2, probabilite=0.3, cote=3.0)],
        "live", datetime(2026, 10, 18, 12, 0), list(manques),
    )
    for p in partants:
        p.ordre_arrivee = 1 if p.num_pmu == gagnant else 2
    repo.update_resultats(course.id, partants, True)


def test_dashboard_data_bilan_global_et_decoupages(repo):
    course_pronostiquee(repo, 1, "plat", gagnant=1)
    course_pronostiquee(repo, 2, "trot", gagnant=2, manques=["historique_absent"])

    response = client.get("/dashboard/data", params={"variante": "live"})

    assert response.status_code == 200
    data = response.json()
    assert data["variante"] == "live"
    assert data["global"]["courses"] == 2
    assert data["global"]["taux_gagnant"] == 0.5
    assert data["global"]["taux_favori"] == 0.5
    assert data["par_discipline"]["plat"]["taux_gagnant"] == 1.0
    assert data["par_discipline"]["trot"]["taux_gagnant"] == 0.0
    assert data["par_qualite"]["completes"]["courses"] == 1
    assert data["par_qualite"]["degradees"]["courses"] == 1
    assert len(data["global"]["calibration"]) == 6


def test_dashboard_data_variante_inconnue_rejetee(repo):
    assert client.get("/dashboard/data", params={"variante": "autre"}).status_code == 422


def test_dashboard_data_sans_pronostic(repo):
    data = client.get("/dashboard/data").json()

    assert data["global"]["courses"] == 0
    assert data["par_discipline"] == {}


def test_dashboard_page_html(repo):
    response = client.get("/dashboard")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert "/dashboard/data" in response.text


def test_dashboard_data_suivi_du_jour(repo):
    course_pronostiquee(repo, 1, "plat", gagnant=1)
    course_pronostiquee(repo, 2, "trot", gagnant=2, manques=["historique_absent"])
    # Une course sans pronostic et une course pronostiquée mais sans arrivée.
    sans_pronostic = repo.upsert_course(CourseInfo(
        date=date(2026, 10, 18), numero_reunion=1, numero_course=3, hippodrome="X", pays="FRA",
        libelle="Prix", discipline="plat", discipline_brute="PLAT", distance=1600.0, allocation=None,
        corde=None, nb_partants_declares=2, arrivee_definitive=False, heure_depart=datetime(2026, 10, 18, 16, 0),
    ))
    en_attente = repo.upsert_course(CourseInfo(
        date=date(2026, 10, 18), numero_reunion=1, numero_course=4, hippodrome="X", pays="FRA",
        libelle="Prix", discipline="plat", discipline_brute="PLAT", distance=1600.0, allocation=None,
        corde=None, nb_partants_declares=2, arrivee_definitive=False, heure_depart=datetime(2026, 10, 18, 17, 0),
    ))
    repo.save_prediction_run(en_attente.id, [HorseAnalysis(nom="a", num_pmu=1, probabilite=0.5)],
                             "live", datetime(2026, 10, 18, 12, 0), [])
    assert sans_pronostic.id

    suivi = client.get("/dashboard/data", params={"jour": "2026-10-18"}).json()["suivi"]

    assert suivi == {"jour": "2026-10-18", "courses": 4, "pronostiquees": 3, "evaluees": 2,
                     "en_attente": 1, "degradees": 1, "pronostics_app": 0, "utilisateurs": 0}


def pronostic_app(repo, numero, installation_id, p1, modifiees):
    course_id = next(c.id for c in repo.list_courses_for_date(date(2026, 10, 18)) if c.numero_course == numero)
    repo.save_prediction_run(
        course_id,
        [HorseAnalysis(nom="a", num_pmu=1, probabilite=p1), HorseAnalysis(nom="b", num_pmu=2, probabilite=1 - p1)],
        "app", datetime(2026, 10, 18, 13, 0), [], installation_id=installation_id, donnees_modifiees=modifiees,
    )


def test_dashboard_data_comparaison_app_contre_automatique(repo):
    course_pronostiquee(repo, 1, "plat", gagnant=2)   # auto : 0.7 sur le 1, perd
    course_pronostiquee(repo, 2, "plat", gagnant=1)   # auto : gagne
    pronostic_app(repo, 1, "u1", 0.2, modifiees=True)    # l'utilisateur vise le 2 : gagne
    pronostic_app(repo, 2, "u2", 0.7, modifiees=False)   # même avis que le moteur : gagne

    data = client.get("/dashboard/data", params={"variante": "app", "jour": "2026-10-18"}).json()

    assert data["global"]["courses"] == 2
    comparaison = data["comparaison_app"]
    assert comparaison["toutes"]["paires"] == 2
    assert comparaison["toutes"]["utilisateurs"] == 2
    assert comparaison["toutes"]["taux_gagnant_app"] == 1.0
    assert comparaison["toutes"]["taux_gagnant_auto"] == 0.5
    assert comparaison["donnees_modifiees"]["paires"] == 1
    assert comparaison["donnees_intactes"]["paires"] == 1
    assert (data["suivi"]["pronostics_app"], data["suivi"]["utilisateurs"]) == (2, 2)
