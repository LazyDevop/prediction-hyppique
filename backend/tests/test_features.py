"""Tests de `model/features.py` : une fonction par ligne de la matrice I/O
du spec (spec-features-modele.md), plus le garde-fou anti-fuite (registre et
perturbation des résultats de la course elle-même)."""

import copy
from datetime import date, timedelta

import pytest

from app.model import features as F
from app.model.features import ConstructeurFeatures, CourseRecord, PartantRecord

D1 = date(2025, 3, 2)
D2 = date(2025, 3, 9)


def partant(num, cheval_id, rang=None, incident=None, **brut):
    donnees = {"statut": "PARTANT", "nomPere": f"PERE {cheval_id}"}
    donnees.update(brut)
    return PartantRecord(
        num_pmu=num, cheval_id=cheval_id, brut=donnees,
        driver=donnees.get("driver", f"Driver {cheval_id}"), entraineur=donnees.get("entraineur", f"Ent {cheval_id}"),
        rang_arrivee=rang, incident=incident, cote_reference=5.0, cote_direct=4.0,
    )


def course(course_id, jour, partants, discipline="plat", **kw):
    defaults = dict(distance=2000.0, allocation=20000.0, terrain="Bon", hippodrome="DEAUVILLE")
    defaults.update(kw)
    return CourseRecord(course_id=course_id, date=jour, discipline=discipline, partants=partants, **defaults)


def par_num(lignes, course_id=None):
    return {l["num_pmu"]: l for l in lignes if course_id is None or l["course_id"] == course_id}


def test_deux_jours_historique_du_lendemain():
    b = ConstructeurFeatures()
    l1 = b.traiter_jour([course(1, D1, [partant(1, 10, rang=1), partant(2, 20, rang=2), partant(3, 30, rang=3)])])
    j1 = par_num(l1)[1]
    assert j1["f_nb_courses_connues"] == 0
    assert j1["f_rang_rel_dernier"] is None
    assert j1["f_taux_victoire_6"] is None
    assert j1["f_nb_courses_6"] == 0
    assert j1["f_jours_depuis_derniere"] is None
    assert j1["f_driver_nb_365"] == 0 and j1["f_driver_taux_victoire_365"] is None

    l2 = b.traiter_jour([course(2, D2, [partant(1, 10, rang=4), partant(5, 50, rang=1)])])
    j2 = par_num(l2)[1]
    assert j2["f_rang_rel_dernier"] == 0.0  # dernier rang = 1
    assert j2["f_taux_victoire_6"] == 1.0
    assert j2["f_nb_courses_6"] == 1
    assert j2["f_nb_courses_connues"] == 1
    assert j2["f_jours_depuis_derniere"] == (D2 - D1).days
    assert j2["f_driver_taux_victoire_365"] == 1.0 and j2["f_driver_nb_365"] == 1
    assert j2["f_pere_nb_disc"] == 1 and j2["f_pere_taux_victoire_disc"] == 1.0
    assert j2["f_chgt_discipline"] == 0 and j2["f_chgt_hippodrome"] == 0 and j2["f_ecart_distance"] == 0


def test_meme_jour_isole_le_driver():
    b = ConstructeurFeatures()
    r1 = course(1, D1, [partant(1, 10, rang=1, driver="X"), partant(2, 20, rang=2)])
    r5 = course(5, D1, [partant(3, 30, rang=2, driver="X"), partant(4, 40, rang=1)])
    lignes = b.traiter_jour([r1, r5])
    x_r5 = par_num(lignes, 5)[3]
    assert x_r5["f_driver_nb_365"] == 0
    assert x_r5["f_driver_taux_victoire_365"] is None
    # Le lendemain, la victoire de R1 compte.
    lendemain = b.traiter_jour([course(9, D1 + timedelta(days=1), [partant(7, 70, driver="X"), partant(8, 80)])])
    assert par_num(lendemain)[7]["f_driver_nb_365"] == 2
    assert par_num(lendemain)[7]["f_driver_taux_victoire_365"] == 0.5


