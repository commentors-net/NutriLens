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
from io import StringIO, BytesIO
from datetime import date, datetime
from typing import List, Optional, Literal

from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from reportlab.pdfgen import canvas

from app.db.db_factory import db
from app.models.schemas import (
    AnalyzeMealResponse,
    MealTotalResponse,
    SaveMealRequest,
)
from app.services.analysis import analyze_images
from app.services.nutrition import get_food_fuzzy, compute_macros_from_food

router = APIRouter()
logger = logging.getLogger(__name__)


def _parse_date(date_str: str) -> datetime:
    try:
        return datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid date format: {date_str}. Use YYYY-MM-DD") from exc


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
        analysis = await analyze_images(image_bytes, meta_dict)
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
        "correction_count": correction_count,
        "unmatched_labels": unmatched,
        "status": "saved",
    }


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
