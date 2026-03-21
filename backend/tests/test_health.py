from fastapi.testclient import TestClient


def test_live_health(client: TestClient) -> None:
    # 验证 live 健康检查在不依赖外部组件的情况下可以正常返回。
    response = client.get("/api/v1/health/live")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
