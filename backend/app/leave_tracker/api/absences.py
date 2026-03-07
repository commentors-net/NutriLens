
from fastapi import APIRouter, Depends, HTTPException
from typing import Optional
from datetime import date as date_type, datetime
from .. import schemas
from ..db_factory import db
from ..core.security import get_current_user

router = APIRouter()

@router.get("/absences", response_model=list[schemas.Absence])
def read_absences(
    skip: int = 0, 
    limit: int = 1000,
    person_id: Optional[str] = None,
    type_id: Optional[str] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    current_user: str = Depends(get_current_user)
):
    # Convert date strings to date objects
    date_from_obj = datetime.fromisoformat(date_from).date() if date_from else None
    date_to_obj = datetime.fromisoformat(date_to).date() if date_to else None
    
    absences = db.get_all_absences(
        person_id=person_id,
        type_id=type_id,
        date_from=date_from_obj,
        date_to=date_to_obj
    )
    
    # Apply pagination
    return absences[skip:skip+limit]

@router.post("/absences", response_model=schemas.Absence)
def create_absence(
    absence: schemas.AbsenceCreate,
    current_user: str = Depends(get_current_user)
):
    absence_data = db.create_absence(
        date_val=absence.date,
        duration=absence.duration,
        reason=absence.reason,
        type_id=absence.type_id,
        person_id=absence.person_id,
        applied=absence.applied
    )
    return absence_data

@router.patch("/absences/{absence_id}", response_model=schemas.Absence)
def update_absence(
    absence_id: str,
    absence_update: schemas.AbsenceUpdate,
    current_user: str = Depends(get_current_user)
):
    absence = db.get_absence_by_id(absence_id)
    if not absence:
        raise HTTPException(status_code=404, detail="Absence not found")
    
    updated_absence = db.update_absence(absence_id, applied=absence_update.applied)
    return updated_absence

@router.delete("/absences/{absence_id}")
def delete_absence(
    absence_id: str,
    current_user: str = Depends(get_current_user)
):
    absence = db.get_absence_by_id(absence_id)
    if not absence:
        raise HTTPException(status_code=404, detail="Absence not found")
    
    db.delete_absence(absence_id)
    return {"message": "Absence deleted successfully"}

@router.post("/absences/bulk-delete")
def bulk_delete_absences(
    absence_ids: list[str],
    current_user: str = Depends(get_current_user)
):
    deleted_count = db.bulk_delete_absences(absence_ids)
    return {"message": f"{deleted_count} absences deleted successfully"}

@router.post("/absences/bulk-update-applied")
def bulk_update_applied(
    data: dict,
    current_user: str = Depends(get_current_user)
):
    absence_ids = data.get("ids", [])
    applied = data.get("applied", 1)
    
    updated_count = db.bulk_update_applied(absence_ids, applied)
    return {"message": f"{updated_count} absences updated successfully"}
