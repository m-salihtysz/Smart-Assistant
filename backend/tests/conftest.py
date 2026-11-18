import os
import tempfile

# Ayarlar app import edilmeden ÖNCE verilmeli (gerçek .env ve API anahtarları test dışı kalır).
_tmp = tempfile.mkdtemp()
os.environ["DATABASE_URL"] = os.environ.get("TEST_DATABASE_URL", f"sqlite:///{_tmp}/test.db")
os.environ["SECRET_KEY"] = "test-secret-key-test-secret-key-0123456789"
os.environ["GEMINI_API_KEY"] = ""
os.environ["OPENAI_API_KEY"] = ""
os.environ["ENVIRONMENT"] = "development"

import pytest
from fastapi.testclient import TestClient

from app.db import Base, engine
from app.main import app
from app.ratelimit import limiter


@pytest.fixture(autouse=True)
def _fresh_state():
  Base.metadata.drop_all(bind=engine)
  Base.metadata.create_all(bind=engine)
  limiter.reset()
  yield


@pytest.fixture
def client():
  return TestClient(app)


@pytest.fixture
def auth_headers(client):
  def _make(email="user@example.com", password="password123"):
    r = client.post("/auth/register", json={"email": email, "password": password})
    assert r.status_code == 201, r.text
    r = client.post("/auth/login", data={"username": email, "password": password})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}

  return _make
