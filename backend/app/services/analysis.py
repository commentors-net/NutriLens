"""Analysis service for meal images.

Default behavior remains deterministic fallback for local/dev reliability.
When `GEMINI_API_KEY` is configured, NutriLens will first attempt multimodal
Gemini analysis and then map labels to the nutrition database.
"""

import hashlib
import json
import os
import re
from typing import List, Dict, Any, Optional

import google.generativeai as genai

from app.db.db_factory import db
from app.models.schemas import (
    AnalyzeMealResponse,
    AnalyzeItem,
    GramsRange,
    Macros,
)
from app.services.nutrition import get_food_fuzzy, compute_macros_from_food


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

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_MODEL = os.getenv("NUTRILENS_ANALYSIS_MODEL", os.getenv("GEMINI_MODEL", "gemini-2.0-flash-lite"))
FALLBACK_GEMINI_MODELS = [
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash-latest",
]
_resolved_gemini_model: Optional[str] = None

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

ALLOWED_SHOTS = {"top_down", "lower_left_angle", "lower_right_angle", "closeup"}


def _normalize_model_name(model_name: str) -> str:
    if model_name.startswith("models/"):
        return model_name.split("/", 1)[1]
    return model_name


def _list_generate_content_models() -> List[str]:
    models = []
    for model in genai.list_models():
        methods = getattr(model, "supported_generation_methods", []) or []
        if "generateContent" not in methods:
            continue

        model_name = _normalize_model_name(getattr(model, "name", ""))
        if model_name and model_name not in models:
            models.append(model_name)
    return models


def resolve_gemini_model(force_refresh: bool = False) -> str:
    global _resolved_gemini_model

    if _resolved_gemini_model and not force_refresh:
        return _resolved_gemini_model

    preferred_model = _normalize_model_name(GEMINI_MODEL)
    candidate_models = []
    for model_name in [preferred_model, *FALLBACK_GEMINI_MODELS]:
        normalized = _normalize_model_name(model_name)
        if normalized and normalized not in candidate_models:
            candidate_models.append(normalized)

    try:
        available_models = _list_generate_content_models()
        for model_name in candidate_models:
            if model_name in available_models:
                _resolved_gemini_model = model_name
                return _resolved_gemini_model

        if available_models:
            _resolved_gemini_model = available_models[0]
            return _resolved_gemini_model
    except Exception:
        pass

    _resolved_gemini_model = preferred_model
    return _resolved_gemini_model


def _generate_gemini_content(parts: List[Dict[str, Any]]):
    model_name = resolve_gemini_model()
    try:
        model = genai.GenerativeModel(model_name)
        return model.generate_content(parts)
    except Exception as first_error:
        message = str(first_error).lower()
        should_refresh = "404" in message or "not found" in message or "not supported" in message
        if not should_refresh:
            raise

        refreshed_model = resolve_gemini_model(force_refresh=True)
        if refreshed_model == model_name:
            raise

        model = genai.GenerativeModel(refreshed_model)
        return model.generate_content(parts)


def _extract_json_block(text: str) -> Dict[str, Any]:
    cleaned = text.strip()
    cleaned = re.sub(r"^```json\s*", "", cleaned)
    cleaned = re.sub(r"```$", "", cleaned).strip()
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("No JSON object found in AI response")
    return json.loads(cleaned[start : end + 1])


def _guess_mime_type(image_data: bytes) -> str:
    if image_data.startswith(b"\x89PNG"):
        return "image/png"
    if image_data.startswith(b"\xff\xd8"):
        return "image/jpeg"
    if image_data.startswith(b"GIF87a") or image_data.startswith(b"GIF89a"):
        return "image/gif"
    return "image/jpeg"


def _clamp_confidence(value: Any, default: float) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        parsed = default
    return max(0.0, min(parsed, 1.0))


def _normalize_suggested_shots(value: Any, needs_more_photos: bool) -> List[str]:
    if not isinstance(value, list):
        return ["top_down", "closeup"] if needs_more_photos else []

    normalized: List[str] = []
    for shot in value:
        shot_name = str(shot).strip()
        if shot_name in ALLOWED_SHOTS and shot_name not in normalized:
            normalized.append(shot_name)

    if needs_more_photos and not normalized:
        return ["top_down", "closeup"]
    return normalized


