"""Bilan des pronostics ML face au marché (app/jobs/bilan_pronostics.py)."""

import math
import os
from datetime import date, datetime

import pytest
from sqlalchemy.orm import Session

from app.data.models import Cheval, CoteInstantanee, Course, Participation
from app.data.repository import Repository
from app.jobs import bilan_pronostics as bp

JOUR = date(2026, 11, 15)


@pytest.fixture
def repo(tmp_path):
    repository = Repository(database_url=f"sqlite:///{tmp_path / 'bilan.db'}")
    yield repository
    repository.engine.dispose()


def course(repo, jour=JOUR, reunion=1, numero=1, rangs=None):
    """Trois partants n°1 à 3 ; rangs : {num_pmu: rang}."""
    rangs = rangs or {}
    with Session(repo.engine) as session:
        c = Course(date=jour, numero_reunion=reunion, numero_course=numero, hippodrome="PAU",
                   discipline="plat", source="pmu", heure_depart=datetime.combine(jour, datetime.min.time()))
        session.add(c)
        session.flush()
        for num in (1, 2, 3):
            cheval = Cheval(nom_normalise=f"C{c.id}-{num}")
            session.add(cheval)
            session.flush()
            session.add(Participation(course_id=c.id, cheval_id=cheval.id, num_pmu=num, rang_arrivee=rangs.get(num)))
        session.commit()
        return c.id


def instantane(repo, course_id, cible, cotes):
    with Session(repo.engine) as session:
        for pid, num in session.query(Participation.id, Participation.num_pmu).filter_by(course_id=course_id):
            session.add(CoteInstantanee(course_id=course_id, participation_id=pid, num_pmu=num, cible_minutes=cible,
                                        pris_le=datetime(2026, 11, 15, 12), cote_direct=cotes.get(num), statut="PARTANT"))
        session.commit()


def pronostic(repo, course_id, horizon, probas, fondamentales=None):
    fondamentales = fondamentales or probas
    return repo.enregistrer_pronostic_ml(
        course_id, horizon, datetime(2026, 11, 15, 11), [
            {"num_pmu": n, "probabilite": p, "probabilite_fondamentale": fondamentales[n]} for n, p in probas.items()
        ], [], {},
    )


PROBAS = {1: 0.5, 2: 0.3, 3: 0.2}
COTES = {1: 4.0, 2: 2.0, 3: 4.0}  # marché normalisé : 0.25, 0.5, 0.25


def test_score_modele_fondamental_marche(repo):
    cid = course(repo, rangs={1: 1, 2: 2, 3: 3})
    instantane(repo, cid, 10, COTES)
    pronostic(repo, cid, "h10", PROBAS, {1: 0.4, 2: 0.4, 3: 0.2})
    [ligne] = bp.calculer(repo, JOUR, JOUR).lignes["h10"]
    assert ligne.ll_modele == pytest.approx(-math.log(0.5))
    assert ligne.ll_fondamental == pytest.approx(-math.log(0.4))
    assert ligne.ll_marche == pytest.approx(-math.log(0.25))
    assert (ligne.numero_modele, ligne.numero_marche, ligne.gagnant) == (1, 2, 1)
    assert ligne.modele_juste and not ligne.marche_juste


def test_matin_compare_au_marche_h60(repo):
    cid = course(repo, rangs={2: 1})
    instantane(repo, cid, 60, COTES)
    pronostic(repo, cid, "matin", PROBAS)
    [ligne] = bp.calculer(repo, JOUR, JOUR).lignes["matin"]
    assert ligne.ll_marche == pytest.approx(-math.log(0.5))


def test_course_sans_arrivee_ou_ex_aequo_ecartee_et_comptee(repo):
    sans = course(repo, numero=1)
    ex_aequo = course(repo, numero=2, rangs={1: 1, 2: 1})
    for cid in (sans, ex_aequo):
        instantane(repo, cid, 10, COTES)
        pronostic(repo, cid, "h10", PROBAS)
    bilan = bp.calculer(repo, JOUR, JOUR)
    assert bilan.sans_arrivee == 2
    assert bilan.lignes["h10"] == []


