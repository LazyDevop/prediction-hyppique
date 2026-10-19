import math

import pytest

from app.engine.evaluation import ChevalPredit, CoursePredite, agreger, evaluer_course


def course(probas, gagnant, cotes=None, discipline="plat", degradee=False):
    cotes = cotes or [None] * len(probas)
    return CoursePredite(
        discipline=discipline,
        degradee=degradee,
        chevaux=[
            ChevalPredit(num_pmu=i + 1, probabilite=p, cote=c, rang_arrivee=1 if i + 1 == gagnant else None)
            for i, (p, c) in enumerate(zip(probas, cotes))
        ],
    )


def test_evaluer_course_gagnant_trouve_et_scores():
    resultat = evaluer_course(course([0.5, 0.3, 0.2], gagnant=1))

    assert resultat.gagnant_trouve is True
    assert resultat.gagnant_dans_top3 is True
    assert resultat.log_loss == pytest.approx(-math.log(0.5))
    assert resultat.brier == pytest.approx((0.5 - 1) ** 2 + 0.3 ** 2 + 0.2 ** 2)
    assert resultat.log_loss_hasard == pytest.approx(math.log(3))


def test_evaluer_course_gagnant_hors_top3():
    resultat = evaluer_course(course([0.4, 0.3, 0.2, 0.1], gagnant=4))

    assert resultat.gagnant_trouve is False
    assert resultat.gagnant_dans_top3 is False
    assert resultat.log_loss == pytest.approx(-math.log(0.1))


def test_evaluer_course_favori_du_marche():
    # Le moteur vise le 1, le marché (cote la plus basse) le 2, qui gagne.
    resultat = evaluer_course(course([0.5, 0.3, 0.2], gagnant=2, cotes=[6.0, 2.5, 4.0]))

    assert resultat.gagnant_trouve is False
    assert resultat.favori_gagnant is True


def test_evaluer_course_sans_cote_n_a_pas_de_favori():
    assert evaluer_course(course([0.5, 0.5], gagnant=1)).favori_gagnant is None


def test_evaluer_course_sans_gagnant_connu_n_est_pas_evaluable():
    assert evaluer_course(course([0.5, 0.5], gagnant=None)) is None


def test_evaluer_course_probabilite_nulle_du_gagnant_reste_finie():
    resultat = evaluer_course(course([1.0, 0.0], gagnant=2))

    assert math.isfinite(resultat.log_loss)


def test_agreger_taux_moyennes_et_references():
    courses = [
        course([0.6, 0.4], gagnant=1, cotes=[2.0, 3.0]),
        course([0.6, 0.4], gagnant=2, cotes=[2.0, 3.0]),
        course([0.7, 0.3], gagnant=1),
    ]

    bilan = agreger([evaluer_course(c) for c in courses])

    assert bilan.courses == 3
    assert bilan.taux_gagnant == pytest.approx(2 / 3)
    assert bilan.taux_favori == pytest.approx(1 / 2)  # seulement les courses avec cotes
    assert bilan.courses_avec_cotes == 2
    assert bilan.log_loss == pytest.approx((-math.log(0.6) - math.log(0.4) - math.log(0.7)) / 3)
    assert bilan.log_loss_hasard == pytest.approx(math.log(2))


def test_agreger_calibration_par_tranche():
    courses = [course([0.6, 0.4], gagnant=1), course([0.6, 0.4], gagnant=2)]

    bilan = agreger([evaluer_course(c) for c in courses])

    tranches = {(t.borne_basse, t.borne_haute): t for t in bilan.calibration}
    assert tranches[(0.3, 0.5)].chevaux == 2
    assert tranches[(0.3, 0.5)].proba_moyenne == pytest.approx(0.4)
    assert tranches[(0.3, 0.5)].taux_victoire == pytest.approx(0.5)
    assert tranches[(0.5, 1.0)].taux_victoire == pytest.approx(0.5)
    assert tranches[(0.0, 0.05)].chevaux == 0


def test_agreger_vide():
    bilan = agreger([])

    assert bilan.courses == 0
    assert bilan.taux_gagnant is None
    assert bilan.log_loss is None


def test_agreger_par_discipline_et_par_qualite_des_donnees():
    courses = [
        course([0.6, 0.4], gagnant=1, discipline="plat"),
        course([0.6, 0.4], gagnant=2, discipline="trot", degradee=True),
    ]
    evaluations = [evaluer_course(c) for c in courses]

    assert agreger([e for e in evaluations if e.discipline == "trot"]).taux_gagnant == 0.0
    assert agreger([e for e in evaluations if not e.degradee]).taux_gagnant == 1.0


def test_comparer_apparie_par_course_le_pronostic_app_et_l_automatique():
    from app.engine.evaluation import comparer

    def avec_cle(c, course_id, installation_id=None, modifiee=False):
        c.course_id, c.installation_id, c.donnees_modifiees = course_id, installation_id, modifiee
        return evaluer_course(c)

    auto = [avec_cle(course([0.6, 0.4], gagnant=2), 1), avec_cle(course([0.6, 0.4], gagnant=1), 2),
            avec_cle(course([0.5, 0.5], gagnant=1), 3)]
    app = [
        avec_cle(course([0.3, 0.7], gagnant=2), 1, "u1", modifiee=True),   # l'utilisateur corrige le moteur
        avec_cle(course([0.6, 0.4], gagnant=1), 2, "u2"),
        avec_cle(course([0.6, 0.4], gagnant=1), 9, "u1"),                  # pas de pronostic auto : non apparié
    ]

    comparaison = comparer(app, auto)

    assert comparaison.paires == 2
    assert comparaison.utilisateurs == 2
    assert comparaison.taux_gagnant_app == 1.0
    assert comparaison.taux_gagnant_auto == 0.5
    assert comparaison.log_loss_app == pytest.approx((-math.log(0.7) - math.log(0.6)) / 2)
    assert comparaison.log_loss_auto == pytest.approx((-math.log(0.4) - math.log(0.6)) / 2)


def test_comparer_sans_paire():
    from app.engine.evaluation import comparer

    comparaison = comparer([], [])

    assert (comparaison.paires, comparaison.taux_gagnant_app, comparaison.log_loss_auto) == (0, None, None)
