"""Tests de couverture pour `repository.py` (Story 2.1 — voir
_bmad-output/implementation-artifacts/spec-2-1-repository-test-coverage.md).

Chaque test construit son propre `Repository` contre un fichier SQLite
temporaire neuf (jamais `:memory:`, jamais partagé entre fonctions de test) :
même raisonnement que `test_main.py` — le pattern de session de `Repository`
doit rester visible quel que soit le thread qui le sollicite — mais poussé
plus loin ici pour garder chaque test indépendant et order-proof (Boundaries
du spec).

Portée non couverte, assumée (Boundaries du spec) : `Repository._migrate()`
n'est pas testée — ses chemins ALTER TABLE défensifs nécessiteraient de
fabriquer un fichier SQLite pré-migration, plus coûteux à mettre en place que
la valeur qu'il ajoute ici. `import_course` (stub `pass`) n'a rien à tester.
Reporté, pas oublié (voir aussi deferred-work.md pour les branches plus
etroites laissees de cote apres la revue : succes/echec de participation
absente dans save_historique/update_resultats, update_resultats(False),
plusieurs performances en un seul appel, champs non asserted de
save_partants/ajouter_performance_historique_backfill, appel sur un
course_id inexistant).
"""

import atexit
import os
import tempfile
from datetime import date, datetime

import pytest
from sqlalchemy.orm import Session

from app.data.models import Cheval, Course, PerformanceHistorique
from app.data.pmu_client import CourseInfo, PartantInfo, PerformancePassee
from app.data.repository import Repository
from app.engine.constants import terrain_coefficient


@pytest.fixture
def repo():
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_repository_")
    os.close(fd)

    def _cleanup() -> None:
        # Best-effort : sur Windows, sqlite3 peut garder le fichier verrouillé
        # tant que la connexion n'est pas explicitement fermée par Repository
        # (voir test_main.py) — un échec de suppression est sans conséquence.
        try:
            os.remove(path)
        except OSError:
            pass

    atexit.register(_cleanup)
    repository = Repository(database_url=f"sqlite:///{path}")
    yield repository
    _cleanup()
    # Le nettoyage explicite ci-dessus vient de tourner : desenregistrer
    # evite d'accumuler un handler atexit par test sur toute la duree d'une
    # suite (chacun referencant un fichier deja supprime) - trouvaille de
    # revue, sans consequence fonctionnelle mais inutile.
    atexit.unregister(_cleanup)


def make_course_info(**overrides) -> CourseInfo:
    defaults = dict(
        date=date(2026, 1, 15),
        numero_reunion=1,
        numero_course=3,
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
        terrain=None,
    )
    defaults.update(overrides)
    return PerformancePassee(**defaults)


# 1. upsert_course : crée, puis met à jour sans dupliquer -------------------

def test_upsert_course_meme_cle_met_a_jour_sans_dupliquer(repo):
    course1 = repo.upsert_course(make_course_info(allocation=20000.0))
    course2 = repo.upsert_course(make_course_info(
        allocation=99999.0, libelle="Prix Mis A Jour", hippodrome="Enghien",
        discipline="plat", distance=1600.0, corde="droite",
        nb_partants_declares=16, heure_depart=None,
    ))

    assert course1.id == course2.id
    toutes = repo.list_courses_for_date(date(2026, 1, 15))
    assert len(toutes) == 1
    # repository.py:155-162 réécrit ces 8 champs à chaque appel — vérifier
    # seulement `allocation` laisserait passer une régression sur n'importe
    # lequel des 7 autres sans qu'aucun test n'échoue (revue de code).
    course = toutes[0]
    assert course.allocation == 99999.0
    assert course.libelle == "Prix Mis A Jour"
    assert course.hippodrome == "Enghien"
    assert course.discipline == "plat"
    assert course.distance == 1600.0
    assert course.corde == "droite"
    assert course.nb_partants == 16


# 2. upsert_cheval : matché par nom_normalise, réutilisé malgré casse/espaces

