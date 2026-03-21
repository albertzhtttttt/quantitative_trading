from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.logging import setup_logging
from app.services.auth import ensure_auth_schema_and_admin

setup_logging()
settings = get_settings()


@asynccontextmanager
async def lifespan(_: FastAPI):
    # 应用启动时先确保最小认证表和管理员账号存在，避免首条登录链路缺少数据基线。
    ensure_auth_schema_and_admin()
    yield


# 当前阶段先提供最小 API 应用入口，后续在此基础上扩展认证、策略、回测与模拟盘模块。
app = FastAPI(
    title="量化交易 API",
    version="0.1.0",
    summary="量化交易 MVP 后端服务",
    lifespan=lifespan,
)

if settings.cors_allow_origins:
    # 仅在明确配置开发 origin 时开启最小 CORS，并允许浏览器在跨域请求中携带会话 Cookie。
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allow_origins,
        allow_credentials=True,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["*"],
    )

app.include_router(api_router)


@app.get("/", include_in_schema=False)
def root() -> dict[str, str]:
    # 返回最小首页信息，方便本地联调和容器健康检查时确认服务已启动。
    return {
        "message": "量化交易 API",
        "environment": settings.app_env,
    }
