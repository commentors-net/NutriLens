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
        self.db_path = os.getenv("DATABASE_URL", "sqlite:///./unified_dev.db").replace(
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

            CREATE TABLE IF NOT EXISTS meal_corrections (
                correction_id   TEXT PRIMARY KEY,
                meal_id         TEXT NOT NULL,
                timestamp       TEXT NOT NULL,
                date_str        TEXT NOT NULL,
                item_id         TEXT,
                corrected_label TEXT NOT NULL,
                corrected_grams INTEGER NOT NULL,
                original_label  TEXT,
                original_grams  INTEGER,
                grams_delta     INTEGER NOT NULL
            );

            CREATE TABLE IF NOT EXISTS nutrilens_settings (
                setting_key TEXT PRIMARY KEY,
                setting_value TEXT NOT NULL,
                updated_by TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS nutrilens_settings_audit (
                audit_id TEXT PRIMARY KEY,
                setting_key TEXT NOT NULL,
                setting_value TEXT NOT NULL,
                updated_by TEXT NOT NULL,
                updated_at TEXT NOT NULL
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
        # Map database field names (with _g suffix) to API field names (without _g)
        foods = []
        for row in rows:
            food_dict = dict(row)
            foods.append({
                "food_id": food_dict["food_id"],
                "name": food_dict["name"],
                "kcal_per_100g": food_dict["kcal_per_100g"],
                "protein_per_100g": food_dict["protein_g_per_100g"],
                "carbs_per_100g": food_dict["carbs_g_per_100g"],
                "fat_per_100g": food_dict["fat_g_per_100g"],
            })
        return foods

    def get_food_by_id(self, food_id: str) -> Optional[Dict[str, Any]]:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM foods WHERE food_id = ?", (food_id,))
        row = cursor.fetchone()
        conn.close()
        if row:
            food_dict = dict(row)
            return {
                "food_id": food_dict["food_id"],
                "name": food_dict["name"],
                "kcal_per_100g": food_dict["kcal_per_100g"],
                "protein_per_100g": food_dict["protein_g_per_100g"],
                "carbs_per_100g": food_dict["carbs_g_per_100g"],
                "fat_per_100g": food_dict["fat_g_per_100g"],
            }
        return None

    def get_food_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Exact, case-insensitive match."""
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM foods WHERE LOWER(name) = LOWER(?)", (name.strip(),)
        )
        row = cursor.fetchone()
        conn.close()
        if row:
            food_dict = dict(row)
            return {
                "food_id": food_dict["food_id"],
                "name": food_dict["name"],
                "kcal_per_100g": food_dict["kcal_per_100g"],
                "protein_per_100g": food_dict["protein_g_per_100g"],
                "carbs_per_100g": food_dict["carbs_g_per_100g"],
                "fat_per_100g": food_dict["fat_g_per_100g"],
            }
        return None

    def get_food_count(self) -> int:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM foods")
        count = cursor.fetchone()[0]
        conn.close()
        return count

    def save_food(self, food: Dict[str, Any]) -> Dict[str, Any]:
        """Save or update a food record."""
        food_id = food.get("food_id")
        if not food_id:
            raise ValueError("food_id is required")
        
        conn = self._get_connection()
        cursor = conn.cursor()
        
        # Map API field names (without _g) to database column names (with _g)
        cursor.execute(
            """
            INSERT INTO foods (food_id, name, kcal_per_100g, protein_g_per_100g, carbs_g_per_100g, fat_g_per_100g)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(food_id) DO UPDATE SET
                name = excluded.name,
                kcal_per_100g = excluded.kcal_per_100g,
                protein_g_per_100g = excluded.protein_g_per_100g,
                carbs_g_per_100g = excluded.carbs_g_per_100g,
                fat_g_per_100g = excluded.fat_g_per_100g
            """,
            (
                food_id,
                food.get("name", ""),
                food.get("kcal_per_100g", 0),
                food.get("protein_per_100g", 0.0),
                food.get("carbs_per_100g", 0.0),
                food.get("fat_per_100g", 0.0),
            ),
        )
        conn.commit()
        conn.close()
        return food

    def delete_food(self, food_id: str) -> None:
        """Delete a food record."""
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM foods WHERE food_id = ?", (food_id,))
        conn.commit()
        conn.close()

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

    def get_meals_by_date_range(self, start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """Return all meals between start_date and end_date (inclusive, YYYY-MM-DD format)."""
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM meals WHERE date_str >= ? AND date_str <= ? ORDER BY timestamp DESC",
            (start_date, end_date),
        )
        rows = cursor.fetchall()
        conn.close()
        result = []
        for row in rows:
            meal = dict(row)
            meal["items"] = json.loads(meal.get("items", "[]"))
            result.append(meal)
        return result

    def save_corrections(self, corrections: List[Dict[str, Any]]) -> int:
        if not corrections:
            return 0

        conn = self._get_connection()
        cursor = conn.cursor()
        inserted = 0

        for correction in corrections:
            correction_id = correction.get("correction_id") or str(uuid.uuid4())
            timestamp = correction.get("timestamp") or datetime.utcnow().isoformat()
            date_str = correction.get("date_str") or timestamp[:10]

            cursor.execute(
                """
                INSERT INTO meal_corrections (
                    correction_id, meal_id, timestamp, date_str, item_id,
                    corrected_label, corrected_grams, original_label, original_grams, grams_delta
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    correction_id,
                    correction.get("meal_id", ""),
                    timestamp,
                    date_str,
                    correction.get("item_id"),
                    correction.get("corrected_label", ""),
                    int(correction.get("corrected_grams", 0)),
                    correction.get("original_label"),
                    correction.get("original_grams"),
                    int(correction.get("grams_delta", 0)),
                ),
            )
            inserted += 1

        conn.commit()
        conn.close()
        return inserted

    def get_corrections(
        self,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 100,
    ) -> List[Dict[str, Any]]:
        conn = self._get_connection()
        cursor = conn.cursor()

        query = "SELECT * FROM meal_corrections"
        params: List[Any] = []
        filters: List[str] = []

        if start_date:
            filters.append("date_str >= ?")
            params.append(start_date)
        if end_date:
            filters.append("date_str <= ?")
            params.append(end_date)

        if filters:
            query += " WHERE " + " AND ".join(filters)

        query += " ORDER BY timestamp DESC LIMIT ?"
        params.append(limit)

        cursor.execute(query, tuple(params))
        rows = cursor.fetchall()
        conn.close()

        return [dict(row) for row in rows]

    # ==================== SETTINGS ====================

    def get_nutrilens_setting(self, key: str) -> Optional[Dict[str, Any]]:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT setting_key, setting_value, updated_by, updated_at FROM nutrilens_settings WHERE setting_key = ?",
            (key,),
        )
        row = cursor.fetchone()
        conn.close()
        if not row:
            return None
        payload = dict(row)
        return {
            "key": payload.get("setting_key"),
            "value": payload.get("setting_value"),
            "updated_by": payload.get("updated_by"),
            "updated_at": payload.get("updated_at"),
        }

    def set_nutrilens_setting(self, key: str, value: str, updated_by: str) -> Dict[str, Any]:
        updated_at = datetime.utcnow().isoformat()
        user = updated_by or "system"

        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO nutrilens_settings (setting_key, setting_value, updated_by, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(setting_key) DO UPDATE SET
                setting_value = excluded.setting_value,
                updated_by = excluded.updated_by,
                updated_at = excluded.updated_at
            """,
            (key, value, user, updated_at),
        )

        audit_id = str(uuid.uuid4())
        cursor.execute(
            """
            INSERT INTO nutrilens_settings_audit (audit_id, setting_key, setting_value, updated_by, updated_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (audit_id, key, value, user, updated_at),
        )
        conn.commit()
        conn.close()

        return {
            "key": key,
            "value": value,
            "updated_by": user,
            "updated_at": updated_at,
        }

    def get_nutrilens_setting_audit(self, key: str, limit: int = 20) -> List[Dict[str, Any]]:
        conn = self._get_connection()
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT audit_id, setting_key, setting_value, updated_by, updated_at
            FROM nutrilens_settings_audit
            WHERE setting_key = ?
            ORDER BY updated_at DESC
            LIMIT ?
            """,
            (key, max(1, int(limit))),
        )
        rows = cursor.fetchall()
        conn.close()
        return [
            {
                "id": row["audit_id"],
                "key": row["setting_key"],
                "value": row["setting_value"],
                "updated_by": row["updated_by"],
                "updated_at": row["updated_at"],
            }
            for row in rows
        ]


# Global singleton
sqlite_db = NutriLensSQLiteDB()
