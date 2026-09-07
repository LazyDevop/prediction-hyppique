"""Tests de couverture pour `jobs/ingest_daily.py` (Story 2.2 — voir
_bmad-output/implementation-artifacts/spec-2-2-ingest-daily-test-coverage.md).

Comme `test_repository.py` (Story 2.1), chaque test construit son propre
`Repository` contre un fichier SQLite temporaire neuf (jamais `:memory:`) :
les effets de bord de persistance sont vérifiés pour de vrai. Seules les
trois fonctions de `pmu_client` appelées par le job (`get_programme`,
`get_participants`, `get_historique`) sont mockées — c'est la frontière
réseau isolée par le pattern adaptateur (AD-1) ; `pmu_client.py` lui-même
n'est pas testé ici (hors périmètre, voir test_pmu_client.py).

Hors périmètre, reporté (voir deferred-work.md pour le détail) : `get_programme`
n'est protégé par aucun try/except dans `ingest_daily.py` (contrairement à
`get_participants`/`get_historique`) — un simple échec réseau y ferait
planter tout `run()`. C'est une trouvaille pertinente pour le produit, pas
seulement un manque de test ; corriger `ingest_daily.py` est hors périmètre
de cette story (lecture seule).
"""

import atexit
import os
import tempfile
from datetime import date, timedelta
from unittest.mock import call, patch

import pytest

from app.data.pmu_client import CourseInfo, PartantInfo, PerformancePassee
from app.data.repository import Repository
from app.jobs import ingest_daily


@pytest.fixture
def repo():
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_ingest_daily_")
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
        date=date(2026, 1, 15),
        numero_reunion=1,
        numero_course=1,
        hippodrome="Vincennes",
        pays="FRA",
        libelle="Prix Test",
        discipline="trot",
        discipline_brute="ATTELE",
        distance=2700.0,
        allocation=20000.0,
        corde="gauche",
        nb_partants_declares=14,
        arrivee_definitive=False,
        heure_depart=None,
    )
    defaults.update(overrides)
    return CourseInfo(**defaults)


def make_partant_info(**overrides) -> PartantInfo:
    defaults = dict(
        num_pmu=5,
        nom="Bucephale",
        age=5,
        sexe="M",
        statut="PARTANT",
        driver_jockey="J. Dupont",
        entraineur="P. Martin",
        musique="1a2a3a",
        nombre_courses=10,
        inedit=False,
        handicap_poids=57.5,
        cote_reference=4.5,
        cote_direct=4.2,
        ordre_arrivee=None,
        incident=None,
        raw={},
    )
    defaults.update(overrides)
    return PartantInfo(**defaults)


def make_performance_passee(**overrides) -> PerformancePassee:
    defaults = dict(
        date=date(2025, 12, 1),
        hippodrome="Enghien",
        discipline="trot",
        allocation=15000.0,
        distance=2650.0,
        nb_participants=16,
        rang=3,
        incident=None,
    )
    defaults.update(overrides)
    return PerformancePassee(**defaults)


# 1. ingest_programme_du_jour : upsert + partants + historique pour chaque course ---

