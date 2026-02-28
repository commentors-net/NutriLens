from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes_meals import router as meals_router
from app.db.session import init_db, SessionLocal
from app.db.seed import seed_foods
from app.db.models import Food

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialise DB tables and seed foods on startup."""
    init_db()
    db = SessionLocal()
    try:
        food_count = db.query(Food).count()
        if food_count == 0:
            n = seed_foods(db)
            logger.info(f"Seeded {n} food(s) into the nutrition DB.")
        else:
            logger.info(f"Nutrition DB already has {food_count} food(s) — skipping seed.")
    finally:
        db.close()
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
