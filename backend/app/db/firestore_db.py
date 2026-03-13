"""
NutriLens Firestore database layer.

Collections:
  nutrilens_foods       — food items (seeded on startup, per 100g macros)
  nutrilens_meals       — saved meals (embedded items for denormalised reads)

Document shape:
  foods:  { food_id, name, kcal_per_100g, protein_g_per_100g, carbs_g_per_100g, fat_g_per_100g }
  meals:  { meal_id, timestamp, date_str, notes, items: [{food_id, grams, kcal, protein_g, carbs_g, fat_g, label}] }
"""

from __future__ import annotations

import os
from datetime import date, datetime
from typing import Any, Dict, List, Optional

from google.cloud import firestore


class NutriLensFirestoreDB:
    FOODS = "nutrilens_foods"
    MEALS = "nutrilens_meals"
    CORRECTIONS = "nutrilens_meal_corrections"

    def __init__(self) -> None:
        project_id = os.getenv("GCP_PROJECT_ID", "leave-tracker-2025")
        self.db = firestore.Client(project=project_id)

    # ==================== FOODS ====================

    def seed_foods(self, foods: List[Dict[str, Any]]) -> int:
        """
        Idempotent bulk-insert of foods.
        Uses food_id as Firestore document ID to avoid duplicates.
        Returns the number of newly inserted documents.
        """
        inserted = 0
        for food in foods:
            fid = food["food_id"]
            ref = self.db.collection(self.FOODS).document(fid)
            if not ref.get().exists:
                ref.set(food)
                inserted += 1
        return inserted

    def _map_food_fields(self, food_doc: Dict[str, Any]) -> Dict[str, Any]:
        """
        Map Firestore field names to API field names.
        Database has: protein_g_per_100g, carbs_g_per_100g, fat_g_per_100g
        API expects: protein_per_100g, carbs_per_100g, fat_per_100g
        """
        if "protein_g_per_100g" in food_doc:
            food_doc["protein_per_100g"] = food_doc["protein_g_per_100g"]
        if "carbs_g_per_100g" in food_doc:
            food_doc["carbs_per_100g"] = food_doc["carbs_g_per_100g"]
        if "fat_g_per_100g" in food_doc:
            food_doc["fat_per_100g"] = food_doc["fat_g_per_100g"]
        return food_doc

    def get_all_foods(self) -> List[Dict[str, Any]]:
        """Return all food documents."""
        docs = self.db.collection(self.FOODS).stream()
        return [self._map_food_fields({"id": d.id, **d.to_dict()}) for d in docs]

    def get_food_by_id(self, food_id: str) -> Optional[Dict[str, Any]]:
        """Return a single food document by food_id."""
        ref = self.db.collection(self.FOODS).document(food_id)
        doc = ref.get()
        if doc.exists:
            return self._map_food_fields({"id": doc.id, **doc.to_dict()})
        return None

    def get_food_by_name(self, name: str) -> Optional[Dict[str, Any]]:
        """Exact-match lookup by food name (case-sensitive, lower-normalised)."""
        docs = (
            self.db.collection(self.FOODS)
            .where("name", "==", name.lower().strip())
            .limit(1)
            .stream()
        )
        for doc in docs:
            return self._map_food_fields({"id": doc.id, **doc.to_dict()})
        return None

    def get_food_count(self) -> int:
        """Return total number of food documents."""
        docs = self.db.collection(self.FOODS).stream()
        return sum(1 for _ in docs)

    def save_food(self, food: Dict[str, Any]) -> Dict[str, Any]:
        """Save or update a food document."""
        food_id = food.get("food_id")
        if not food_id:
            raise ValueError("food_id is required")
        
        # Map API schema to database schema when saving
        db_food = food.copy()
        if "protein_per_100g" in db_food:
            db_food["protein_g_per_100g"] = db_food.pop("protein_per_100g")
        if "carbs_per_100g" in db_food:
            db_food["carbs_g_per_100g"] = db_food.pop("carbs_per_100g")
        if "fat_per_100g" in db_food:
            db_food["fat_g_per_100g"] = db_food.pop("fat_per_100g")
        
        self.db.collection(self.FOODS).document(food_id).set(db_food)
        return food  # Return original food with API schema

    def delete_food(self, food_id: str) -> None:
        """Delete a food document."""
        self.db.collection(self.FOODS).document(food_id).delete()

    # ==================== MEALS ====================

    def save_meal(
        self,
        meal_id: str,
        timestamp: str,
        notes: Optional[str],
        items: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Persist a meal as a single Firestore document (denormalised, items embedded).

        `items` each contain: food_id, grams, kcal, protein_g, carbs_g, fat_g, label
        `date_str` (YYYY-MM-DD, UTC) is stored as a filterable top-level field.
        """
        date_str = timestamp[:10]  # "2025-02-28T12:34:56" → "2025-02-28"
        data: Dict[str, Any] = {
            "meal_id": meal_id,
            "timestamp": timestamp,
            "date_str": date_str,
            "notes": notes or "",
            "items": items,
        }
        self.db.collection(self.MEALS).document(meal_id).set(data)
        return {"id": meal_id, **data}

    def get_meals_by_date(self, date_str: str) -> List[Dict[str, Any]]:
        """
        Return all meals matching an exact date_str (YYYY-MM-DD).
        """
        docs = (
            self.db.collection(self.MEALS)
            .where("date_str", "==", date_str)
            .stream()
        )
        return [{"id": d.id, **d.to_dict()} for d in docs]

    def get_meals_by_date_range(self, start_date: str, end_date: str) -> List[Dict[str, Any]]:
        """
        Return all meals between start_date and end_date (inclusive, YYYY-MM-DD format).
        """
        docs = (
            self.db.collection(self.MEALS)
            .where("date_str", ">=", start_date)
            .where("date_str", "<=", end_date)
            .stream()
        )
        meals = [{"id": d.id, **d.to_dict()} for d in docs]
        meals.sort(key=lambda meal: meal.get("timestamp", ""), reverse=True)
        return meals

    def save_corrections(self, corrections: List[Dict[str, Any]]) -> int:
        if not corrections:
            return 0

        batch = self.db.batch()
        inserted = 0

        for correction in corrections:
            correction_id = correction.get("correction_id")
            if not correction_id:
                continue

            ref = self.db.collection(self.CORRECTIONS).document(correction_id)
            batch.set(ref, correction)
            inserted += 1

        if inserted:
            batch.commit()

        return inserted

    def get_corrections(
        self,
        start_date: Optional[str] = None,
        end_date: Optional[str] = None,
        limit: int = 100,
    ) -> List[Dict[str, Any]]:
        query = self.db.collection(self.CORRECTIONS)

        if start_date:
            query = query.where("date_str", ">=", start_date)
        if end_date:
            query = query.where("date_str", "<=", end_date)

        docs = query.limit(limit).stream()
        corrections = [{"id": d.id, **d.to_dict()} for d in docs]
        corrections.sort(key=lambda entry: entry.get("timestamp", ""), reverse=True)
        return corrections


# Lazy singleton — only instantiate when actually needed (i.e., when ENVIRONMENT != development)
_firestore_db_instance = None


def get_firestore_db() -> NutriLensFirestoreDB:
    global _firestore_db_instance
    if _firestore_db_instance is None:
        _firestore_db_instance = NutriLensFirestoreDB()
    return _firestore_db_instance


# For backward compatibility with existing code that imports firestore_db directly
firestore_db = None  # Will be set by db_factory when needed
