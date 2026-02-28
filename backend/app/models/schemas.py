"""
Pydantic schemas for request/response models.
Must stay in sync with shared/schemas/ JSON schemas.
"""

from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime


class ClientInfo(BaseModel):
    """Client metadata"""
    platform: Optional[str] = None
    app_version: Optional[str] = None


class CaptureInfo(BaseModel):
    """Capture metadata"""
    photo_count: Optional[int] = None


class AnalyzeMealRequest:
    """
    Multipart form-data request.
    images: List of image files
    metadata: Optional JSON string with client/capture info
    """
    pass


class GramsRange(BaseModel):
    """Range estimate for grams"""
    min: int
    max: int


class Macros(BaseModel):
    """Nutritional macros"""
    kcal: int
    protein_g: float = Field(..., alias="protein_g")
    carbs_g: float = Field(..., alias="carbs_g")
    fat_g: float = Field(..., alias="fat_g")

    model_config = {"populate_by_name": True}


class AnalyzeItem(BaseModel):
    """Single food item in analysis result"""
    item_id: str
    label: str
    label_confidence: float
    grams_estimate: int
    grams_range: GramsRange
    grams_confidence: float
    macros: Macros


class AnalyzeMealResponse(BaseModel):
    """Response from POST /meals/analyze"""
    overall_confidence: float
    needs_more_photos: bool
    suggested_next_shots: List[str]
    items: List[AnalyzeItem]
    warnings: List[str] = Field(default_factory=list)


class MealItem(BaseModel):
    """Item within a saved meal"""
    label: str
    grams: int
    macros: Macros


class SaveMealRequest(BaseModel):
    """Request to save a confirmed meal"""
    items: List[MealItem]
    timestamp: Optional[datetime] = None
    notes: Optional[str] = None


class MealTotalResponse(BaseModel):
    """Response for today's meal totals"""
    total_kcal: int
    total_protein_g: float
    total_carbs_g: float
    total_fat_g: float
    meal_count: int
    meals: List[Dict[str, Any]] = Field(default_factory=list)
