from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    # 统一声明 SQLAlchemy Base，后续所有模型都从这里继承。
    pass


from app.models.user import User  # noqa: E402,F401

__all__ = ["Base", "User"]