def test_upsert_course_terrain_du_jour_mis_a_jour_mais_jamais_efface(repo):
    course = repo.upsert_course(make_course_info(terrain=None))
    assert course.terrain is None

    course = repo.upsert_course(make_course_info(terrain="Bon souple"))
    assert course.terrain == "Bon souple"

    # Une ré-ingestion sans mesure (ex. réponse partielle) ne doit pas
    # effacer une mesure déjà obtenue ; une nouvelle mesure la remplace.
    course = repo.upsert_course(make_course_info(terrain=None))
    assert course.terrain == "Bon souple"
    course = repo.upsert_course(make_course_info(terrain="Souple"))
    assert course.terrain == "Souple"


def test_upsert_cheval_reutilise_par_nom_normalise(repo):
    with Session(repo.engine) as session:
        cheval1 = repo.upsert_cheval(session, "Bucéphale")
        session.commit()
        cheval1_id = cheval1.id

    with Session(repo.engine) as session:
        cheval2 = repo.upsert_cheval(session, "  bucéphale  ")
        session.commit()
        assert cheval2.id == cheval1_id
        assert cheval2.nom_normalise == "BUCÉPHALE"


# 3. save_partants : même (course_id, cheval_id) met à jour sans dupliquer --

def test_save_partants_meme_cle_met_a_jour_sans_dupliquer(repo):
    course = repo.upsert_course(make_course_info())
    repo.save_partants(course.id, [make_partant_info(cote_reference=4.5)])
    repo.save_partants(course.id, [make_partant_info(cote_reference=2.1)])

    full_course = repo.get_course_by_id(course.id)
    assert len(full_course.participations) == 1
    assert full_course.participations[0].cote_reference == 2.1


def test_save_partants_meme_cheval_deux_courses_identite_partagee_participations_distinctes(repo):
    # cahier backend §6.2 : num_pmu n'est pas un identifiant stable
    # inter-courses, upsert_cheval matche par nom_normalise — un même cheval
    # inscrit dans deux courses doit partager une seule ligne Cheval tout en
    # produisant deux Participation indépendantes (pas une seule réutilisée
    # à tort, pas deux Cheval dupliqués).
    course_a = repo.upsert_course(make_course_info(date=date(2026, 4, 1), numero_reunion=1, numero_course=1))
    course_b = repo.upsert_course(make_course_info(date=date(2026, 4, 2), numero_reunion=1, numero_course=2))

    repo.save_partants(course_a.id, [make_partant_info(num_pmu=3, nom="Bucephale")])
    repo.save_partants(course_b.id, [make_partant_info(num_pmu=11, nom="Bucephale")])

    with Session(repo.engine) as session:
        chevaux = session.query(Cheval).filter(Cheval.nom_normalise == "BUCEPHALE").all()
        assert len(chevaux) == 1
        cheval_id = chevaux[0].id

    full_a = repo.get_course_by_id(course_a.id)
    full_b = repo.get_course_by_id(course_b.id)
    assert full_a.participations[0].cheval_id == cheval_id
    assert full_b.participations[0].cheval_id == cheval_id
    assert full_a.participations[0].id != full_b.participations[0].id
    assert full_a.participations[0].num_pmu == 3
    assert full_b.participations[0].num_pmu == 11


# 4. save_historique : source="pmu" écrase toujours un conflit du backfill --

def test_save_historique_source_pmu_ecrase_toujours(repo):
    course = repo.upsert_course(make_course_info())
    repo.save_partants(course.id, [make_partant_info(num_pmu=5, nom="Bucephale")])

    perf_date = date(2025, 11, 1)
    hippodrome = "Enghien"

    inserted = repo.ajouter_performance_historique_backfill(
        nom_cheval="Bucephale",
        date_course=perf_date,
        hippodrome=hippodrome,
        discipline="trot",
        allocation=10000.0,
        distance=2600.0,
        nb_participants=12,
        rang=7,
        incident=None,
    )
    assert inserted is True

    performance_pmu = make_performance_passee(
        date=perf_date, hippodrome=hippodrome, allocation=25000.0, rang=1,
    )
    repo.save_historique(course.id, {5: [performance_pmu]})

    with Session(repo.engine) as session:
        cheval = session.query(Cheval).filter(Cheval.nom_normalise == "BUCEPHALE").one()
        lignes = session.query(PerformanceHistorique).filter(
            PerformanceHistorique.cheval_id == cheval.id,
            PerformanceHistorique.date_course == perf_date,
            PerformanceHistorique.hippodrome == hippodrome,
        ).all()

    assert len(lignes) == 1
    ligne = lignes[0]
    assert ligne.source == "pmu"
    assert ligne.rang == 1
    assert ligne.allocation == 25000.0


