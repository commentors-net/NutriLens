from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
import google.generativeai as genai
import os
import json
import re
from datetime import datetime
from ..models import User
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

# Configure Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

@router.post("/smart-identify", response_model=schemas.SmartIdentificationResponse)
async def smart_identify_leaves(
    request: schemas.SmartIdentificationRequest, 
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Parse chat conversations to identify leave requests using Google Gemini AI.
    
    The AI will extract:
    - Person name (from the message sender)
    - Date (from timestamp or message content)
    - Leave type (MC/Medical, Annual, Dependent, WFH, etc.)
    - Reason (the actual message content)
    """
    
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=500, 
            detail="Gemini API key not configured. Please set GEMINI_API_KEY environment variable."
        )
    
    try:
        # Get all people and leave types from database for context
        from ..models import People, Type, AIInstructions
        people = db.query(People).all()
        leave_types = db.query(Type).all()
        
        # Get AI instructions from database
        ai_instructions = db.query(AIInstructions).first()
        if ai_instructions:
            rules_text = ai_instructions.instructions
        else:
            # Fallback to default rules if not in database
            rules_text = """RULES:
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
        
        people_names = [p.name for p in people] if people else []
        leave_type_names = [t.name for t in leave_types] if leave_types else []
        
        # Initialize Gemini model (use the latest stable flash model)
        model = genai.GenerativeModel('gemini-2.0-flash')
        
        # Create the prompt
        prompt = f"""
You are an expert at parsing chat conversations to identify leave/absence requests.

CONTEXT:
- Known people in the system: {', '.join(people_names) if people_names else 'No people registered yet'}
- Known leave types: {', '.join(leave_type_names) if leave_type_names else 'Medical, Annual, WFH, Dependent'}

CHAT CONVERSATION:
{request.conversation}

TASK:
Analyze the conversation and extract leave/absence information. Look for:
1. Messages indicating someone is taking leave (not "get well soon" responses)
2. The person's name from the message sender (before the colon)
3. The date from the timestamp (format: MM/DD/YYYY)
4. The leave type (MC/Medical, Annual, Dependent, WFH, etc.)
5. The reason (the actual message they sent)
6. Confidence level (high/medium/low)

{rules_text}

OUTPUT FORMAT (JSON):
{{
  "entries": [
    {{
      "person_name": "Full Name",
      "date": "MM/DD/YYYY",
      "leave_type": "Medical|Annual|Dependent|WFH",
      "duration": "Full Day|First Half|Second Half",
      "reason": "The actual message they sent",
      "confidence": "high|medium|low"
    }}
  ],
  "analysis": "Brief explanation of what was found"
}}

Return ONLY valid JSON, no additional text.
"""
        
        # Call Gemini API
        response = model.generate_content(prompt)
        response_text = response.text.strip()
        
        # Extract JSON from response (sometimes Gemini wraps it in markdown)
        json_match = re.search(r'\{[\s\S]*\}', response_text)
        if json_match:
            response_text = json_match.group(0)
        
        # Parse the response
        parsed_response = json.loads(response_text)
        
        # Convert to response model
        entries = []
        for entry in parsed_response.get("entries", []):
            entries.append(schemas.ParsedLeaveEntry(
                person_name=entry.get("person_name", "Unknown"),
                date=entry.get("date", ""),
                leave_type=entry.get("leave_type", "Unknown"),
                reason=entry.get("reason", ""),
                confidence=entry.get("confidence", "medium")
            ))
        
        return schemas.SmartIdentificationResponse(
            entries=entries,
            raw_analysis=parsed_response.get("analysis", "Analysis complete")
        )
        
    except json.JSONDecodeError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to parse AI response: {str(e)}. Response: {response_text}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error processing conversation: {str(e)}"
        )

@router.get("/smart-identify/health")
async def check_smart_identify_health(current_user: User = Depends(get_current_user)):
    """Check if Gemini API is configured and accessible"""
    if not GEMINI_API_KEY:
        return {
            "status": "error",
            "message": "Gemini API key not configured",
            "configured": False
        }
    
    try:
        # Try a simple test call (use the latest stable flash model)
        model = genai.GenerativeModel('gemini-2.0-flash')
        response = model.generate_content("Say 'OK' if you can read this.")
        return {
            "status": "success",
            "message": "Gemini API is configured and working",
            "configured": True,
            "model": "gemini-2.0-flash"
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"Gemini API error: {str(e)}",
            "configured": True
        }
