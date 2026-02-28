"""
API routes for meal analysis and management — Phase P2 (Cloud-ready).

POST /meals/analyze  — deterministic mock analysis (unchanged from M2/M3)
POST /meals          — persist a confirmed meal via db_factory (Firestore / SQLite)
GET  /meals/today    — daily totals from db_factory
"""

import logging
import json
import uuid
from datetime import date, datetime
from typing import List, Optional

from fastapi import APIRouter, HTTPException, UploadFile, File, Form

from app.db.db_factory import db
from app.models.schemas import (
    AnalyzeMealResponse,
    MealTotalResponse,
    SaveMealRequest,
)
from app.services.analysis import analyze_images_deterministic
from app.services.nutrition import get_food_fuzzy, compute_macros_from_food

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/analyze", response_model=AnalyzeMealResponse)
async def analyze_meal(
    images: List[UploadFile] = File(...),
    metadata: Optional[str] = Form(None),
):
    """
    POST /meals/analyze

    Accepts multipart form-data with multiple images and optional metadata.
    Returns deterministic mock analysis for MVP.
    """
    if not images:
        raise HTTPException(status_code=400, detail="At least one image is required")
    if len(images) < 3:
        raise HTTPException(status_code=400, detail="Minimum 3 photos required")

    meta_dict = {}
    if metadata:
        try:
            meta_dict = json.loads(metadata)
        except json.JSONDecodeError:
            logger.warning("Failed to parse metadata JSON")

    image_bytes = [await img.read() for img in images]

    try:
        analysis = await analyze_images_deterministic(image_bytes, meta_dict)
        return analysis
    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        raise HTTPException(status_code=500, detail="Analysis failed")


@router.post("/")
async def save_meal(request: SaveMealRequest):
    """
    POST /meals

    Persists a confirmed meal.
    Fuzzy-matches each item label to a food record, recomputes macros from DB,
    and stores everything as a single meal document (denormalised, items embedded).

    Returns the saved meal's ID, timestamp, item count, and total kcal.
    """
    meal_id = str(uuid.uuid4())
    timestamp = (request.timestamp or datetime.utcnow()).isoformat()

    embedded_items: List[dict] = []
    total_kcal = 0
    unmatched: List[str] = []

    for item in request.items:
        food = get_food_fuzzy(db, item.label)

        if food is None:
            logger.warning(f"No DB match for label='{item.label}'; using client macros")
            unmatched.append(item.label)
            macros = {
                "kcal": item.macros.kcal,
                "protein_g": item.macros.protein_g,
                "carbs_g": item.macros.carbs_g,
                "fat_g": item.macros.fat_g,
            }
            food_id = "unknown"
        else:
            macros = compute_macros_from_food(food, item.grams)
            food_id = food.get("food_id", "unknown")

        total_kcal += macros["kcal"]
        embedded_items.append({
            "food_id": food_id,
            "label": item.label,
            "grams": item.grams,
            **macros,
        })

    db.save_meal(
        meal_id=meal_id,
        timestamp=timestamp,
        notes=request.notes,
        items=embedded_items,
    )

    return {
        "meal_id": meal_id,
        "timestamp": timestamp,
        "item_count": len(request.items),
        "total_kcal": total_kcal,
        "unmatched_labels": unmatched,
        "status": "saved",
    }


@router.get("/today", response_model=MealTotalResponse)
async def get_meals_today():
    """
    GET /meals/today

    Returns totals for all meals saved today (UTC date).
    Reads embedded item macros — no re-join needed.
    """
    today_str = date.today().isoformat()  # "YYYY-MM-DD"
    meals = db.get_meals_by_date(today_str)

    total_kcal = 0
    total_protein = 0.0
    total_carbs = 0.0
    total_fat = 0.0
    meal_summaries = []

    for meal in meals:
        meal_kcal = sum(it.get("kcal", 0) for it in meal.get("items", []))
        total_kcal += meal_kcal
        total_protein += sum(it.get("protein_g", 0.0) for it in meal.get("items", []))
        total_carbs += sum(it.get("carbs_g", 0.0) for it in meal.get("items", []))
        total_fat += sum(it.get("fat_g", 0.0) for it in meal.get("items", []))
        meal_summaries.append({
            "meal_id": meal.get("meal_id"),
            "timestamp": meal.get("timestamp"),
            "item_count": len(meal.get("items", [])),
            "total_kcal": meal_kcal,
        })

    return MealTotalResponse(
        total_kcal=total_kcal,
        total_protein_g=round(total_protein, 1),
        total_carbs_g=round(total_carbs, 1),
        total_fat_g=round(total_fat, 1),
        meal_count=len(meals),
        meals=meal_summaries,
    )