def _normalize_warnings(value: Any) -> List[str]:
    if not isinstance(value, list):
        return []

    normalized: List[str] = []
    for warning in value:
        warning_text = str(warning).strip()
        if warning_text and warning_text not in normalized:
            normalized.append(warning_text)
    return normalized


def _build_item_from_ai(item_id: str, item_data: Dict[str, Any]) -> AnalyzeItem:
    label = str(item_data.get("label", "unknown food")).strip().lower()
    grams_estimate = max(int(round(float(item_data.get("grams_estimate", 100)))), 1)
    range_min = max(int(round(float(item_data.get("grams_range", {}).get("min", max(grams_estimate - 30, 1))))), 1)
    range_max = max(int(round(float(item_data.get("grams_range", {}).get("max", grams_estimate + 30)))), range_min)

    food = get_food_fuzzy(db, label)
    if food:
        macros_dict = compute_macros_from_food(food, grams_estimate)
    else:
        macros_dict = {"kcal": 0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0}

    return AnalyzeItem(
        item_id=item_id,
        label=label,
        label_confidence=_clamp_confidence(item_data.get("label_confidence"), 0.65),
        grams_estimate=grams_estimate,
        grams_range=GramsRange(min=range_min, max=range_max),
        grams_confidence=_clamp_confidence(item_data.get("grams_confidence"), 0.55),
        macros=Macros(**macros_dict),
    )


def build_analysis_response_from_ai_payload(
    payload: Dict[str, Any],
    image_count: int,
) -> AnalyzeMealResponse:
    raw_items = payload.get("items") or []
    if not raw_items:
        raise ValueError("AI response did not include any items")

    items = [_build_item_from_ai(f"tmp-{index + 1}", item) for index, item in enumerate(raw_items[:5])]
    unmatched_labels = [item.label for item in items if item.macros.kcal == 0]

    overall_confidence = _clamp_confidence(payload.get("overall_confidence"), 0.68)
    needs_more_photos = bool(payload.get("needs_more_photos", image_count < 5))
    if overall_confidence < 0.7 and image_count < 5:
        needs_more_photos = True

    warnings = _normalize_warnings(payload.get("warnings"))
    if unmatched_labels:
        warnings.append(f"nutrition_db_unmatched: {', '.join(unmatched_labels)}")

    return AnalyzeMealResponse(
        overall_confidence=overall_confidence,
        needs_more_photos=needs_more_photos,
        suggested_next_shots=_normalize_suggested_shots(payload.get("suggested_next_shots"), needs_more_photos),
        items=items,
        warnings=warnings,
    )


async def analyze_images(
    image_bytes: List[bytes],
    metadata: Dict[str, Any],
) -> AnalyzeMealResponse:
    if GEMINI_API_KEY:
        try:
            return await analyze_images_gemini(image_bytes, metadata)
        except Exception:
            # Preserve existing reliability by falling back to deterministic output.
            pass

    return await analyze_images_deterministic(image_bytes, metadata)


async def analyze_images_gemini(
    image_bytes: List[bytes],
    metadata: Dict[str, Any],
) -> AnalyzeMealResponse:
    if not image_bytes:
        raise ValueError("At least one image required")

    prompt = f"""
You are a food analysis assistant for NutriLens.

Analyze the provided meal photos and identify visible food items.
Estimate grams conservatively and return JSON only.

Rules:
- Prefer 1 to 5 food items.
- Use simple food labels likely to match a nutrition database.
- Return confidence values between 0 and 1.
- If portion size is uncertain, widen grams_range and lower grams_confidence.
- If the meal is unclear, set needs_more_photos to true and suggest useful next shots.

Metadata:
{json.dumps(metadata or {}, ensure_ascii=True)}

Output schema:
{{
  "overall_confidence": 0.0,
  "needs_more_photos": false,
  "suggested_next_shots": ["top_down"],
  "items": [
    {{
      "label": "white rice",
      "label_confidence": 0.8,
      "grams_estimate": 180,
      "grams_range": {{"min": 140, "max": 230}},
      "grams_confidence": 0.6
    }}
  ],
  "warnings": []
}}
""".strip()

    parts: List[Dict[str, Any] | str] = [prompt]
    for image in image_bytes[:6]:
        parts.append({
            "mime_type": _guess_mime_type(image),
            "data": image,
        })

    response = _generate_gemini_content(parts)
    payload = _extract_json_block(getattr(response, "text", ""))
    return build_analysis_response_from_ai_payload(payload, len(image_bytes))


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
