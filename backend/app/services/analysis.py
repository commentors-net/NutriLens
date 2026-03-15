"""Analysis service for meal images.

Default behavior remains deterministic fallback for local/dev reliability.
When `GEMINI_API_KEY` is configured, NutriLens will first attempt multimodal
Gemini analysis and then map labels to the nutrition database.
"""

import hashlib
import json
import os
import re
import time
from datetime import datetime
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

try:
    from google import genai
    from google.genai import types as genai_types
except Exception:
    genai = None
    genai_types = None

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
_genai_client = None

if GEMINI_API_KEY and genai is not None:
    _genai_client = genai.Client(api_key=GEMINI_API_KEY)

ALLOWED_SHOTS = {"top_down", "lower_left_angle", "lower_right_angle", "closeup"}

RULE_CACHE_TTL_SECONDS = int(os.getenv("NUTRILENS_RULE_CACHE_TTL_SECONDS", "300"))
RULE_MIN_SAMPLES = int(os.getenv("NUTRILENS_RULE_MIN_SAMPLES", "2"))
RULE_MIN_CONFIDENCE = float(os.getenv("NUTRILENS_RULE_MIN_CONFIDENCE", "0.6"))
RULE_MAX_FETCH = int(os.getenv("NUTRILENS_RULE_MAX_FETCH", "2000"))


