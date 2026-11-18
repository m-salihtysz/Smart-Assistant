import json

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError

from .. import models, schemas
from ..config import get_settings
from ..deps import CurrentUser, DbSession
from ..ratelimit import limiter


router = APIRouter(prefix="/sync", tags=["sync"])

# İstemcinin yedeklediği koleksiyonlar. Başka anahtarlar reddedilir.
ALLOWED_KEYS = {
  "activities",
  "routines",
  "sport_plans",
  "finance_transactions",
  "finance_watchlist",
  "notes_v2",
}


def _validate_json(data: str) -> None:
  try:
    parsed = json.loads(data)
  except ValueError:
    raise HTTPException(
      status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Veri geçerli bir JSON değil."
    ) from None
  if not isinstance(parsed, (list, dict)):
    raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Veri liste ya da nesne olmalı.")


@router.get("", response_model=schemas.SyncSnapshot)
def get_snapshot(db: DbSession, current_user: CurrentUser):
  """Kullanıcının tüm yedek belgelerini döndürür."""
  rows = db.query(models.SyncDocument).filter(models.SyncDocument.user_id == current_user.id).all()
  return schemas.SyncSnapshot(documents={r.key: schemas.SyncDocumentRead.model_validate(r) for r in rows})


@router.put("/{key}", response_model=schemas.SyncWriteResult)
def put_document(key: str, body: schemas.SyncWrite, db: DbSession, current_user: CurrentUser):
  """Bir koleksiyonu yedekler. `base_version` sunucudakiyle uyuşmazsa (başka cihaz yazmış) 409 döner."""
  if key not in ALLOWED_KEYS:
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bilinmeyen veri anahtarı.")
  limiter.check(f"sync:{current_user.id}", 120, 60)
  settings = get_settings()
  if len(body.data.encode("utf-8")) > settings.max_sync_document_bytes:
    raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Veri çok büyük.")
  _validate_json(body.data)

  doc = (
    db.query(models.SyncDocument)
    .filter(models.SyncDocument.user_id == current_user.id, models.SyncDocument.key == key)
    .first()
  )
  if doc is None:
    doc = models.SyncDocument(user_id=current_user.id, key=key, data=body.data, version=1)
    db.add(doc)
  else:
    if not body.force and body.base_version is not None and body.base_version != doc.version:
      raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={"message": "Başka bir cihaz bu veriyi güncellemiş.", "server_version": doc.version},
      )
    doc.data = body.data
    doc.version += 1
  try:
    db.commit()
  except IntegrityError:
    # İki cihaz aynı anda ilk kez yazdı: biri kazandı, diğeri çakışma görür ve yeniden dener.
    db.rollback()
    raise HTTPException(
      status_code=status.HTTP_409_CONFLICT,
      detail={"message": "Başka bir cihaz bu veriyi güncellemiş.", "server_version": 1},
    ) from None
  db.refresh(doc)
  return schemas.SyncWriteResult(key=doc.key, version=doc.version, updated_at=doc.updated_at)


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def delete_all(db: DbSession, current_user: CurrentUser):
  """Sunucudaki tüm yedekleri siler (kullanıcı yedeklemeyi kapatınca)."""
  db.query(models.SyncDocument).filter(models.SyncDocument.user_id == current_user.id).delete()
  db.commit()
  return Response(status_code=status.HTTP_204_NO_CONTENT)
