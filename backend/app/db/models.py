"""
SQLAlchemy models for database tables — Milestone 3.
"""

import uuid
from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship, declarative_base

Base = declarative_base()


class Food(Base):
    """Nutrition reference data (per 100g)"""
    __tablename__ = "foods"

    food_id = Column(String, primary_key=True)
    name = Column(String, nullable=False, unique=True, index=True)
    kcal_per_100g = Column(Float, nullable=False)
    protein_g_per_100g = Column(Float, nullable=False)
    carbs_g_per_100g = Column(Float, nullable=False)
    fat_g_per_100g = Column(Float, nullable=False)

    meal_items = relationship("MealItem", back_populates="food")


class Meal(Base):
    """Saved meal records"""
    __tablename__ = "meals"

    meal_id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    timestamp = Column(DateTime, nullable=False, default=datetime.utcnow)
    notes = Column(String)

    items = relationship("MealItem", back_populates="meal", cascade="all, delete-orphan")


class MealItem(Base):
    """Individual items within a meal (FK → meals + foods)"""
    __tablename__ = "meal_items"

    item_id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    meal_id = Column(String, ForeignKey("meals.meal_id"), nullable=False)
    food_id = Column(String, ForeignKey("foods.food_id"), nullable=False)
    grams = Column(Integer, nullable=False)

    meal = relationship("Meal", back_populates="items")
    food = relationship("Food", back_populates="meal_items")
