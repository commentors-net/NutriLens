
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import desc, or_
from typing import Optional
from datetime import date as date_type
from ..models import Absence, People, Type
from .. import schemas
from ..database import SessionLocal
from ..core.security import get_current_user

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.get("/absences", response_model=list[schemas.Absence])
def read_absences(
    skip: int = 0, 
    limit: int = 1000,
    person_id: Optional[int] = None,
    type_id: Optional[int] = None,
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    query = db.query(Absence)
    
    # Apply filters
    if person_id:
        query = query.filter(Absence.person_id == person_id)
    if type_id:
        query = query.filter(Absence.type_id == type_id)
    if date_from:
        query = query.filter(Absence.date >= date_from)
    if date_to:
        query = query.filter(Absence.date <= date_to)
    
    # Order by date descending
    absences = query.order_by(desc(Absence.date)).offset(skip).limit(limit).all()
    return absences

@router.post("/absences", response_model=schemas.Absence)
def create_absence(
    absence: schemas.AbsenceCreate, 
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    db_absence = Absence(**absence.model_dump())
    db.add(db_absence)
    db.commit()
    db.refresh(db_absence)
    return db_absence

@router.patch("/absences/{absence_id}", response_model=schemas.Absence)
def update_absence(
    absence_id: int,
    absence_update: schemas.AbsenceUpdate,
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    db_absence = db.query(Absence).filter(Absence.id == absence_id).first()
    if not db_absence:
        raise HTTPException(status_code=404, detail="Absence not found")
    
    db_absence.applied = absence_update.applied
    db.commit()
    db.refresh(db_absence)
    return db_absence

@router.delete("/absences/{absence_id}")
def delete_absence(
    absence_id: int,
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    db_absence = db.query(Absence).filter(Absence.id == absence_id).first()
    if not db_absence:
        raise HTTPException(status_code=404, detail="Absence not found")
    
    db.delete(db_absence)
    db.commit()
    return {"message": "Absence deleted successfully"}

@router.post("/absences/bulk-delete")
def bulk_delete_absences(
    absence_ids: list[int],
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    deleted_count = db.query(Absence).filter(Absence.id.in_(absence_ids)).delete(synchronize_session=False)
    db.commit()
    return {"message": f"{deleted_count} absences deleted successfully"}

@router.post("/absences/bulk-update-applied")
def bulk_update_applied(
    data: dict,
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    absence_ids = data.get("ids", [])
    applied = data.get("applied", 1)
    
    updated_count = db.query(Absence).filter(Absence.id.in_(absence_ids)).update(
        {"applied": applied}, 
        synchronize_session=False
    )
    db.commit()
    return {"message": f"{updated_count} absences updated successfully"}
