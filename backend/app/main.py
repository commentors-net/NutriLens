from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes_meals import router as meals_router

logger = logging.getLogger(__name__)

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
    title="FoodVision API",
    version="0.2.0",
    description="Multi-photo food logging + AI analysis",
    lifespan=lifespan,
)

# CORS middleware for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(meals_router, prefix="/meals", tags=["meals"])


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok"}


if __name__ == "__main__":

    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
