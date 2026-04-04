"""
API routes for meal analysis and management — Phase P2 (Cloud-ready).

POST /meals/analyze  — deterministic mock analysis (unchanged from M2/M3)
POST /meals          — persist a confirmed meal via db_factory (Firestore / SQLite)
GET  /meals/today    — daily totals from db_factory
"""

import logging
import json
import uuid
import csv
import os
from collections import Counter
from io import StringIO, BytesIO
from datetime import date, datetime, timedelta
from typing import List, Optional, Literal

from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends, Header
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from reportlab.pdfgen import canvas

from app.db.db_factory import db
from app.leave_tracker.db_factory import db as auth_db
from app.leave_tracker.core.security import get_current_user
from app.leave_tracker.core.security import jwt as auth_jwt
from app.leave_tracker.core.security import SECRET_KEY, ALGORITHM
from app.models.schemas import (
    AnalyzeMealResponse,
    MealTotalResponse,
    SaveMealRequest,
)
from app.services.analysis import (
    analyze_images,
    get_analysis_runtime_status,
    get_feedback_rule_observability,
    set_feedback_rules_enabled,
)
from app.services.meal_photo_storage import (
    upload_meal_images,
    resolve_meal_image_url,
    delete_meal_image,
)
from app.services.app_log_storage import save_app_log, list_app_logs, get_app_log
from app.services.nutrition import get_food_fuzzy, compute_macros_from_food

router = APIRouter()
logger = logging.getLogger(__name__)


class FeedbackRulesToggleRequest(BaseModel):
    enabled: bool


class MealPhotoAccessRequest(BaseModel):
    image_urls: List[str]


class MealPhotoDeleteRequest(BaseModel):
    image_url: str


class AppLogUploadRequest(BaseModel):
    app_version: Optional[str] = None
    platform: Optional[str] = None
    environment: Optional[str] = None
    session_id: Optional[str] = None
    log_scope: Optional[str] = None
    range_start: Optional[str] = None
    range_end: Optional[str] = None
    logs: str


def _require_access_admin(current_user: str) -> None:
    user = auth_db.get_user_by_username(current_user)
    if user and user.get("is_admin"):
        return

    configured = os.getenv("ADMIN_USERS", "").strip()
    if not configured:
        raise HTTPException(status_code=403, detail="Admin access required")

    admin_users = {u.strip() for u in configured.split(",") if u.strip()}
    if current_user not in admin_users:
        raise HTTPException(status_code=403, detail="Admin access required")


def _parse_date(date_str: str) -> datetime:
    try:
        return datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid date format: {date_str}. Use YYYY-MM-DD") from exc


def _normalize_label(value: Optional[str]) -> str:
    return str(value or "").strip().lower()


def _extract_correction_date(correction: dict) -> Optional[date]:
    raw_date = str(correction.get("date_str") or "").strip()
    if raw_date:
        try:
            return datetime.strptime(raw_date, "%Y-%m-%d").date()
        except ValueError:
            pass

    raw_timestamp = str(correction.get("timestamp") or "").strip()
    if len(raw_timestamp) >= 10:
        try:
            return datetime.strptime(raw_timestamp[:10], "%Y-%m-%d").date()
        except ValueError:
            return None
    return None


def _build_correction_window_summary(
    corrections: List[dict],
    start_date: date,
    end_date: date,
    days: int,
) -> dict:
    date_counter: Counter[str] = Counter()

    for correction in corrections:
        correction_date = _extract_correction_date(correction)
        if correction_date is None:
            continue
        if correction_date < start_date or correction_date > end_date:
            continue
        date_counter[correction_date.isoformat()] += 1

    total_corrections = sum(date_counter.values())
    correction_rate_per_day = round(total_corrections / days, 2) if days > 0 else 0.0

    return {
        "days": days,
        "start": start_date.isoformat(),
        "end": end_date.isoformat(),
        "total_corrections": total_corrections,
        "days_with_corrections": len(date_counter),
        "correction_rate_per_day": correction_rate_per_day,
        "correction_frequency_by_date": [
            {"date": d, "count": count}
            for d, count in sorted(date_counter.items(), key=lambda item: item[0])
        ],
    }


