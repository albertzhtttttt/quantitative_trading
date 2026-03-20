from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # 统一收敛基础运行配置，避免环境变量分散在各个模块中硬编码。
    app_env: str = "development"
    secret_key: str = "change-me-before-production"
    admin_username: str = "admin"
    admin_password: str = "change-me-before-production"
    default_exchange: str = "binance"
    enable_live_trading: bool = False
    database_url: str = "postgresql+psycopg://quant:quant_dev_password@postgres:5432/quantitative_trading"
    redis_url: str = "redis://redis:6379/0"

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
