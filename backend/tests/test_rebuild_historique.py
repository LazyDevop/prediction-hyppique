"""Tests de `jobs/rebuild_historique.py` : une fonction par ligne de la
matrice I/O du spec (spec-rebuild-historique-turfinfo.md). Même style que
test_ingest_daily.py : un `Repository` sur un fichier SQLite temporaire
neuf, `pmu_client` mocké à la frontière du module."""

import atexit
import os
import tempfile
from datetime import date, datetime, timedelta
from unittest.mock import patch

import pytest
from sqlalchemy.orm import Session

from app.data.models import Course, Participation, PerformanceHistorique
from app.data.pmu_client import CourseInfo, PartantInfo, PerformancePassee
from app.data.repository import Repository
from app.jobs import rebuild_historique

JOUR = date(2026, 3, 1)


@pytest.fixture
def repo():
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_rebuild_historique_")
    os.close(fd)

    def _cleanup() -> None:
        try:
            os.remove(path)
        except OSError:
            pass

    atexit.register(_cleanup)
    repository = Repository(database_url=f"sqlite:///{path}")
    yield repository
    _cleanup()
    atexit.unregister(_cleanup)


def make_course_info(**overrides) -> CourseInfo:
    defaults = dict(
        date=JOUR,
        numero_reunion=1,
        numero_course=1,
        hippodrome="CAGNES/MER",
        pays="FRA",
        libelle="Prix Test",
        discipline="plat",
        discipline_brute="PLAT",
        distance=1600.0,
        allocation=20000.0,
        corde="gauche",
        nb_partants_declares=4,
        arrivee_definitive=True,
        heure_depart=None,
        terrain="Bon",
    )
    defaults.update(overrides)
    return CourseInfo(**defaults)


def make_partant_info(**overrides) -> PartantInfo:
    defaults = dict(
        num_pmu=1,
        nom="Alpha",
        age=5,
        sexe="M",
        statut="PARTANT",
        driver_jockey="J. Dupont",
        entraineur="P. Martin",
        musique="1p2p",
        nombre_courses=10,
        inedit=False,
        handicap_poids=57.5,
        cote_reference=4.5,
        cote_direct=4.2,
        ordre_arrivee=None,
        incident=None,
        raw={},
        cote_reference_le=datetime(2026, 3, 1, 12, 30),
        cote_direct_le=datetime(2026, 3, 1, 13, 1),
    )
    defaults.update(overrides)
    return PartantInfo(**defaults)


def partants_types(prefixe: str):
    """2 classés, un ARRETE, un NON_PARTANT."""
    return [
        make_partant_info(num_pmu=1, nom=f"{prefixe} Un", ordre_arrivee=1),
        make_partant_info(num_pmu=2, nom=f"{prefixe} Deux", ordre_arrivee=2),
        make_partant_info(num_pmu=3, nom=f"{prefixe} Trois", incident="ARRETE"),
        make_partant_info(num_pmu=4, nom=f"{prefixe} Quatre", statut="NON_PARTANT"),
    ]


def _historique(repo):
    with Session(repo.engine) as session:
        return session.query(PerformanceHistorique).all()


def _courses(repo):
    with Session(repo.engine) as session:
        return session.query(Course).order_by(Course.numero_reunion, Course.numero_course).all()


def _participations(repo):
    with Session(repo.engine) as session:
        return session.query(Participation).all()


def _programme_jour():
    # get_programme filtre déjà la France : la course étrangère n'arrive
    # jamais jusqu'au job (filtre "FRA" par défaut, voir test_pmu_client).
    return [
        make_course_info(numero_reunion=1, numero_course=1),
        make_course_info(numero_reunion=2, numero_course=3, hippodrome="BORELY"),
    ]


def _participants(d, reunion, course):
    return partants_types(f"R{reunion}C{course}")