@router.post("/analyze", response_model=AnalyzeMealResponse)
async def analyze_meal(
    images: List[UploadFile] = File(...),
    metadata: Optional[str] = Form(None),
    authorization: Optional[str] = Header(None),
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

    user_identity: Optional[str] = None
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ", 1)[1].strip()
        if token:
            try:
                payload = auth_jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
                user_identity = payload.get("sub")
            except Exception:
                user_identity = None

    try:
        analysis = await analyze_images(image_bytes, meta_dict, user_identity)
        return analysis
    except Exception as e:
        logger.error(f"Analysis failed: {e}")
        raise HTTPException(status_code=500, detail="Analysis failed")


@router.get("/analyze/runtime-status")
async def get_analyze_runtime_status():
    """
    Returns the current meal-analysis runtime mode.

    Useful for operational checks to confirm whether Gemini analysis is active
    or whether deterministic fallback is currently in use.
    """
    return get_analysis_runtime_status()


@router.post("")
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
    correction_events: List[dict] = []
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
        embedded_item = {
            "food_id": food_id,
            "label": item.label,
            "grams": item.grams,
            **macros,
        }

        if item.original_label is not None:
            embedded_item["original_label"] = item.original_label
        if item.original_grams is not None:
            embedded_item["original_grams"] = item.original_grams
        if item.corrected:
            embedded_item["corrected"] = True

            corrected_grams = int(item.grams)
            original_grams = int(item.original_grams or item.grams)
            correction_events.append({
                "correction_id": str(uuid.uuid4()),
                "meal_id": meal_id,
                "timestamp": timestamp,
                "date_str": timestamp[:10],
                "item_id": getattr(item, "item_id", None),
                "corrected_label": item.label,
                "corrected_grams": corrected_grams,
                "original_label": item.original_label or item.label,
                "original_grams": original_grams,
                "grams_delta": corrected_grams - original_grams,
            })

        embedded_items.append(embedded_item)

    db.save_meal(
        meal_id=meal_id,
        timestamp=timestamp,
        notes=request.notes,
        items=embedded_items,
        image_urls=request.image_urls,
    )

    correction_count = 0
    if correction_events and hasattr(db, "save_corrections"):
        try:
            correction_count = db.save_corrections(correction_events)
        except Exception as e:
            logger.warning(f"Failed to persist correction events for meal_id={meal_id}: {e}")

    return {
        "meal_id": meal_id,
        "timestamp": timestamp,
        "item_count": len(request.items),
        "total_kcal": total_kcal,
        "image_count": len(request.image_urls or []),
        "correction_count": correction_count,
        "unmatched_labels": unmatched,
        "status": "saved",
    }


@router.post("/with-images")
async def save_meal_with_images(
    payload: str = Form(...),
    images: List[UploadFile] = File(default_factory=list),
):
    """Save a meal and optionally upload attached meal photos.

    Payload is JSON encoded SaveMealRequest sent as a multipart field.
    """
    try:
        parsed_payload = json.loads(payload)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="Invalid payload JSON") from exc

    request = SaveMealRequest.model_validate(parsed_payload)

    meal_id = str(uuid.uuid4())
    uploaded_urls: List[str] = []
    upload_warning: Optional[str] = None
    if images:
        try:
            uploaded_urls = upload_meal_images(meal_id, images)
        except Exception as exc:
            logger.warning(f"Meal photo upload failed for meal {meal_id}: {exc}")
            upload_warning = "meal_photo_upload_failed"

    request_with_images = request.model_copy(
        update={
            "image_urls": list(request.image_urls) + uploaded_urls,
            "timestamp": request.timestamp,
        }
    )

    # Reuse existing save pipeline while preserving pre-generated meal_id.
    timestamp = (request_with_images.timestamp or datetime.utcnow()).isoformat()

    embedded_items: List[dict] = []
    correction_events: List[dict] = []
    total_kcal = 0
    unmatched: List[str] = []

    for item in request_with_images.items:
        food = get_food_fuzzy(db, item.label)

        if food is None:
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
        embedded_item = {
            "food_id": food_id,
            "label": item.label,
            "grams": item.grams,
            **macros,
        }

        if item.original_label is not None:
            embedded_item["original_label"] = item.original_label
        if item.original_grams is not None:
            embedded_item["original_grams"] = item.original_grams
        if item.corrected:
            embedded_item["corrected"] = True

            corrected_grams = int(item.grams)
            original_grams = int(item.original_grams or item.grams)
            correction_events.append({
                "correction_id": str(uuid.uuid4()),
                "meal_id": meal_id,
                "timestamp": timestamp,
                "date_str": timestamp[:10],
                "item_id": getattr(item, "item_id", None),
                "corrected_label": item.label,
                "corrected_grams": corrected_grams,
                "original_label": item.original_label or item.label,
                "original_grams": original_grams,
                "grams_delta": corrected_grams - original_grams,
            })

        embedded_items.append(embedded_item)

    db.save_meal(
        meal_id=meal_id,
        timestamp=timestamp,
        notes=request_with_images.notes,
        items=embedded_items,
        image_urls=request_with_images.image_urls,
    )

    correction_count = 0
    if correction_events and hasattr(db, "save_corrections"):
        try:
            correction_count = db.save_corrections(correction_events)
        except Exception as exc:
            logger.warning(f"Failed to persist correction events for meal_id={meal_id}: {exc}")

    response = {
        "meal_id": meal_id,
        "timestamp": timestamp,
        "item_count": len(request_with_images.items),
        "total_kcal": total_kcal,
        "image_count": len(request_with_images.image_urls),
        "correction_count": correction_count,
        "unmatched_labels": unmatched,
        "status": "saved",
    }
    if upload_warning:
        response["warning"] = upload_warning
    return response


