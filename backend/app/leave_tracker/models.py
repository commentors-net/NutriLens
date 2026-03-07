
from sqlalchemy import Column, Integer, String, Date, ForeignKey, Text
from sqlalchemy.orm import relationship
from .database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    password = Column(String)
    otp_secret = Column(String)

class AIInstructions(Base):
    __tablename__ = "ai_instructions"

    id = Column(Integer, primary_key=True, index=True)
    instructions = Column(Text, nullable=False)
    created_at = Column(String)  # ISO format datetime string
    updated_at = Column(String)  # ISO format datetime string

class Absence(Base):
    __tablename__ = "absences"

    id = Column(Integer, primary_key=True, index=True)
    date = Column(Date)
    duration = Column(String)
    reason = Column(String)
    type_id = Column(Integer, ForeignKey("types.id"))
    person_id = Column(Integer, ForeignKey("people.id"))
    applied = Column(Integer, default=0)  # 0 = not applied, 1 = applied

    type = relationship("Type", back_populates="absences")
    person = relationship("People", back_populates="absences")

class People(Base):
    __tablename__ = "people"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)

    absences = relationship("Absence", back_populates="person")

class Type(Base):
    __tablename__ = "types"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)

    absences = relationship("Absence", back_populates="type")
