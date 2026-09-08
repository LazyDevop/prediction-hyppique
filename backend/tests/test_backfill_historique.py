"""Tests de couverture pour `jobs/backfill_historique.py` (Story 2.3 — voir
_bmad-output/implementation-artifacts/spec-2-3-backfill-historique-test-coverage.md).

Comme `test_repository.py` (Story 2.1) et `test_ingest_daily.py` (Story 2.2),
chaque test construit son propre `Repository` contre un fichier SQLite
temporaire neuf (jamais `:memory:`) : les effets de bord de persistance sont
vérifiés pour de vrai plutôt que mockés. Seule `open_pmu_client.get_arrivees`
est mockée — c'est la frontière réseau isolée par le pattern adaptateur
(AD-1) ; `open_pmu_client.py` lui-même n'est pas testé ici (hors périmètre,
mocked boundary du spec).

Point central couvert : `backfill_plage` et
`backfill_cheval_par_hippodromes_connus` utilisent délibérément deux sources
de date différentes pour `date_course` — `jour` (la date de boucle demandée)
pour la première, `arrivee.date` (la date parsée de la réponse) pour la
seconde, faute d'un seul jour demandé dans ce second cas (Boundaries #3/#6 du
spec).
"""

import atexit
import os
import tempfile
from datetime import date
from unittest.mock import call, patch

import pytest
from sqlalchemy.orm import Session

from app.data.models import Cheval, PerformanceHistorique
from app.data.open_pmu_client import Arrivee, ArriveeCheval
from app.data.repository import Repository
from app.jobs import backfill_historique


@pytest.fixture
def repo():
    fd, path = tempfile.mkstemp(suffix=".db", prefix="test_backfill_historique_")
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


def make_arrivee_cheval(**overrides) -> ArriveeCheval:
    defaults = dict(
        num_pmu=1,
        nom="Bucephale",
        sexe="M",
        annee_naissance=2018,
        jockey="J. Dupont",
        entraineur="P. Martin",
        musique="1a2a3a",
        cotes_brutes=[],
        corde=3,
        rang=1,
        incident=None,
    )
    defaults.update(overrides)
    return ArriveeCheval(**defaults)


def make_arrivee(**overrides) -> Arrivee:
    defaults = dict(
        reunion_course="R1/C1",
        date_brute="2026-01-15T00:00:00.000Z",
        date=date(2026, 1, 15),
        hippodrome="Vincennes",
        prix="Prix Test",
        discipline="trot",
        discipline_brute="ATTELE",
        distance=2700.0,
        allocation=20000.0,
        nb_partants=14,
        heure_depart=None,
        chevaux=[],
    )
    defaults.update(overrides)
    return Arrivee(**defaults)


PATCH_TARGET = "app.jobs.backfill_historique.open_pmu_client.get_arrivees"


# 1. backfill_plage : un appel par jour, bornes incluses --------------------

def test_backfill_plage_itere_chaque_jour_de_la_plage_incluse(repo):
    date_debut = date(2026, 1, 10)
    date_fin = date(2026, 1, 13)

    with patch(PATCH_TARGET, return_value=[]) as mock_get:
        backfill_historique.backfill_plage(repo, date_debut, date_fin)

    assert mock_get.call_args_list == [
        call(target_date=date(2026, 1, 10), hippodrome=None),
        call(target_date=date(2026, 1, 11), hippodrome=None),
        call(target_date=date(2026, 1, 12), hippodrome=None),
        call(target_date=date(2026, 1, 13), hippodrome=None),
    ]


def test_backfill_plage_date_debut_egale_date_fin_un_seul_appel(repo):
    jour = date(2026, 2, 1)

    with patch(PATCH_TARGET, return_value=[]) as mock_get:
        backfill_historique.backfill_plage(repo, jour, jour, hippodrome="Vincennes")

    mock_get.assert_called_once_with(target_date=jour, hippodrome="Vincennes")


def test_backfill_plage_date_fin_avant_date_debut_ne_fait_rien(repo):
    # main() valide date_fin >= date_debut côté CLI (backfill_historique.py:
    # 134-135), mais backfill_plage reste une fonction publique appelable
    # directement (ex. futurs appelants, script) sans passer par cette garde
    # — edge-case-hunter, revue de code. La boucle `while jour <= date_fin`
    # doit rester un no-op sûr (zéro appel, zéro écriture), pas une erreur.
    with patch(PATCH_TARGET) as mock_get:
        backfill_historique.backfill_plage(repo, date(2026, 2, 10), date(2026, 2, 5))

    mock_get.assert_not_called()


# 2. backfill_plage : filtre cheval (normalisé, insensible casse/espaces) ---

def test_backfill_plage_sans_filtre_persiste_tous_les_chevaux_trouves(repo):
    jour = date(2026, 3, 1)
    arrivee = make_arrivee(chevaux=[
        make_arrivee_cheval(num_pmu=1, nom="Bucephale", rang=1),
        make_arrivee_cheval(num_pmu=2, nom="Furia", rang=2),
    ])

    with patch(PATCH_TARGET, return_value=[arrivee]):
        backfill_historique.backfill_plage(repo, jour, jour)

    with Session(repo.engine) as session:
        noms = {c.nom_normalise for c in session.query(Cheval).all()}
    assert noms == {"BUCEPHALE", "FURIA"}


