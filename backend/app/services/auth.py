from datetime import datetime, timezone
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import hash_password, verify_password
from app.db.base import Base
from app.db.session import SessionLocal, engine
from app.models.user import User


def ensure_auth_schema_and_admin() -> None:
    # 在 T06 阶段先通过 create_all 建立最小 users 表和管理员账号，避免阻塞首条登录闭环。
    Base.metadata.create_all(bind=engine, tables=[User.__table__])
    settings = get_settings()

    with SessionLocal() as session:
        admin_user = session.scalar(select(User).where(User.username == settings.admin_username))
        if admin_user is None:
            admin_user = User(
                username=settings.admin_username,
                password_hash=hash_password(settings.admin_password),
                is_active=True,
            )
            session.add(admin_user)
            session.commit()
            return

        changed = False
        if not admin_user.is_active:
            admin_user.is_active = True
            changed = True
        if not verify_password(settings.admin_password, admin_user.password_hash):
            admin_user.password_hash = hash_password(settings.admin_password)
            changed = True

        if changed:
            session.add(admin_user)
            session.commit()


def authenticate_user(session: Session, username: str, password: str) -> User | None:
    # 登录时只允许已激活用户通过用户名和密码进行认证。
    user = session.scalar(select(User).where(User.username == username))
    if user is None or not user.is_active:
        return None
    if not verify_password(password, user.password_hash):
        return None

    user.last_login_at = datetime.now(timezone.utc)
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def get_user_by_id(session: Session, user_id: int) -> User | None:
    # 基于会话中的 user_id 恢复当前用户；若账号失效则视为未登录。
    user = session.get(User, user_id)
    if user is None or not user.is_active:
        return None
    return user