def test_ingest_programme_du_jour_persiste_course_partants_et_historique(repo):
    target_date = date(2026, 4, 1)
    info1 = make_course_info(date=target_date, numero_reunion=1, numero_course=1, hippodrome="Vincennes")
    info2 = make_course_info(date=target_date, numero_reunion=2, numero_course=5, hippodrome="Longchamp")

    def participants_side_effect(d, reunion, course):
        if (reunion, course) == (1, 1):
            return [make_partant_info(num_pmu=7, nom="Alpha")]
        return [make_partant_info(num_pmu=9, nom="Beta")]

    def historique_side_effect(d, reunion, course):
        if (reunion, course) == (1, 1):
            return {7: [make_performance_passee(hippodrome="Enghien")]}
        return {9: [make_performance_passee(hippodrome="Auteuil")]}

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[info1, info2]), \
         patch("app.jobs.ingest_daily.pmu_client.get_participants", side_effect=participants_side_effect), \
         patch("app.jobs.ingest_daily.pmu_client.get_historique", side_effect=historique_side_effect):
        ingest_daily.ingest_programme_du_jour(repo, target_date)

    courses = repo.list_courses_for_date(target_date)
    assert len(courses) == 2

    course1 = next(c for c in courses if c.numero_course == 1)
    course2 = next(c for c in courses if c.numero_course == 5)

    full1 = repo.get_course_by_id(course1.id)
    assert full1.hippodrome == "Vincennes"
    assert len(full1.participations) == 1
    assert full1.participations[0].num_pmu == 7
    assert full1.participations[0].cheval.nom_normalise == "ALPHA"
    assert len(full1.participations[0].cheval.performances_historiques) == 1
    assert full1.participations[0].cheval.performances_historiques[0].hippodrome == "Enghien"

    full2 = repo.get_course_by_id(course2.id)
    assert full2.hippodrome == "Longchamp"
    assert len(full2.participations) == 1
    assert full2.participations[0].num_pmu == 9
    assert full2.participations[0].cheval.nom_normalise == "BETA"
    assert full2.participations[0].cheval.performances_historiques[0].hippodrome == "Auteuil"


# 2. ingest_programme_du_jour : une course en échec n'interrompt pas la boucle ------

def test_ingest_programme_du_jour_echec_partants_est_avale_et_boucle_continue(repo):
    target_date = date(2026, 4, 2)
    info1 = make_course_info(date=target_date, numero_reunion=1, numero_course=1, hippodrome="Vincennes")
    info2 = make_course_info(date=target_date, numero_reunion=1, numero_course=2, hippodrome="Vincennes")

    def participants_side_effect(d, reunion, course):
        if course == 1:
            raise RuntimeError("PMU indisponible")
        return [make_partant_info(num_pmu=3, nom="Gamma")]

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[info1, info2]), \
         patch("app.jobs.ingest_daily.pmu_client.get_participants", side_effect=participants_side_effect), \
         patch("app.jobs.ingest_daily.pmu_client.get_historique",
               return_value={3: [make_performance_passee()]}) as mock_historique:
        ingest_daily.ingest_programme_du_jour(repo, target_date)

    courses = repo.list_courses_for_date(target_date)
    assert len(courses) == 2  # les deux courses sont upsertées malgré l'échec de la 1ère

    course1 = next(c for c in courses if c.numero_course == 1)
    course2 = next(c for c in courses if c.numero_course == 2)

    full1 = repo.get_course_by_id(course1.id)
    assert full1.participations == []  # save_partants jamais atteint pour la course 1

    full2 = repo.get_course_by_id(course2.id)
    assert len(full2.participations) == 1
    assert full2.participations[0].num_pmu == 3
    assert len(full2.participations[0].cheval.performances_historiques) == 1

    # get_historique n'est appelé que pour la course 2 : la course 1 n'atteint
    # jamais cette ligne (l'exception vient de get_participants avant).
    mock_historique.assert_called_once_with(target_date, 1, 2)


