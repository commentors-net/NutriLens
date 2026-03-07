
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..models import People
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

@router.get("/people", response_model=list[schemas.People])
def read_people(
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    people = db.query(People).offset(skip).limit(limit).all()
    return people

@router.post("/people", response_model=schemas.People)
def create_people(
    people: schemas.PeopleCreate, 
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    db_people = People(name=people.name)
    db.add(db_people)
    db.commit()
    db.refresh(db_people)
    return db_people

@router.put("/people/{people_id}", response_model=schemas.People)
def update_people(
    people_id: int, 
    people: schemas.PeopleCreate, 
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    db_people = db.query(People).filter(People.id == people_id).first()
    if not db_people:
        raise HTTPException(status_code=404, detail="Person not found")
    db_people.name = people.name
    db.commit()
    db.refresh(db_people)
    return db_people

@router.delete("/people/{people_id}")
def delete_people(
    people_id: int, 
    db: Session = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    db_people = db.query(People).filter(People.id == people_id).first()
    if not db_people:
        raise HTTPException(status_code=404, detail="Person not found")
    db.delete(db_people)
    db.commit()
    return {"message": "Person deleted successfully"}
