from datetime import timedelta

import pytest

from app.security import create_access_token


def test_register_login_me(client, auth_headers):
  headers = auth_headers("A@Example.com")
  me = client.get("/auth/me", headers=headers).json()
  assert me["email"] == "a@example.com"


def test_duplicate_email_rejected(client, auth_headers):
  auth_headers("dup@example.com")
  r = client.post("/auth/register", json={"email": "DUP@example.com", "password": "password123"})
  assert r.status_code == 400


def test_short_password_rejected(client):
  r = client.post("/auth/register", json={"email": "x@example.com", "password": "short"})
  assert r.status_code == 422


def test_wrong_password(client, auth_headers):
  auth_headers("w@example.com")
  r = client.post("/auth/login", data={"username": "w@example.com", "password": "nope-nope"})
  assert r.status_code == 401


def test_login_rate_limited(client):
  for _ in range(10):
    assert client.post("/auth/login", data={"username": "z@example.com", "password": "x"}).status_code == 401
  r = client.post("/auth/login", data={"username": "z@example.com", "password": "x"})
  assert r.status_code == 429
  assert "Retry-After" in r.headers


def test_invalid_and_expired_token(client):
  assert client.get("/auth/me", headers={"Authorization": "Bearer garbage"}).status_code == 401
  expired = create_access_token("a@example.com", timedelta(minutes=-1))
  assert client.get("/auth/me", headers={"Authorization": f"Bearer {expired}"}).status_code == 401


def test_update_profile(client, auth_headers):
  headers = auth_headers()
  r = client.put("/auth/me", headers=headers, json={"name": "Ali", "birth_date": "1999-05-01"})
  assert r.status_code == 200
  assert r.json()["name"] == "Ali" and r.json()["birth_date"] == "1999-05-01"


def test_change_password(client, auth_headers):
  headers = auth_headers("p@example.com", "password123")
  bad = client.post("/auth/change-password", headers=headers,
                    json={"current_password": "wrong-one", "new_password": "newpassword1"})
  assert bad.status_code == 400
  ok = client.post("/auth/change-password", headers=headers,
                   json={"current_password": "password123", "new_password": "newpassword1"})
  assert ok.status_code == 204
  assert client.post("/auth/login", data={"username": "p@example.com", "password": "password123"}).status_code == 401
  assert client.post("/auth/login", data={"username": "p@example.com", "password": "newpassword1"}).status_code == 200


def test_delete_account_removes_data(client, auth_headers):
  headers = auth_headers("d@example.com")
  client.post("/assistant/chat", headers=headers, json={"message": "selam"})
  assert client.delete("/auth/me", headers=headers).status_code == 204
  assert client.get("/auth/me", headers=headers).status_code == 401
  # Aynı e-posta ile tekrar kayıt olunabilmeli ve geçmiş boş olmalı
  headers = auth_headers("d@example.com")
  assert client.get("/assistant/history", headers=headers).json() == []


def test_production_requires_strong_secret(monkeypatch):
  from app import config

  monkeypatch.setenv("ENVIRONMENT", "production")
  monkeypatch.setenv("SECRET_KEY", "change-me-in-prod")
  config.get_settings.cache_clear()
  try:
    with pytest.raises(RuntimeError):
      config.get_settings()
  finally:
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("SECRET_KEY", "test-secret-key-test-secret-key-0123456789")
    config.get_settings.cache_clear()


def test_underage_and_future_birth_dates_rejected(client, auth_headers):
  from datetime import date

  headers = auth_headers()
  today = date.today()
  too_young = today.replace(year=today.year - 12).isoformat()
  future = today.replace(year=today.year + 1).isoformat()
  assert client.put("/auth/me", headers=headers, json={"birth_date": too_young}).status_code == 422
  assert client.put("/auth/me", headers=headers, json={"birth_date": future}).status_code == 422
  r = client.post("/auth/register", json={"email": "k@example.com", "password": "password123", "birth_date": too_young})
  assert r.status_code == 422


def test_exactly_13_years_old_is_accepted(client, auth_headers):
  from datetime import date

  headers = auth_headers()
  today = date.today()
  thirteen = today.replace(year=today.year - 13, day=min(today.day, 28)).isoformat()
  assert client.put("/auth/me", headers=headers, json={"birth_date": thirteen}).status_code == 200


def test_reading_legacy_underage_profile_does_not_break(client, auth_headers):
  """Eski kayıtlardaki geçersiz doğum tarihi yanıt üretimini bozmamalı (doğrulama yalnızca girdide)."""
  from datetime import datetime

  from app.db import SessionLocal
  from app.models import User

  headers = auth_headers("legacy@example.com")
  with SessionLocal() as db:
    user = db.query(User).filter(User.email == "legacy@example.com").one()
    user.birth_date = datetime(datetime.now().year - 5, 1, 1)
    db.commit()
  assert client.get("/auth/me", headers=headers).status_code == 200


def test_production_requires_smtp_email_backend(monkeypatch):
  from app import config

  monkeypatch.setenv("ENVIRONMENT", "production")
  monkeypatch.setenv("SECRET_KEY", "a-long-random-production-secret-key-0123456789")
  monkeypatch.setenv("EMAIL_BACKEND", "console")
  config.get_settings.cache_clear()
  try:
    with pytest.raises(RuntimeError, match="smtp"):
      config.get_settings()
    monkeypatch.setenv("EMAIL_BACKEND", "smtp")
    with pytest.raises(RuntimeError, match="SMTP_HOST"):
      config.get_settings()
    monkeypatch.setenv("SMTP_HOST", "smtp.example.com")
    assert config.get_settings().email_backend == "smtp"
  finally:
    for k in ("ENVIRONMENT", "EMAIL_BACKEND", "SMTP_HOST"):
      monkeypatch.delenv(k, raising=False)
    monkeypatch.setenv("ENVIRONMENT", "development")
    monkeypatch.setenv("SECRET_KEY", "test-secret-key-test-secret-key-0123456789")
    config.get_settings.cache_clear()


def test_unknown_account_login_still_does_password_work(client, monkeypatch):
  """Hesap yokken de parola doğrulama maliyeti ödenir (yanıt süresinden hesap varlığı anlaşılmasın)."""
  from app.routers import auth

  calls = []
  monkeypatch.setattr(auth, "burn_password_check", lambda pw: calls.append(pw))
  r = client.post("/auth/login", data={"username": "ghost@example.com", "password": "whatever1"})
  assert r.status_code == 401
  assert calls == ["whatever1"]