@pytest.mark.parametrize("cotes", [None, {1: None, 2: 2.0, 3: 4.0}, {1: 1.0, 2: 2.0, 3: 4.0}])
def test_horizon_sans_instantane_ou_cote_gagnant_invalide_ecarte(repo, cotes):
    cid = course(repo, rangs={1: 1})
    if cotes is not None:
        instantane(repo, cid, 10, cotes)
    pronostic(repo, cid, "h10", PROBAS)
    assert bp.calculer(repo, JOUR, JOUR).lignes["h10"] == []


def test_periode_bornee(repo):
    dedans = course(repo, rangs={1: 1})
    dehors = course(repo, jour=date(2026, 11, 13), rangs={1: 1})
    for cid in (dedans, dehors):
        instantane(repo, cid, 30, COTES)
        pronostic(repo, cid, "h30", PROBAS)
    assert len(bp.calculer(repo, JOUR, JOUR).lignes["h30"]) == 1
    assert bp.premier_jour(repo) == date(2026, 11, 13)


def test_intervalle_bootstrap():
    assert all(math.isnan(x) for x in bp.intervalle([0.1]))
    bas, haut = bp.intervalle([0.1, -0.1] * 50)
    assert bas < 0 < haut
    assert bp.intervalle([0.2] * 10) == (pytest.approx(0.2), pytest.approx(0.2))


def test_rapport_markdown(repo):
    cid = course(repo, rangs={1: 1})
    instantane(repo, cid, 10, COTES)
    pronostic(repo, cid, "h10", PROBAS)
    texte = bp.rapport_quotidien(repo, JOUR)
    assert "## Veille (2026-11-15 → 2026-11-15)" in texte
    assert "## Cumul" in texte
    assert "| h10 | 1 | 0.693 |" in texte
    assert "| matin | 0 |" in texte
    assert "Désaccords à h10" in texte and "| 2026-11-15 R1C1 | 1 | 2 | 1 |" in texte


def test_ecrire_si_du(repo, tmp_path):
    dossier = str(tmp_path / "bilans")
    cid = course(repo)  # arrivée pas encore ingérée
    instantane(repo, cid, 10, COTES)
    pronostic(repo, cid, "h10", PROBAS)
    lendemain = datetime(2026, 11, 16, 9, 59)
    assert bp.ecrire_si_du(repo, lendemain, 10, dossier) is None  # avant l'heure
    assert bp.ecrire_si_du(repo, lendemain.replace(hour=11), 10, dossier) is None  # attend les arrivées
    chemin = bp.ecrire_si_du(repo, lendemain.replace(hour=14), 10, dossier)  # écrit quand même
    assert chemin == os.path.join(dossier, "bilan_2026-11-15.md")
    assert "1 course(s) écartée(s)" in open(chemin, encoding="utf-8").read()
    assert bp.ecrire_si_du(repo, lendemain.replace(hour=15), 10, dossier) is None  # jamais réécrit


def test_ecrire_si_du_des_que_les_arrivees_sont_la(repo, tmp_path):
    cid = course(repo, rangs={1: 1})
    instantane(repo, cid, 10, COTES)
    pronostic(repo, cid, "h10", PROBAS)
    assert bp.ecrire_si_du(repo, datetime(2026, 11, 16, 10), 10, str(tmp_path)) is not None


def test_cli(repo, monkeypatch, tmp_path, capsys):
    cid = course(repo, rangs={1: 1})
    instantane(repo, cid, 10, COTES)
    pronostic(repo, cid, "h10", PROBAS)
    monkeypatch.setattr(bp, "Repository", lambda: repo)
    assert bp.main(["--fin", "2026-11-15", "--jours", "1", "--sortie", str(tmp_path)]) == 0
    assert "| h10 | 1 |" in capsys.readouterr().out
    assert (tmp_path / "bilan_2026-11-15.md").exists()
    with pytest.raises(SystemExit):
        bp.parse_args(["--debut", "2026-11-14", "--jours", "2"])
