from fastapi import APIRouter, Depends, HTTPException
import os
import json
import re
from typing import List, Optional

try:
    from google import genai
except Exception:
    genai = None
from .. import schemas
from ..db_factory import db
from ..core.security import get_current_user

router = APIRouter()

# Configure Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash-lite")
FALLBACK_GEMINI_MODELS = [
    "gemini-2.5-flash",
    "gemini-2.0-flash",
    "gemini-1.5-flash-latest",
]
_resolved_gemini_model: Optional[str] = None
_genai_client = genai.Client(api_key=GEMINI_API_KEY) if GEMINI_API_KEY and genai is not None else None

def _normalize_model_name(model_name: str) -> str:
    if model_name.startswith("models/"):
        return model_name.split("/", 1)[1]
    return model_name

def resolve_gemini_model(force_refresh: bool = False) -> str:
    global _resolved_gemini_model

    if _resolved_gemini_model and not force_refresh:
        return _resolved_gemini_model

    preferred_model = _normalize_model_name(GEMINI_MODEL)
    candidate_models = []
    for model_name in [preferred_model, *FALLBACK_GEMINI_MODELS]:
        normalized = _normalize_model_name(model_name)
        if normalized and normalized not in candidate_models:
            candidate_models.append(normalized)

    _resolved_gemini_model = candidate_models[0] if candidate_models else preferred_model
    return _resolved_gemini_model

def _extract_response_text(response: object) -> str:
    direct_text = getattr(response, "text", None)
    if direct_text:
        return direct_text.strip()

    candidates = getattr(response, "candidates", []) or []
    for candidate in candidates:
        content = getattr(candidate, "content", None)
        parts = getattr(content, "parts", []) or []
        chunks = []
        for part in parts:
            text = getattr(part, "text", None)
            if text:
                chunks.append(text)
        if chunks:
            return "\n".join(chunks).strip()

    return ""

def generate_content_with_resolved_model(prompt: str):
    if _genai_client is None:
        raise RuntimeError("google.genai client is not initialized")

    preferred_model = resolve_gemini_model()
    candidate_models = []
    for model_name in [preferred_model, *FALLBACK_GEMINI_MODELS]:
        normalized = _normalize_model_name(model_name)
        if normalized and normalized not in candidate_models:
            candidate_models.append(normalized)

    last_error = None
    for model_name in candidate_models:
        try:
            response = _genai_client.models.generate_content(
                model=model_name,
                contents=prompt,
            )
            return _extract_response_text(response), model_name
        except Exception as error:
            last_error = error
            continue

    if last_error is not None:
        raise last_error
    raise RuntimeError("Gemini generation failed")

def _extract_retry_seconds(error_text: str) -> Optional[int]:
    retry_in_match = re.search(r"retry in\s+([0-9]+(?:\.[0-9]+)?)s", error_text, flags=re.IGNORECASE)
    if retry_in_match:
        return int(float(retry_in_match.group(1)))

    retry_delay_match = re.search(r"retry_delay\s*\{\s*seconds:\s*(\d+)", error_text, flags=re.IGNORECASE)
    if retry_delay_match:
        return int(retry_delay_match.group(1))

    return None

def _raise_http_for_gemini_error(error: Exception) -> None:
    error_text = str(error)
    lowered = error_text.lower()

    is_quota_or_rate_limit = (
        "429" in lowered
        or "quota exceeded" in lowered
        or "rate limit" in lowered
        or "resource_exhausted" in lowered
    )
    if is_quota_or_rate_limit:
        retry_seconds = _extract_retry_seconds(error_text)
        detail = (
            "Gemini quota exceeded for this API key/project. "
            "Enable billing or use a key with available quota."
        )
        if retry_seconds is not None:
            detail += f" Retry after about {retry_seconds} seconds."

        headers = {"Retry-After": str(retry_seconds)} if retry_seconds is not None else None
        raise HTTPException(status_code=429, detail=detail, headers=headers)

    is_gemini_related = (
        "gemini" in lowered
        or "generativelanguage" in lowered
        or "generatecontent" in lowered
        or "google.api_core" in lowered
    )
    if is_gemini_related:
        raise HTTPException(
            status_code=502,
            detail=f"Gemini API request failed: {error_text}"
        )

    raise HTTPException(
        status_code=500,
        detail=f"Error processing conversation: {error_text}"
    )

@router.post("/smart-identify", response_model=schemas.SmartIdentificationResponse)
async def smart_identify_leaves(
    request: schemas.SmartIdentificationRequest,
    current_user: str = Depends(get_current_user)
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
        # Get all people and leave types from Firestore for context
        people = db.get_all_people()
        leave_types = db.get_all_types()
        
        # Get AI instructions from Firestore
        ai_instructions = db.get_ai_instructions()
        if ai_instructions:
            rules_text = ai_instructions["instructions"]
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
        
        people_names = [p["name"] for p in people] if people else []
        leave_type_names = [t["name"] for t in leave_types] if leave_types else []
        
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
        response_text, _ = generate_content_with_resolved_model(prompt)
        
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
        _raise_http_for_gemini_error(e)

@router.get("/smart-identify/health")
async def check_smart_identify_health(current_user: str = Depends(get_current_user)):
    """Check if Gemini API is configured and accessible"""
    if not GEMINI_API_KEY:
        return {
            "status": "error",
            "message": "Gemini API key not configured",
            "configured": False
        }
    if _genai_client is None:
        return {
            "status": "error",
            "message": "google.genai client is unavailable",
            "configured": True
        }
    
    try:
        resolved_model = resolve_gemini_model(force_refresh=True)
        return {
            "status": "success",
            "message": "Gemini API key configured and model resolved",
            "configured": True,
            "model": resolved_model
        }
    except Exception as e:
        return {
            "status": "error",
            "message": f"Gemini API error: {str(e)}",
            "configured": True
        }