def test_nouveau_jour_stocke_courses_participations_et_historique(repo):
    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()) as prog, \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants) as part:
        bilan = rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    prog.assert_called_once_with(JOUR)
    assert part.call_count == 2
    courses = _courses(repo)
    assert len(courses) == 2
    assert all(c.finalisee for c in courses)

    participations = _participations(repo)
    assert len(participations) == 8
    assert all(p.cote_reference == 4.5 and p.cote_direct == 4.2 for p in participations)
    assert all(p.cote_reference_le == datetime(2026, 3, 1, 12, 30) for p in participations)
    assert all(p.cote_direct_le == datetime(2026, 3, 1, 13, 1) for p in participations)

    lignes = _historique(repo)
    assert len(lignes) == 6  # 3 partants effectifs x 2 courses
    assert bilan.lignes_historique == 6
    assert bilan.courses_recuperees == 2
    assert all(l.nb_participants == 3 for l in lignes)
    assert all(l.source == "pmu" and l.rang_impute is False for l in lignes)
    assert all(l.participation_id is not None for l in lignes)
    assert {(l.rang, l.incident) for l in lignes if l.hippodrome == "CAGNES/MER"} == {
        (1, None), (2, None), (None, "A"),
    }
    premiere = next(l for l in lignes if l.rang == 1 and l.hippodrome == "CAGNES/MER")
    assert (premiere.date_course, premiere.discipline, premiere.allocation, premiere.distance, premiere.terrain) == (
        JOUR, "plat", 20000.0, 1600.0, "Bon",
    )


def test_relance_jour_deja_fait_ne_redemande_rien(repo):
    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants):
        rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()) as prog, \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants) as part:
        bilan = rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    prog.assert_called_once()
    part.assert_not_called()
    assert bilan.courses_sautees == 2
    assert len(_participations(repo)) == 8
    assert len(_historique(repo)) == 6


def test_jour_interrompu_ne_reprend_que_la_course_manquante(repo):
    programme = _programme_jour()
    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=programme[:1]), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants):
        rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=programme), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants) as part:
        rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    part.assert_called_once_with(JOUR, 2, 3)
    assert len(_courses(repo)) == 2
    assert len(_historique(repo)) == 6


def test_arrivee_non_definitive_stocke_sans_historique(repo):
    info = make_course_info(arrivee_definitive=False)
    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=[info]), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants):
        rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    courses = _courses(repo)
    assert len(courses) == 1 and courses[0].finalisee
    assert len(_participations(repo)) == 4
    assert _historique(repo) == []


def test_ligne_existante_le_meme_jour_saute_la_ligne_derivee(repo):
    # Le cheval a déjà sa course du jour, nommée par performances-detaillees.
    course_ulterieure = repo.upsert_course(make_course_info(date=JOUR + timedelta(days=5), arrivee_definitive=False))
    alpha = make_partant_info(num_pmu=1, nom="R1C1 Un")
    repo.save_partants(course_ulterieure.id, [alpha])
    repo.save_historique(course_ulterieure.id, {1: [PerformancePassee(
        date=JOUR, hippodrome="CAGNES-SUR-MER", discipline="plat", allocation=20000.0,
        distance=1600.0, nb_participants=3, rang=1, incident=None,
    )]})

    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()[:1]), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants):
        bilan = rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    lignes_alpha = [l for l in _historique(repo) if l.rang == 1]
    assert [l.hippodrome for l in lignes_alpha] == ["CAGNES-SUR-MER"]
    assert bilan.lignes_historique == 2


def test_ingestion_apres_reconstruction_remplace_la_ligne_du_jour(repo):
    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()[:1]), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants):
        rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    # Plus tard, l'ingestion quotidienne d'une autre course du même cheval
    # ramène cette même course sous le nom de performances-detaillees.
    course_suivante = repo.upsert_course(make_course_info(date=JOUR + timedelta(days=10), numero_course=7))
    repo.save_partants(course_suivante.id, [make_partant_info(num_pmu=5, nom="R1C1 Un")])
    repo.save_historique(course_suivante.id, {5: [PerformancePassee(
        date=JOUR, hippodrome="CAGNES-SUR-MER", discipline="plat", allocation=20000.0,
        distance=1600.0, nb_participants=3, rang=1, incident=None,
    )]})

    with Session(repo.engine) as session:
        lignes = session.query(PerformanceHistorique).join(
            Participation, Participation.cheval_id == PerformanceHistorique.cheval_id
        ).filter(Participation.num_pmu == 5).all()
    assert [(l.date_course, l.hippodrome) for l in lignes] == [(JOUR, "CAGNES-SUR-MER")]
    assert len(_historique(repo)) == 3