@pytest.mark.parametrize("ecart,attendu", [(364, 1), (365, 0)])
def test_fenetre_personnes_365_jours(ecart, attendu):
    b = ConstructeurFeatures()
    b.traiter_jour([course(1, D1, [partant(1, 10, rang=1, driver="X"), partant(2, 20, rang=2)])])
    plus_tard = D1 + timedelta(days=ecart)
    lignes = b.traiter_jour([course(2, plus_tard, [partant(3, 30, driver="X"), partant(4, 40)])])
    assert par_num(lignes)[3]["f_driver_nb_365"] == attendu


def test_entraineur_365_victoire_anterieure_comptee_meme_jour_exclu():
    b = ConstructeurFeatures()
    b.traiter_jour([course(1, D1, [partant(1, 10, rang=1, entraineur="T"), partant(2, 20, rang=2)])])
    lignes = b.traiter_jour([
        course(2, D2, [partant(1, 30, rang=1, entraineur="T"), partant(2, 40, rang=2)]),
        course(3, D2, [partant(1, 50, rang=2, entraineur="T"), partant(2, 60, rang=1)]),
    ])
    for course_id in (2, 3):
        l = par_num(lignes, course_id)[1]
        assert l["f_entraineur_nb_365"] == 1
        assert l["f_entraineur_taux_victoire_365"] == 1.0
    suite = par_num(b.traiter_jour([course(4, D2 + timedelta(days=1), [partant(1, 70, entraineur="T")])]))[1]
    assert suite["f_entraineur_nb_365"] == 3
    assert suite["f_entraineur_taux_victoire_365"] == pytest.approx(2 / 3)


def test_personne_sans_nom_vide():
    b = ConstructeurFeatures()
    p = partant(1, 10)
    p.driver = None
    l = par_num(b.traiter_jour([course(1, D1, [p])]))[1]
    assert l["f_driver_nb_365"] is None and l["f_driver_taux_victoire_365"] is None


def test_allocation_relative():
    b = ConstructeurFeatures()
    b.traiter_jour([course(1, D1, [partant(1, 10, rang=1)], allocation=10000.0)])
    b.traiter_jour([course(2, D2, [partant(1, 10, rang=1)], allocation=30000.0)])
    l = par_num(b.traiter_jour([course(3, D2 + timedelta(days=7), [partant(1, 10)], allocation=40000.0)]))[1]
    assert l["f_allocation_rel"] == 2.0
    assert l["f_nb_allocations"] == 2


def test_pere_par_discipline():
    b = ConstructeurFeatures()
    b.traiter_jour([course(1, D1, [partant(1, 10, rang=1, nomPere="P"), partant(2, 20, rang=2)], discipline="trot")])
    lignes = b.traiter_jour([
        course(2, D2, [partant(1, 30, nomPere="P")], discipline="plat"),
        course(3, D2, [partant(1, 40, nomPere="P")], discipline="trot"),
    ])
    plat = par_num(lignes, 2)[1]
    assert plat["f_pere_nb_disc"] == 0 and plat["f_pere_taux_victoire_disc"] is None
    trot = par_num(lignes, 3)[1]
    assert trot["f_pere_nb_disc"] == 1 and trot["f_pere_taux_victoire_disc"] == 1.0


def test_contexte_transmis():
    b = ConstructeurFeatures()
    p = partant(1, 10, handicapPoids=575, placeCorde=7, oeilleres="OEILLERES_AUSTRALIENNES", handicapValeur=29.5)
    l = par_num(b.traiter_jour([course(1, D1, [p])]))[1]
    assert l["f_handicap_poids"] == 57.5
    assert l["f_place_corde"] == 7
    assert l["f_oeilleres"] == "OEILLERES_AUSTRALIENNES"
    assert l["f_handicap_valeur"] == 29.5


@pytest.mark.parametrize("valeur,attendu", [
    (True, 1), (False, 0), ("true", 1), ("false", 0), ("TRUE", 1), ("1", 1), ("0", 0), (1, 1), (0, 0),
    ("peut-être", None), (None, None), (2, None),
])
def test_drapeaux_avant_course(valeur, attendu):
    b = ConstructeurFeatures()
    l = par_num(b.traiter_jour([course(1, D1, [partant(1, 10, driverChange=valeur, indicateurInedit=valeur)])]))[1]
    assert l["f_driver_change"] == attendu
    assert l["f_inedit"] == attendu


