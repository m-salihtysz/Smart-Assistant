import re
from datetime import timedelta

import pytest

from app.db import SessionLocal, utcnow
from app.models import EmailCode, Message, RefreshToken
from app.routers import assistant, auth


@pytest.fixture
def outbox(monkeypatch):
  sent: list[dict] = []
  monkeypatch.setattr(auth, "send_email", lambda to, subject, body: sent.append({"to": to, "subject": subject, "body": body}))
  return sent


def _code(mail: dict) -> str:
  return re.search(r"\b(\d{6})\b", mail["body"]).group(1)


def _login(client, email="user@example.com", password="password123"):
  r = client.post("/auth/login", data={"username": email, "password": password})
  assert r.status_code == 200, r.text
  return r.json()


def _register(client, email="user@example.com", password="password123"):
  r = client.post("/auth/register", json={"email": email, "password": password})
  assert r.status_code == 201, r.text
  return r


# ---------- refresh token ----------

def test_login_returns_refresh_token_and_refresh_rotates(client):
  _register(client)
  first = _login(client)
  assert first["refresh_token"]

  r = client.post("/auth/refresh", json={"refresh_token": first["refresh_token"]})
  assert r.status_code == 200
  second = r.json()
  assert second["refresh_token"] != first["refresh_token"]
  assert client.get("/auth/me", headers={"Authorization": f"Bearer {second['access_token']}"}).status_code == 200


def test_reusing_a_rotated_refresh_token_revokes_every_session(client):
  _register(client)
  first = _login(client)
  second = client.post("/auth/refresh", json={"refresh_token": first["refresh_token"]}).json()

  # Eski token tekrar kullanılırsa: reddedilir ve yeni token da iptal edilir (çalıntı şüphesi)
  assert client.post("/auth/refresh", json={"refresh_token": first["refresh_token"]}).status_code == 401
  assert client.post("/auth/refresh", json={"refresh_token": second["refresh_token"]}).status_code == 401


def test_invalid_and_expired_refresh_tokens(client):
  _register(client)
  assert client.post("/auth/refresh", json={"refresh_token": "x" * 40}).status_code == 401
  tokens = _login(client)
  with SessionLocal() as db:
    db.query(RefreshToken).update({"expires_at": utcnow() - timedelta(seconds=1)})
    db.commit()
  assert client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]}).status_code == 401


def test_logout_revokes_only_that_device(client):
  _register(client)
  phone = _login(client)
  tablet = _login(client)
  assert client.post("/auth/logout", json={"refresh_token": phone["refresh_token"]}).status_code == 204
  # tablet etkilenmez
  assert client.post("/auth/refresh", json={"refresh_token": tablet["refresh_token"]}).status_code == 200


def test_logged_out_refresh_token_cannot_be_used(client):
  _register(client)
  phone = _login(client)
  client.post("/auth/logout", json={"refresh_token": phone["refresh_token"]})
  assert client.post("/auth/refresh", json={"refresh_token": phone["refresh_token"]}).status_code == 401


def test_logout_with_unknown_token_is_silent(client):
  assert client.post("/auth/logout", json={"refresh_token": "y" * 40}).status_code == 204


def test_change_password_revokes_refresh_tokens(client):
  _register(client)
  tokens = _login(client)
  headers = {"Authorization": f"Bearer {tokens['access_token']}"}
  r = client.post("/auth/change-password", headers=headers,
                  json={"current_password": "password123", "new_password": "another-pass1"})
  assert r.status_code == 204
  assert client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]}).status_code == 401


def test_delete_account_removes_tokens_and_codes(client, outbox):
  _register(client)
  tokens = _login(client)
  client.post("/auth/forgot-password", json={"email": "user@example.com"})
  headers = {"Authorization": f"Bearer {tokens['access_token']}"}
  assert client.delete("/auth/me", headers=headers).status_code == 204
  with SessionLocal() as db:
    assert db.query(RefreshToken).count() == 0
    assert db.query(EmailCode).count() == 0


# ---------- şifre sıfırlama ----------

def test_password_reset_flow(client, outbox):
  _register(client)
  tokens = _login(client)

  assert client.post("/auth/forgot-password", json={"email": "USER@example.com"}).status_code == 204
  assert len(outbox) == 1 and outbox[0]["to"] == "user@example.com"
  code = _code(outbox[0])

  bad = client.post("/auth/reset-password", json={"email": "user@example.com", "code": "000000" if code != "000000" else "111111", "new_password": "brand-new-pass"})
  assert bad.status_code == 400

  ok = client.post("/auth/reset-password", json={"email": "user@example.com", "code": code, "new_password": "brand-new-pass"})
  assert ok.status_code == 204

  # kod tek kullanımlık
  again = client.post("/auth/reset-password", json={"email": "user@example.com", "code": code, "new_password": "third-pass-1"})
  assert again.status_code == 400
  # eski şifre ve eski oturumlar geçersiz
  assert client.post("/auth/login", data={"username": "user@example.com", "password": "password123"}).status_code == 401
  assert client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]}).status_code == 401
  assert _login(client, password="brand-new-pass")["access_token"]