@router.post("/photos/access")
async def get_meal_photo_access_urls(
    request: MealPhotoAccessRequest,
    current_user: str = Depends(get_current_user),
):
    """Return browser-safe photo URLs for currently configured access mode."""
    _ = current_user
    resolved = []
    errors = []

    for url in request.image_urls:
        try:
            access_url = resolve_meal_image_url(url)
            resolved.append({"source_url": url, "access_url": access_url})
        except Exception as exc:
            errors.append({"source_url": url, "error": str(exc)})

    return {
        "count": len(resolved),
        "urls": resolved,
        "errors": errors,
    }


@router.delete("/photos")
async def delete_meal_photo(
    request: MealPhotoDeleteRequest,
    current_user: str = Depends(get_current_user),
):
    """Delete a meal photo object (admin-only cleanup endpoint)."""
    _require_access_admin(current_user)
    try:
        deleted = delete_meal_image(request.image_url)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Failed to delete image: {exc}") from exc

    return {
        "status": "deleted" if deleted else "not_found",
        "image_url": request.image_url,
    }


@router.post("/logs")
async def upload_app_logs(
    request: AppLogUploadRequest,
    authorization: Optional[str] = Header(None),
):
    if not request.logs.strip():
        raise HTTPException(status_code=400, detail="logs must not be empty")

    if len(request.logs) > 500_000:
        raise HTTPException(status_code=400, detail="logs payload too large")

    user_identity: Optional[str] = None
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ", 1)[1].strip()
        if token:
            try:
                payload = auth_jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
                user_identity = payload.get("sub")
            except Exception:
                user_identity = None

    result = save_app_log(
        {
            "app_version": request.app_version,
            "platform": request.platform,
            "environment": request.environment,
            "session_id": request.session_id,
            "log_scope": request.log_scope,
            "range_start": request.range_start,
            "range_end": request.range_end,
            "logs": request.logs,
        },
        user_identity=user_identity,
    )

    logger.info(f"Received app log upload {result.get('log_id')} stored via {result.get('storage')}")
    return {
        "status": "uploaded",
        **result,
    }


@router.get("/logs")
async def list_app_log_entries(
    start: Optional[str] = None,
    end: Optional[str] = None,
    limit: int = 50,
    current_user: str = Depends(get_current_user),
):
    """Admin-only: list uploaded app log metadata, newest first."""
    _require_access_admin(current_user)
    if start:
        _parse_date(start)
    if end:
        _parse_date(end)
    if start and end and start > end:
        raise HTTPException(status_code=400, detail="start date must be on or before end date")
    bounded_limit = max(1, min(limit, 200))
    logs = list_app_logs(start_date=start, end_date=end, limit=bounded_limit)
    return {"logs": logs, "count": len(logs)}


