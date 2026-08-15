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
    # consultée. participation_id reste renseigné quand la ligne vient du
    # flux d'ingestion normal (traçabilité), mais est nullable : le backfill
    # (open_pmu_client.py) peuple des chevaux qui n'ont pas forcément de
    # participation en base.
    #
    # Contrainte d'unicité (cheval_id, date_course, hippodrome) : les deux
    # sources (job quotidien pmu_client.py, backfill open_pmu_client.py)
    # écrivent dans cette même table sans jamais produire de doublon pour une
    # même course. En cas de conflit : le job quotidien (source="pmu",
    # donnée turfinfo, la plus proche du PMU officiel) écrase toujours ;
    # le backfill (source="open_pmu_api") ne remplace jamais une ligne
    # existante, quelle que soit sa source - voir repository.py.
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
    terrain: Mapped[Optional[str]] = mapped_column(String(64))
    incident: Mapped[Optional[str]] = mapped_column(String(16))
    source: Mapped[str] = mapped_column(String(16), default="pmu")
    cheval: Mapped[Cheval] = relationship(back_populates="performances_historiques")
