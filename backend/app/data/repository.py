import json
import logging
import os
from datetime import date, datetime
from typing import List, Optional

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session, selectinload

from app.data.models import (
    Base, Course, Cheval, Participation, PerformanceHistorique, PredictionCheval, PredictionRun,
)
from app.data.pmu_client import (
    STATUS_TO_INCIDENT, CourseInfo, PartantInfo, PerformancePassee, _normalize_name,
)
from app.engine.constants import terrain_coefficient
from app.engine.evaluation import ChevalPredit, CoursePredite, evaluer_paris
from app.engine.scoring import HorseAnalysis, Performance

logger = logging.getLogger(__name__)

DEFAULT_DATABASE_URL = "sqlite:///./hippique.db"


class Repository:
    def __init__(self, database_url: Optional[str] = None):
        if database_url is None:
            database_url = os.environ.get("DATABASE_URL", DEFAULT_DATABASE_URL)
        self.engine = create_engine(database_url, connect_args={"check_same_thread": False})
        Base.metadata.create_all(self.engine)
        self._migrate()

    def _migrate(self) -> None:
        """Pas d'Alembic pour ce projet perso (section 6.4 du document
        backend) : ajout défensif des colonnes manquantes sur les tables déjà
        créées avant qu'un champ n'existe."""
        inspector = inspect(self.engine)

        courses_columns = {col["name"] for col in inspector.get_columns("courses")}
        if "heure_depart" not in courses_columns:
            with self.engine.begin() as conn:
                conn.execute(text("ALTER TABLE courses ADD COLUMN heure_depart DATETIME"))

        perf_columns = {col["name"] for col in inspector.get_columns("performances_historiques")}
        if "cheval_id" not in perf_columns:
            # SQLite ne permet pas de rendre participation_id nullable ni
            # d'ajouter une colonne NOT NULL sans défaut sur une table déjà
            # peuplée : on recrée la table cible et on migre les lignes
            # existantes (rattachées au cheval de leur participation).
            with self.engine.begin() as conn:
                conn.execute(text("""
                    CREATE TABLE performances_historiques_new (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        cheval_id INTEGER NOT NULL REFERENCES chevaux(id),
                        participation_id INTEGER REFERENCES participations(id),
                        date_course DATE,
                        hippodrome VARCHAR(128),
                        discipline VARCHAR(32),
                        allocation FLOAT,
                        distance FLOAT,
                        nb_participants INTEGER,
                        rang INTEGER,
                        terrain VARCHAR(64),
                        incident VARCHAR(16),
                        source VARCHAR(16) DEFAULT 'pmu'
                    )
                """))
                conn.execute(text("""
                    INSERT INTO performances_historiques_new
                        (id, cheval_id, participation_id, date_course, hippodrome, discipline,
                         allocation, distance, nb_participants, rang, terrain, incident, source)
                    SELECT ph.id, p.cheval_id, ph.participation_id, ph.date_course, ph.hippodrome,
                           ph.discipline, ph.allocation, ph.distance, ph.nb_participants, ph.rang,
                           ph.terrain, ph.incident, 'pmu'
                    FROM performances_historiques ph
                    JOIN participations p ON p.id = ph.participation_id
                """))
                conn.execute(text("DROP TABLE performances_historiques"))
                conn.execute(text("ALTER TABLE performances_historiques_new RENAME TO performances_historiques"))

        index_names = {idx["name"] for idx in inspector.get_indexes("performances_historiques")}
        if "uq_perf_hist_cheval_date_hippo" not in index_names:
            with self.engine.begin() as conn:
                # Dédoublonnage préalable (sinon la création de l'index
                # unique échoue) : conserve la ligne au plus petit id par
                # groupe. Exclut explicitement date_course IS NULL : un
                # index unique SQLite traite les NULL comme tous distincts
                # les uns des autres, GROUP BY non - ne pas fusionner à tort
                # des lignes à date inconnue qui n'ont rien à voir entre elles.
                conn.execute(text("""
                    DELETE FROM performances_historiques
                    WHERE date_course IS NOT NULL
                    AND id NOT IN (
                        SELECT MIN(id) FROM performances_historiques
                        WHERE date_course IS NOT NULL
                        GROUP BY cheval_id, date_course, hippodrome
                    )
                """))
                conn.execute(text("""
                    CREATE UNIQUE INDEX uq_perf_hist_cheval_date_hippo
                    ON performances_historiques (cheval_id, date_course, hippodrome)
                """))

        run_columns = {col["name"] for col in inspect(self.engine).get_columns("prediction_runs")}
        colonnes_app = {
            "installation_id": "VARCHAR(64)",
            "donnees_modifiees": "BOOLEAN",
            "reglages_par_defaut": "BOOLEAN",
            "terrain_modifie": "BOOLEAN",
            "parametres": "TEXT",
            "combinaisons": "TEXT",
        }
        for nom, type_sql in colonnes_app.items():
            if nom not in run_columns:
                with self.engine.begin() as conn:
                    conn.execute(text(f"ALTER TABLE prediction_runs ADD COLUMN {nom} {type_sql}"))

        cheval_columns = {col["name"] for col in inspect(self.engine).get_columns("prediction_chevaux")}
        for nom in ("top2", "top3", "top4", "value", "mise"):
            if nom not in cheval_columns:
                with self.engine.begin() as conn:
                    conn.execute(text(f"ALTER TABLE prediction_chevaux ADD COLUMN {nom} FLOAT"))

        perf_columns = {col["name"] for col in inspect(self.engine).get_columns("performances_historiques")}
        if "rang_impute" not in perf_columns:
            with self.engine.begin() as conn:
                conn.execute(text(
                    "ALTER TABLE performances_historiques ADD COLUMN rang_impute BOOLEAN NOT NULL DEFAULT 0"
                ))

        participation_columns = {col["name"] for col in inspect(self.engine).get_columns("participations")}
        for nom in ("cote_reference_le", "cote_direct_le"):
            if nom not in participation_columns:
                with self.engine.begin() as conn:
                    conn.execute(text(f"ALTER TABLE participations ADD COLUMN {nom} DATETIME"))

    def list_courses_for_date(self, target_date: date) -> List[Course]:
        with Session(self.engine) as session:
            return session.query(Course).filter(Course.date == target_date).all()

    def get_course_by_id(self, course_id: int) -> Optional[Course]:
        with Session(self.engine) as session:
            return session.query(Course).options(
                selectinload(Course.participations)
                .selectinload(Participation.cheval)
                .selectinload(Cheval.performances_historiques),
            ).filter(Course.id == course_id).one_or_none()

    def get_horses_for_course(self, course: Course, avant: Optional[date] = None) -> List[HorseAnalysis]:
        """`avant` : ne retenir que les performances strictement antérieures
        à cette date (rejeu d'une course passée, sans fuite de son arrivée)."""
        with Session(self.engine) as session:
            course = session.get(Course, course.id)
            horses = []
            for participation in course.participations:
                cheval = participation.cheval
                # Les plus récentes d'abord (C1..) : le moteur (section 7.3)
                # suppose cet ordre et tronque au 6 éléments les plus récents
                # (compute_forme) — nécessaire depuis que le backfill peut
                # produire un historique plus profond que 6 performances.
                perfs_triees = sorted(
                    (p for p in cheval.performances_historiques
                     if avant is None or (p.date_course is not None and p.date_course < avant)),
                    key=lambda p: p.date_course or date.min,
                    reverse=True,
                )
                performances = [
                    Performance(
                        partants=perf.nb_participants or 0,
                        rang=perf.rang,
                        distance=perf.distance,
                        terrain=terrain_coefficient(perf.terrain),
                        niveau=None,
                        incident=perf.incident,
                    )
                    for perf in perfs_triees
                ]
                horses.append(HorseAnalysis(
                    nom=cheval.nom_normalise,
                    num_pmu=participation.num_pmu,
                    age=participation.age_a_la_course,
                    poids=participation.poids,
                    cote=participation.cote_reference or participation.cote_direct,
                    inedit=participation.inedit,
                    performances=performances,
                ))
            return horses

    def upsert_course(self, info: CourseInfo) -> Course:
        with Session(self.engine) as session:
            course = session.query(Course).filter(
                Course.date == info.date,
                Course.numero_reunion == info.numero_reunion,
                Course.numero_course == info.numero_course,
            ).one_or_none()
            if course is None:
                course = Course(date=info.date, numero_reunion=info.numero_reunion, numero_course=info.numero_course)
                session.add(course)

            course.libelle = info.libelle
            course.hippodrome = info.hippodrome
            course.discipline = info.discipline
            course.distance = info.distance
            course.allocation = info.allocation
            course.corde = info.corde
            course.nb_partants = info.nb_partants_declares
            course.heure_depart = info.heure_depart
            # Le pénétromètre n'est mesuré que le matin de la course : une
            # ingestion antérieure (ou une réponse partielle) ne doit pas
            # effacer une mesure déjà obtenue.
            if info.terrain is not None:
                course.terrain = info.terrain
            course.source = "pmu"
            session.commit()
            session.refresh(course)
            return course

    def upsert_cheval(self, session: Session, nom: str) -> Cheval:
        nom_normalise = _normalize_name(nom)
        cheval = session.query(Cheval).filter(Cheval.nom_normalise == nom_normalise).one_or_none()
        if cheval is None:
            cheval = Cheval(nom_normalise=nom_normalise)
            session.add(cheval)
            session.flush()
        return cheval

    def get_cheval_by_id(self, cheval_id: int) -> Optional[Cheval]:
        with Session(self.engine) as session:
            return session.query(Cheval).options(
                selectinload(Cheval.performances_historiques)
            ).filter(Cheval.id == cheval_id).one_or_none()

    def derniere_participation(self, cheval_id: int) -> Optional[Course]:
        """Course la plus récente (par date) à laquelle ce cheval a participé,
        ou None s'il n'est connu que par son historique. Sert de point d'entrée
        au rafraîchissement de son historique (POST /chevaux/{id}/backfill) :
        performances-detaillees de cette course donne ses dernières courses."""
        with Session(self.engine) as session:
            # Sans numéro de réunion/course, l'URL turfinfo est impossible à
            # construire : une telle course n'est jamais retenue.
            return session.query(Course).join(Participation).filter(
                Participation.cheval_id == cheval_id,
                Course.numero_reunion.isnot(None),
                Course.numero_course.isnot(None),
            ).order_by(Course.date.desc(), Course.heure_depart.desc(), Course.id.desc()).first()

    def save_partants(self, course_id: int, partants: List[PartantInfo]) -> None:
        with Session(self.engine) as session:
            course = session.get(Course, course_id)
            for partant in partants:
                cheval = self.upsert_cheval(session, partant.nom)
                participation = session.query(Participation).filter(
                    Participation.course_id == course.id,
                    Participation.cheval_id == cheval.id,
                ).one_or_none()
                if participation is None:
                    participation = Participation(course_id=course.id, cheval_id=cheval.id)
                    session.add(participation)

                participation.num_pmu = partant.num_pmu
                participation.age_a_la_course = partant.age
                participation.poids = partant.handicap_poids
                participation.cote_reference = partant.cote_reference
                participation.cote_direct = partant.cote_direct
                participation.cote_reference_le = partant.cote_reference_le
                participation.cote_direct_le = partant.cote_direct_le
                participation.rang_arrivee = partant.ordre_arrivee
                participation.incident = partant.incident
                participation.inedit = partant.inedit
                participation.driver = partant.driver_jockey
                participation.entraineur = partant.entraineur
                participation.donnees_brutes = json.dumps(partant.raw, ensure_ascii=False)
            session.commit()

    def save_historique(self, course_id: int, historique: dict) -> None:
        """historique: dict[num_pmu, list[PerformancePassee]] issu de pmu_client.get_historique.
        Upsert par (cheval_id, date_course, hippodrome) : source='pmu'
        (turfinfo, la plus proche du PMU officiel) écrase toujours une ligne
        en conflit sur cette clé, y compris une ancienne ligne open-pmu-api
        - voir la contrainte d'unicité dans models.py.

        Une seule ligne par cheval et par jour : performances-detaillees
        nomme les hippodromes autrement que le programme (CAGNES-SUR-MER vs
        CAGNES/MER), donc une ligne du même jour sous un autre nom (dérivée
        par deriver_historique_course) est remplacée, pas doublée."""
        with Session(self.engine) as session:
            course = session.get(Course, course_id)
            participations = {p.num_pmu: p for p in course.participations}
            ecrits = set()
            for num_pmu, performances in historique.items():
                participation = participations.get(num_pmu)
                if participation is None:
                    continue
                for perf in performances:
                    valeurs = {
                        "cheval_id": participation.cheval_id,
                        "participation_id": participation.id,
                        "date_course": perf.date,
                        "hippodrome": perf.hippodrome,
                        "discipline": perf.discipline,
                        "allocation": perf.allocation,
                        "distance": perf.distance,
                        "nb_participants": perf.nb_participants,
                        "rang": perf.rang,
                        "rang_impute": perf.rang_impute,
                        "terrain": perf.terrain,
                        "incident": perf.incident,
                        "source": "pmu",
                    }
                    # Le même jour sous un autre nom d'hippodrome (le programme et
                    # performances-detaillees ne l'écrivent pas pareil) : une
                    # seule ligne par cheval et par jour. Sans hippodrome, ou si
                    # cet appel a déjà écrit ce jour pour ce cheval, on ne
                    # supprime rien.
                    jour_cheval = (participation.cheval_id, perf.date)
                    if perf.date is not None and perf.hippodrome is not None and jour_cheval not in ecrits:
                        session.query(PerformanceHistorique).filter(
                            PerformanceHistorique.cheval_id == participation.cheval_id,
                            PerformanceHistorique.date_course == perf.date,
                            PerformanceHistorique.hippodrome.is_distinct_from(perf.hippodrome),
                        ).delete(synchronize_session=False)
                    stmt = sqlite_insert(PerformanceHistorique).values(**valeurs)
                    stmt = stmt.on_conflict_do_update(
                        index_elements=["cheval_id", "date_course", "hippodrome"],
                        set_={k: v for k, v in valeurs.items() if k not in ("cheval_id", "date_course", "hippodrome")},
                    )
                    session.execute(stmt)
                    ecrits.add(jour_cheval)
            session.commit()

    def course_complete(self, target_date: date, numero_reunion: int, numero_course: int) -> bool:
        """Course déjà stockée, finalisée et avec ses participations : la
        reconstruction de l'historique n'a pas à la redemander."""
        with Session(self.engine) as session:
            return session.query(Participation.id).join(Course).filter(
                Course.date == target_date,
                Course.numero_reunion == numero_reunion,
                Course.numero_course == numero_course,
                Course.finalisee.is_(True),
            ).first() is not None

    def marquer_finalisee(self, course_id: int) -> None:
        with Session(self.engine) as session:
            course = session.get(Course, course_id)
            course.finalisee = True
            session.commit()

    def deriver_historique_course(self, course_id: int, partants: List[PartantInfo]) -> int:
        """Une ligne d'historique par partant effectif (statut PARTANT) d'une
        course à l'arrivée définitive, tirée de la course elle-même et de
        son arrivée. Jamais écrite si le cheval a déjà une ligne ce jour-là
        (souvent la même course sous un autre nom d'hippodrome, venue de
        performances-detaillees). Retourne le nombre de lignes écrites."""
        partants_effectifs = [p for p in partants if p.statut == "PARTANT"]
        nb_participants = len(partants_effectifs)
        ecrites = 0
        with Session(self.engine) as session:
            course = session.get(Course, course_id)
            participations = {p.num_pmu: p for p in course.participations}
            for partant in partants_effectifs:
                participation = participations.get(partant.num_pmu)
                if participation is None:
                    continue
                deja_la = session.query(PerformanceHistorique.id).filter(
                    PerformanceHistorique.cheval_id == participation.cheval_id,
                    PerformanceHistorique.date_course == course.date,
                ).first()
                if deja_la is not None:
                    continue
                incident = None
                if partant.incident:
                    incident = STATUS_TO_INCIDENT.get(partant.incident)
                    if incident is None:
                        # Jamais deviné : un incident inconnu reste absent.
                        logger.warning(
                            "incident non traduit : %r (course %s, num %s)",
                            partant.incident, course_id, partant.num_pmu,
                        )
                session.add(PerformanceHistorique(
                    cheval_id=participation.cheval_id,
                    participation_id=participation.id,
                    date_course=course.date,
                    hippodrome=course.hippodrome,
                    discipline=course.discipline,
                    allocation=course.allocation,
                    distance=course.distance,
                    nb_participants=nb_participants,
                    rang=partant.ordre_arrivee,
                    rang_impute=False,
                    terrain=course.terrain,
                    incident=incident,
                    source="pmu",
                ))
                ecrites += 1
            session.commit()
        return ecrites

    def update_resultats(self, course_id: int, partants: List[PartantInfo], arrivee_definitive: bool) -> None:
        with Session(self.engine) as session:
            course = session.get(Course, course_id)
            by_num_pmu = {p.num_pmu: p for p in partants}
            for participation in course.participations:
                partant = by_num_pmu.get(participation.num_pmu)
                if partant is None:
                    continue
                participation.rang_arrivee = partant.ordre_arrivee
                participation.incident = partant.incident
            course.finalisee = arrivee_definitive
            session.commit()

    def get_unfinalized_courses_before(self, target_date: date) -> List[Course]:
        with Session(self.engine) as session:
            return session.query(Course).filter(
                Course.date < target_date,
                Course.finalisee.is_(False),
            ).all()

    def save_prediction_run(
        self,
        course_id: int,
        analyses: List[HorseAnalysis],
        variante: str,
        cree_le: datetime,
        manques: List[str],
        installation_id: Optional[str] = None,
        donnees_modifiees: Optional[bool] = None,
        reglages_par_defaut: Optional[bool] = None,
        terrain_modifie: Optional[bool] = None,
        parametres: Optional[dict] = None,
        combinaisons: Optional[dict] = None,
    ) -> int:
        with Session(self.engine) as session:
            run = PredictionRun(
                course_id=course_id,
                cree_le=cree_le,
                variante=variante,
                degradee=bool(manques),
                manques=json.dumps(manques),
                installation_id=installation_id,
                donnees_modifiees=donnees_modifiees,
                reglages_par_defaut=reglages_par_defaut,
                terrain_modifie=terrain_modifie,
                parametres=json.dumps(parametres) if parametres is not None else None,
                combinaisons=json.dumps(combinaisons) if combinaisons is not None else None,
                chevaux=[
                    PredictionCheval(
                        num_pmu=a.num_pmu, probabilite=a.probabilite, cote=a.cote,
                        top2=a.top2, top3=a.top3, top4=a.top4, value=a.value, mise=a.mise,
                    )
                    # Les outsiders virtuels (num_pmu None) ne servent qu'au
                    # calcul des probabilités : ils n'ont pas d'arrivée.
                    for a in analyses if a.num_pmu is not None
                ],
            )
            session.add(run)
            session.commit()
            return run.id

    def courses_evaluables(self, variante: str) -> List[CoursePredite]:
        with Session(self.engine) as session:
            requete = session.query(PredictionRun, Course).join(Course, Course.id == PredictionRun.course_id).filter(
                PredictionRun.variante == variante,
            )
            # Seul un pronostic fait avant le départ compte, qu'il vienne du
            # moteur automatique ou d'un utilisateur de l'app.
            if variante in ("live", "app"):
                requete = requete.filter(
                    Course.heure_depart.is_not(None),
                    PredictionRun.cree_le <= Course.heure_depart,
                )
            # Le dernier avant le départ, par course et par utilisateur
            # (installation_id vaut None pour le moteur automatique).
            dernier_par_course = {}
            for run, course in requete.order_by(PredictionRun.cree_le):
                dernier_par_course[(course.id, run.installation_id)] = (run, course)

            resultat = []
            for run, course in dernier_par_course.values():
                rangs = {p.num_pmu: p.rang_arrivee for p in course.participations}
                arrivee = [n for n, r in sorted(((n, r) for n, r in rangs.items() if r), key=lambda x: x[1])]
                resultat.append(CoursePredite(
                    discipline=course.discipline,
                    degradee=run.degradee,
                    course_id=course.id,
                    installation_id=run.installation_id,
                    donnees_modifiees=bool(run.donnees_modifiees),
                    combinaisons=json.loads(run.combinaisons) if run.combinaisons else None,
                    arrivee=arrivee,
                    nb_partants=course.nb_partants or len(course.participations),
                    chevaux=[
                        ChevalPredit(
                            num_pmu=c.num_pmu, probabilite=c.probabilite, cote=c.cote,
                            rang_arrivee=rangs.get(c.num_pmu),
                        )
                        for c in sorted(run.chevaux, key=lambda c: c.num_pmu)
                    ],
                ))
            return resultat

    def pronostics_du_jour(self, jour: date, variante: str) -> List[dict]:
        """Le pronostic retenu pour chaque course du jour (par utilisateur pour
        l'app) : son top 3 et, une fois l'arrivée connue, s'il a vu juste."""
        with Session(self.engine) as session:
            requete = session.query(PredictionRun, Course).join(Course, Course.id == PredictionRun.course_id).filter(
                Course.date == jour,
                PredictionRun.variante == variante,
            )
            if variante in ("live", "app"):
                requete = requete.filter(
                    Course.heure_depart.is_not(None),
                    PredictionRun.cree_le <= Course.heure_depart,
                )
            retenus = {}
            for run, course in requete.order_by(PredictionRun.cree_le):
                retenus[(course.id, run.installation_id)] = (run, course)

            lignes = []
            for run, course in retenus.values():
                noms = {p.num_pmu: p.cheval.nom_normalise for p in course.participations}
                gagnant = next((p.num_pmu for p in course.participations if p.rang_arrivee == 1), None)
                arrivee = [p.num_pmu for p in sorted(
                    (p for p in course.participations if p.rang_arrivee), key=lambda p: p.rang_arrivee)]
                classement = [c.num_pmu for c in sorted(run.chevaux, key=lambda c: c.probabilite, reverse=True)]
                probas = {c.num_pmu: c.probabilite for c in run.chevaux}
                if gagnant is None:
                    statut = "en_attente"
                elif classement[:1] == [gagnant]:
                    statut = "trouve"
                elif gagnant in classement[:3]:
                    statut = "top3"
                else:
                    statut = "rate"
                lignes.append({
                    "course_id": course.id,
                    "reunion": course.numero_reunion,
                    "course": course.numero_course,
                    "hippodrome": course.hippodrome,
                    "discipline": course.discipline,
                    "heure_depart": course.heure_depart.isoformat() if course.heure_depart else None,
                    "installation_id": run.installation_id,
                    "cree_le": run.cree_le.isoformat(),
                    "donnees_modifiees": bool(run.donnees_modifiees),
                    "degradee": run.degradee,
                    "top3": [
                        {"num_pmu": n, "nom": noms.get(n), "probabilite": probas[n]} for n in classement[:3]
                    ],
                    "gagnant": {"num_pmu": gagnant, "nom": noms.get(gagnant)} if gagnant is not None else None,
                    "statut": statut,
                    "paris": evaluer_paris(
                        json.loads(run.combinaisons) if run.combinaisons else None, arrivee,
                        course.nb_partants or len(course.participations), classement[0] if classement else None,
                    ) if gagnant is not None else {},
                })
            return sorted(lignes, key=lambda l: (l["heure_depart"] or "", l["reunion"] or 0, l["course"] or 0,
                                                 l["installation_id"] or ""))

    def suivi_du_jour(self, jour: date) -> dict:
        """Avancement des pronostics « avant course » d'une journée."""
        with Session(self.engine) as session:
            courses = session.query(Course).filter(Course.date == jour).all()
            pronostiquees = evaluees = degradees = 0
            for course in courses:
                if course.heure_depart is None:
                    continue
                dernier = session.query(PredictionRun).filter(
                    PredictionRun.course_id == course.id,
                    PredictionRun.variante == "live",
                    PredictionRun.cree_le <= course.heure_depart,
                ).order_by(PredictionRun.cree_le.desc()).first()
                if dernier is None:
                    continue
                pronostiquees += 1
                degradees += dernier.degradee
                evaluees += any(p.rang_arrivee == 1 for p in course.participations)
            pronostics_app = session.query(PredictionRun).join(Course, Course.id == PredictionRun.course_id).filter(
                Course.date == jour,
                PredictionRun.variante == "app",
            ).with_entities(PredictionRun.installation_id).all()
            return {
                "jour": jour.isoformat(),
                "courses": len(courses),
                "pronostiquees": pronostiquees,
                "evaluees": evaluees,
                "en_attente": pronostiquees - evaluees,
                "degradees": degradees,
                "pronostics_app": len(pronostics_app),
                "utilisateurs": len({i for (i,) in pronostics_app}),
            }

    def import_course(self, course_id: int) -> None:
        pass
