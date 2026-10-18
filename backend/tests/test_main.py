"""Seule protection de non-régression sur le câblage de `app.main` : rien
d'autre ne pin les trois routeurs (courses/chevaux/analyse) inclus sans
préfixe.

Un fichier SQLite temporaire (pas `sqlite:///:memory:`) : chaque routeur
instancie son propre `Repository()` (donc sa propre connexion), et
`TestClient` exécute les endpoints dans un thread de threadpool différent
du thread d'import — un `:memory:` non partagé donnerait une base vide et
fraîche par connexion/thread ("no such table"). Un fichier réel est visible
depuis n'importe quel thread ; il est supprimé après la session de test."""

import atexit
import os
import tempfile

_tmp_db_fd, _tmp_db_path = tempfile.mkstemp(suffix=".db", prefix="test_main_")
os.close(_tmp_db_fd)


def _cleanup_tmp_db() -> None:
    # Best-effort : sur Windows, sqlite3 peut encore tenir le fichier
    # verrouillé à la sortie du process (connexion jamais fermée
    # explicitement par Repository) — un échec de suppression est sans
    # conséquence, le fichier vit dans le dossier temp du système.
    try:
        os.remove(_tmp_db_path)
    except OSError:
        pass


atexit.register(_cleanup_tmp_db)
os.environ.setdefault("DATABASE_URL", f"sqlite:///{_tmp_db_path}")

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_routes_courses_est_bien_cablee():
    # Aucune course en base -> liste vide, 200 : jamais un 404 de routage.
    # Preuve que routes_courses.router est bien inclus sans préfixe (le
    # postman_collection.json pointe vers /courses nu).
    response = client.get("/courses", params={"date": "2026-08-17"})
    assert response.status_code == 200
    assert response.json() == []


def test_routes_analyse_est_bien_cablee():
    # Corps vide -> 400 "Aucun cheval fourni" (erreur métier de
    # routes_analyse.analyse), jamais un 404 de routage. Preuve que
    # routes_analyse.router est bien inclus sans préfixe.
    response = client.post("/analyse", json={})
    assert response.status_code == 400


def test_routes_chevaux_est_bien_cablee():
    # Cheval inexistant -> 404 MÉTIER avec le message explicite de
    # routes_chevaux.backfill_cheval, à distinguer d'un 404 de routage
    # FastAPI par défaut (dont le detail serait "Not Found") : ce test
    # prouve donc que la route existe bien plutôt que de se contenter du
    # code 404, ambigu à lui seul.
    response = client.post("/chevaux/999999/backfill")
    assert response.status_code == 404
    assert response.json()["detail"] == "Cheval introuvable"


def test_partants_expose_le_marqueur_de_rang_impute():
    from datetime import date

    from app.api import routes_courses
    from app.data.pmu_client import CourseInfo, PartantInfo, PerformancePassee

    repo = routes_courses.repository
    course = repo.upsert_course(CourseInfo(
        date=date(2099, 1, 2), numero_reunion=1, numero_course=1, hippodrome="Deauville",
        pays="FRA", libelle="Prix Test", discipline="plat", discipline_brute="PLAT",
        distance=1600.0, allocation=20000.0, corde=None, nb_partants_declares=1,
        arrivee_definitive=False, heure_depart=None,
    ))
    repo.save_partants(course.id, [PartantInfo(
        num_pmu=1, nom="Rang Impute Test", age=4, sexe=None, statut="PARTANT", driver_jockey=None,
        entraineur=None, musique=None, nombre_courses=1, inedit=False, handicap_poids=None,
        cote_reference=None, cote_direct=None, ordre_arrivee=None, incident=None,
    )])
    repo.save_historique(course.id, {1: [PerformancePassee(
        date=date(2098, 12, 1), hippodrome="Deauville", discipline="plat", allocation=None,
        distance=1600.0, nb_participants=16, rang=11, incident=None, rang_impute=True,
    )]})

    response = client.get(f"/courses/{course.id}/partants")

    assert response.status_code == 200
    perf = response.json()[0]["performances"][0]
    assert (perf["rang"], perf["rang_impute"]) == (11, True)
