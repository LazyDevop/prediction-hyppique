import atexit
import json
import os
import tempfile
from datetime import date, datetime, time

import pytest
from sqlalchemy.orm import Session

from app.data.models import PredictionRun
from app.data.pmu_client import CourseInfo, PartantInfo, PerformancePassee
from app.data.repository import Repository
from app.jobs import predict


@pytest.fixture
def repo():
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_predict_")
    os.close(fd)

    def _cleanup() -> None:
        try:
            os.remove(path)
        except OSError:
            pass

    atexit.register(_cleanup)
    repository = Repository(database_url=f"sqlite:///{path}")
    yield repository
    repository.engine.dispose()
    _cleanup()
    atexit.unregister(_cleanup)


JOUR = date(2026, 10, 18)


def ajouter_course(repo, numero, heure, discipline="plat", terrain="Bon", partants=None):
    course = repo.upsert_course(CourseInfo(
        date=JOUR, numero_reunion=1, numero_course=numero, hippodrome="ParisLongchamp", pays="FRA",
        libelle=f"Prix {numero}", discipline=discipline, discipline_brute=discipline.upper(), distance=1600.0,
        allocation=20000.0, corde=None, nb_partants_declares=2, arrivee_definitive=False,
        heure_depart=datetime.combine(JOUR, heure) if heure else None, terrain=terrain,
    ))
    partants = partants if partants is not None else [(1, False, 2), (2, False, 5)]
    repo.save_partants(course.id, [
        PartantInfo(num_pmu=num, nom=f"Cheval {numero}-{num}", age=4, sexe=None, statut="PARTANT",
                    driver_jockey=None, entraineur=None, musique=None, nombre_courses=3, inedit=inedit,
                    handicap_poids=None, cote_reference=3.0 + num, cote_direct=None, ordre_arrivee=None,
                    incident=None)
        for num, inedit, _ in partants
    ])
    repo.save_historique(course.id, {
        num: [PerformancePassee(date=date(2026, 9, 1), hippodrome="Deauville", discipline=discipline,
                                allocation=None, distance=1600.0, nb_participants=10, rang=rang, incident=None,
                                terrain="Bon")]
        for num, inedit, rang in partants if rang is not None
    })
    return course


def runs(repo):
    with Session(repo.engine) as session:
        return [(r.course_id, r.variante, r.cree_le, r.degradee, json.loads(r.manques))
                for r in session.query(PredictionRun).order_by(PredictionRun.id)]


def test_predire_courses_a_venir_ne_pronostique_que_les_courses_pas_encore_parties(repo):
    passee = ajouter_course(repo, 1, time(11, 0))
    a_venir = ajouter_course(repo, 2, time(15, 0))
    ajouter_course(repo, 3, None)
    maintenant = datetime.combine(JOUR, time(12, 0))

    predict.predire_courses_a_venir(repo, maintenant)

    assert runs(repo) == [(a_venir.id, "live", maintenant, False, [])]
    assert passee.id not in [r[0] for r in runs(repo)]


def test_predire_course_enregistre_des_probabilites_pour_chaque_partant(repo):
    course = ajouter_course(repo, 1, time(15, 0))

    predict.predire_course(repo, course, "live", datetime.combine(JOUR, time(12, 0)))

    [predite] = repo.courses_evaluables("live")
    assert [c.num_pmu for c in predite.chevaux] == [1, 2]
    assert predite.chevaux[0].probabilite > predite.chevaux[1].probabilite  # 2e vs 5e
    assert predite.chevaux[0].cote == 4.0


@pytest.mark.parametrize("discipline, terrain, partants, manques", [
    ("plat", None, [(1, False, 2), (2, False, 5)], ["terrain_du_jour"]),
    ("trot", None, [(1, False, 2), (2, False, 5)], []),  # pas de terrain au trot
    ("plat", "Bon", [(1, False, 2), (2, False, None)], ["historique_absent"]),
    ("plat", "Bon", [(1, False, 2), (2, True, None)], []),  # un inédit n'a pas d'historique
])
def test_predire_course_signale_les_donnees_manquantes(repo, discipline, terrain, partants, manques):
    course = ajouter_course(repo, 1, time(15, 0), discipline=discipline, terrain=terrain, partants=partants)

    predict.predire_course(repo, course, "live", datetime.combine(JOUR, time(12, 0)))

    assert runs(repo)[0][3:] == (bool(manques), manques)


def test_rejouer_pronostique_toutes_les_courses_du_jour_en_variante_rejeu(repo):
    ajouter_course(repo, 1, time(11, 0))
    ajouter_course(repo, 2, time(15, 0))
    maintenant = datetime(2026, 10, 19, 9, 0)

    predict.rejouer(repo, JOUR, maintenant)

    assert [(r[1], r[2]) for r in runs(repo)] == [("rejeu", maintenant), ("rejeu", maintenant)]


def test_rejouer_n_utilise_que_les_performances_anterieures_a_la_course(repo):
    # L'historique ingéré après la course contient la course elle-même : la
    # voir dans le rejeu reviendrait à pronostiquer en connaissant l'arrivée.
    course = ajouter_course(repo, 1, time(15, 0), partants=[(1, False, 9), (2, False, 9)])
    repo.save_historique(course.id, {
        1: [PerformancePassee(date=JOUR, hippodrome="ParisLongchamp", discipline="plat", allocation=None,
                              distance=1600.0, nb_participants=10, rang=1, incident=None, terrain="Bon")],
    })

    predict.rejouer(repo, JOUR, datetime(2026, 10, 19, 9, 0))

    [predite] = repo.courses_evaluables("rejeu")
    assert predite.chevaux[0].probabilite == pytest.approx(predite.chevaux[1].probabilite)