def test_save_historique_persiste_le_terrain(repo):
    course = repo.upsert_course(make_course_info())
    repo.save_partants(course.id, [make_partant_info(num_pmu=5, nom="Bucephale")])

    repo.save_historique(course.id, {5: [make_performance_passee(terrain="Bon souple")]})

    with Session(repo.engine) as session:
        ligne = session.query(PerformanceHistorique).one()
    assert ligne.terrain == "Bon souple"

    horses = repo.get_horses_for_course(repo.get_course_by_id(course.id))
    assert horses[0].performances[0].terrain == terrain_coefficient("Bon souple")


def test_save_historique_persiste_le_rang_impute_et_son_marqueur(repo):
    course = repo.upsert_course(make_course_info())
    repo.save_partants(course.id, [make_partant_info(num_pmu=5, nom="Bucephale")])

    repo.save_historique(course.id, {5: [
        make_performance_passee(date=date(2025, 12, 1), rang=11, rang_impute=True),
        make_performance_passee(date=date(2025, 11, 1), rang=2),
    ]})

    with Session(repo.engine) as session:
        lignes = session.query(PerformanceHistorique).order_by(PerformanceHistorique.date_course).all()
    assert [(l.rang, l.rang_impute) for l in lignes] == [(2, False), (11, True)]


def test_save_historique_num_pmu_sans_participation_correspondante_est_ignore(repo):
    # repository.py:232-234 : si le num_pmu de l'historique ne correspond à
    # aucune participation de la course (feuille de départ désynchronisée du
    # retour PMU), la ligne est ignorée sans lever - un num_pmu orphelin ne
    # doit ni planter ni écrire de ligne PerformanceHistorique.
    course = repo.upsert_course(make_course_info())
    repo.save_partants(course.id, [make_partant_info(num_pmu=5, nom="Bucephale")])

    num_pmu_orphelin = 999
    repo.save_historique(course.id, {num_pmu_orphelin: [make_performance_passee()]})

    with Session(repo.engine) as session:
        assert session.query(PerformanceHistorique).count() == 0


# 5. ajouter_performance_historique_backfill : ne jamais écraser -----------

def test_backfill_ne_jamais_ecraser_ligne_existante(repo):
    args = dict(
        nom_cheval="Bucephale",
        date_course=date(2025, 10, 1),
        hippodrome="Longchamp",
        discipline="plat",
        allocation=10000.0,
        distance=1600.0,
        nb_participants=14,
        rang=5,
        incident=None,
    )
    first = repo.ajouter_performance_historique_backfill(**args)
    assert first is True

    args_maj = dict(args, allocation=99999.0, rang=1)
    second = repo.ajouter_performance_historique_backfill(**args_maj)
    assert second is False

    with Session(repo.engine) as session:
        cheval = session.query(Cheval).filter(Cheval.nom_normalise == "BUCEPHALE").one()
        lignes = session.query(PerformanceHistorique).filter(
            PerformanceHistorique.cheval_id == cheval.id
        ).all()

    assert len(lignes) == 1
    assert lignes[0].allocation == 10000.0
    assert lignes[0].rang == 5


# 6. get_horses_for_course : tri le plus récent d'abord, terrain, niveau ---

