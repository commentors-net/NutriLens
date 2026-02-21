from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes_meals import router as meals_router

app = FastAPI(
    title="FoodVision API",
    version="0.1.0",
    description="Multi-photo food logging + AI analysis",
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
