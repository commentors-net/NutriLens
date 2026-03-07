from fastapi import APIRouter, Depends, HTTPException
from datetime import datetime
from .. import schemas
from ..db_factory import db
from ..core.security import get_current_user

router = APIRouter()

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
    current_user: str = Depends(get_current_user)
):
    """Get current AI instructions for Smart Identification"""
    instructions = db.get_ai_instructions()
    
    if not instructions:
        # Create default instructions if none exist
        instructions = db.create_ai_instructions(DEFAULT_INSTRUCTIONS)
    
    return instructions

@router.put("/ai-instructions", response_model=schemas.AIInstructions)
async def update_ai_instructions(
    request: schemas.AIInstructionsUpdate,
    current_user: str = Depends(get_current_user)
):
    """Update AI instructions for Smart Identification"""
    instructions = db.get_ai_instructions()
    
    if not instructions:
        # Create if doesn't exist
        instructions = db.create_ai_instructions(request.instructions)
    else:
        # Update existing
        instructions = db.update_ai_instructions(instructions["id"], request.instructions)
    
    return instructions

@router.post("/ai-instructions/reset", response_model=schemas.AIInstructions)
async def reset_ai_instructions(
    current_user: str = Depends(get_current_user)
):
    """Reset AI instructions to default"""
    instructions = db.get_ai_instructions()
    
    if not instructions:
        instructions = db.create_ai_instructions(DEFAULT_INSTRUCTIONS)
    else:
        instructions = db.update_ai_instructions(instructions["id"], DEFAULT_INSTRUCTIONS)
    
    return instructions
