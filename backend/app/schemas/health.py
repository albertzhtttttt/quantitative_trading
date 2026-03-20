from typing import Literal

from pydantic import BaseModel


class DependencyStatus(BaseModel):
    name: str
    ok: bool
    detail: str | None = None


class HealthResponse(BaseModel):
    status: Literal["ok"]


class ReadyResponse(BaseModel):
    status: Literal["ok", "degraded"]
    dependencies: list[DependencyStatus]