def test_ingest_programme_du_jour_echec_historique_persiste_quand_meme_les_partants(repo):
    # get_participants et get_historique partagent le même bloc try/except
    # (ingest_daily.py:18-27) — le test précédent ne fait échouer que
    # get_participants. Ici c'est get_historique qui échoue : les partants,
    # déjà persistés avant cet appel, doivent le rester (pas de transaction
    # qui annulerait tout), et la boucle doit quand même continuer vers la
    # course suivante (blind-hunter + edge-case-hunter, revue de code).
    target_date = date(2026, 4, 3)
    info1 = make_course_info(date=target_date, numero_reunion=1, numero_course=1)
    info2 = make_course_info(date=target_date, numero_reunion=1, numero_course=2)

    def participants_side_effect(d, reunion, course):
        if course == 1:
            return [make_partant_info(num_pmu=9, nom="Delta")]
        return [make_partant_info(num_pmu=11, nom="Epsilon")]

    def historique_side_effect(d, reunion, course):
        if course == 1:
            raise RuntimeError("historique indisponible")
        return {11: [make_performance_passee()]}

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[info1, info2]), \
         patch("app.jobs.ingest_daily.pmu_client.get_participants", side_effect=participants_side_effect), \
         patch("app.jobs.ingest_daily.pmu_client.get_historique", side_effect=historique_side_effect):
        ingest_daily.ingest_programme_du_jour(repo, target_date)

    courses = repo.list_courses_for_date(target_date)
    course1 = next(c for c in courses if c.numero_course == 1)
    course2 = next(c for c in courses if c.numero_course == 2)

    full1 = repo.get_course_by_id(course1.id)
    assert len(full1.participations) == 1  # save_partants déjà exécuté avant l'échec get_historique
    assert full1.participations[0].cheval.performances_historiques == []

    full2 = repo.get_course_by_id(course2.id)
    assert len(full2.participations) == 1
    assert len(full2.participations[0].cheval.performances_historiques) == 1


# 3. ingest_resultats_veille : course sans numero_reunion/numero_course -> skip -----

def test_ingest_resultats_veille_course_sans_numeros_est_ignoree_sans_appel_pmu(repo):
    veille = date(2026, 5, 1)
    course_incomplete = repo.upsert_course(make_course_info(
        date=veille, numero_reunion=None, numero_course=None, hippodrome="Inconnu",
    ))
    course_normale = repo.upsert_course(make_course_info(
        date=veille, numero_reunion=1, numero_course=1, hippodrome="Vincennes",
    ))

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[
        make_course_info(date=veille, numero_reunion=1, numero_course=1, arrivee_definitive=True),
    ]) as mock_get_programme, \
         patch("app.jobs.ingest_daily.pmu_client.get_participants",
               return_value=[make_partant_info(num_pmu=1, ordre_arrivee=1)]) as mock_get_participants:
        ingest_daily.ingest_resultats_veille(repo, veille)

    # Un seul appel PMU au total, et uniquement pour la course complète : si la
    # course sans numéros n'était pas ignorée, get_participants serait appelé
    # une seconde fois (avec reunion/course=None), ce qui ferait échouer ces
    # assertions "called_once".
    mock_get_programme.assert_called_once_with(veille)
    mock_get_participants.assert_called_once_with(veille, 1, 1)

    assert repo.get_course_by_id(course_incomplete.id).finalisee is False


def test_ingest_resultats_veille_course_avec_un_seul_numero_manquant_est_ignoree(repo):
    # Boundary #3 : `numero_reunion is None OR numero_course is None`
    # (ingest_daily.py:37). Le test précédent ne fixe que le cas où les DEUX
    # sont None — une régression vers `and` s'y comporterait identiquement.
    # Ici un seul des deux champs est absent (blind-hunter, revue de code).
    veille = date(2026, 5, 2)
    course_partiel = repo.upsert_course(make_course_info(
        date=veille, numero_reunion=1, numero_course=None, hippodrome="Partiel",
    ))

    with patch("app.jobs.ingest_daily.pmu_client.get_programme") as mock_get_programme, \
         patch("app.jobs.ingest_daily.pmu_client.get_participants") as mock_get_participants:
        ingest_daily.ingest_resultats_veille(repo, veille)

    mock_get_programme.assert_not_called()
    mock_get_participants.assert_not_called()
    assert repo.get_course_by_id(course_partiel.id).finalisee is False


# 4. ingest_resultats_veille : get_programme appelé au plus une fois par date -------

