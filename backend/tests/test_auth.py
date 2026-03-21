from fastapi.testclient import TestClient


def test_login_me_logout_flow(client: TestClient) -> None:
    # 验证管理员可以登录、读取当前会话，并在登出后失去会话状态。
    login_response = client.post(
        "/api/v1/auth/login",
        json={"username": "admin", "password": "admin123456"},
    )
    assert login_response.status_code == 200
    assert login_response.json()["user"]["username"] == "admin"

    me_response = client.get("/api/v1/auth/me")
    assert me_response.status_code == 200
    assert me_response.json()["username"] == "admin"

    logout_response = client.post("/api/v1/auth/logout")
    assert logout_response.status_code == 200
    assert logout_response.json() == {"message": "已退出登录"}

    after_logout_response = client.get("/api/v1/auth/me")
    assert after_logout_response.status_code == 401


def test_login_rejects_invalid_password(client: TestClient) -> None:
    # 错误密码必须被拒绝，避免在默认管理员场景下出现无保护登录。
    response = client.post(
        "/api/v1/auth/login",
        json={"username": "admin", "password": "wrong-password"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "用户名或密码错误"
