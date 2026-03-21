import os
import tempfile
from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

TEST_DB_PATH = Path(tempfile.gettempdir()) / "quantitative_trading_test.db"
if TEST_DB_PATH.exists():
    TEST_DB_PATH.unlink()

os.environ["DATABASE_URL"] = f"sqlite:///{TEST_DB_PATH.resolve().as_posix()}"
os.environ["REDIS_URL"] = "redis://localhost:6379/15"
os.environ["SECRET_KEY"] = "test-secret-key"
os.environ["ADMIN_USERNAME"] = "admin"
os.environ["ADMIN_PASSWORD"] = "admin123456"
os.environ["SESSION_COOKIE_NAME"] = "test_session"
os.environ["SESSION_MAX_AGE"] = "3600"
os.environ["SESSION_COOKIE_SECURE"] = "false"


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
    from app.main import app

    with TestClient(app) as test_client:
        yield test_client


def pytest_sessionfinish(session, exitstatus) -> None:  # type: ignore[no-untyped-def]
    from app.db.session import engine

    engine.dispose()
    if TEST_DB_PATH.exists():
        TEST_DB_PATH.unlink()
