from fastapi import APIRouter

# 当前只保留认证路由占位，下一阶段在这里补齐登录、登出和 /auth/me。
router = APIRouter(prefix="/auth", tags=["auth"])
