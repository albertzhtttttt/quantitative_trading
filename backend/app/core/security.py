from app.core.config import get_settings


def live_trading_enabled() -> bool:
    # 统一读取实盘开关，确保默认状态下不会误开启真实交易路径。
    return get_settings().enable_live_trading
