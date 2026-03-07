from contextlib import asynccontextmanager
import logging
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from app.api.routes_meals import router as meals_router
from app.leave_tracker.api import (
    auth as lt_auth,
    people as lt_people,
    types as lt_types,
    absences as lt_absences,
    smart_identification as lt_smart_identification,
    ai_instructions as lt_ai_instructions,
)

logger = logging.getLogger(__name__)
load_dotenv()

# ─── Food seed data (mirrors seed.py but uses plain dicts for db_factory) ────
from app.db.seed import FOOD_SEED_DATA as _SEED


def _seed_data():
    return [
        {
            "food_id": row[0],
            "name": row[1],
            "kcal_per_100g": row[2],
            "protein_g_per_100g": row[3],
            "carbs_g_per_100g": row[4],
            "fat_g_per_100g": row[5],
        }
        for row in _SEED
    ]


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialise DB and seed foods on startup."""
    from app.db.db_factory import db
    food_count = db.get_food_count()
    if food_count == 0:
        n = db.seed_foods(_seed_data())
        logger.info(f"Seeded {n} food(s) into the nutrition DB.")
    else:
        logger.info(f"Nutrition DB already has {food_count} food(s) — skipping seed.")
    yield


app = FastAPI(
    title="NutriLens + Leave Tracker Unified API",
    version="0.3.0",
    description="Single backend hosting NutriLens and Leave Tracker services",
    lifespan=lifespan,
)

# CORS middleware for development
cors_origins = os.getenv("CORS_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# NutriLens routes (legacy + namespaced)
app.include_router(meals_router, prefix="/meals", tags=["meals"])
app.include_router(meals_router, prefix="/nutrilens/meals", tags=["nutrilens-meals"])

# Leave Tracker legacy routes (kept for current web frontend compatibility)
app.include_router(lt_auth.router, prefix="/auth", tags=["auth"])
app.include_router(lt_people.router, prefix="/api", tags=["people"])
app.include_router(lt_types.router, prefix="/api", tags=["types"])
app.include_router(lt_absences.router, prefix="/api", tags=["absences"])
app.include_router(
    lt_smart_identification.router,
    prefix="/api",
    tags=["smart-identification"],
)
app.include_router(lt_ai_instructions.router, prefix="/api", tags=["ai-instructions"])

# Leave Tracker namespaced routes (for explicit multi-system separation)
app.include_router(lt_auth.router, prefix="/leave-tracker/auth", tags=["leave-tracker-auth"])
app.include_router(lt_people.router, prefix="/leave-tracker/api", tags=["leave-tracker-people"])
app.include_router(lt_types.router, prefix="/leave-tracker/api", tags=["leave-tracker-types"])
app.include_router(lt_absences.router, prefix="/leave-tracker/api", tags=["leave-tracker-absences"])
app.include_router(
    lt_smart_identification.router,
    prefix="/leave-tracker/api",
    tags=["leave-tracker-smart-identification"],
)
app.include_router(
    lt_ai_instructions.router,
    prefix="/leave-tracker/api",
    tags=["leave-tracker-ai-instructions"],
)

# NutriLens namespaced auth alias (reuses Leave Tracker auth flow for a single-user system)
app.include_router(lt_auth.router, prefix="/nutrilens/auth", tags=["nutrilens-auth"])


@app.get("/health")
async def health_check():
    """Unified health check endpoint"""
    return {
        "status": "ok",
        "services": {
            "nutrilens": "enabled",
            "leave_tracker": "enabled",
        },
    }


@app.get("/nutrilens/health")
async def nutrilens_health():
    """NutriLens service health check"""
    return {
        "status": "ok",
        "service": "nutrilens",
        "version": "0.3.0",
    }


@app.get("/leave-tracker/health")
async def leave_tracker_health():
    """Leave Tracker service health check"""
    return {
        "status": "ok",
        "service": "leave_tracker",
        "version": "0.1.0",
    }


@app.get("/auth/health")
async def auth_health():
    """Legacy auth health check (Leave Tracker compatibility)"""
    return {
        "status": "ok",
        "service": "leave_tracker.auth",
    }


if __name__ == "__main__":

    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