@router.get("/logs/{log_id}")
async def get_app_log_entry(
    log_id: str,
    date: Optional[str] = None,
    current_user: str = Depends(get_current_user),
):
    """Admin-only: retrieve the full content of an uploaded app log."""
    _require_access_admin(current_user)
    if not log_id.strip():
        raise HTTPException(status_code=400, detail="log_id must not be empty")
    if date:
        _parse_date(date)
    entry = get_app_log(log_id=log_id, date_str=date)
    if entry is None:
        raise HTTPException(status_code=404, detail="Log entry not found")
    return entry


@router.get("/corrections")
async def get_meal_corrections(
    start: Optional[str] = None,
    end: Optional[str] = None,
    limit: int = 100,
):
    if start:
        _parse_date(start)
    if end:
        _parse_date(end)
    if start and end and start > end:
        raise HTTPException(status_code=400, detail="start date must be on or before end date")

    bounded_limit = max(1, min(limit, 500))

    if not hasattr(db, "get_corrections"):
        return {
            "count": 0,
            "corrections": [],
        }

    corrections = db.get_corrections(start_date=start, end_date=end, limit=bounded_limit)
    return {
        "count": len(corrections),
        "corrections": corrections,
    }


@router.get("/corrections/analytics")
async def get_meal_correction_analytics(
    start: Optional[str] = None,
    end: Optional[str] = None,
    limit: int = 1000,
):
    if start:
        _parse_date(start)
    if end:
        _parse_date(end)
    if start and end and start > end:
        raise HTTPException(status_code=400, detail="start date must be on or before end date")

    bounded_limit = max(1, min(limit, 5000))

    if not hasattr(db, "get_corrections"):
        return {
            "count": 0,
            "top_corrected_labels": [],
            "avg_grams_delta": 0.0,
            "correction_frequency": {
                "by_date": [],
                "by_corrected_label": [],
            },
        }

    corrections = db.get_corrections(start_date=start, end_date=end, limit=bounded_limit)

    label_counter = Counter()
    original_label_counter = Counter()
    date_counter = Counter()
    delta_sum = 0
    delta_count = 0

    for correction in corrections:
        corrected_label = str(correction.get("corrected_label") or "").strip().lower()
        if corrected_label:
            label_counter[corrected_label] += 1

        original_label = _normalize_label(correction.get("original_label"))
        if original_label:
            original_label_counter[original_label] += 1

        date_str = str(correction.get("date_str") or "").strip()
        if date_str:
            date_counter[date_str] += 1

        try:
            delta = int(correction.get("grams_delta", 0))
            delta_sum += delta
            delta_count += 1
        except (TypeError, ValueError):
            continue

    top_corrected_labels = [
        {"label": label, "count": count}
        for label, count in label_counter.most_common(10)
    ]

    top_corrected_original_labels = [
        {"original_label": label, "count": count}
        for label, count in original_label_counter.most_common(10)
    ]

    by_date = [
        {"date": date_key, "count": count}
        for date_key, count in sorted(date_counter.items(), key=lambda item: item[0])
    ]

    by_corrected_label = [
        {"label": label, "count": count}
        for label, count in label_counter.most_common()
    ]

    avg_grams_delta = round(delta_sum / delta_count, 2) if delta_count else 0.0

    return {
        "count": len(corrections),
        "window": {
            "start": start,
            "end": end,
            "limit": bounded_limit,
        },
        "top_corrected_labels": top_corrected_labels,
        "top_corrected_original_labels": top_corrected_original_labels,
        "avg_grams_delta": avg_grams_delta,
        "correction_frequency": {
            "by_date": by_date,
            "by_corrected_label": by_corrected_label,
        },
        "feedback_rules": get_feedback_rule_observability(),
    }