def test_ingest_resultats_veille_get_programme_appele_une_fois_par_date_partagee(repo):
    veille = date(2026, 6, 1)
    repo.upsert_course(make_course_info(date=veille, numero_reunion=1, numero_course=1))
    repo.upsert_course(make_course_info(date=veille, numero_reunion=1, numero_course=2))

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[]) as mock_get_programme, \
         patch("app.jobs.ingest_daily.pmu_client.get_participants",
               return_value=[make_partant_info()]) as mock_get_participants:
        ingest_daily.ingest_resultats_veille(repo, veille)

    mock_get_programme.assert_called_once_with(veille)
    assert mock_get_participants.call_count == 2  # les deux courses sont bien traitées


def test_ingest_resultats_veille_get_programme_une_fois_par_date_distincte(repo):
    # Le test précédent n'utilise qu'UNE seule date : il ne peut pas
    # distinguer un cache correctement indexé par date d'un bug qui ne
    # fetch qu'une fois au total (ex. un booléen au lieu d'un dict) —
    # blind-hunter + edge-case-hunter, revue de code. Deux dates distinctes
    # ici, chacune doit déclencher son propre appel, une seule fois.
    veille = date(2026, 6, 4)
    date_a = date(2026, 6, 1)
    date_b = date(2026, 6, 2)
    repo.upsert_course(make_course_info(date=date_a, numero_reunion=1, numero_course=1))
    repo.upsert_course(make_course_info(date=date_a, numero_reunion=1, numero_course=2))
    repo.upsert_course(make_course_info(date=date_b, numero_reunion=1, numero_course=1))

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[]) as mock_get_programme, \
         patch("app.jobs.ingest_daily.pmu_client.get_participants", return_value=[make_partant_info()]):
        ingest_daily.ingest_resultats_veille(repo, veille)

    # Tri des appels (pas d'ORDER BY côté repository : l'ordre d'itération
    # des courses n'est pas garanti) — seul le CONTENU compte ici : chaque
    # date exactement une fois.
    appels = sorted(c.args for c in mock_get_programme.call_args_list)
    assert appels == [(date_a,), (date_b,)]


# 5. ingest_resultats_veille : arrivee_definitive lu depuis l'entrée programme -----

def test_ingest_resultats_veille_arrivee_definitive_selon_correspondance_programme(repo):
    veille = date(2026, 6, 2)
    course_matchee = repo.upsert_course(make_course_info(date=veille, numero_reunion=1, numero_course=1))
    course_sans_match = repo.upsert_course(make_course_info(date=veille, numero_reunion=1, numero_course=2))

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[
        # Seule une entrée pour R1C1 est retournée : R1C2 n'a aucune
        # correspondance dans le programme mis en cache.
        make_course_info(date=veille, numero_reunion=1, numero_course=1, arrivee_definitive=True),
    ]), \
         patch("app.jobs.ingest_daily.pmu_client.get_participants", return_value=[make_partant_info()]):
        ingest_daily.ingest_resultats_veille(repo, veille)

    assert repo.get_course_by_id(course_matchee.id).finalisee is True
    assert repo.get_course_by_id(course_sans_match.id).finalisee is False


def test_ingest_resultats_veille_arrivee_definitive_ne_matche_pas_sur_numero_course_seul(repo):
    # Gap confirmé par la revue verification-gap : le test précédent utilise
    # le même numero_reunion (1) pour ses deux courses, donc il ne peut pas
    # détecter une régression qui ferait matcher `any(...)` sur numero_course
    # seul (ingest_daily.py:48-51) sans comparer aussi numero_reunion. Ici,
    # même numero_course (5) mais numero_reunion différent : seule R1C5 doit
    # être finalisée.
    veille = date(2026, 6, 3)
    course_r1 = repo.upsert_course(make_course_info(date=veille, numero_reunion=1, numero_course=5))
    course_r2 = repo.upsert_course(make_course_info(date=veille, numero_reunion=2, numero_course=5))

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[
        make_course_info(date=veille, numero_reunion=1, numero_course=5, arrivee_definitive=True),
    ]), \
         patch("app.jobs.ingest_daily.pmu_client.get_participants", return_value=[make_partant_info()]):
        ingest_daily.ingest_resultats_veille(repo, veille)

    assert repo.get_course_by_id(course_r1.id).finalisee is True
    assert repo.get_course_by_id(course_r2.id).finalisee is False