def test_bandes_de_distance():
    assert F.bande_distance(2199) == "courte"
    assert F.bande_distance(2200) == "moyenne"
    assert F.bande_distance(2699) == "moyenne"
    assert F.bande_distance(2700) == "longue"
    assert F.bande_distance(None) is None


@pytest.mark.parametrize("musique,attendu", [
    ("", (0, None, None)),
    (None, (0, None, None)),
    ("0", (0, None, None)),
    ("0a", (1, 10, 0)),
    ("DaAmTh", (3, 10, 0)),
    ("(24)", (0, None, None)),
    ("(24)(23)", (0, None, None)),
])
def test_lire_musique_cas_limites(musique, attendu):
    assert F.lire_musique(musique) == attendu


@pytest.mark.parametrize("statut,incident", [("PARTANT", "NON_PARTANT"), ("NON_PARTANT", None)])
def test_non_partant_par_statut_ou_incident(statut, incident):
    b = ConstructeurFeatures()
    p = partant(3, 30, incident=incident, statut=statut)
    lignes = b.traiter_jour([course(1, D1, [partant(1, 10, rang=1), p])])
    assert set(par_num(lignes)) == {1}
    assert 30 not in b.chevaux


def test_statut_inconnu_compte_partant_et_signale(caplog):
    b = ConstructeurFeatures()
    with caplog.at_level("WARNING"):
        lignes = b.traiter_jour([course(1, D1, [partant(1, 10, statut="BIZARRE"), partant(2, 20, statut="BIZARRE"),
                                               partant(3, 30, statut=None)])])
    assert set(par_num(lignes)) == {1, 2, 3}
    assert b.compteurs["statut_inconnu"] == 3
    assert sum("BIZARRE" in r.getMessage() for r in caplog.records) == 1  # une fois par valeur


def test_discipline_inconnue_signalee_une_fois(caplog):
    b = ConstructeurFeatures()
    with caplog.at_level("WARNING"):
        b.traiter_jour([course(1, D1, [partant(1, 10)], discipline="attele"),
                        course(2, D1, [partant(1, 20)], discipline="attele")])
    assert sum("discipline inconnue" in r.getMessage() for r in caplog.records) == 1


def test_dossard_absent_compte_dans_le_champ_sans_ligne():
    b = ConstructeurFeatures()
    lignes = b.traiter_jour([course(1, D1, [partant(1, 10, rang=2), partant(None, 20, rang=1)])])
    assert [l["num_pmu"] for l in lignes] == [1]
    assert lignes[0]["f_nb_partants"] == 2
    assert b.compteurs["num_pmu_absent"] == 1
    # L'état a vu le partant sans dossard.
    l2 = par_num(b.traiter_jour([course(2, D2, [partant(5, 20)])]))[5]
    assert l2["f_nb_courses_connues"] == 1 and l2["f_taux_victoire_6"] == 1.0


@pytest.mark.parametrize("rang", [0, -1])
def test_rang_invalide_non_classe(rang):
    b = ConstructeurFeatures()
    l = par_num(b.traiter_jour([course(1, D1, [partant(1, 10, rang=rang), partant(2, 20, rang=1)])]))[1]
    assert l["rang"] is None and l["gagnant"] == 0 and l["place"] == 0


def test_non_partant_sans_ligne_ni_historique():
    b = ConstructeurFeatures()
    np_ = partant(3, 30, incident="NON_PARTANT", statut="NON_PARTANT")
    lignes = b.traiter_jour([course(1, D1, [partant(1, 10, rang=1), partant(2, 20, rang=2), np_])])
    assert set(par_num(lignes)) == {1, 2}
    assert all(l["f_nb_partants"] == 2 for l in lignes)
    assert 30 not in b.chevaux
    l2 = b.traiter_jour([course(2, D2, [partant(3, 30), partant(4, 40)])])
    assert par_num(l2)[3]["f_nb_courses_connues"] == 0


