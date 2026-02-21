"""
SQLAlchemy models for database tables.
TODO: Implement in Milestone 3
"""

from sqlalchemy import Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class Food(Base):
    """Nutrition reference data (per 100g)"""
    __tablename__ = "foods"
    
    food_id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    kcal_per_100g = Column(Float, nullable=False)
    protein_g_per_100g = Column(Float, nullable=False)
    carbs_g_per_100g = Column(Float, nullable=False)
    fat_g_per_100g = Column(Float, nullable=False)


class Meal(Base):
    """Saved meal records"""
    __tablename__ = "meals"
    
    meal_id = Column(String, primary_key=True)
    timestamp = Column(DateTime, nullable=False)
    notes = Column(String)


class MealItem(Base):
    """Individual items within a meal"""
    __tablename__ = "meal_items"
    
    item_id = Column(String, primary_key=True)
    meal_id = Column(String, nullable=False)
    food_id = Column(String, nullable=False)
    grams = Column(Integer, nullable=False)
