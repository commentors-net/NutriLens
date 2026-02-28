"""
Nutrition calculation service — Milestone 3 / Phase P2.
- In-memory NUTRITION_DB retained for mock analysis backward compat.
- DB-backed functions now use the db_factory abstraction (dict-based),
  compatible with both SQLite dev and Firestore production.
- Fuzzy food name matching via difflib (stdlib, no extra dep).
"""

import difflib
from typing import Any, Dict, List, Optional


# ─── In-memory DB (used by deterministic mock analysis service) ──────────────
# These stay in sync with the CANNED_FOODS in analysis.py.
NUTRITION_DB: Dict[str, Dict[str, Any]] = {
    "white rice": {
        "food_id": "white_rice",
        "name": "white rice",
        "kcal_per_100g": 130,
        "protein_g_per_100g": 2.7,
        "carbs_g_per_100g": 28.7,
        "fat_g_per_100g": 0.3,
    },
    "chicken breast": {
        "food_id": "chicken_breast",
        "name": "chicken breast",
        "kcal_per_100g": 165,
        "protein_g_per_100g": 36.0,
        "carbs_g_per_100g": 0.0,
        "fat_g_per_100g": 0.9,
    },
    "broccoli": {
        "food_id": "broccoli",
        "name": "broccoli",
        "kcal_per_100g": 34,
        "protein_g_per_100g": 3.6,
        "carbs_g_per_100g": 5.6,
        "fat_g_per_100g": 0.4,
    },
    "olive oil": {
        "food_id": "olive_oil",
        "name": "olive oil",
        "kcal_per_100g": 884,
        "protein_g_per_100g": 0.0,
        "carbs_g_per_100g": 0.0,
        "fat_g_per_100g": 100.0,
    },
    "mixed grain rice": {
        "food_id": "brown_rice",
        "name": "brown rice",
        "kcal_per_100g": 123,
        "protein_g_per_100g": 2.6,
        "carbs_g_per_100g": 25.6,
        "fat_g_per_100g": 1.0,
    },
}


# ─── Fuzzy matching ───────────────────────────────────────────────────────────

def _normalize(name: str) -> str:
    return name.lower().strip()


def get_food_fuzzy(db: Any, label: str) -> Optional[Dict[str, Any]]:
    """
    Find a food dict by fuzzy matching the given label.

    `db` is the db_factory singleton (NutriLensFirestoreDB or NutriLensSQLiteDB).

    Strategy (in order):
    1. Exact match via db.get_food_by_name()
    2. Label is a substring of any food name (or vice-versa)
    3. Best difflib closest match (cutoff 0.55)

    Returns a food dict or None if nothing is close enough.
    """
    norm_label = _normalize(label)

    # 1. Exact match
    food = db.get_food_by_name(norm_label)
    if food:
        return food

    # 2 & 3. Load all foods, run substring + difflib
    all_foods: List[Dict[str, Any]] = db.get_all_foods()
    for f in all_foods:
        if norm_label in _normalize(f["name"]) or _normalize(f["name"]) in norm_label:
            return f

    names = [_normalize(f["name"]) for f in all_foods]
    matches = difflib.get_close_matches(norm_label, names, n=1, cutoff=0.55)
    if matches:
        for f in all_foods:
            if _normalize(f["name"]) == matches[0]:
                return f

    return None


def compute_macros_from_food(food: Dict[str, Any], grams: int) -> Dict[str, Any]:
    """Compute macros given a food dict and grams."""
    factor = grams / 100.0
    return {
        "kcal": int(round(food["kcal_per_100g"] * factor)),
        "protein_g": round(food["protein_g_per_100g"] * factor, 1),
        "carbs_g": round(food["carbs_g_per_100g"] * factor, 1),
        "fat_g": round(food["fat_g_per_100g"] * factor, 1),
    }


def compute_macros(food_name: str, grams: int) -> Dict[str, Any]:
    """
    Compute macros for a food given weight in grams.
    
    Returns:
        Dict with kcal, protein_g, carbs_g, fat_g (all rounded appropriately)
    """
    food_data = NUTRITION_DB.get(food_name.lower())
    if not food_data:
        raise ValueError(f"Food '{food_name}' not found in nutrition DB")
    
    # Calculate macros
    kcal = int(round(grams * food_data["kcal_per_100g"] / 100))
    protein_g = round(grams * food_data["protein_g_per_100g"] / 100, 1)
    carbs_g = round(grams * food_data["carbs_g_per_100g"] / 100, 1)
    fat_g = round(grams * food_data["fat_g_per_100g"] / 100, 1)
    
    return {
        "kcal": kcal,
        "protein_g": protein_g,
        "carbs_g": carbs_g,
        "fat_g": fat_g,
    }


def compute_total_macros(items: list) -> Dict[str, Any]:
    """
    Sum macros across multiple items.
    
    Args:
        items: List of dicts with 'label' and 'grams' keys
        
    Returns:
        Total kcal, protein, carbs, fat
    """
    total_kcal = 0
    total_protein = 0.0
    total_carbs = 0.0
    total_fat = 0.0
    
    for item in items:
        macros = compute_macros(item["label"], item["grams"])
        total_kcal += macros["kcal"]
        total_protein += macros["protein_g"]
        total_carbs += macros["carbs_g"]
        total_fat += macros["fat_g"]
    
    return {
        "kcal": total_kcal,
        "protein_g": round(total_protein, 1),
        "carbs_g": round(total_carbs, 1),
        "fat_g": round(total_fat, 1),
    }
