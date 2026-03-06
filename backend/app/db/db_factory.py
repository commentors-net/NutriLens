"""
NutriLens database factory.

Mirrors the Leave Tracker pattern:
  ENVIRONMENT=development  →  SQLite (local dev / testing)
  any other value          →  Firestore (staging / production / Cloud Run)

Usage anywhere in the app:
    from app.db.db_factory import db
    all_foods = db.get_all_foods()
"""

import os
from dotenv import load_dotenv

# Load environment variables from .env file (if it exists)
load_dotenv()


def get_database():
    environment = os.getenv("ENVIRONMENT", "production").lower()
    if environment == "development":
        from app.db.sqlite_db_cloud import sqlite_db
        return sqlite_db
    else:
        from app.db.firestore_db import get_firestore_db
        return get_firestore_db()


db = get_database()