def test_erreur_api_sur_une_course_n_arrete_pas_les_autres(repo, caplog):
    def participants(d, reunion, course):
        if reunion == 1:
            raise RuntimeError("HTTP 500")
        return _participants(d, reunion, course)

    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=participants):
        bilan = rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    assert bilan.courses_en_echec == 1 and bilan.courses_recuperees == 1
    assert "Echec reconstruction R1C1" in caplog.text
    assert not repo.course_complete(JOUR, 1, 1)
    assert repo.course_complete(JOUR, 2, 3)
    assert all(c.finalisee for c in _courses(repo))  # seule R2C3 est stockée
    assert [c.numero_reunion for c in _courses(repo)] == [2]


def test_erreur_api_sur_un_jour_passe_au_jour_suivant(repo, caplog):
    lendemain = JOUR + timedelta(days=1)

    def programme(d):
        if d == JOUR:
            raise RuntimeError("timeout")
        return [make_course_info(date=d)]

    with patch.object(rebuild_historique.pmu_client, "get_programme", side_effect=programme), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants):
        bilan = rebuild_historique.rebuild_plage(repo, JOUR, lendemain)

    assert bilan.jours == 2 and bilan.jours_en_echec == 1
    assert "Echec du programme" in caplog.text
    assert [c.date for c in _courses(repo)] == [lendemain]


@pytest.mark.parametrize("debut, fin", [
    ("2026-10-01", "2026-10-19"),  # la veille
    ("2026-10-01", "2026-10-25"),  # le futur
    ("2026-10-10", "2026-10-05"),  # fin avant début
])
def test_dates_invalides_erreur_cli_sans_requete(debut, fin):
    with patch.object(rebuild_historique.pmu_client, "get_programme") as prog, \
         patch.object(rebuild_historique.pmu_client, "get_participants") as part, \
         pytest.raises(SystemExit) as excinfo:
        rebuild_historique.parse_args(["--date-debut", debut, "--date-fin", fin], today=date(2026, 10, 20))
    assert excinfo.value.code == 2
    prog.assert_not_called()
    part.assert_not_called()


def test_dates_valides_jusqu_a_l_avant_veille():
    args = rebuild_historique.parse_args(
        ["--date-debut", "2026-10-01", "--date-fin", "2026-10-18"], today=date(2026, 10, 20)
    )
    assert (args.date_debut, args.date_fin) == (date(2026, 10, 1), date(2026, 10, 18))


def test_course_sans_numero_comptee_en_echec_sans_requete(repo, caplog):
    programme = [make_course_info(numero_course=None), make_course_info(numero_reunion=2, numero_course=3)]

    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=programme), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants) as part:
        bilan = rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    assert (bilan.courses_en_echec, bilan.courses_recuperees) == (1, 1)
    assert part.call_count == 1


@pytest.mark.parametrize("echec, code", [(False, 0), (True, 1)])
def test_main_code_de_sortie_selon_les_echecs(monkeypatch, repo, echec, code):
    monkeypatch.setattr(rebuild_historique, "Repository", lambda: repo)
    monkeypatch.setattr(rebuild_historique, "parse_args", lambda argv: type("A", (), {"date_debut": JOUR, "date_fin": JOUR, "sans_rejeu": True})())

    def participants(d, reunion, course):
        if echec:
            raise RuntimeError("HTTP 500")
        return _participants(d, reunion, course)

    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()), \
         patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=participants):
        assert rebuild_historique.main([]) == code


def test_jour_recupere_est_rejoue_puis_visible_en_rejeu(repo):
    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()),          patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants):
        bilan = rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    assert bilan.jours_rejoues == 1
    assert {c.course_id for c in repo.courses_evaluables("rejeu")} == {c.id for c in _courses(repo)}


def test_jour_deja_complet_n_est_pas_rejoue(repo):
    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()),          patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants):
        rebuild_historique.rebuild_plage(repo, JOUR, JOUR, rejouer=False)
        with patch.object(rebuild_historique.predict, "rejouer") as rejeu:
            bilan = rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    rejeu.assert_not_called()
    assert bilan.jours_rejoues == 0


def test_echec_du_rejeu_n_arrete_pas_la_reconstruction(repo, caplog):
    with patch.object(rebuild_historique.pmu_client, "get_programme", return_value=_programme_jour()),          patch.object(rebuild_historique.pmu_client, "get_participants", side_effect=_participants),          patch.object(rebuild_historique.predict, "rejouer", side_effect=RuntimeError("moteur")):
        bilan = rebuild_historique.rebuild_plage(repo, JOUR, JOUR)

    assert bilan.courses_recuperees == 2 and bilan.jours_rejoues == 0
    assert "Echec du rejeu" in caplog.text