# 6. ingest_resultats_veille : échec get_participants -> course ignorée, boucle continue

def test_ingest_resultats_veille_echec_participants_est_ignore_et_boucle_continue(repo):
    veille = date(2026, 7, 1)
    course1 = repo.upsert_course(make_course_info(date=veille, numero_reunion=1, numero_course=1))
    repo.save_partants(course1.id, [make_partant_info(num_pmu=1, nom="Cheval Un", ordre_arrivee=None)])
    course2 = repo.upsert_course(make_course_info(date=veille, numero_reunion=1, numero_course=2))
    repo.save_partants(course2.id, [make_partant_info(num_pmu=2, nom="Cheval Deux", ordre_arrivee=None)])

    def participants_side_effect(d, reunion, course):
        if course == 1:
            raise RuntimeError("PMU indisponible")
        return [make_partant_info(num_pmu=2, nom="Cheval Deux", ordre_arrivee=4, incident=None)]

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[]), \
         patch("app.jobs.ingest_daily.pmu_client.get_participants", side_effect=participants_side_effect), \
         patch.object(repo, "update_resultats", wraps=repo.update_resultats) as spy_update:
        ingest_daily.ingest_resultats_veille(repo, veille)

    # update_resultats n'est appelé qu'une fois, et uniquement pour la course 2 :
    # la course 1 (get_participants en échec) ne doit jamais l'atteindre.
    spy_update.assert_called_once()
    assert spy_update.call_args[0][0] == course2.id

    full1 = repo.get_course_by_id(course1.id)
    assert full1.finalisee is False
    assert full1.participations[0].rang_arrivee is None  # inchangé

    full2 = repo.get_course_by_id(course2.id)
    assert full2.participations[0].rang_arrivee == 4


# 7. run : ingest_programme_du_jour pour today..today+days_ahead, puis veille ------

def test_run_appelle_get_programme_pour_today_et_days_ahead_puis_ingest_resultats_veille(repo):
    today = date(2026, 3, 10)

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[]) as mock_get_programme, \
         patch("app.jobs.ingest_daily.pmu_client.get_participants") as mock_get_participants, \
         patch("app.jobs.ingest_daily.pmu_client.get_historique") as mock_get_historique:
        ingest_daily.run(repo, today, days_ahead=2)

    # Séquence exacte des dates : today, today+1, today+2 (ingest_programme_du_jour),
    # aucun appel supplémentaire par ingest_resultats_veille(today-1) puisque la
    # base est vide (aucune course non finalisée à re-vérifier).
    assert mock_get_programme.call_args_list == [
        call(date(2026, 3, 10)),
        call(date(2026, 3, 11)),
        call(date(2026, 3, 12)),
    ]
    mock_get_participants.assert_not_called()
    mock_get_historique.assert_not_called()


def test_run_avec_days_ahead_par_defaut_ingere_today_et_today_plus_1(repo):
    # Le test précédent ne passe jamais `days_ahead` implicitement — toujours
    # explicite (=2). `main()` (ingest_daily.py:62-70) appelle `run()` sans
    # argument quand `--days-ahead` est omis : la valeur par défaut (=1)
    # n'était couverte par aucun test (edge-case-hunter, revue de code).
    today = date(2026, 8, 1)

    with patch("app.jobs.ingest_daily.pmu_client.get_programme", return_value=[]) as mock_get_programme, \
         patch("app.jobs.ingest_daily.pmu_client.get_participants"), \
         patch("app.jobs.ingest_daily.pmu_client.get_historique"):
        ingest_daily.run(repo, today)

    assert mock_get_programme.call_args_list == [
        call(date(2026, 8, 1)),
        call(date(2026, 8, 2)),
    ]
