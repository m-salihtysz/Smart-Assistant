import json

from app.db import SessionLocal
from app.models import SyncDocument


def _put(client, headers, key, data, **extra):
  return client.put(f"/sync/{key}", headers=headers, json={"data": json.dumps(data), **extra})


def test_requires_auth(client):
  assert client.get("/sync").status_code == 401
  assert client.put("/sync/notes_v2", json={"data": "[]"}).status_code == 401
  assert client.delete("/sync").status_code == 401


def test_first_write_then_read_back(client, auth_headers):
  headers = auth_headers()
  assert client.get("/sync", headers=headers).json() == {"documents": {}}

  r = _put(client, headers, "notes_v2", [{"title": "a", "body": "b"}])
  assert r.status_code == 200 and r.json()["version"] == 1

  snap = client.get("/sync", headers=headers).json()["documents"]
  assert list(snap) == ["notes_v2"]
  assert json.loads(snap["notes_v2"]["data"]) == [{"title": "a", "body": "b"}]
  assert snap["notes_v2"]["version"] == 1


def test_version_increments_and_base_version_is_checked(client, auth_headers):
  headers = auth_headers()
  assert _put(client, headers, "activities", []).json()["version"] == 1
  assert _put(client, headers, "activities", [{"x": 1}], base_version=1).json()["version"] == 2


def test_stale_base_version_returns_conflict_and_force_overrides(client, auth_headers):
  headers = auth_headers()
  _put(client, headers, "activities", [])  # v1
  _put(client, headers, "activities", [{"from": "phone"}], base_version=1)  # v2

  stale = _put(client, headers, "activities", [{"from": "tablet"}], base_version=1)
  assert stale.status_code == 409
  assert stale.json()["detail"]["server_version"] == 2
  # sunucu verisi bozulmadı
  data = client.get("/sync", headers=headers).json()["documents"]["activities"]
  assert json.loads(data["data"]) == [{"from": "phone"}]

  forced = _put(client, headers, "activities", [{"from": "tablet"}], base_version=1, force=True)
  assert forced.status_code == 200 and forced.json()["version"] == 3


def test_unknown_key_and_bad_payloads_rejected(client, auth_headers):
  headers = auth_headers()
  assert _put(client, headers, "passwords", []).status_code == 404
  assert client.put("/sync/notes_v2", headers=headers, json={"data": "{bozuk"}).status_code == 422
  assert client.put("/sync/notes_v2", headers=headers, json={"data": '"sadece metin"'}).status_code == 422
  assert client.put("/sync/notes_v2", headers=headers, json={"data": ""}).status_code == 422


def test_document_size_limit(client, auth_headers, monkeypatch):
  from app.routers import sync

  small = sync.get_settings().model_copy(update={"max_sync_document_bytes": 200})
  monkeypatch.setattr(sync, "get_settings", lambda: small)
  headers = auth_headers()
  assert _put(client, headers, "notes_v2", [{"body": "x" * 500}]).status_code == 413
  assert _put(client, headers, "notes_v2", [{"body": "ok"}]).status_code == 200


def test_data_is_isolated_per_user(client, auth_headers):
  a = auth_headers("a@example.com")
  b = auth_headers("b@example.com")
  _put(client, a, "notes_v2", [{"title": "gizli"}])
  assert client.get("/sync", headers=b).json() == {"documents": {}}
  # aynı anahtar başka kullanıcıda ayrı belge
  assert _put(client, b, "notes_v2", [{"title": "b"}]).json()["version"] == 1


def test_delete_all_and_account_deletion_remove_backups(client, auth_headers):
  headers = auth_headers("d@example.com")
  _put(client, headers, "notes_v2", [])
  _put(client, headers, "routines", {})
  assert client.delete("/sync", headers=headers).status_code == 204
  assert client.get("/sync", headers=headers).json() == {"documents": {}}

  _put(client, headers, "notes_v2", [])
  assert client.delete("/auth/me", headers=headers).status_code == 204
  with SessionLocal() as db:
    assert db.query(SyncDocument).count() == 0


def test_concurrent_first_write_conflict_is_reported_not_500(client, auth_headers, monkeypatch):
  """İki cihaz aynı anda ilk kez yazarsa kaybeden 500 değil 409 almalı (istemci yeniden dener)."""
  from sqlalchemy.exc import IntegrityError
  from sqlalchemy.orm import Session

  headers = auth_headers()
  real_commit = Session.commit
  state = {"raised": False}

  def flaky_commit(self):
    if not state["raised"] and any(isinstance(o, SyncDocument) for o in self.new):
      state["raised"] = True
      raise IntegrityError("insert", {}, Exception("unique violation"))
    return real_commit(self)

  monkeypatch.setattr(Session, "commit", flaky_commit)
  r = _put(client, headers, "notes_v2", [{"title": "a"}])
  assert r.status_code == 409
  # Yeniden deneme başarılı olur
  assert _put(client, headers, "notes_v2", [{"title": "a"}]).status_code == 200
