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
