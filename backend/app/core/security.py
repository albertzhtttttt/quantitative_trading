import base64
import hashlib
import hmac
import secrets
import time

from app.core.config import get_settings

PASSWORD_SCHEME = "pbkdf2_sha256"
PASSWORD_ITERATIONS = 390000


def live_trading_enabled() -> bool:
    # 统一读取实盘开关，确保默认状态下不会误开启真实交易路径。
    return get_settings().enable_live_trading



def hash_password(password: str) -> str:
    # 使用 PBKDF2 生成带盐哈希，避免在数据库中保存明文密码。
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        PASSWORD_ITERATIONS,
    )
    return f"{PASSWORD_SCHEME}${PASSWORD_ITERATIONS}${salt}${digest.hex()}"



def verify_password(password: str, password_hash: str) -> bool:
    # 按约定格式重新计算哈希并对比，兼容未来替换哈希算法的扩展空间。
    try:
        scheme, iterations_raw, salt, expected_digest = password_hash.split("$", 3)
        iterations = int(iterations_raw)
    except ValueError:
        return False

    if scheme != PASSWORD_SCHEME:
        return False

    actual_digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        iterations,
    ).hex()
    return hmac.compare_digest(actual_digest, expected_digest)



def create_session_token(user_id: int) -> str:
    # 生成带签名的短期会话令牌，通过 HttpOnly Cookie 在浏览器和后端之间传递。
    settings = get_settings()
    expires_at = int(time.time()) + settings.session_max_age
    payload = f"{user_id}:{expires_at}"
    signature = _sign_payload(payload)
    raw_token = f"{payload}:{signature}"
    return base64.urlsafe_b64encode(raw_token.encode("utf-8")).decode("utf-8")



def decode_session_token(token: str) -> int | None:
    # 校验签名和过期时间，只在令牌可信且未过期时返回 user_id。
    try:
        raw_token = base64.urlsafe_b64decode(token.encode("utf-8")).decode("utf-8")
        user_id_raw, expires_at_raw, provided_signature = raw_token.split(":", 2)
        payload = f"{user_id_raw}:{expires_at_raw}"
        expected_signature = _sign_payload(payload)
        expires_at = int(expires_at_raw)
        user_id = int(user_id_raw)
    except (ValueError, TypeError):
        return None

    if not hmac.compare_digest(expected_signature, provided_signature):
        return None
    if expires_at < int(time.time()):
        return None
    return user_id



def _sign_payload(payload: str) -> str:
    # 所有会话令牌都通过 SECRET_KEY 做 HMAC 签名，防止客户端篡改 user_id。
    secret_key = get_settings().secret_key.encode("utf-8")
    return hmac.new(secret_key, payload.encode("utf-8"), hashlib.sha256).hexdigest()
