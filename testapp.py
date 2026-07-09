import pytest
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.json["status"] == "success"
    assert response.json["data"]["message"] == "Hello from Flask in Docker!"


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json["status"] == "ok"


def test_version(client):
    response = client.get("/version")
    assert response.status_code == 200
    assert response.json["version"] == "1.0.0"


def test_ping(client):
    response = client.get("/ping")
    assert response.status_code == 200
    assert response.json["message"] == "pong"