def test_backfill_plage_avec_filtre_ne_persiste_que_le_cheval_correspondant(repo):
    # Normalisation insensible à la casse et aux espaces : "  bucephale  "
    # doit matcher le filtre "Bucephale".
    jour = date(2026, 3, 2)
    arrivee = make_arrivee(chevaux=[
        make_arrivee_cheval(num_pmu=1, nom="  bucephale  ", rang=1),
        make_arrivee_cheval(num_pmu=2, nom="Furia", rang=2),
    ])

    with patch(PATCH_TARGET, return_value=[arrivee]):
        backfill_historique.backfill_plage(repo, jour, jour, cheval="Bucephale")

    with Session(repo.engine) as session:
        noms = {c.nom_normalise for c in session.query(Cheval).all()}
    assert noms == {"BUCEPHALE"}  # "Furia" jamais persisté, filtré avant d'atteindre le repository


# 3. backfill_plage : persiste `jour` (la boucle), jamais `arrivee.date` ----

def test_backfill_plage_persiste_jour_de_boucle_pas_date_de_la_reponse(repo):
    jour = date(2026, 4, 5)
    arrivee = make_arrivee(
        date=date(2026, 4, 1),  # délibérément différente de `jour`
        date_brute="2026-04-01T00:00:00.000Z",
        chevaux=[make_arrivee_cheval(nom="Bucephale")],
    )

    with patch(PATCH_TARGET, return_value=[arrivee]):
        backfill_historique.backfill_plage(repo, jour, jour)

    with Session(repo.engine) as session:
        ligne = session.query(PerformanceHistorique).one()

    assert ligne.date_course == jour
    assert ligne.date_course != arrivee.date


def test_backfill_plage_transmet_tous_les_champs_de_larrivee_a_la_ligne_persistee(repo):
    # Les 3 lentilles de revue (blind-hunter, edge-case-hunter,
    # verification-gap) ont convergé sur ce gap : aucun test n'affirmait les
    # champs transmis tels quels (hippodrome, discipline, allocation,
    # distance, nb_participants, rang, incident) sur la ligne persistée —
    # seuls date_course et le nom du cheval l'étaient. Un bug de mapping
    # "bon argument, mauvaise position" (ex. distance/allocation inversées)
    # serait passé inaperçu de tous les tests précédents.
    jour = date(2026, 7, 1)
    arrivee = make_arrivee(
        hippodrome="Chantilly", discipline="plat", allocation=25000.0,
        distance=1600.0, nb_partants=12,
        chevaux=[make_arrivee_cheval(nom="Bucephale", rang=4, incident="D")],
    )

    with patch(PATCH_TARGET, return_value=[arrivee]):
        backfill_historique.backfill_plage(repo, jour, jour)

    with Session(repo.engine) as session:
        ligne = session.query(PerformanceHistorique).one()

    assert ligne.hippodrome == "Chantilly"
    assert ligne.discipline == "plat"
    assert ligne.allocation == 25000.0
    assert ligne.distance == 1600.0
    assert ligne.nb_participants == 12
    assert ligne.rang == 4
    assert ligne.incident == "D"


# 4. backfill_plage : un jour en échec est avalé, la boucle continue -------

def test_backfill_plage_jour_en_echec_est_avale_et_boucle_continue(repo):
    jour1, jour2, jour3 = date(2026, 5, 1), date(2026, 5, 2), date(2026, 5, 3)
    arrivee_jour3 = make_arrivee(chevaux=[make_arrivee_cheval(nom="Furia")])

    def side_effect(target_date=None, hippodrome=None):
        if target_date == jour2:
            raise RuntimeError("open-pmu-api indisponible")
        if target_date == jour3:
            return [arrivee_jour3]
        return []

    with patch(PATCH_TARGET, side_effect=side_effect) as mock_get:
        backfill_historique.backfill_plage(repo, jour1, jour3)

    # Les 3 jours sont bien tentés (jour2 lève mais n'interrompt pas la boucle).
    assert mock_get.call_args_list == [
        call(target_date=jour1, hippodrome=None),
        call(target_date=jour2, hippodrome=None),
        call(target_date=jour3, hippodrome=None),
    ]
    with Session(repo.engine) as session:
        cheval = session.query(Cheval).filter(Cheval.nom_normalise == "FURIA").one_or_none()
    assert cheval is not None  # jour3, après l'échec de jour2, a bien été traité


# 5. backfill_plage : doublon ne duplique jamais la ligne persistée --------

def test_backfill_plage_doublon_ne_duplique_pas_la_ligne_persistee(repo):
    jour = date(2026, 6, 1)
    arrivee = make_arrivee(hippodrome="Chantilly", chevaux=[make_arrivee_cheval(nom="Bucephale")])

    with patch(PATCH_TARGET, return_value=[arrivee]):
        backfill_historique.backfill_plage(repo, jour, jour)
        backfill_historique.backfill_plage(repo, jour, jour)  # même (cheval, date, hippodrome)

    with Session(repo.engine) as session:
        lignes = session.query(PerformanceHistorique).all()
    assert len(lignes) == 1  # vérifié via l'état persisté, pas via le log ajoutee/doublon


