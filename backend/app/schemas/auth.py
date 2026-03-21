from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class LoginRequest(BaseModel):
    # 登录接口当前只接受用户名和密码，后续如需二次验证可在这里扩展。
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=255)


class CurrentUserResponse(BaseModel):
    # 统一返回当前登录用户的最小信息，前端据此判断会话状态。
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    is_active: bool
    last_login_at: datetime | None = None


class LoginResponse(BaseModel):
    message: str
    user: CurrentUserResponse


class LogoutResponse(BaseModel):
    message: str
