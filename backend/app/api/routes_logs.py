"""Admin-only routes for viewing uploaded mobile app diagnostic logs."""

import logging
import os
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from app.leave_tracker.db_factory import db as auth_db
from app.leave_tracker.core.security import get_current_user
from app.services.app_log_storage import list_app_logs, get_app_log

router = APIRouter()
logger = logging.getLogger(__name__)


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


def _parse_date(date_str: str) -> None:
    from datetime import datetime
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid date format: {date_str}. Use YYYY-MM-DD",
        ) from exc


@router.get("")
@router.get("/")
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
        raise HTTPException(
            status_code=400,
            detail="start date must be on or before end date",
        )
    bounded_limit = max(1, min(limit, 200))
    logs = list_app_logs(start_date=start, end_date=end, limit=bounded_limit)
    return {"logs": logs, "count": len(logs)}


@router.get("/{log_id}")
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
