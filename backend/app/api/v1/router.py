from fastapi import APIRouter

from app.api.v1 import auth, health

# 统一挂载 v1 路由，后续新增模块时都从这里汇总注册。
api_router = APIRouter(prefix="/api/v1")
api_router.include_router(health.router)
api_router.include_router(auth.router)
