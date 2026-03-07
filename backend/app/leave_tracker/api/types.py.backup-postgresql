
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..models import Type
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

@router.get("/types", response_model=list[schemas.Type])
def read_types(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    types = db.query(Type).offset(skip).limit(limit).all()
    return types

@router.post("/types", response_model=schemas.Type)
def create_type(
    type: schemas.TypeCreate, 
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    db_type = Type(name=type.name)
    db.add(db_type)
    db.commit()
    db.refresh(db_type)
    return db_type

@router.put("/types/{type_id}", response_model=schemas.Type)
def update_type(
    type_id: int, 
    type: schemas.TypeCreate, 
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    db_type = db.query(Type).filter(Type.id == type_id).first()
    if not db_type:
        raise HTTPException(status_code=404, detail="Type not found")
    db_type.name = type.name
    db.commit()
    db.refresh(db_type)
    return db_type

@router.delete("/types/{type_id}")
def delete_type(
    type_id: int, 
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    db_type = db.query(Type).filter(Type.id == type_id).first()
    if not db_type:
        raise HTTPException(status_code=404, detail="Type not found")
    db.delete(db_type)
    db.commit()
    return {"message": "Type deleted successfully"}
