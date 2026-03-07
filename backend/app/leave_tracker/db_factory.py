# Database Factory - Choose SQLite or Firestore based on environment
import os
from typing import Union

def get_database():
    """
    Returns the appropriate database instance based on ENVIRONMENT variable.
    - development: SQLite (local)
    - production: Firestore (cloud)
    """
    environment = os.getenv("ENVIRONMENT", "production").lower()
    
    if environment == "development":
        # Use SQLite for local development
        from .sqlite_db import sqlite_db
        return sqlite_db
    else:
        # Use Firestore for production
        from .firestore_db import firestore_db
        return firestore_db

# Export the database instance
db = get_database()
