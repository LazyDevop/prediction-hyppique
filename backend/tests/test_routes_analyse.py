"""Regression pour le bug corrige (voir deferred-work.md) : les outsiders
virtuels (num_pmu=None) qu'analyse_course ajoute pour completer le champ de
calcul (cahier des charges 7.8) ne doivent jamais fuiter dans la reponse de
l'API /analyse."""

import atexit
import os
import tempfile

_tmp_db_fd, _tmp_db_path = tempfile.mkstemp(suffix=".db", prefix="test_routes_analyse_")
os.close(_tmp_db_fd)


def _cleanup_tmp_db() -> None:
    try:
        os.remove(_tmp_db_path)
    except OSError:
        pass


atexit.register(_cleanup_tmp_db)
os.environ.setdefault("DATABASE_URL", f"sqlite:///{_tmp_db_path}")

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_analyse_ne_renvoie_jamais_d_outsiders_virtuels():
    payload = {
        "chevaux": [
            {
                "nom": f"Cheval {i}",
                "num_pmu": i,
                "age": 5,
                "poids": 60,
                "cote": 3.0,
                "inedit": False,
                "performances": [],
            }
            for i in range(1, 6)
        ],
        "distance": 1600,
        "terrain": 1.0,
        "niveau": 3.0,
        "nb_partants_course": 14,
    }
    response = client.post("/analyse", json=payload)
    assert response.status_code == 200

    resultats = response.json()["resultats"]
    assert len(resultats) == 5
    assert all(r["num_pmu"] is not None for r in resultats)