@pytest.mark.parametrize("rang,incident", [(None, None), (None, "DISQUALIFIE_POUR_ALLURE_IRREGULIERE"), (2, "ARRETE")])
def test_non_classe_ou_incident_compte_comme_pire(rang, incident):
    b = ConstructeurFeatures()
    b.traiter_jour([course(1, D1, [partant(1, 10, rang=1), partant(2, 20, rang=2), partant(3, 30, rang=rang, incident=incident)])])
    l2 = par_num(b.traiter_jour([course(2, D2, [partant(3, 30), partant(4, 40)])]))[3]
    assert l2["f_rang_rel_dernier"] == 1.0
    assert l2["f_nb_courses_connues"] == 1
    assert l2["f_nb_courses_6"] == 1
    assert l2["f_taux_victoire_6"] == 0.0 and l2["f_taux_place_6"] == 0.0


def test_label_incident_non_classe():
    b = ConstructeurFeatures()
    lignes = par_num(b.traiter_jour([course(1, D1, [partant(1, 10, rang=1, incident="DISTANCE"), partant(2, 20, rang=2)])]))
    assert lignes[1]["rang"] is None and lignes[1]["gagnant"] == 0 and lignes[1]["place"] == 0
    # Moins de 4 partants : une seule place payée, le 2e n'est pas placé.
    assert lignes[2]["rang"] == 2 and lignes[2]["place"] == 0 and lignes[2]["gagnant"] == 0


def test_place_selon_nombre_de_partants():
    assert F.nb_places_payees(8) == 3
    assert F.nb_places_payees(7) == 2
    assert F.nb_places_payees(4) == 2
    assert F.nb_places_payees(3) == 1


def test_rang_relatif():
    assert F.rang_relatif(1, True, 10) == 0.0
    assert F.rang_relatif(10, True, 10) == 1.0
    assert F.rang_relatif(None, False, 10) == 1.0
    assert F.rang_relatif(1, True, 1) is None


def test_donnee_manquante_cellule_vide():
    b = ConstructeurFeatures()
    lignes = b.traiter_jour([course(1, D1, [partant(1, 10, rang=1), partant(2, 20)], discipline="trot", terrain=None)])
    l = par_num(lignes)[1]
    assert l["f_place_corde"] is None
    assert l["f_handicap_valeur"] is None
    assert l["f_deferre"] is None
    assert l["f_terrain"] is None
    assert l["f_gains_par_course"] is None
    assert l["f_rk_meilleure_disc"] is None and l["f_rk_nb_disc"] == 0


def test_terrain_galop_seulement():
    b = ConstructeurFeatures()
    lignes = b.traiter_jour([
        course(1, D1, [partant(1, 10)], discipline="plat", terrain="Souple"),
        course(2, D1, [partant(1, 20)], discipline="trot", terrain="Souple"),
    ])
    assert par_num(lignes, 1)[1]["f_terrain"] == "Souple"
    assert par_num(lignes, 2)[1]["f_terrain"] is None


def test_reduction_km_passee_trot():
    b = ConstructeurFeatures()
    b.traiter_jour([course(1, D1, [partant(1, 10, rang=1, reductionKilometrique=74800), partant(2, 20, rang=2)],
                          discipline="trot", distance=2100.0)])
    b.traiter_jour([course(2, D2, [partant(1, 10, rang=2, reductionKilometrique=76000), partant(2, 20, rang=1)],
                          discipline="trot", distance=2850.0)])
    l = par_num(b.traiter_jour([course(3, D2 + timedelta(days=7), [partant(1, 10), partant(3, 30)],
                                       discipline="trot", distance=2150.0)]))[1]
    assert l["f_rk_meilleure_disc"] == pytest.approx(74.8)
    assert l["f_rk_moy_disc"] == pytest.approx(75.4)
    assert l["f_rk_nb_disc"] == 2
    assert l["f_rk_meilleure_bande"] == pytest.approx(74.8) and l["f_rk_nb_bande"] == 1