def test_get_horses_for_course_tri_terrain_et_niveau(repo):
    course = repo.upsert_course(make_course_info(date=date(2026, 2, 1)))
    repo.save_partants(course.id, [make_partant_info(num_pmu=7, nom="Etoile Filante")])

    full_course = repo.get_course_by_id(course.id)
    cheval_id = full_course.participations[0].cheval_id

    # save_historique ne stocke que des libellés déjà normalisés : insertion
    # directe via l'ORM pour exercer aussi un libellé non reconnu en base
    # (setup, pas le code sous test).
    with Session(repo.engine) as session:
        session.add_all([
            PerformanceHistorique(
                cheval_id=cheval_id, date_course=date(2025, 9, 1), hippodrome="A",
                terrain="Bon", nb_participants=10, rang=2, source="pmu",
            ),
            PerformanceHistorique(
                cheval_id=cheval_id, date_course=date(2025, 10, 1), hippodrome="B",
                terrain="Piste Mystère", nb_participants=10, rang=3, source="pmu",
            ),
            PerformanceHistorique(
                cheval_id=cheval_id, date_course=date(2025, 11, 1), hippodrome="C",
                terrain=None, nb_participants=10, rang=1, source="pmu",
            ),
        ])
        session.commit()

    horses = repo.get_horses_for_course(course)
    assert len(horses) == 1
    horse = horses[0]

    # Champs du cheval lui-même (pas seulement ses performances) — une
    # erreur de mapping participation -> HorseAnalysis (ex. `age` mappé
    # depuis le mauvais attribut) ne cassait aucune assertion avant cet
    # ajout, revue de code.
    assert horse.nom == "ETOILE FILANTE"
    assert horse.num_pmu == 7
    assert horse.age == 5
    assert horse.poids == 57.5
    assert horse.cote == 4.5  # cote_reference (4.5) prioritaire sur cote_direct (4.2)
    assert horse.inedit is False

    performances = horse.performances
    assert len(performances) == 3

    # Plus récente d'abord : 2025-11-01 (rang 1), 2025-10-01 (rang 3), 2025-09-01 (rang 2)
    assert [p.rang for p in performances] == [1, 3, 2]

    assert performances[0].terrain is None  # NULL en base -> None
    assert performances[1].terrain is None  # label non reconnu -> None
    assert performances[2].terrain == terrain_coefficient("Bon") == 1.00

    assert all(p.niveau is None for p in performances)


def test_get_horses_for_course_cote_repli_sur_cote_direct_si_reference_absente(repo):
    # cote_reference is None -> repository.py:138 doit se replier sur
    # cote_direct plutôt que de renvoyer None (le "or" ne serait jamais
    # exercé côté cote_reference=None sans ce test dédié).
    course = repo.upsert_course(make_course_info(date=date(2026, 2, 2)))
    repo.save_partants(course.id, [
        make_partant_info(num_pmu=8, nom="Sans Reference", cote_reference=None, cote_direct=6.1),
    ])

    horses = repo.get_horses_for_course(course)
    assert len(horses) == 1
    assert horses[0].cote == 6.1


# 7. get_unfinalized_courses_before : date < target ET finalisee is False --

def test_get_unfinalized_courses_before(repo):
    target = date(2026, 3, 10)

    course_avant_non_finalisee = repo.upsert_course(make_course_info(
        date=date(2026, 3, 5), numero_reunion=1, numero_course=1,
    ))

    course_avant_finalisee = repo.upsert_course(make_course_info(
        date=date(2026, 3, 6), numero_reunion=1, numero_course=2,
    ))
    with Session(repo.engine) as session:
        c = session.get(Course, course_avant_finalisee.id)
        c.finalisee = True
        session.commit()

    repo.upsert_course(make_course_info(
        date=date(2026, 3, 10), numero_reunion=1, numero_course=3,
    ))  # == target : exclue (comparaison stricte <)

    repo.upsert_course(make_course_info(
        date=date(2026, 3, 15), numero_reunion=1, numero_course=4,
    ))  # après target : exclue

    result = repo.get_unfinalized_courses_before(target)
    assert [c.id for c in result] == [course_avant_non_finalisee.id]


def test_get_unfinalized_courses_before_aucune_qualifiante_retourne_vide(repo):
    repo.upsert_course(make_course_info(date=date(2026, 5, 1), numero_reunion=1, numero_course=1))
    with Session(repo.engine) as session:
        c = session.get(Course, repo.list_courses_for_date(date(2026, 5, 1))[0].id)
        c.finalisee = True
        session.commit()

    result = repo.get_unfinalized_courses_before(date(2026, 5, 10))
    assert result == []


