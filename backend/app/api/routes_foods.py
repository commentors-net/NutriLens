"""
API routes for food database management — Phase P5.

GET  /foods          — list all foods
GET  /foods/{id}     — get food by ID
POST /foods          — create new food
PUT  /foods/{id}     — update food macros
DELETE /foods/{id}   — delete food
"""

import logging
import uuid
from typing import List, Optional

from fastapi import APIRouter, HTTPException

from app.db.db_factory import db
from app.models.schemas import (
    Food,
    FoodCreate,
    FoodUpdate,
)

router = APIRouter()
logger = logging.getLogger(__name__)


@router.get("/", response_model=List[Food])
async def list_foods():
    """
    GET /foods

    Returns all foods in the database, sorted by name.
    """
    try:
        foods = db.get_all_foods()
        # Sort by name for consistent ordering
        return sorted(foods, key=lambda f: f.get("name", "").lower())
    except Exception as e:
        logger.error(f"Failed to list foods: {e}")
        raise HTTPException(status_code=500, detail="Failed to list foods")


@router.get("/{food_id}", response_model=Food)
async def get_food(food_id: str):
    """
    GET /foods/{id}

    Returns a single food by ID.
    """
    try:
        food = db.get_food_by_id(food_id)
        if not food:
            raise HTTPException(status_code=404, detail="Food not found")
        return food
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get food {food_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get food")


@router.post("/", response_model=Food)
async def create_food(data: FoodCreate):
    """
    POST /foods

    Creates a new food entry and returns the created food with ID.
    """
    food_id = str(uuid.uuid4())
    
    food_dict = {
        "food_id": food_id,
        "name": data.name,
        "kcal_per_100g": data.kcal_per_100g,
        "protein_per_100g": data.protein_per_100g,
        "carbs_per_100g": data.carbs_per_100g,
        "fat_per_100g": data.fat_per_100g,
    }
    
    try:
        # Save to database (abstracted by db_factory)
        db.save_food(food_dict)
        return food_dict
    except Exception as e:
        logger.error(f"Failed to create food: {e}")
        raise HTTPException(status_code=500, detail="Failed to create food")


@router.put("/{food_id}", response_model=Food)
async def update_food(food_id: str, data: FoodUpdate):
    """
    PUT /foods/{id}

    Updates a food's macros. Partial updates supported.
    """
    try:
        food = db.get_food_by_id(food_id)
        if not food:
            raise HTTPException(status_code=404, detail="Food not found")
        
        # Update only provided fields
        if data.name is not None:
            food["name"] = data.name
        if data.kcal_per_100g is not None:
            food["kcal_per_100g"] = data.kcal_per_100g
        if data.protein_per_100g is not None:
            food["protein_per_100g"] = data.protein_per_100g
        if data.carbs_per_100g is not None:
            food["carbs_per_100g"] = data.carbs_per_100g
        if data.fat_per_100g is not None:
            food["fat_per_100g"] = data.fat_per_100g
        
        db.save_food(food)
        return food
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update food {food_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to update food")


@router.delete("/{food_id}")
async def delete_food(food_id: str):
    """
    DELETE /foods/{id}

    Deletes a food from the database.
    """
    try:
        food = db.get_food_by_id(food_id)
        if not food:
            raise HTTPException(status_code=404, detail="Food not found")
        
        db.delete_food(food_id)
        return {"status": "deleted", "food_id": food_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to delete food {food_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete food")
