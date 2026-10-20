from datetime import date, datetime
from typing import Optional

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class Course(Base):
    __tablename__ = "courses"
    __table_args__ = (UniqueConstraint("date", "numero_reunion", "numero_course", name="uq_course_pmu_ref"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    heure_depart: Mapped[Optional[datetime]] = mapped_column(DateTime)
    numero_reunion: Mapped[Optional[int]] = mapped_column(Integer)
    numero_course: Mapped[Optional[int]] = mapped_column(Integer)
    libelle: Mapped[Optional[str]] = mapped_column(String(256))
    hippodrome: Mapped[str] = mapped_column(String(128), nullable=False)
    discipline: Mapped[str] = mapped_column(String(32), nullable=False)
    distance: Mapped[Optional[float]] = mapped_column(Float)
    allocation: Mapped[Optional[float]] = mapped_column(Float)
    nb_partants: Mapped[Optional[int]] = mapped_column(Integer)
    corde: Mapped[Optional[str]] = mapped_column(String(32))
    terrain: Mapped[Optional[str]] = mapped_column(String(64))
    niveau_estime: Mapped[Optional[str]] = mapped_column(String(64))
    finalisee: Mapped[bool] = mapped_column(Boolean, default=False)
    source: Mapped[str] = mapped_column(String(16), default="pmu")
    participations: Mapped[list["Participation"]] = relationship(back_populates="course")


class Cheval(Base):
    __tablename__ = "chevaux"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    nom_normalise: Mapped[str] = mapped_column(String(128), nullable=False, unique=True)
    sexe: Mapped[Optional[str]] = mapped_column(String(16))
    date_naissance_ou_age_connu: Mapped[Optional[str]] = mapped_column(String(32))
    robe: Mapped[Optional[str]] = mapped_column(String(64))
    participations: Mapped[list["Participation"]] = relationship(back_populates="cheval")
    performances_historiques: Mapped[list["PerformanceHistorique"]] = relationship(
        back_populates="cheval", cascade="all, delete-orphan"
    )


class Participation(Base):
    __tablename__ = "participations"
    __table_args__ = (UniqueConstraint("course_id", "cheval_id", name="uq_participation_course_cheval"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id"), nullable=False)
    cheval_id: Mapped[int] = mapped_column(ForeignKey("chevaux.id"), nullable=False)
    num_pmu: Mapped[Optional[int]] = mapped_column(Integer)
    age_a_la_course: Mapped[Optional[int]] = mapped_column(Integer)
    poids: Mapped[Optional[float]] = mapped_column(Float)
    cote_reference: Mapped[Optional[float]] = mapped_column(Float)
    cote_direct: Mapped[Optional[float]] = mapped_column(Float)
    rang_arrivee: Mapped[Optional[int]] = mapped_column(Integer)
    incident: Mapped[Optional[str]] = mapped_column(String(16))
    inedit: Mapped[bool] = mapped_column(Boolean, default=False)
    driver: Mapped[Optional[str]] = mapped_column(String(128))
    entraineur: Mapped[Optional[str]] = mapped_column(String(128))
    donnees_brutes: Mapped[Optional[str]] = mapped_column(Text)
    cheval: Mapped[Cheval] = relationship(back_populates="participations")
    course: Mapped[Course] = relationship(back_populates="participations")


class PerformanceHistorique(Base):
    # Rattachée au CHEVAL (pas à une participation précise) : son historique
    # lui appartient, indépendamment de la course pour laquelle on l'a
    # consultée. participation_id reste renseigné par le flux d'ingestion
    # (traçabilité) ; il est nullable car d'anciennes lignes n'en ont pas.
    #
    # Contrainte d'unicité (cheval_id, date_course, hippodrome) : une seule
    # ligne par course passée d'un cheval. Seules des lignes source="pmu"
    # (turfinfo performances-detaillees, via repository.save_historique,
    # upsert) sont écrites désormais. Les anciennes lignes "open_pmu_api"
    # (backfill retiré : Quinté+ et premiers arrivés seulement, historique
    # biaisé) sont supprimées par jobs/purge_open_pmu.py.
    __tablename__ = "performances_historiques"
    __table_args__ = (
        UniqueConstraint("cheval_id", "date_course", "hippodrome", name="uq_perf_hist_cheval_date_hippo"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    cheval_id: Mapped[int] = mapped_column(ForeignKey("chevaux.id"), nullable=False)
    participation_id: Mapped[Optional[int]] = mapped_column(ForeignKey("participations.id"))
    date_course: Mapped[Optional[date]] = mapped_column(Date)
    hippodrome: Mapped[Optional[str]] = mapped_column(String(128))
    discipline: Mapped[Optional[str]] = mapped_column(String(32))
    allocation: Mapped[Optional[float]] = mapped_column(Float)
    distance: Mapped[Optional[float]] = mapped_column(Float)
    nb_participants: Mapped[Optional[int]] = mapped_column(Integer)
    rang: Mapped[Optional[int]] = mapped_column(Integer)
    # Vrai quand `rang` est une estimation (NON_PLACE sans position connue),
    # pas une place officielle.
    rang_impute: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, server_default="0")
    terrain: Mapped[Optional[str]] = mapped_column(String(64))
    incident: Mapped[Optional[str]] = mapped_column(String(16))
    source: Mapped[str] = mapped_column(String(16), default="pmu")
    cheval: Mapped[Cheval] = relationship(back_populates="performances_historiques")


class PredictionRun(Base):
    # Un pronostic n'est jamais réécrit : chaque calcul ajoute une ligne, et
    # l'évaluation retient le dernier calculé avant le départ. La variante
    # sépare les pronostics réellement enregistrés avant la course ("live")
    # des recalculs a posteriori ("rejeu"), qui ne prouvent rien.
    __tablename__ = "prediction_runs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    course_id: Mapped[int] = mapped_column(ForeignKey("courses.id"), nullable=False, index=True)
    cree_le: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    variante: Mapped[str] = mapped_column(String(16), nullable=False)
    degradee: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    manques: Mapped[str] = mapped_column(Text, default="[]", nullable=False)
    # Variante "app" uniquement : pronostic d'un utilisateur, identifié par
    # son installation (pas encore de comptes), et ce qu'il a changé.
    installation_id: Mapped[Optional[str]] = mapped_column(String(64), index=True)
    donnees_modifiees: Mapped[Optional[bool]] = mapped_column(Boolean)
    reglages_par_defaut: Mapped[Optional[bool]] = mapped_column(Boolean)
    terrain_modifie: Mapped[Optional[bool]] = mapped_column(Boolean)
    parametres: Mapped[Optional[str]] = mapped_column(Text)
    # Combinaisons proposées par type de pari, en dossards (JSON) : elles
    # dépendent des outsiders virtuels et d'une simulation, on ne peut pas
    # les recalculer à l'identique après coup.
    combinaisons: Mapped[Optional[str]] = mapped_column(Text)
    chevaux: Mapped[list["PredictionCheval"]] = relationship(back_populates="run", cascade="all, delete-orphan")


class PredictionCheval(Base):
    __tablename__ = "prediction_chevaux"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    run_id: Mapped[int] = mapped_column(ForeignKey("prediction_runs.id"), nullable=False, index=True)
    num_pmu: Mapped[int] = mapped_column(Integer, nullable=False)
    probabilite: Mapped[float] = mapped_column(Float, nullable=False)
    # Cote connue au moment du pronostic, pour comparer au favori du marché
    # tel qu'il était alors, pas à la cote finale.
    cote: Mapped[Optional[float]] = mapped_column(Float)
    top2: Mapped[Optional[float]] = mapped_column(Float)
    top3: Mapped[Optional[float]] = mapped_column(Float)
    top4: Mapped[Optional[float]] = mapped_column(Float)
    value: Mapped[Optional[float]] = mapped_column(Float)
    mise: Mapped[Optional[float]] = mapped_column(Float)
    run: Mapped[PredictionRun] = relationship(back_populates="chevaux")
