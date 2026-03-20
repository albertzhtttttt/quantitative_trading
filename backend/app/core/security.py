from app.core.config import get_settings


def live_trading_enabled() -> bool:
    return get_settings().enable_live_trading
