"""
Nutrition calculation service.
MVP: In-memory canned food DB (Milestone 2)
Later: Real nutrition DB (Milestone 3)
"""

from typing import Dict, Any


# Nutrition DB (per 100g) — will move to DB in Milestone 3
NUTRITION_DB = {
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
