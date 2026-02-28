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

    def get_all_foods(self) -> List[Dict[str, Any]]:
        """Return all food documents."""
        docs = self.db.collection(self.FOODS).stream()
        return [{"id": d.id, **d.to_dict()} for d in docs]

    def get_food_by_id(self, food_id: str) -> Optional[Dict[str, Any]]:
        """Return a single food document by food_id."""
        ref = self.db.collection(self.FOODS).document(food_id)
        doc = ref.get()
        if doc.exists:
            return {"id": doc.id, **doc.to_dict()}
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
            return {"id": doc.id, **doc.to_dict()}
        return None

    def get_food_count(self) -> int:
        """Return total number of food documents."""
        docs = self.db.collection(self.FOODS).stream()
        return sum(1 for _ in docs)

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


# Global singleton — import and use directly in routes / services.
firestore_db = NutriLensFirestoreDB()
