import logging
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from .. import models, schemas
from ..ai_client import generate_assistant_reply
from ..db import get_db
from ..deps import get_current_user


router = APIRouter(prefix="/assistant", tags=["assistant"])


DbSession = Annotated[Session, Depends(get_db)]
CurrentUser = Annotated[models.User, Depends(get_current_user)]


def _dummy_ai_reply(user_message: str, user_name: str | None) -> str:
  prefix = f"{user_name}, " if user_name else ""
  return (
    f"{prefix}şu an demo modundayım. "
    "Gerçek yapay zeka servisine bağlandığında, burada sana özel spor, finans ve rutin önerileri üreteceğim. "
    f"Şimdilik mesajını gördüm: \"{user_message}\"."
  )


@router.post("/chat", response_model=schemas.ChatResponse)
def chat(
  body: schemas.ChatRequest,
  db: DbSession,
  current_user: CurrentUser,
):
  user_msg = models.Message(
    user_id=current_user.id,
    role="user",
    content=body.message,
  )
  db.add(user_msg)
  db.commit()
  db.refresh(user_msg)

  try:
    reply_text, action = generate_assistant_reply(
      message=body.message,
      user_name=current_user.name,
      context=body.context,
    )
  except Exception as e:
    # Herhangi bir hata durumunda (ör. API key yok/geçersiz, ağ hatası) demo cevaba dön.
    logging.warning("AI cevabı alınamadı, demo moda düşüldü: %s", e)
    reply_text = _dummy_ai_reply(body.message, current_user.name)

  assistant_msg = models.Message(
    user_id=current_user.id,
    role="assistant",
    content=reply_text,
  )
  db.add(assistant_msg)
  db.commit()

  return schemas.ChatResponse(reply=reply_text, action=action)

