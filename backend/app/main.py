from fastapi import FastAPI

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.logging import setup_logging

setup_logging()
settings = get_settings()

# 当前阶段先提供最小 API 应用入口，后续在此基础上扩展认证、策略、回测与模拟盘模块。
app = FastAPI(
    title="量化交易 API",
    version="0.1.0",
    summary="量化交易 MVP 后端服务",
)
app.include_router(api_router)


@app.get("/", include_in_schema=False)
def root() -> dict[str, str]:
    # 返回最小首页信息，方便本地联调和容器健康检查时确认服务已启动。
    return {
        "message": "量化交易 API",
        "environment": settings.app_env,
    }