def test_champs_avant_course_lus():
    b = ConstructeurFeatures()
    p = partant(
        1, 10, age=5, sexe="FEMELLES", musique="1a(24)3aDa", nombreCourses=10, nombreVictoires=2, nombrePlaces=5,
        gainsParticipant={"gainsCarriere": 1000000}, driverChange=True, deferre="DEFERRE_ANTERIEURS",
        oeilleres="SANS_OEILLERES", handicapDistance=2125, avisEntraineur="POSITIF", indicateurInedit=False,
    )
    l = par_num(b.traiter_jour([course(1, D1, [p, partant(2, 20)], discipline="trot", distance=2100.0)]))[1]
    assert l["f_age"] == 5 and l["f_sexe"] == "FEMELLES"
    assert (l["f_musique_nb"], l["f_musique_moy"], l["f_musique_victoires"]) == (3, pytest.approx(14 / 3), 1)
    assert l["f_taux_victoire_carriere"] == 0.2 and l["f_taux_place_carriere"] == 0.5
    assert l["f_gains_par_course"] == 1000.0
    assert l["f_driver_change"] == 1 and l["f_inedit"] == 0
    assert l["f_recul"] == 25 and l["f_handicap_distance"] == 2125
    assert l["f_deferre"] == "DEFERRE_ANTERIEURS" and l["f_avis_entraineur"] == "POSITIF"


def test_rang_du_taux_dans_le_champ():
    b = ConstructeurFeatures()
    b.traiter_jour([
        course(1, D1, [partant(1, 10, rang=1), partant(2, 20, rang=2)]),
        course(2, D1, [partant(1, 30, rang=2), partant(2, 40, rang=1)]),
    ])
    lignes = par_num(b.traiter_jour([course(3, D2, [partant(1, 10), partant(2, 30), partant(3, 50)])]))
    assert lignes[1]["f_taux_victoire_6_rang_champ"] == 0.0
    assert lignes[2]["f_taux_victoire_6_rang_champ"] == 1.0
    assert lignes[1]["f_taux_victoire_6_ecart_champ"] == 0.5
    assert lignes[3]["f_taux_victoire_6_rang_champ"] is None
    assert all(l["f_nb_champ_taux_victoire_6"] == 2 for l in lignes.values())
    assert lignes[1]["f_nb_rang_rel_3"] == 1 and lignes[3]["f_nb_rang_rel_3"] == 0


def test_jours_dans_le_desordre_refuses():
    b = ConstructeurFeatures()
    b.traiter_jour([course(1, D2, [partant(1, 10)])])
    with pytest.raises(ValueError):
        b.traiter_jour([course(2, D1, [partant(1, 10)])])


# --- Garde-fou anti-fuite ----------------------------------------------------

def test_registre_aucune_source_interdite():
    for col in F.COLONNES:
        if col.groupe != "feature":
            continue
        assert col.nom.startswith("f_")
        assert col.avant_course
        assert col.sources
        for source in col.sources:
            origine, _, champ = source.partition(".")
            assert origine in ("partant", "course", "historique"), source
            if origine == "historique":
                continue
            assert champ not in F.CHAMPS_INTERDITS, f"{col.nom} lit {source}"
            autorises = F.CHAMPS_PARTANT_AVANT_COURSE if origine == "partant" else F.CHAMPS_COURSE_AVANT_COURSE
            assert champ in autorises, f"{col.nom} lit {source}, hors liste avant course"


def test_registre_groupes_et_colonnes_calculees():
    groupes = {c.nom: c.groupe for c in F.COLONNES}
    assert [n for n, g in groupes.items() if g == "id"] == ["course_id", "date", "discipline", "num_pmu"]
    assert {n for n, g in groupes.items() if g == "label"} == {"rang", "gagnant", "place"}
    assert {n for n, g in groupes.items() if g == "marche"} == {"cote_reference", "cote_direct"}
    assert not set(F.NOMS_FEATURES) & {"rang", "gagnant", "place", "cote_reference", "cote_direct"}
    b = ConstructeurFeatures()
    lignes = b.traiter_jour([course(1, D1, [partant(1, 10), partant(2, 20)])])
    assert set(lignes[0]) == set(F.NOMS_COLONNES)


