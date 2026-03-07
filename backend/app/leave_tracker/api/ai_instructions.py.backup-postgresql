from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from ..models import User, AIInstructions
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

# Default AI instructions
DEFAULT_INSTRUCTIONS = """RULES:
- Only extract entries from people REQUESTING leave, not people responding with "gws" or "get well soon"
- IGNORE if someone mentions being late (e.g., "I'll be late", "running late") - this is NOT a leave
- IGNORE if someone is away for just 1-2 hours - this is NOT a leave
- If someone says "taking off first half" or "taking off second half" → Annual leave with appropriate duration
- Match person names to the known people list if possible, but include close matches
- For leave type: 
  * "not feeling well", "clinic", "MC", "sick" → Medical
  * "dependent", "child sick", "family emergency" → Dependent
  * "WFH", "work from home", "working from home" → WFH (Work From Home)
  * "annual", "vacation", "taking off", "day off" → Annual
- Duration should be inferred from context:
  * "first half", "morning" → First Half
  * "second half", "afternoon", "rest of the day" → Second Half
  * "full day", "whole day", "entire day" → Full Day
- Include the original message as the reason"""

@router.get("/ai-instructions", response_model=schemas.AIInstructions)
async def get_ai_instructions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Get current AI instructions for Smart Identification"""
    instructions = db.query(AIInstructions).first()
    
    if not instructions:
        # Create default instructions if none exist
        now = datetime.utcnow().isoformat()
        instructions = AIInstructions(
            instructions=DEFAULT_INSTRUCTIONS,
            created_at=now,
            updated_at=now
        )
        db.add(instructions)
        db.commit()
        db.refresh(instructions)
    
    return instructions

@router.put("/ai-instructions", response_model=schemas.AIInstructions)
async def update_ai_instructions(
    request: schemas.AIInstructionsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Update AI instructions for Smart Identification"""
    instructions = db.query(AIInstructions).first()
    
    if not instructions:
        # Create if doesn't exist
        now = datetime.utcnow().isoformat()
        instructions = AIInstructions(
            instructions=request.instructions,
            created_at=now,
            updated_at=now
        )
        db.add(instructions)
    else:
        # Update existing
        instructions.instructions = request.instructions
        instructions.updated_at = datetime.utcnow().isoformat()
    
    db.commit()
    db.refresh(instructions)
    return instructions

@router.post("/ai-instructions/reset", response_model=schemas.AIInstructions)
async def reset_ai_instructions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Reset AI instructions to default"""
    instructions = db.query(AIInstructions).first()
    
    if not instructions:
        now = datetime.utcnow().isoformat()
        instructions = AIInstructions(
            instructions=DEFAULT_INSTRUCTIONS,
            created_at=now,
            updated_at=now
        )
        db.add(instructions)
    else:
        instructions.instructions = DEFAULT_INSTRUCTIONS
        instructions.updated_at = datetime.utcnow().isoformat()
    
    db.commit()
    db.refresh(instructions)
    return instructions
