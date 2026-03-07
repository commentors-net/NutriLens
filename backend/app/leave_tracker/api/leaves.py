from fastapi import APIRouter

router = APIRouter()

@router.get("/")
def get_leaves():
    return {"message": "List of leaves"}

@router.post("/")
def create_leave():
    return {"message": "Leave created"}
