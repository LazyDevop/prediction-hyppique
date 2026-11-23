"""Déclenchement de l'ingestion quotidienne (app/jobs/scheduler.py)."""

from datetime import date, datetime

import pytest

from app.jobs import scheduler

JOUR = date(2026, 11, 23)


def a(heure, minute=0):
    return datetime(2026, 11, 23, heure, minute)


@pytest.fixture(autouse=True)
def heure_ingestion(monkeypatch):
    monkeypatch.setattr(scheduler, "RUN_HOUR", 6)


def test_pas_avant_l_heure():
    assert not scheduler.ingestion_due(a(5, 59), date(2026, 11, 22), None)


def test_a_l_heure():
    assert scheduler.ingestion_due(a(6), date(2026, 11, 22), None)


def test_rattrapee_au_reveil_apres_l_heure():
    # PC en veille de 5 h à 9 h : l'ingestion part au réveil.
    assert scheduler.ingestion_due(a(9, 12), date(2026, 11, 22), a(5, 0))


def test_une_seule_fois_par_jour():
    assert not scheduler.ingestion_due(a(14), JOUR, a(6))


def test_echec_retente_apres_le_delai():
    hier = date(2026, 11, 22)
    assert not scheduler.ingestion_due(a(6, 14), hier, a(6, 0))
    assert scheduler.ingestion_due(a(6, 15), hier, a(6, 0))
