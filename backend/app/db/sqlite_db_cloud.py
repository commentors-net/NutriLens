"""
NutriLens SQLite database layer — development / local use.

Exposes the same public interface as NutriLensFirestoreDB so the rest of
the application is fully agnostic of the underlying storage engine.

Collections map to plain SQLite tables:
  nutrilens_foods  →  foods
  nutrilens_meals  →  meals  (items stored as JSON in an `items` column)
"""

from __future__ import annotations

import json
import os
import sqlite3
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional


class NutriLensSQLiteDB:
    def __init__(self) -> None:
        self.db_path = os.getenv("DATABASE_URL", "nutrition_cloud.db").replace(
            "sqlite:///./", ""
        )
        self._create_tables()

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _create_tables(self) -> None:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.executescript("""
            CREATE TABLE IF NOT EXISTS foods (
                food_id              TEXT PRIMARY KEY,
                name                 TEXT NOT NULL,
                kcal_per_100g        REAL NOT NULL,
                protein_g_per_100g   REAL NOT NULL,
                carbs_g_per_100g     REAL NOT NULL,
                fat_g_per_100g       REAL NOT NULL
            );

            CREATE TABLE IF NOT EXISTS meals (
                meal_id   TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                date_str  TEXT NOT NULL,
                notes     TEXT DEFAULT '',
                items     TEXT DEFAULT '[]'
            );
        """)
        conn.commit()
        conn.close()

    # ==================== FOODS ====================

    def seed_foods(self, foods: List[Dict[str, Any]]) -> int:
        """Idempotent bulk-insert of foods. Returns newly inserted count."""
        conn = self._get_connection()
        cursor = conn.cursor()
        inserted = 0
        for food in foods:
            cursor.execute("SELECT food_id FROM foods WHERE food_id = ?", (food["food_id"],))
            if cursor.fetchone() is None:
                cursor.execute(
                    """INSERT INTO foods
                         (food_id, name, kcal_per_100g, protein_g_per_100g, carbs_g_per_100g, fat_g_per_100g)
                       VALUES (?, ?, ?, ?, ?, ?)""",
                    (
                        food["food_id"],
                        food["name"],
                        food["kcal_per_100g"],
                        food["protein_g_per_100g"],
                        food["carbs_g_per_100g"],
                        food["fat_g_per_100g"],
                    ),
                )
                inserted += 1
        conn.commit()
        conn.close()
        return inserted

    def get_all_foods(self) -> List[Dict[str, Any]]:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM foods")
        rows = cursor.fetchall()
        conn.close()
        return [dict(row) for row in rows]

    def get_food_by_id(self, food_id: str) -> Optional[Dict[str, Any]]:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM foods WHERE food_id = ?", (food_id,))
        row = cursor.fetchone()
        conn.close()
        return dict(row) if row else None

    def get_food_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Exact, case-insensitive match."""
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM foods WHERE LOWER(name) = LOWER(?)", (name.strip(),)
        )
        row = cursor.fetchone()
        conn.close()
        return dict(row) if row else None

    def get_food_count(self) -> int:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM foods")
        count = cursor.fetchone()[0]
        conn.close()
        return count

    # ==================== MEALS ====================

    def save_meal(
        self,
        meal_id: str,
        timestamp: str,
        notes: Optional[str],
        items: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        date_str = timestamp[:10]
        items_json = json.dumps(items)
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO meals (meal_id, timestamp, date_str, notes, items) VALUES (?, ?, ?, ?, ?)",
            (meal_id, timestamp, date_str, notes or "", items_json),
        )
        conn.commit()
        conn.close()
        return {
            "id": meal_id,
            "meal_id": meal_id,
            "timestamp": timestamp,
            "date_str": date_str,
            "notes": notes or "",
            "items": items,
        }

    def get_meals_by_date(self, date_str: str) -> List[Dict[str, Any]]:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM meals WHERE date_str = ?", (date_str,))
        rows = cursor.fetchall()
        conn.close()
        result = []
        for row in rows:
            meal = dict(row)
            meal["items"] = json.loads(meal.get("items", "[]"))
            result.append(meal)
        return result


# Global singleton
sqlite_db = NutriLensSQLiteDB()