def test_vue_avant_course_sans_champ_interdit():
    p = partant(1, 10, rang=1, ordreArrivee=1, tempsObtenu=1, reductionKilometrique=1,
                dernierRapportDirect={"rapport": 2.0}, dernierRapportReference={"rapport": 3.0},
                commentaireApresCourse="x", distanceChevalPrecedent={"x": 1}, incident="x")
    vue = F.vue_avant_course(p)
    assert not set(vue) & F.CHAMPS_INTERDITS
    assert set(vue) <= F.CHAMPS_PARTANT_AVANT_COURSE


def _historique_puis_course(perturber):
    """Jour 1 : historique. Jour 2 : la course dont on regarde les features,
    éventuellement perturbée (résultat, cotes, champs après course)."""
    b = ConstructeurFeatures()
    b.traiter_jour([course(1, D1, [
        partant(1, 10, rang=1, reductionKilometrique=75000, driver="A"),
        partant(2, 20, rang=2, reductionKilometrique=76000, driver="B"),
        partant(3, 30, incident="ARRETE", driver="C"),
    ], discipline="trot")])
    jour2 = course(2, D2, [
        partant(1, 10, rang=3, driver="A", musique="1a2a", nombreCourses=5),
        partant(2, 20, rang=1, driver="B", reductionKilometrique=74000, tempsObtenu=180000),
        partant(3, 30, rang=2, driver="C"),
        partant(4, 40, rang=4, driver="A2"),
    ], discipline="trot")
    # Autre course du même jour, mêmes pères et drivers que la course
    # observée : son résultat et un statut sont perturbés aussi.
    voisine = course(3, D2, [
        partant(1, 50, rang=1, driver="A", nomPere="PERE 10"),
        partant(2, 60, rang=2, driver="B", nomPere="PERE 20"),
        partant(3, 70, rang=3, driver="C"),
    ], discipline="trot")
    if perturber:
        voisine.partants[0].rang_arrivee, voisine.partants[1].rang_arrivee = 2, 1
        voisine.partants[2].brut["statut"] = "NON_PARTANT"
        voisine.partants[2].rang_arrivee = None
        rangs = {1: 1, 2: None, 3: 4, 4: 2}
        for p in jour2.partants:
            p.rang_arrivee = rangs[p.num_pmu]
            p.incident = "DISQUALIFIE_POUR_ALLURE_IRREGULIERE" if p.num_pmu == 2 else None
            p.cote_direct = 99.0
            p.cote_reference = 42.0
            p.brut.update({
                "ordreArrivee": rangs[p.num_pmu], "incident": "ARRETE", "tempsObtenu": 1,
                "reductionKilometrique": 1, "distanceChevalPrecedent": {"libelleCourt": "Nez"},
                "commentaireApresCourse": {"texte": "fuite"}, "dernierRapportDirect": {"rapport": 99.0},
                "dernierRapportReference": {"rapport": 42.0},
            })
    lignes = b.traiter_jour([jour2, voisine])
    return {n: {k: v for k, v in l.items() if k in F.NOMS_FEATURES} for n, l in par_num(lignes, 2).items()}


def test_perturbation_du_resultat_ne_change_pas_les_features():
    assert _historique_puis_course(False) == _historique_puis_course(True)


def test_perturbation_change_les_labels():
    # Contrôle du test précédent : la perturbation touche bien la course.
    b = ConstructeurFeatures()
    base = course(1, D1, [partant(1, 10, rang=1), partant(2, 20, rang=2)])
    autre = copy.deepcopy(base)
    autre.partants[0].rang_arrivee, autre.partants[1].rang_arrivee = 2, 1
    l1 = par_num(b.traiter_jour([base]))
    l2 = par_num(ConstructeurFeatures().traiter_jour([autre]))
    assert l1[1]["gagnant"] != l2[1]["gagnant"]
