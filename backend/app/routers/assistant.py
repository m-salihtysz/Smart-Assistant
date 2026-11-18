import logging

from fastapi import APIRouter, HTTPException, Response, status

from .. import models, schemas
from ..ai_client import generate_assistant_reply
from ..config import get_settings
from ..db import utcnow
from ..deps import CurrentUser, DbSession
from ..ratelimit import limiter


logger = logging.getLogger(__name__)

router = APIRouter(prefix="/assistant", tags=["assistant"])

CHAT_LIMIT_PER_MINUTE = 20


def _dummy_ai_reply(user_message: str, user_name: str | None) -> str:
  prefix = f"{user_name}, " if user_name else ""
  return (
    f"{prefix}şu an demo modundayım. "
    "Gerçek yapay zeka servisine bağlandığında, burada sana özel spor, finans ve rutin önerileri üreteceğim. "
    f"Şimdilik mesajını gördüm: \"{user_message}\"."
  )


def _check_daily_quota(db, user_id: int, limit: int) -> None:
  """Kullanıcının bugün (UTC) gönderdiği mesaj sayısı günlük sınırı aşıyorsa 429 verir."""
  start = utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
  sent = (
    db.query(models.Message)
    .filter(
      models.Message.user_id == user_id,
      models.Message.role == "user",
      models.Message.created_at >= start,
    )
    .count()
  )
  if sent >= limit:
    raise HTTPException(
      status_code=status.HTTP_429_TOO_MANY_REQUESTS,
      detail="Günlük asistan mesaj sınırına ulaştın. Yarın tekrar deneyebilirsin.",
    )


def _prune_old_messages(db, user_id: int, keep: int) -> None:
  """Kullanıcı başına en yeni `keep` mesajı bırakır; veritabanı sınırsız büyümez."""
  cutoff = (
    db.query(models.Message.id)
    .filter(models.Message.user_id == user_id)
    .order_by(models.Message.id.desc())
    .offset(keep)
    .limit(1)
    .scalar()
  )
  if cutoff is not None:
    db.query(models.Message).filter(
      models.Message.user_id == user_id, models.Message.id <= cutoff
    ).delete()
    db.commit()


@router.post("/chat", response_model=schemas.ChatResponse)
def chat(body: schemas.ChatRequest, db: DbSession, current_user: CurrentUser):
  limiter.check(f"chat:{current_user.id}", CHAT_LIMIT_PER_MINUTE, 60)
  settings = get_settings()
  _check_daily_quota(db, current_user.id, settings.daily_chat_limit)

  # Geçmişi yeni mesajı eklemeden önce al; böylece mesaj iki kez gönderilmez.
  recent = (
    db.query(models.Message)
    .filter(models.Message.user_id == current_user.id)
    .order_by(models.Message.id.desc())
    .limit(settings.history_messages)
    .all()
  )
  history = [(m.role, m.content) for m in reversed(recent)]

  user_msg = models.Message(user_id=current_user.id, role="user", content=body.message)
  db.add(user_msg)
  db.commit()

  action = None
  try:
    reply_text, action = generate_assistant_reply(
      message=body.message,
      user_name=current_user.name,
      context=body.context,
      history=history,
    )
  except Exception as e:
    if settings.is_production:
      # Üretimde sahte "demo" cevabı verme; istemci dürüst bir hata göstersin.
      logger.error("AI cevabı alınamadı: %s", e)
      # Cevapsız kalan mesaj, sonraki isteklerin sohbet geçmişini bozmasın.
      db.delete(user_msg)
      db.commit()
      raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Asistan şu anda kullanılamıyor. Lütfen biraz sonra tekrar dene.",
      ) from None
    # Geliştirmede (API key yok/geçersiz, ağ hatası vb.) demo cevaba dön.
    logger.warning("AI cevabı alınamadı, demo moda düşüldü: %s", e)
    reply_text = _dummy_ai_reply(body.message, current_user.name)

  db.add(models.Message(user_id=current_user.id, role="assistant", content=reply_text))
  db.commit()
  _prune_old_messages(db, current_user.id, settings.max_stored_messages)

  return schemas.ChatResponse(reply=reply_text, action=action)


@router.post("/report", status_code=status.HTTP_204_NO_CONTENT)
def report_reply(body: schemas.ReportCreate, db: DbSession, current_user: CurrentUser):
  """Uygunsuz ya da hatalı bir asistan yanıtını bildir (App Store AI içerik gereği)."""
  limiter.check(f"report:{current_user.id}", 10, 3600)
  db.add(models.Report(user_id=current_user.id, content=body.content, reason=body.reason))
  db.commit()
  logger.warning("Asistan yanıtı bildirildi (kullanıcı %s): %s", current_user.id, (body.reason or "-")[:100])
  return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/history", response_model=list[schemas.MessageRead])
def history(db: DbSession, current_user: CurrentUser, limit: int = 100):
  limit = max(1, min(limit, 500))
  rows = (
    db.query(models.Message)
    .filter(models.Message.user_id == current_user.id)
    .order_by(models.Message.id.desc())
    .limit(limit)
    .all()
  )
  return list(reversed(rows))


@router.delete("/history", status_code=status.HTTP_204_NO_CONTENT)
def clear_history(db: DbSession, current_user: CurrentUser):
  db.query(models.Message).filter(models.Message.user_id == current_user.id).delete()
  db.commit()
  return Response(status_code=status.HTTP_204_NO_CONTENT)
