
from fastapi import APIRouter, Depends, HTTPException
from .. import schemas
from ..db_factory import db
from ..core.security import get_current_user

router = APIRouter()

@router.get("/types", response_model=list[schemas.Type])
def read_types(
    skip: int = 0, 
    limit: int = 100,
    current_user: str = Depends(get_current_user)
):
    types = db.get_all_types()
    # Apply pagination
    return types[skip:skip+limit]

@router.post("/types", response_model=schemas.Type)
def create_type(
    type: schemas.TypeCreate,
    current_user: str = Depends(get_current_user)
):
    type_obj = db.create_type(type.name)
    return type_obj

@router.put("/types/{type_id}", response_model=schemas.Type)
def update_type(
    type_id: str, 
    type: schemas.TypeCreate,
    current_user: str = Depends(get_current_user)
):
    type_obj = db.get_type_by_id(type_id)
    if not type_obj:
        raise HTTPException(status_code=404, detail="Type not found")
    updated_type = db.update_type(type_id, type.name)
    return updated_type

@router.delete("/types/{type_id}")
def delete_type(
    type_id: str,
    current_user: str = Depends(get_current_user)
):
    type_obj = db.get_type_by_id(type_id)
    if not type_obj:
        raise HTTPException(status_code=404, detail="Type not found")
    db.delete_type(type_id)
    return {"message": "Type deleted successfully"}
