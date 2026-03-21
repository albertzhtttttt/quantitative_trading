from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import create_session_token, decode_session_token
from app.db.session import get_db_session
from app.models.user import User
from app.schemas.auth import CurrentUserResponse, LoginRequest, LoginResponse, LogoutResponse
from app.services.auth import authenticate_user, get_user_by_id

router = APIRouter(prefix="/auth", tags=["auth"])



def _set_session_cookie(response: Response, user_id: int) -> None:
    # 登录成功后写入 HttpOnly Cookie，前端只需依赖浏览器自动携带会话即可。
    settings = get_settings()
    token = create_session_token(user_id)
    response.set_cookie(
        key=settings.session_cookie_name,
        value=token,
        max_age=settings.session_max_age,
        httponly=True,
        secure=settings.session_cookie_secure,
        samesite="lax",
        path="/",
    )



def _clear_session_cookie(response: Response) -> None:
    # 登出时主动删除 Cookie，确保浏览器端的旧会话立即失效。
    settings = get_settings()
    response.delete_cookie(
        key=settings.session_cookie_name,
        path="/",
        secure=settings.session_cookie_secure,
        httponly=True,
        samesite="lax",
    )



def get_current_user(request: Request, session: Session = Depends(get_db_session)) -> User:
    # 从 HttpOnly Cookie 中恢复当前用户；任一步失败都按未登录处理。
    settings = get_settings()
    token = request.cookies.get(settings.session_cookie_name)
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="未登录")

    user_id = decode_session_token(token)
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="登录状态已失效")

    user = get_user_by_id(session, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="登录状态已失效")
    return user


@router.post("/login", response_model=LoginResponse)
def login(
    payload: LoginRequest,
    response: Response,
    session: Session = Depends(get_db_session),
) -> LoginResponse:
    # 使用管理员用户名和密码完成最小登录闭环，并返回当前用户信息。
    user = authenticate_user(session, payload.username, payload.password)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="用户名或密码错误")

    _set_session_cookie(response, user.id)
    return LoginResponse(message="登录成功", user=CurrentUserResponse.model_validate(user))


@router.post("/logout", response_model=LogoutResponse)
def logout(response: Response) -> LogoutResponse:
    # 无论当前是否已登录，都允许客户端调用退出接口清理本地会话。
    _clear_session_cookie(response)
    return LogoutResponse(message="已退出登录")


@router.get("/me", response_model=CurrentUserResponse)
def me(current_user: User = Depends(get_current_user)) -> CurrentUserResponse:
    # 前端通过该接口判断当前浏览器是否仍持有有效会话。
    return CurrentUserResponse.model_validate(current_user)
