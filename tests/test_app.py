
import pytest

from app.app import create_app


@pytest.fixture()
def client(monkeypatch):
    monkeypatch.delenv("APP_MODE", raising=False)

    app = create_app()
    app.config["TESTING"] = True

    with app.test_client() as test_client:
        yield test_client


def test_home_returns_application_details(client):
    response = client.get("/")

    assert response.status_code == 200
    assert response.is_json

    data = response.get_json()

    assert data["message"] == "Damolak DevOps Challenge API"
    assert data["status"] == "running"
    assert data["mode"] == "development"


def test_health_returns_healthy_status(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json() == {"status": "healthy"}