@router.get("/corrections/trends")
async def get_meal_correction_trends(
    end: Optional[str] = None,
    top_k: int = 10,
    limit: int = 5000,
):
    if end:
        end_date = _parse_date(end).date()
    else:
        end_date = datetime.utcnow().date()

    bounded_top_k = max(1, min(top_k, 50))
    bounded_limit = max(1, min(limit, 10000))

    start_7 = end_date - timedelta(days=6)
    start_30 = end_date - timedelta(days=29)

    if not hasattr(db, "get_corrections"):
        return {
            "window_end": end_date.isoformat(),
            "window_7d": _build_correction_window_summary([], start_7, end_date, 7),
            "window_30d": _build_correction_window_summary([], start_30, end_date, 30),
            "top_corrected_original_labels": [],
            "top_original_to_corrected": [],
        }

    corrections = db.get_corrections(
        start_date=start_30.isoformat(),
        end_date=end_date.isoformat(),
        limit=bounded_limit,
    )

    original_label_counter: Counter[str] = Counter()
    original_to_corrected_counter: Counter[tuple[str, str]] = Counter()

    for correction in corrections:
        original_label = _normalize_label(correction.get("original_label"))
        corrected_label = _normalize_label(correction.get("corrected_label"))

        if original_label:
            original_label_counter[original_label] += 1

        if original_label and corrected_label and original_label != corrected_label:
            original_to_corrected_counter[(original_label, corrected_label)] += 1

    top_corrected_original_labels = [
        {"original_label": label, "count": count}
        for label, count in original_label_counter.most_common(bounded_top_k)
    ]

    top_original_to_corrected = [
        {
            "original_label": original_label,
            "corrected_label": corrected_label,
            "count": count,
        }
        for (original_label, corrected_label), count
        in original_to_corrected_counter.most_common(bounded_top_k)
    ]

    return {
        "window_end": end_date.isoformat(),
        "window_7d": _build_correction_window_summary(corrections, start_7, end_date, 7),
        "window_30d": _build_correction_window_summary(corrections, start_30, end_date, 30),
        "top_corrected_original_labels": top_corrected_original_labels,
        "top_original_to_corrected": top_original_to_corrected,
        "window": {
            "limit": bounded_limit,
        },
        "feedback_rules": get_feedback_rule_observability(),
    }


@router.get("/corrections/feedback-rules")
async def get_feedback_rules_runtime_status(
    current_user: str = Depends(get_current_user),
):
    _require_access_admin(current_user)
    return get_feedback_rule_observability()


@router.patch("/corrections/feedback-rules")
async def update_feedback_rules_runtime_status(
    payload: FeedbackRulesToggleRequest,
    current_user: str = Depends(get_current_user),
):
    _require_access_admin(current_user)
    status_payload = set_feedback_rules_enabled(payload.enabled, updated_by=current_user)
    return {
        "status": "updated",
        "updated_by": current_user,
        "feedback_rules": status_payload,
    }


@router.get("/today", response_model=MealTotalResponse)
async def get_meals_today(date: Optional[str] = None):
    """
    GET /meals/today

    Returns totals for all meals saved today (UTC date).
    Reads embedded item macros — no re-join needed.
    """
    target_date = date or datetime.utcnow().date().isoformat()  # "YYYY-MM-DD"
    _parse_date(target_date)
    meals = db.get_meals_by_date(target_date)

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
            "items": meal.get("items", []),
            "notes": meal.get("notes", ""),
            "image_urls": meal.get("image_urls", []),
        })

    return MealTotalResponse(
        total_kcal=total_kcal,
        total_protein_g=round(total_protein, 1),
        total_carbs_g=round(total_carbs, 1),
        total_fat_g=round(total_fat, 1),
        meal_count=len(meals),
        meals=meal_summaries,
    )


@router.get("/range", response_model=MealTotalResponse)
async def get_meals_by_range(start: str, end: str):
    """
    GET /meals/range?start=YYYY-MM-DD&end=YYYY-MM-DD

    Returns totals for all meals saved between start and end dates (inclusive).
    Useful for viewing meal history and trends over time.
    """
    meals = db.get_meals_by_date_range(start, end)

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
            "items": meal.get("items", []),
            "notes": meal.get("notes", ""),
            "image_urls": meal.get("image_urls", []),
        })

    return MealTotalResponse(
        total_kcal=total_kcal,
        total_protein_g=round(total_protein, 1),
        total_carbs_g=round(total_carbs, 1),
        total_fat_g=round(total_fat, 1),
        meal_count=len(meals),
        meals=meal_summaries,
    )


