"""
API routes for meal analysis and management — Milestone 3.
"""

import uuid
import logging
import json
from datetime import datetime, date
from typing import List, Optional

from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.db.models import Meal, MealItem
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
    Returns deterministic mock analysis for MVP (Milestone 2/3).
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

    image_bytes = []
    for img in images:
        content = await img.read()
        image_bytes.append(content)

    try:
        analysis = await analyze_images_deterministic(image_bytes, meta_dict)
        return analysis
    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        raise HTTPException(status_code=500, detail="Analysis failed")


@router.post("/")
async def save_meal(
    request: SaveMealRequest,
    db: Session = Depends(get_db),
):
    """
    POST /meals

    Persists a confirmed meal to SQLite.
    Fuzzy-matches each item label to a Food row, recomputes macros from DB,
    and stores Meal + MealItem records.

    Returns the saved meal's ID, timestamp, item count, and total kcal.
    """
    meal_id = str(uuid.uuid4())
    timestamp = request.timestamp or datetime.utcnow()

    meal = Meal(meal_id=meal_id, timestamp=timestamp, notes=request.notes)
    db.add(meal)

    total_kcal = 0
    unmatched: List[str] = []

    for item in request.items:
        food = get_food_fuzzy(db, item.label)

        if food is None:
            # Fall back to macros supplied by the client (already computed)
            logger.warning(f"No DB match for label='{item.label}'; using client macros")
            unmatched.append(item.label)
            total_kcal += item.macros.kcal
            # Store with a placeholder food_id so FK is satisfied
            food_id = "unknown"
        else:
            macros = compute_macros_from_food(food, item.grams)
            total_kcal += macros["kcal"]
            food_id = food.food_id

        db.add(MealItem(
            item_id=str(uuid.uuid4()),
            meal_id=meal_id,
            food_id=food_id,
            grams=item.grams,
        ))

    db.commit()

    return {
        "meal_id": meal_id,
        "timestamp": timestamp.isoformat(),
        "item_count": len(request.items),
        "total_kcal": total_kcal,
        "unmatched_labels": unmatched,
        "status": "saved",
    }


@router.get("/today", response_model=MealTotalResponse)
async def get_meals_today(db: Session = Depends(get_db)):
    """
    GET /meals/today

    Returns totals for all meals saved today (UTC date).
    Joins MealItem → Food to recompute macros from the authoritative DB.
    """
    today = date.today()

    meals_today = (
        db.query(Meal)
        .filter(Meal.timestamp >= datetime(today.year, today.month, today.day))
        .all()
    )

    total_kcal = 0
    total_protein = 0.0
    total_carbs = 0.0
    total_fat = 0.0
    meal_summaries = []

    for meal in meals_today:
        meal_kcal = 0
        for mi in meal.items:
            if mi.food and mi.food.food_id != "unknown":
                m = compute_macros_from_food(mi.food, mi.grams)
                total_kcal += m["kcal"]
                total_protein += m["protein_g"]
                total_carbs += m["carbs_g"]
                total_fat += m["fat_g"]
                meal_kcal += m["kcal"]

        meal_summaries.append({
            "meal_id": meal.meal_id,
            "timestamp": meal.timestamp.isoformat(),
            "item_count": len(meal.items),
            "total_kcal": meal_kcal,
        })

    return MealTotalResponse(
        total_kcal=total_kcal,
        total_protein_g=round(total_protein, 1),
        total_carbs_g=round(total_carbs, 1),
        total_fat_g=round(total_fat, 1),
        meal_count=len(meals_today),
        meals=meal_summaries,
    )
