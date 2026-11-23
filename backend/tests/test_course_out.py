"""Story 8.9 : CourseOut expose la référence PMU (AD-12) en ajout additif."""

from datetime import date, datetime
from types import SimpleNamespace

from app.schemas.course import CourseOut


def _course(**surcharges):
    champs = dict(
        id=7,
        date=date(2026, 11, 23),
        heure_depart=datetime(2026, 11, 23, 14, 5),
        numero_reunion=1,
        numero_course=4,
        hippodrome="VINCENNES",
        discipline="ATTELE",
        distance=2700.0,
        allocation=None,
        nb_partants=14,
        corde=None,
        terrain=None,
        niveau_estime=None,
        finalisee=False,
        source="pmu",
    )
    champs.update(surcharges)
    return SimpleNamespace(**champs)


def test_cle_course_au_format_aaaammjj_rn_cn():
    out = CourseOut.model_validate(_course())
    assert out.numero_reunion == 1
    assert out.numero_course == 4
    assert out.cle_course == "20261123-R1-C4"


def test_cle_course_sans_zero_de_remplissage():
    out = CourseOut.model_validate(_course(date=date(2026, 1, 5), numero_reunion=12, numero_course=10))
    assert out.cle_course == "20260105-R12-C10"


def test_cle_course_nulle_si_un_numero_manque():
    assert CourseOut.model_validate(_course(numero_reunion=None)).cle_course is None
    assert CourseOut.model_validate(_course(numero_course=None)).cle_course is None
    assert CourseOut.model_validate(_course(numero_reunion=None, numero_course=None)).cle_course is None


def test_json_contient_les_trois_champs_et_garde_les_existants():
    data = CourseOut.model_validate(_course()).model_dump(mode="json")
    assert data["cle_course"] == "20261123-R1-C4"
    assert data["numero_reunion"] == 1
    assert data["numero_course"] == 4
    assert data["id"] == 7
    assert data["date"] == "2026-11-23"
    assert data["heure_depart"].endswith("Z") or data["heure_depart"].endswith("+00:00")


def test_json_cle_nulle_pour_course_sans_numeros():
    data = CourseOut.model_validate(_course(numero_reunion=None, numero_course=None)).model_dump(mode="json")
    assert data["cle_course"] is None
    assert data["numero_reunion"] is None


def test_cle_course_nulle_si_un_numero_vaut_zero_ou_moins():
    assert CourseOut.model_validate(_course(numero_reunion=0)).cle_course is None
    assert CourseOut.model_validate(_course(numero_course=0)).cle_course is None
    assert CourseOut.model_validate(_course(numero_course=-1)).cle_course is None