@router.get("/export")
async def export_meals(start: str, end: str, format: Literal["csv", "pdf"] = "csv"):
    """
    GET /meals/export?format=csv|pdf&start=YYYY-MM-DD&end=YYYY-MM-DD

    Exports meals in the selected date range as CSV or PDF.
    """
    start_date = _parse_date(start)
    end_date = _parse_date(end)
    if start_date > end_date:
        raise HTTPException(status_code=400, detail="start date must be on or before end date")

    meals = db.get_meals_by_date_range(start, end)
    file_suffix = f"{start}_to_{end}"

    if format == "csv":
        output = StringIO()
        writer = csv.writer(output)
        writer.writerow([
            "meal_id",
            "date",
            "time",
            "item_label",
            "grams",
            "kcal",
            "protein_g",
            "carbs_g",
            "fat_g",
            "notes",
        ])

        for meal in meals:
            timestamp = meal.get("timestamp", "")
            date_part, time_part = "", ""
            if "T" in timestamp:
                date_part, time_part = timestamp.split("T", 1)
                time_part = time_part[:8]
            else:
                date_part = timestamp[:10]

            items = meal.get("items", [])
            if not items:
                writer.writerow([
                    meal.get("meal_id", ""),
                    date_part,
                    time_part,
                    "",
                    "",
                    "",
                    "",
                    "",
                    "",
                    meal.get("notes", ""),
                ])
                continue

            for item in items:
                writer.writerow([
                    meal.get("meal_id", ""),
                    date_part,
                    time_part,
                    item.get("label", ""),
                    item.get("grams", 0),
                    item.get("kcal", 0),
                    item.get("protein_g", 0),
                    item.get("carbs_g", 0),
                    item.get("fat_g", 0),
                    meal.get("notes", ""),
                ])

        csv_data = output.getvalue().encode("utf-8")
        return StreamingResponse(
            BytesIO(csv_data),
            media_type="text/csv",
            headers={"Content-Disposition": f'attachment; filename="nutrilens_meals_{file_suffix}.csv"'},
        )

    pdf_buffer = BytesIO()
    pdf = canvas.Canvas(pdf_buffer)
    y = 800
    pdf.setFont("Helvetica-Bold", 14)
    pdf.drawString(40, y, f"NutriLens Meal Export ({start} to {end})")
    y -= 24

    pdf.setFont("Helvetica", 10)
    if not meals:
        pdf.drawString(40, y, "No meals found for the selected date range.")
    else:
        for meal in meals:
            if y < 80:
                pdf.showPage()
                y = 800
                pdf.setFont("Helvetica", 10)

            timestamp = meal.get("timestamp", "")
            meal_id = meal.get("meal_id", "")
            notes = meal.get("notes", "")
            items = meal.get("items", [])

            total_kcal = sum(item.get("kcal", 0) for item in items)
            pdf.setFont("Helvetica-Bold", 10)
            pdf.drawString(40, y, f"Meal: {meal_id} | {timestamp} | Total kcal: {total_kcal}")
            y -= 16

            pdf.setFont("Helvetica", 9)
            if notes:
                pdf.drawString(50, y, f"Notes: {notes}")
                y -= 14

            if not items:
                pdf.drawString(50, y, "No items")
                y -= 14
            else:
                for item in items:
                    line = (
                        f"- {item.get('label', '')}: {item.get('grams', 0)}g, "
                        f"{item.get('kcal', 0)} kcal, P {item.get('protein_g', 0)}g, "
                        f"C {item.get('carbs_g', 0)}g, F {item.get('fat_g', 0)}g"
                    )
                    pdf.drawString(50, y, line[:140])
                    y -= 12

            y -= 8

    pdf.save()
    pdf_buffer.seek(0)
    return StreamingResponse(
        pdf_buffer,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="nutrilens_meals_{file_suffix}.pdf"'},
    )