def test_get_unfinalized_courses_before_plusieurs_qualifiantes(repo):
    course1 = repo.upsert_course(make_course_info(date=date(2026, 6, 1), numero_reunion=1, numero_course=1))
    course2 = repo.upsert_course(make_course_info(date=date(2026, 6, 2), numero_reunion=1, numero_course=2))

    result = repo.get_unfinalized_courses_before(date(2026, 6, 10))
    assert {c.id for c in result} == {course1.id, course2.id}


# 8. update_resultats : match par num_pmu, pose le flag finalisee ----------

def test_update_resultats_met_a_jour_par_num_pmu_et_finalise(repo):
    course = repo.upsert_course(make_course_info())
    repo.save_partants(course.id, [make_partant_info(num_pmu=9, ordre_arrivee=None, incident=None)])

    resultat = make_partant_info(num_pmu=9, ordre_arrivee=2, incident="D")
    repo.update_resultats(course.id, [resultat], arrivee_definitive=True)

    full_course = repo.get_course_by_id(course.id)
    assert full_course.finalisee is True
    participation = full_course.participations[0]
    assert participation.rang_arrivee == 2
    assert participation.incident == "D"


# 9. get_hippodromes_connus : ensemble distinct des hippodromes connus -----

def test_get_hippodromes_connus_retourne_ensemble_distinct(repo):
    commun = dict(
        nom_cheval="Bucephale", discipline="plat", allocation=None,
        distance=None, nb_participants=None, rang=None, incident=None,
    )
    repo.ajouter_performance_historique_backfill(date_course=date(2025, 1, 1), hippodrome="Chantilly", **commun)
    repo.ajouter_performance_historique_backfill(date_course=date(2025, 2, 1), hippodrome="Chantilly", **commun)
    repo.ajouter_performance_historique_backfill(date_course=date(2025, 3, 1), hippodrome="Deauville", **commun)
    repo.ajouter_performance_historique_backfill(date_course=date(2025, 4, 1), hippodrome=None, **commun)

    # Un second cheval, avec ses propres hippodromes distincts — sans lui, une
    # implémentation buguée qui renverrait TOUS les hippodromes de la table
    # (plutôt que ceux filtrés par cheval_id) passerait ce test à tort
    # (verification-gap, revue de code).
    commun_autre = dict(commun, nom_cheval="Ouragan")
    repo.ajouter_performance_historique_backfill(date_course=date(2025, 5, 1), hippodrome="Auteuil", **commun_autre)

    with Session(repo.engine) as session:
        cheval = session.query(Cheval).filter(Cheval.nom_normalise == "BUCEPHALE").one()
        cheval_id = cheval.id
        autre_cheval = session.query(Cheval).filter(Cheval.nom_normalise == "OURAGAN").one()
        autre_cheval_id = autre_cheval.id

    hippodromes = repo.get_hippodromes_connus(cheval_id)
    assert sorted(hippodromes) == ["Chantilly", "Deauville"]
    assert "Auteuil" not in hippodromes

    hippodromes_autre = repo.get_hippodromes_connus(autre_cheval_id)
    assert sorted(hippodromes_autre) == ["Auteuil"]


def test_repository_lit_database_url_a_la_construction(monkeypatch, tmp_path):
    # Lue à l'import, la variable figeait la base du premier module de test
    # importé : les routes de l'API écrivaient alors dans ./hippique.db.
    chemin = tmp_path / "lu_a_la_construction.db"
    monkeypatch.setenv("DATABASE_URL", f"sqlite:///{chemin}")

    repository = Repository()

    assert repository.engine.url.database == str(chemin)
    repository.engine.dispose()


# Pronostics enregistrés ----------------------------------------------------

def _course_avec_partants(repo, heure_depart, partants=((1, "Alpha"), (2, "Beta"))):
    course = repo.upsert_course(make_course_info(heure_depart=heure_depart, discipline="plat"))
    repo.save_partants(course.id, [make_partant_info(num_pmu=n, nom=nom) for n, nom in partants])
    return course


def _analyse(num_pmu, probabilite, cote=None):
    from app.engine.scoring import HorseAnalysis

    return HorseAnalysis(nom=f"H{num_pmu}", num_pmu=num_pmu, probabilite=probabilite, cote=cote)


