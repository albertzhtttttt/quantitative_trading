from typing import Literal

from pydantic import BaseModel


class DependencyStatus(BaseModel):
    # 描述单个外部依赖的可用状态，便于 ready 检查和前端展示。
    name: str
    ok: bool
    detail: str | None = None


class HealthResponse(BaseModel):
    status: Literal["ok"]


class ReadyResponse(BaseModel):
    status: Literal["ok", "degraded"]
    dependencies: list[DependencyStatus]
