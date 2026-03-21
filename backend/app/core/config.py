from functools import lru_cache
from typing import Annotated

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    # 统一收敛基础运行配置，避免环境变量分散在各个模块中硬编码。
    app_env: str = "development"
    secret_key: str = "change-me-before-production"
    admin_username: str = "admin"
    admin_password: str = "change-me-before-production"
    default_exchange: str = "binance"
    enable_live_trading: bool = False
    session_cookie_name: str = "qt_session"
    session_max_age: int = 86400
    session_cookie_secure: bool = False
    cors_allow_origins: Annotated[list[str], NoDecode] = Field(default_factory=list)
    database_url: str = "postgresql+psycopg://quant:quant_dev_password@postgres:5432/quantitative_trading"
    redis_url: str = "redis://redis:6379/0"

    @field_validator("cors_allow_origins", mode="before")
    @classmethod
    def parse_cors_allow_origins(cls, value: object) -> list[str]:
        # 开发环境允许通过逗号分隔环境变量配置少量前端 origin，便于本地跨域携带 Cookie 联调。
        if value is None or value == "":
            return []
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        if isinstance(value, list):
            return [str(item).strip() for item in value if str(item).strip()]
        raise TypeError("cors_allow_origins must be a comma-separated string or list")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    # 通过缓存复用 Settings 实例，减少重复解析环境变量的开销。
    return Settings()