def test_courses_evaluables_retient_le_dernier_pronostic_avant_le_depart(repo):
    depart = datetime(2026, 1, 15, 14, 0)
    course = _course_avec_partants(repo, depart)
    repo.save_prediction_run(course.id, [_analyse(1, 0.3), _analyse(2, 0.7)], "live", datetime(2026, 1, 15, 9, 0), [])
    repo.save_prediction_run(course.id, [_analyse(1, 0.8, cote=2.0), _analyse(2, 0.2)], "live",
                             datetime(2026, 1, 15, 13, 0), ["terrain_du_jour"])
    # Postérieur au départ : ne doit jamais compter comme pronostic.
    repo.save_prediction_run(course.id, [_analyse(1, 0.1), _analyse(2, 0.9)], "live", datetime(2026, 1, 15, 15, 0), [])
    repo.update_resultats(course.id, [make_partant_info(num_pmu=1, ordre_arrivee=1),
                                      make_partant_info(num_pmu=2, ordre_arrivee=2)], True)

    [predite] = repo.courses_evaluables("live")

    assert predite.discipline == "plat"
    assert predite.degradee is True
    assert [(c.num_pmu, c.probabilite, c.cote, c.rang_arrivee) for c in predite.chevaux] == [
        (1, 0.8, 2.0, 1), (2, 0.2, None, 2),
    ]


def test_courses_evaluables_ignore_les_courses_sans_pronostic_ou_sans_heure(repo):
    _course_avec_partants(repo, None)

    assert repo.courses_evaluables("live") == []


def test_courses_evaluables_rejeu_ne_se_melange_pas_au_live(repo):
    course = _course_avec_partants(repo, datetime(2026, 1, 15, 14, 0))
    repo.save_prediction_run(course.id, [_analyse(1, 0.6), _analyse(2, 0.4)], "rejeu", datetime(2026, 1, 16, 10, 0), [])

    assert repo.courses_evaluables("live") == []
    [predite] = repo.courses_evaluables("rejeu")
    assert [c.probabilite for c in predite.chevaux] == [0.6, 0.4]


def test_save_prediction_run_ignore_les_outsiders_virtuels(repo):
    course = _course_avec_partants(repo, datetime(2026, 1, 15, 14, 0))
    virtuel = _analyse(None, 0.05)

    repo.save_prediction_run(course.id, [_analyse(1, 0.5), _analyse(2, 0.45), virtuel], "rejeu",
                             datetime(2026, 1, 16, 10, 0), [])

    [predite] = repo.courses_evaluables("rejeu")
    assert [c.num_pmu for c in predite.chevaux] == [1, 2]


def test_courses_evaluables_app_une_entree_par_utilisateur_avec_ses_indicateurs(repo):
    course = _course_avec_partants(repo, datetime(2026, 1, 15, 14, 0))
    repo.save_prediction_run(course.id, [_analyse(1, 0.5), _analyse(2, 0.5)], "app", datetime(2026, 1, 15, 10, 0), [],
                             installation_id="u1", donnees_modifiees=False)
    repo.save_prediction_run(course.id, [_analyse(1, 0.9), _analyse(2, 0.1)], "app", datetime(2026, 1, 15, 11, 0), [],
                             installation_id="u1", donnees_modifiees=True, reglages_par_defaut=False,
                             terrain_modifie=True, parametres={"contraste": 5})
    repo.save_prediction_run(course.id, [_analyse(1, 0.2), _analyse(2, 0.8)], "app", datetime(2026, 1, 15, 12, 0), [],
                             installation_id="u2", donnees_modifiees=False)

    predites = sorted(repo.courses_evaluables("app"), key=lambda p: p.installation_id)

    assert [(p.course_id, p.installation_id, p.donnees_modifiees, p.chevaux[0].probabilite) for p in predites] == [
        (course.id, "u1", True, 0.9), (course.id, "u2", False, 0.2),
    ]


def test_courses_evaluables_live_porte_l_identifiant_de_course(repo):
    course = _course_avec_partants(repo, datetime(2026, 1, 15, 14, 0))
    repo.save_prediction_run(course.id, [_analyse(1, 0.5), _analyse(2, 0.5)], "live", datetime(2026, 1, 15, 10, 0), [])

    [predite] = repo.courses_evaluables("live")

    assert (predite.course_id, predite.installation_id) == (course.id, None)
