from fastapi import APIRouter, Response, status

from app.db.session import check_database, check_redis
from app.schemas.health import DependencyStatus, HealthResponse, ReadyResponse

router = APIRouter(prefix="/health", tags=["health"])


@router.get("/live", response_model=HealthResponse)
def live() -> HealthResponse:
    return HealthResponse(status="ok")


@router.get("/ready", response_model=ReadyResponse)
def ready(response: Response) -> ReadyResponse:
    dependencies = [
        DependencyStatus(name="postgres", ok=check_database()),
        DependencyStatus(name="redis", ok=check_redis()),
    ]
    overall_ok = all(item.ok for item in dependencies)
    if not overall_ok:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return ReadyResponse(
        status="ok" if overall_ok else "degraded",
        dependencies=dependencies,
    )