def test_forgot_password_does_not_reveal_whether_account_exists(client, outbox):
  assert client.post("/auth/forgot-password", json={"email": "nobody@example.com"}).status_code == 204
  assert outbox == []


def test_reset_code_attempts_are_limited(client, outbox):
  _register(client)
  client.post("/auth/forgot-password", json={"email": "user@example.com"})
  real = _code(outbox[0])
  wrong = "123456" if real != "123456" else "654321"
  for _ in range(5):
    assert client.post("/auth/reset-password", json={"email": "user@example.com", "code": wrong, "new_password": "brand-new-pass"}).status_code in (400, 429)
  # beş yanlış denemeden sonra doğru kod bile kabul edilmez
  r = client.post("/auth/reset-password", json={"email": "user@example.com", "code": real, "new_password": "brand-new-pass"})
  assert r.status_code in (400, 429)
  assert client.post("/auth/login", data={"username": "user@example.com", "password": "password123"}).status_code == 200


def test_reset_code_expires(client, outbox):
  _register(client)
  client.post("/auth/forgot-password", json={"email": "user@example.com"})
  code = _code(outbox[0])
  with SessionLocal() as db:
    db.query(EmailCode).update({"expires_at": utcnow() - timedelta(minutes=1)})
    db.commit()
  r = client.post("/auth/reset-password", json={"email": "user@example.com", "code": code, "new_password": "brand-new-pass"})
  assert r.status_code == 400


def test_forgot_password_is_rate_limited_per_email(client, outbox):
  _register(client)
  for _ in range(3):
    assert client.post("/auth/forgot-password", json={"email": "user@example.com"}).status_code == 204
  assert client.post("/auth/forgot-password", json={"email": "user@example.com"}).status_code == 429


# ---------- e-posta doğrulama ----------

@pytest.fixture
def verification_required(monkeypatch):
  strict = auth.get_settings().model_copy(update={"require_email_verification": True})
  monkeypatch.setattr(auth, "get_settings", lambda: strict)


def test_unverified_user_cannot_login_until_code_is_confirmed(client, outbox, verification_required):
  r = _register(client)
  assert r.json()["email_verified"] is False
  assert len(outbox) == 1
  code = _code(outbox[0])

  assert client.post("/auth/login", data={"username": "user@example.com", "password": "password123"}).status_code == 403

  wrong = "123456" if code != "123456" else "654321"
  assert client.post("/auth/verify-email", json={"email": "user@example.com", "code": wrong}).status_code == 400
  assert client.post("/auth/verify-email", json={"email": "user@example.com", "code": code}).status_code == 204

  tokens = _login(client)
  me = client.get("/auth/me", headers={"Authorization": f"Bearer {tokens['access_token']}"}).json()
  assert me["email_verified"] is True


def test_resend_verification_issues_new_code(client, outbox, verification_required):
  _register(client)
  assert client.post("/auth/resend-verification", json={"email": "user@example.com"}).status_code == 204
  assert len(outbox) == 2
  new_code = _code(outbox[1])
  assert client.post("/auth/verify-email", json={"email": "user@example.com", "code": new_code}).status_code == 204
  # bilinmeyen adres: aynı yanıt, e-posta yok
  assert client.post("/auth/resend-verification", json={"email": "ghost@example.com"}).status_code == 204
  assert len(outbox) == 2


def test_reset_password_also_verifies_address(client, outbox, verification_required):
  _register(client)
  client.post("/auth/forgot-password", json={"email": "user@example.com"})
  code = _code(outbox[-1])
  assert client.post("/auth/reset-password", json={"email": "user@example.com", "code": code, "new_password": "brand-new-pass"}).status_code == 204
  assert _login(client, password="brand-new-pass")["access_token"]


def test_verification_not_required_by_default(client):
  r = _register(client)
  assert r.json()["email_verified"] is True
  assert _login(client)["access_token"]


# ---------- sohbet saklama sınırı ----------

def test_chat_history_is_capped(client, auth_headers, monkeypatch):
  small = assistant.get_settings().model_copy(update={"max_stored_messages": 6})
  monkeypatch.setattr(assistant, "get_settings", lambda: small)
  headers = auth_headers()
  for i in range(8):
    assert client.post("/assistant/chat", headers=headers, json={"message": f"m{i}"}).status_code == 200
  with SessionLocal() as db:
    assert db.query(Message).count() == 6
  history = client.get("/assistant/history", headers=headers).json()
  assert history[-2]["content"] == "m7"
