from collections.abc import Generator

from redis import Redis
from redis.exceptions import RedisError
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings

settings = get_settings()
connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
# 后端统一在这里初始化数据库和 Redis 客户端，便于后续服务层复用。
engine = create_engine(settings.database_url, pool_pre_ping=True, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False, class_=Session)
redis_client = Redis.from_url(settings.redis_url, decode_responses=True)



def get_db_session() -> Generator[Session, None, None]:
    # 统一提供数据库会话依赖，确保请求结束后可以自动释放连接。
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()



def check_database() -> bool:
    # 通过最小查询验证 PostgreSQL 或 SQLite 是否可连通。
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return True
    except SQLAlchemyError:
        return False



def check_redis() -> bool:
    # 通过 ping 验证 Redis 是否可用。
    try:
        redis_client.ping()
        return True
    except RedisError:
        return False
