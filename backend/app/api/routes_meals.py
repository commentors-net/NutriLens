"""
API routes for meal analysis and management.
"""

from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from typing import List, Optional
import json
import logging

from app.models.schemas import (
    AnalyzeMealResponse,
    AnalyzeItem,
    GramsRange,
    Macros,
    MealTotalResponse,
    SaveMealRequest,
)
from app.services.analysis import analyze_images_deterministic
from app.services.nutrition import compute_macros

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
    Returns deterministic mock analysis for MVP (Milestone 2).
    
    Args:
        images: List of image files (JPEG/PNG)
        metadata: Optional JSON string with client/capture info
        
    Returns:
        AnalyzeMealResponse with items, confidence, and macro estimates
    """
    if not images:
        raise HTTPException(status_code=400, detail="At least one image is required")
    
    if len(images) < 3:
        raise HTTPException(
            status_code=400,
            detail="Minimum 3 photos required",
        )
    
    # Parse metadata if provided
    meta_dict = {}
    if metadata:
        try:
            meta_dict = json.loads(metadata)
        except json.JSONDecodeError:
            logger.warning("Failed to parse metadata JSON")
    
    # Read image bytes for deterministic hashing
    image_bytes = []
    for img in images:
        content = await img.read()
        image_bytes.append(content)
    
    # Call deterministic analysis service
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
    
    Saves a confirmed meal (optional for MVP).
    
    Args:
        request: SaveMealRequest with items and optional notes
        
    Returns:
        Confirmation with meal ID and summary
    """
    # TODO: Implement DB save logic in Milestone 3
    total_kcal = sum(item.macros.kcal for item in request.items)
    
    return {
        "meal_id": "meal-001",
        "timestamp": request.timestamp,
        "item_count": len(request.items),
        "total_kcal": total_kcal,
        "status": "saved",
    }


@router.get("/today", response_model=MealTotalResponse)
async def get_meals_today():
    """
    GET /meals/today
    
    Fetches today's meal totals (optional for MVP).
    
    Returns:
        MealTotalResponse with daily aggregates
    """
    # TODO: Implement DB query logic in Milestone 3
    return MealTotalResponse(
        total_kcal=0,
        total_protein_g=0.0,
        total_carbs_g=0.0,
        total_fat_g=0.0,
        meal_count=0,
        meals=[],
    )
