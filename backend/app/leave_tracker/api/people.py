
from fastapi import APIRouter, Depends, HTTPException
from .. import schemas
from ..db_factory import db
from ..core.security import get_current_user

router = APIRouter()

@router.get("/people", response_model=list[schemas.People])
def read_people(
    skip: int = 0, 
    limit: int = 100,
    current_user: str = Depends(get_current_user)
):
    people = db.get_all_people()
    # Apply pagination
    return people[skip:skip+limit]

@router.post("/people", response_model=schemas.People)
def create_people(
    people: schemas.PeopleCreate,
    current_user: str = Depends(get_current_user)
):
    person = db.create_person(people.name)
    return person

@router.put("/people/{people_id}", response_model=schemas.People)
def update_people(
    people_id: str, 
    people: schemas.PeopleCreate,
    current_user: str = Depends(get_current_user)
):
    person = db.get_person_by_id(people_id)
    if not person:
        raise HTTPException(status_code=404, detail="Person not found")
    updated_person = db.update_person(people_id, people.name)
    return updated_person

@router.delete("/people/{people_id}")
def delete_people(
    people_id: str,
    current_user: str = Depends(get_current_user)
):
    person = db.get_person_by_id(people_id)
    if not person:
        raise HTTPException(status_code=404, detail="Person not found")
    db.delete_person(people_id)
    return {"message": "Person deleted successfully"}
