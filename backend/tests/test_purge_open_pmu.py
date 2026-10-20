"""Tests de `jobs/purge_open_pmu.py` : seules les lignes open-pmu et les
chevaux qu'elles seules faisaient exister disparaissent."""

import os
import tempfile
from datetime import date

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.data.models import Cheval, Course, Participation, PerformanceHistorique
from app.data.repository import Repository
from app.jobs.purge_open_pmu import purger


@pytest.fixture
def repo():
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_purge_open_pmu_")
    os.close(fd)
    repository = Repository(database_url=f"sqlite:///{path}")
    yield repository
    repository.engine.dispose()
    os.remove(path)


def _backfill(repo, nom, jour):
    """Ancienne ligne open-pmu, écrite directement : plus aucun code
    applicatif n'écrit cette source."""
    with Session(repo.engine) as session:
        cheval = repo.upsert_cheval(session, nom)
        session.add(PerformanceHistorique(
            cheval_id=cheval.id, date_course=jour, hippodrome="VINCENNES", discipline="trot",
            distance=2700, nb_participants=14, rang=1, source="open_pmu_api",
        ))
        session.commit()


@pytest.fixture
def base(repo):
    # SEUL : connu uniquement par open-pmu. MIXTE : aussi une ligne pmu.
    # PARTANT : aussi une participation. VIDE : aucune donnée, jamais touché
    # par open-pmu, ne doit pas être pris pour un orphelin.
    _backfill(repo, "SEUL", date(2020, 1, 5))
    _backfill(repo, "MIXTE", date(2020, 1, 5))
    _backfill(repo, "PARTANT", date(2020, 1, 5))
    with Session(repo.engine) as session:
        ids = {c.nom_normalise: c.id for c in session.scalars(select(Cheval))}
        session.add(PerformanceHistorique(
            cheval_id=ids["MIXTE"], date_course=date(2021, 3, 1), hippodrome="CAEN", source="pmu",
        ))
        session.add(Cheval(nom_normalise="VIDE"))
        course = Course(date=date(2026, 10, 18), hippodrome="VINCENNES", discipline="trot")
        session.add(course)
        session.flush()
        session.add(Participation(course_id=course.id, cheval_id=ids["PARTANT"]))
        session.commit()
    return repo


def test_simulation_ne_supprime_rien(base):
    bilan = purger(base)

    assert (bilan.lignes, bilan.chevaux_orphelins, bilan.execute) == (3, 1, False)
    with Session(base.engine) as session:
        assert len(session.scalars(select(PerformanceHistorique)).all()) == 4
        assert len(session.scalars(select(Cheval)).all()) == 4


def test_execution_supprime_lignes_open_pmu_et_orphelins(base):
    bilan = purger(base, executer=True)

    assert (bilan.lignes, bilan.chevaux_orphelins, bilan.execute) == (3, 1, True)
    with Session(base.engine) as session:
        sources = [p.source for p in session.scalars(select(PerformanceHistorique))]
        noms = sorted(c.nom_normalise for c in session.scalars(select(Cheval)))
    assert sources == ["pmu"]
    assert noms == ["MIXTE", "PARTANT", "VIDE"]


def test_seconde_execution_sans_effet(base):
    purger(base, executer=True)

    bilan = purger(base, executer=True)

    assert (bilan.lignes, bilan.chevaux_orphelins) == (0, 0)
