import json
import os
from datetime import date
from typing import List, Optional

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session, selectinload

from app.data.models import Base, Course, Cheval, Participation, PerformanceHistorique
from app.data.pmu_client import CourseInfo, PartantInfo, PerformancePassee, _normalize_name
from app.engine.constants import terrain_coefficient
from app.engine.scoring import HorseAnalysis, Performance

DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///./hippique.db")


class Repository:
    def __init__(self, database_url: str = DATABASE_URL):
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

    def get_horses_for_course(self, course: Course) -> List[HorseAnalysis]:
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
                    cheval.performances_historiques,
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

    def get_hippodromes_connus(self, cheval_id: int) -> List[str]:
        """Hippodromes déjà présents dans l'historique de ce cheval — sert de
        point de départ au backfill ciblé (POST /chevaux/{id}/backfill) :
        interroger open-pmu-api par hippodrome connu plutôt que de scanner
        des mois de dates une par une (section performances-detaillees
        limitée à 5 courses, backfill open_pmu_client.py)."""
        with Session(self.engine) as session:
            rows = session.query(PerformanceHistorique.hippodrome).filter(
                PerformanceHistorique.cheval_id == cheval_id,
                PerformanceHistorique.hippodrome.isnot(None),
            ).distinct().all()
            return [r[0] for r in rows if r[0]]

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
        en conflit sur cette clé, y compris une ligne issue du backfill
        open-pmu-api - voir la contrainte d'unicité dans models.py."""
        with Session(self.engine) as session:
            course = session.get(Course, course_id)
            participations = {p.num_pmu: p for p in course.participations}
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
                        "terrain": None,
                        "incident": perf.incident,
                        "source": "pmu",
                    }
                    stmt = sqlite_insert(PerformanceHistorique).values(**valeurs)
                    stmt = stmt.on_conflict_do_update(
                        index_elements=["cheval_id", "date_course", "hippodrome"],
                        set_={k: v for k, v in valeurs.items() if k not in ("cheval_id", "date_course", "hippodrome")},
                    )
                    session.execute(stmt)
            session.commit()

    def ajouter_performance_historique_backfill(
        self,
        nom_cheval: str,
        date_course: Optional[date],
        hippodrome: Optional[str],
        discipline: Optional[str],
        allocation: Optional[float],
        distance: Optional[float],
        nb_participants: Optional[int],
        rang: Optional[int],
        incident: Optional[str],
    ) -> bool:
        """Ajoute une ligne d'historique issue du backfill (open_pmu_client),
        pour un cheval identifié par son nom — crée le cheval s'il n'existe
        pas encore (aucune participation requise). Upsert silencieux : si une
        ligne existe déjà pour (cheval, date, hippodrome), elle est conservée
        telle quelle (jamais écrasée par le backfill, quelle que soit sa
        source — contrainte d'unicité dans models.py) et la méthode renvoie
        False ; True si la ligne a bien été ajoutée."""
        with Session(self.engine) as session:
            cheval = self.upsert_cheval(session, nom_cheval)

            stmt = sqlite_insert(PerformanceHistorique).values(
                cheval_id=cheval.id,
                participation_id=None,
                date_course=date_course,
                hippodrome=hippodrome,
                discipline=discipline,
                allocation=allocation,
                distance=distance,
                nb_participants=nb_participants,
                rang=rang,
                terrain=None,
                incident=incident,
                source="open_pmu_api",
            )
            stmt = stmt.on_conflict_do_nothing(index_elements=["cheval_id", "date_course", "hippodrome"])
            result = session.execute(stmt)
            session.commit()
            return result.rowcount > 0

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

    def import_course(self, course_id: int) -> None:
        pass
