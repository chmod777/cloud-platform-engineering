from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_environment(monkeypatch):
    monkeypatch.setenv("APP_ENV", "test")
    assert client.get("/").json()["environment"] == "test"

def test_unknown_route():
    assert client.get("/missing").status_code == 404
