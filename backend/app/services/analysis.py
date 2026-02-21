"""
Analysis service for meal images.
MVP: Deterministic mocks (Milestone 2)
Later: Integration with ML models (Milestone 4)
"""

import hashlib
from typing import List, Dict, Any
from app.models.schemas import (
    AnalyzeMealResponse,
    AnalyzeItem,
    GramsRange,
    Macros,
)


# Canned foods for deterministic mock analysis
CANNED_FOODS = {
    "white_rice": {
        "label": "white rice",
        "label_confidence": 0.85,
        "grams_estimate": 180,
        "grams_range": {"min": 130, "max": 240},
        "grams_confidence": 0.65,
        "macros": {"kcal": 234, "protein_g": 4.3, "carbs_g": 51.5, "fat_g": 0.6},
    },
    "chicken_breast": {
        "label": "chicken breast",
        "label_confidence": 0.88,
        "grams_estimate": 150,
        "grams_range": {"min": 100, "max": 200},
        "grams_confidence": 0.70,
        "macros": {"kcal": 248, "protein_g": 53.9, "carbs_g": 0.0, "fat_g": 1.4},
    },
    "broccoli": {
        "label": "broccoli",
        "label_confidence": 0.80,
        "grams_estimate": 200,
        "grams_range": {"min": 150, "max": 250},
        "grams_confidence": 0.60,
        "macros": {"kcal": 68, "protein_g": 7.2, "carbs_g": 11.2, "fat_g": 0.9},
    },
    "olive_oil": {
        "label": "olive oil",
        "label_confidence": 0.70,
        "grams_estimate": 15,
        "grams_range": {"min": 10, "max": 20},
        "grams_confidence": 0.50,
        "macros": {"kcal": 135, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 15.0},
    },
    "rice_mixed": {
        "label": "mixed grain rice",
        "label_confidence": 0.72,
        "grams_estimate": 200,
        "grams_range": {"min": 150, "max": 260},
        "grams_confidence": 0.55,
        "macros": {"kcal": 260, "protein_g": 6.5, "carbs_g": 56.0, "fat_g": 1.0},
    },
}


async def analyze_images_deterministic(
    image_bytes: List[bytes],
    metadata: Dict[str, Any],
) -> AnalyzeMealResponse:
    """
    Deterministic mock analysis using image hash.
    
    - Hash the first image's bytes
    - Pick canned food based on hash mod len(CANNED_FOODS)
    - Return consistent output
    - If only 3-4 photos, suggest more
    
    Args:
        image_bytes: List of image binary data
        metadata: Optional metadata from client
        
    Returns:
        AnalyzeMealResponse with mocked results
    """
    if not image_bytes:
        raise ValueError("At least one image required")
    
    # Hash first image for determinism
    first_hash = hashlib.md5(image_bytes[0]).digest()
    hash_int = int.from_bytes(first_hash, byteorder='big')
    
    # Pick food based on hash
    food_keys = list(CANNED_FOODS.keys())
    food_key = food_keys[hash_int % len(food_keys)]
    food_template = CANNED_FOODS[food_key]
    
    # Build response
    item = AnalyzeItem(
        item_id="tmp-1",
        label=food_template["label"],
        label_confidence=food_template["label_confidence"],
        grams_estimate=food_template["grams_estimate"],
        grams_range=GramsRange(**food_template["grams_range"]),
        grams_confidence=food_template["grams_confidence"],
        macros=Macros(**food_template["macros"]),
    )
    
    photo_count = len(image_bytes)
    needs_more = photo_count < 5
    
    suggested_shots = []
    if needs_more:
        suggested_shots = ["top_down", "lower_left_angle", "lower_right_angle"]
    
    overall_conf = 0.65 if photo_count < 5 else 0.75
    
    return AnalyzeMealResponse(
        overall_confidence=overall_conf,
        needs_more_photos=needs_more,
        suggested_next_shots=suggested_shots,
        items=[item],
        warnings=["oil_sauce_uncertain"] if "oil" in food_key else [],
    )