def _env_flag(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


FEEDBACK_RULES_ENABLED = _env_flag("NUTRILENS_FEEDBACK_RULES_ENABLED", True)
_feedback_rules_enabled = FEEDBACK_RULES_ENABLED
_feedback_rules_state_loaded = False
_feedback_rules_last_change: Optional[Dict[str, str]] = None


@dataclass
class FeedbackRule:
    original_label: str
    corrected_label: str
    avg_grams_delta: int
    sample_count: int
    confidence: float


_feedback_rule_cache: Dict[str, FeedbackRule] = {}
_feedback_rule_cache_expires_at = 0.0
_feedback_rule_metrics: Dict[str, int] = {
    "analyze_requests_total": 0,
    "feedback_rules_enabled_requests": 0,
    "feedback_rules_disabled_requests": 0,
    "rules_cache_refresh_count": 0,
    "rules_applied_request_count": 0,
    "rules_applied_item_count": 0,
}


def _increment_metric(metric_name: str, amount: int = 1) -> None:
    _feedback_rule_metrics[metric_name] = int(_feedback_rule_metrics.get(metric_name, 0)) + amount


def _parse_bool(value: Any, default: bool) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return default
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _load_feedback_rules_state(force_refresh: bool = False) -> None:
    global _feedback_rules_enabled, _feedback_rules_state_loaded, _feedback_rules_last_change

    if _feedback_rules_state_loaded and not force_refresh:
        return

    _feedback_rules_enabled = FEEDBACK_RULES_ENABLED
    _feedback_rules_last_change = None

    if not hasattr(db, "get_nutrilens_setting"):
        _feedback_rules_state_loaded = True
        return

    try:
        setting = db.get_nutrilens_setting("feedback_rules_enabled")
        if setting and "value" in setting:
            _feedback_rules_enabled = _parse_bool(setting.get("value"), FEEDBACK_RULES_ENABLED)
            _feedback_rules_last_change = {
                "updated_by": str(setting.get("updated_by") or "system"),
                "updated_at": str(setting.get("updated_at") or ""),
            }
    except Exception:
        _feedback_rules_enabled = FEEDBACK_RULES_ENABLED

    _feedback_rules_state_loaded = True


def _normalize_label(label: str) -> str:
    return str(label or "").strip().lower()


def _build_feedback_rules(corrections: List[Dict[str, Any]]) -> Dict[str, FeedbackRule]:
    by_original: Dict[str, Dict[str, Any]] = {}

    for row in corrections:
        original_label = _normalize_label(row.get("original_label"))
        corrected_label = _normalize_label(row.get("corrected_label"))
        if not original_label or not corrected_label:
            continue

        original_bucket = by_original.setdefault(
            original_label,
            {"total": 0, "variants": {}},
        )
        original_bucket["total"] += 1

        variant_bucket = original_bucket["variants"].setdefault(
            corrected_label,
            {"count": 0, "delta_sum": 0},
        )
        variant_bucket["count"] += 1

        try:
            variant_bucket["delta_sum"] += int(row.get("grams_delta", 0))
        except (TypeError, ValueError):
            pass

    rules: Dict[str, FeedbackRule] = {}
    for original_label, aggregate in by_original.items():
        variants = aggregate["variants"]
        if not variants:
            continue

        corrected_label, stats = max(
            variants.items(),
            key=lambda item: item[1]["count"],
        )
        sample_count = int(stats["count"])
        total_count = int(aggregate["total"])
        confidence = sample_count / total_count if total_count else 0.0

        if sample_count < RULE_MIN_SAMPLES or confidence < RULE_MIN_CONFIDENCE:
            continue
        if corrected_label == original_label:
            continue

        avg_delta = int(round(stats["delta_sum"] / sample_count)) if sample_count else 0

        rules[original_label] = FeedbackRule(
            original_label=original_label,
            corrected_label=corrected_label,
            avg_grams_delta=avg_delta,
            sample_count=sample_count,
            confidence=round(confidence, 2),
        )

    return rules


def _get_feedback_rules() -> Dict[str, FeedbackRule]:
    global _feedback_rule_cache, _feedback_rule_cache_expires_at

    now = time.time()
    if _feedback_rule_cache and now < _feedback_rule_cache_expires_at:
        return _feedback_rule_cache

    if not hasattr(db, "get_corrections"):
        _feedback_rule_cache = {}
        _feedback_rule_cache_expires_at = now + RULE_CACHE_TTL_SECONDS
        return _feedback_rule_cache

    try:
        _increment_metric("rules_cache_refresh_count")
        corrections = db.get_corrections(limit=RULE_MAX_FETCH)
        _feedback_rule_cache = _build_feedback_rules(corrections)
    except Exception:
        _feedback_rule_cache = {}

    _feedback_rule_cache_expires_at = now + RULE_CACHE_TTL_SECONDS
    return _feedback_rule_cache


def _apply_feedback_rules_to_response(response: AnalyzeMealResponse) -> AnalyzeMealResponse:
    _load_feedback_rules_state()

    if not _feedback_rules_enabled:
        _increment_metric("feedback_rules_disabled_requests")
        return response

    _increment_metric("feedback_rules_enabled_requests")
    rules = _get_feedback_rules()
    if not rules:
        return response

    updated_items: List[AnalyzeItem] = []
    feedback_warnings: List[str] = []

    for item in response.items:
        normalized_label = _normalize_label(item.label)
        rule = rules.get(normalized_label)
        if not rule:
            updated_items.append(item)
            continue

        new_grams = max(item.grams_estimate + rule.avg_grams_delta, 1)
        grams_shift = new_grams - item.grams_estimate

        grams_min = max(item.grams_range.min + grams_shift, 1)
        grams_max = max(item.grams_range.max + grams_shift, grams_min)

        food = get_food_fuzzy(db, rule.corrected_label)
        if food:
            macros_dict = compute_macros_from_food(food, new_grams)
            macros = Macros(**macros_dict)
        else:
            macros = item.macros

        updated_items.append(
            AnalyzeItem(
                item_id=item.item_id,
                label=rule.corrected_label,
                label_confidence=item.label_confidence,
                grams_estimate=new_grams,
                grams_range=GramsRange(min=grams_min, max=grams_max),
                grams_confidence=item.grams_confidence,
                macros=macros,
            )
        )

        feedback_warnings.append(
            f"feedback_rule_applied: {rule.original_label}->{rule.corrected_label}"
        )

    if not feedback_warnings:
        return response

    _increment_metric("rules_applied_request_count")
    _increment_metric("rules_applied_item_count", len(feedback_warnings))

    warnings = list(response.warnings)
    for warning in feedback_warnings:
        if warning not in warnings:
            warnings.append(warning)

    return AnalyzeMealResponse(
        overall_confidence=response.overall_confidence,
        needs_more_photos=response.needs_more_photos,
        suggested_next_shots=response.suggested_next_shots,
        items=updated_items,
        warnings=warnings,
    )


def get_feedback_rule_observability() -> Dict[str, Any]:
    _load_feedback_rules_state()
    active_rules = _get_feedback_rules() if _feedback_rules_enabled else {}
    enabled_requests = int(_feedback_rule_metrics.get("feedback_rules_enabled_requests", 0))
    applied_requests = int(_feedback_rule_metrics.get("rules_applied_request_count", 0))
    hit_rate_pct = round((applied_requests / enabled_requests) * 100, 2) if enabled_requests else 0.0
    recent_audit: List[Dict[str, Any]] = []

    if hasattr(db, "get_nutrilens_setting_audit"):
        try:
            entries = db.get_nutrilens_setting_audit("feedback_rules_enabled", limit=5)
            recent_audit = [
                {
                    "value": str(entry.get("value", "")),
                    "updated_by": str(entry.get("updated_by", "system")),
                    "updated_at": str(entry.get("updated_at", "")),
                }
                for entry in entries
            ]
        except Exception:
            recent_audit = []

    return {
        "enabled": _feedback_rules_enabled,
        "configured_default_enabled": FEEDBACK_RULES_ENABLED,
        "last_change": _feedback_rules_last_change,
        "recent_audit": recent_audit,
        "settings": {
            "cache_ttl_seconds": RULE_CACHE_TTL_SECONDS,
            "min_samples": RULE_MIN_SAMPLES,
            "min_confidence": RULE_MIN_CONFIDENCE,
            "max_fetch": RULE_MAX_FETCH,
        },
        "active_rule_count": len(active_rules),
        "metrics": {
            "analyze_requests_total": int(_feedback_rule_metrics.get("analyze_requests_total", 0)),
            "feedback_rules_enabled_requests": enabled_requests,
            "feedback_rules_disabled_requests": int(_feedback_rule_metrics.get("feedback_rules_disabled_requests", 0)),
            "rules_cache_refresh_count": int(_feedback_rule_metrics.get("rules_cache_refresh_count", 0)),
            "rules_applied_request_count": applied_requests,
            "rules_applied_item_count": int(_feedback_rule_metrics.get("rules_applied_item_count", 0)),
            "rule_hit_rate_pct": hit_rate_pct,
        },
    }


def set_feedback_rules_enabled(enabled: bool, updated_by: str = "system") -> Dict[str, Any]:
    global _feedback_rules_enabled, _feedback_rules_last_change

    _load_feedback_rules_state()

    _feedback_rules_enabled = bool(enabled)

    setting_value = "true" if _feedback_rules_enabled else "false"
    if hasattr(db, "set_nutrilens_setting"):
        try:
            saved = db.set_nutrilens_setting("feedback_rules_enabled", setting_value, updated_by or "system")
            _feedback_rules_last_change = {
                "updated_by": str(saved.get("updated_by") or updated_by or "system"),
                "updated_at": str(saved.get("updated_at") or ""),
            }
        except Exception:
            pass

    if _feedback_rules_last_change is None:
        _feedback_rules_last_change = {
            "updated_by": updated_by or "system",
            "updated_at": datetime.utcnow().isoformat(),
        }

    return get_feedback_rule_observability()


def _normalize_model_name(model_name: str) -> str:
    if model_name.startswith("models/"):
        return model_name.split("/", 1)[1]
    return model_name


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

    _resolved_gemini_model = candidate_models[0] if candidate_models else preferred_model
    return _resolved_gemini_model


def _extract_gemini_text(response: Any) -> str:
    direct_text = getattr(response, "text", None)
    if direct_text:
        return direct_text

    candidates = getattr(response, "candidates", []) or []
    for candidate in candidates:
        content = getattr(candidate, "content", None)
        parts = getattr(content, "parts", []) or []
        chunks: List[str] = []
        for part in parts:
            text = getattr(part, "text", None)
            if text:
                chunks.append(text)
        if chunks:
            return "\n".join(chunks)

    return ""


def _generate_gemini_content(parts: List[Any]):
    if _genai_client is None:
        raise RuntimeError("google.genai client is not initialized")

    preferred_model = resolve_gemini_model()
    candidate_models = []
    for model_name in [preferred_model, *FALLBACK_GEMINI_MODELS]:
        normalized = _normalize_model_name(model_name)
        if normalized and normalized not in candidate_models:
            candidate_models.append(normalized)

    last_error: Optional[Exception] = None
    for model_name in candidate_models:
        try:
            response = _genai_client.models.generate_content(
                model=model_name,
                contents=parts,
            )
            return _extract_gemini_text(response)
        except Exception as error:
            last_error = error
            continue

    if last_error:
        raise last_error
    raise RuntimeError("Gemini generation failed without a specific error")


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
    _increment_metric("analyze_requests_total")
    analysis: AnalyzeMealResponse
    if GEMINI_API_KEY and _genai_client is not None and genai_types is not None:
        try:
            analysis = await analyze_images_gemini(image_bytes, metadata)
            return _apply_feedback_rules_to_response(analysis)
        except Exception:
            # Preserve existing reliability by falling back to deterministic output.
            pass

    analysis = await analyze_images_deterministic(image_bytes, metadata)
    return _apply_feedback_rules_to_response(analysis)


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

    if genai_types is None:
        raise RuntimeError("google.genai SDK types are unavailable")

    parts: List[Any] = [genai_types.Part.from_text(text=prompt)]
    for image in image_bytes[:6]:
        parts.append(genai_types.Part.from_bytes(
            data=image,
            mime_type=_guess_mime_type(image),
        ))

    response_text = _generate_gemini_content(parts)
    payload = _extract_json_block(response_text)
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
