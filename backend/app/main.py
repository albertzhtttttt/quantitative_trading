from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.logging import setup_logging

setup_logging()
settings = get_settings()

app = FastAPI(
    title="Quantitative Trading API",
    version="0.1.0",
    summary="Backend services for the quantitative trading MVP",
)
app.include_router(api_router)


@app.get("/", include_in_schema=False)
def root() -> dict[str, str]:
    return {
        "message": "Quantitative Trading API",
        "environment": settings.app_env,
    }