# 6. backfill_cheval_par_hippodromes_connus : un appel par hippodrome, ------
#    correspondance EXACTE (normalisée), persiste arrivee.date ------------

def test_backfill_cheval_par_hippodromes_appelle_par_hippodrome_et_persiste_date_reponse(repo):
    arrivee_vincennes = make_arrivee(hippodrome="Vincennes", date=date(2025, 1, 10), chevaux=[
        make_arrivee_cheval(num_pmu=1, nom="Bucephale", rang=3),
        make_arrivee_cheval(num_pmu=2, nom="Bucephale Junior", rang=1),  # ne doit pas matcher partiellement
    ])
    arrivee_longchamp = make_arrivee(hippodrome="Longchamp", date=date(2025, 2, 15), chevaux=[
        make_arrivee_cheval(num_pmu=1, nom="bucephale", rang=5),  # correspondance exacte insensible à la casse
    ])

    def side_effect(hippodrome=None, target_date=None, prix=None):
        if hippodrome == "Vincennes":
            return [arrivee_vincennes]
        if hippodrome == "Longchamp":
            return [arrivee_longchamp]
        return []

    with patch(PATCH_TARGET, side_effect=side_effect) as mock_get:
        total = backfill_historique.backfill_cheval_par_hippodromes_connus(
            repo, "Bucephale", ["Vincennes", "Longchamp"]
        )

    assert mock_get.call_args_list == [call(hippodrome="Vincennes"), call(hippodrome="Longchamp")]
    assert total == 2

    with Session(repo.engine) as session:
        noms = {c.nom_normalise for c in session.query(Cheval).all()}
        cheval = session.query(Cheval).filter(Cheval.nom_normalise == "BUCEPHALE").one()
        lignes = session.query(PerformanceHistorique).filter(
            PerformanceHistorique.cheval_id == cheval.id
        ).all()

    assert "BUCEPHALE JUNIOR" not in noms  # exact match seulement, pas de correspondance partielle
    assert sorted(l.date_course for l in lignes) == [date(2025, 1, 10), date(2025, 2, 15)]  # arrivee.date, pas de "jour" ici


# 7. backfill_cheval_par_hippodromes_connus : un hippodrome en échec --------
#    est avalé, la boucle continue -----------------------------------------

def test_backfill_cheval_par_hippodromes_echec_est_avale_et_boucle_continue(repo):
    arrivee_ok = make_arrivee(hippodrome="Auteuil", date=date(2025, 3, 1), chevaux=[
        make_arrivee_cheval(nom="Bucephale"),
    ])

    def side_effect(hippodrome=None, target_date=None, prix=None):
        if hippodrome == "Enghien":
            raise RuntimeError("open-pmu-api indisponible")
        return [arrivee_ok]

    with patch(PATCH_TARGET, side_effect=side_effect) as mock_get:
        total = backfill_historique.backfill_cheval_par_hippodromes_connus(
            repo, "Bucephale", ["Enghien", "Auteuil"]
        )

    assert mock_get.call_args_list == [call(hippodrome="Enghien"), call(hippodrome="Auteuil")]
    assert total == 1
    with Session(repo.engine) as session:
        assert session.query(PerformanceHistorique).count() == 1  # Auteuil traité malgré l'échec d'Enghien


# 8. backfill_cheval_par_hippodromes_connus : retourne le compte des --------
#    lignes réellement ajoutées, doublons exclus ----------------------------

def test_backfill_cheval_par_hippodromes_retourne_compte_sans_doublons(repo):
    arrivee = make_arrivee(hippodrome="Deauville", date=date(2025, 4, 1), chevaux=[
        make_arrivee_cheval(nom="Bucephale"),
    ])

    with patch(PATCH_TARGET, return_value=[arrivee]):
        first_total = backfill_historique.backfill_cheval_par_hippodromes_connus(repo, "Bucephale", ["Deauville"])
        second_total = backfill_historique.backfill_cheval_par_hippodromes_connus(repo, "Bucephale", ["Deauville"])

    assert first_total == 1
    assert second_total == 0  # même (cheval, date, hippodrome) : doublon non compté dans le total retourné
    with Session(repo.engine) as session:
        assert session.query(PerformanceHistorique).count() == 1


def test_backfill_cheval_par_hippodromes_liste_vide_ne_fait_rien(repo):
    # Scénario réel d'entrée pour POST /chevaux/{id}/backfill (docstring de
    # backfill_cheval_par_hippodromes_connus) : un cheval tout juste ajouté,
    # sans historique connu, produit hippodromes=[] via
    # get_hippodromes_connus — edge-case-hunter, revue de code.
    with patch(PATCH_TARGET) as mock_get:
        total = backfill_historique.backfill_cheval_par_hippodromes_connus(repo, "Bucephale", [])

    mock_get.assert_not_called()
    assert total == 0
