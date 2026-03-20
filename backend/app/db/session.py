from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
from redis import Redis
from redis.exceptions import RedisError

from app.core.config import get_settings

settings = get_settings()
engine = create_engine(settings.database_url, pool_pre_ping=True)
redis_client = Redis.from_url(settings.redis_url, decode_responses=True)


def check_database() -> bool:
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return True
    except SQLAlchemyError:
        return False



def check_redis() -> bool:
    try:
        redis_client.ping()
        return True
    except RedisError:
        return False
