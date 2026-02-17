from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_get_root_returns_plain_text() -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.text == "Hello, DevOps!"
    assert response.headers["content-type"].startswith("text/plain")


def test_post_echo_returns_same_payload() -> None:
    payload = {"message": "hello", "value": 42}
    response = client.post("/echo", json=payload)

    assert response.status_code == 200
    assert response.json() == payload
