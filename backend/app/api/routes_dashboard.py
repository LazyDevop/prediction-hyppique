"""Tableau de bord pronostics vs résultats : page HTML et ses données."""

from dataclasses import asdict
from datetime import date
from pathlib import Path
from typing import Literal, Optional

from fastapi import APIRouter
from fastapi.responses import FileResponse

from app.data.repository import Repository
from app.engine.evaluation import agreger, comparer, evaluer_course

router = APIRouter()
repository = Repository()

PAGE = Path(__file__).resolve().parent.parent / "static" / "dashboard.html"


def _evaluations(variante: str):
    return [e for e in map(evaluer_course, repository.courses_evaluables(variante)) if e is not None]


@router.get("/dashboard/data")
def dashboard_data(variante: Literal["live", "rejeu", "app"] = "live", jour: Optional[date] = None):
    evaluations = _evaluations(variante)
    app = evaluations if variante == "app" else _evaluations("app")
    auto = evaluations if variante == "live" else _evaluations("live")
    disciplines = sorted({e.discipline for e in evaluations})
    return {
        "variante": variante,
        "suivi": repository.suivi_du_jour(jour or date.today()),
        "pronostics_du_jour": repository.pronostics_du_jour(jour or date.today(), variante),
        "global": asdict(agreger(evaluations)),
        "par_discipline": {d: asdict(agreger([e for e in evaluations if e.discipline == d])) for d in disciplines},
        "par_qualite": {
            "completes": asdict(agreger([e for e in evaluations if not e.degradee])),
            "degradees": asdict(agreger([e for e in evaluations if e.degradee])),
        },
        # Toujours sur les mêmes courses : pronostic de l'utilisateur contre
        # celui du moteur automatique, selon qu'il a modifié les données.
        "comparaison_app": {
            "toutes": asdict(comparer(app, auto)),
            "donnees_modifiees": asdict(comparer([e for e in app if e.donnees_modifiees], auto)),
            "donnees_intactes": asdict(comparer([e for e in app if not e.donnees_modifiees], auto)),
        },
    }


@router.get("/dashboard", include_in_schema=False)
def dashboard_page():
    return FileResponse(PAGE, media_type="text/html")
