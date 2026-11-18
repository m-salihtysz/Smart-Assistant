import logging
from datetime import datetime, timedelta
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from .. import models, schemas
from ..config import get_settings
from ..db import utcnow
from ..deps import CurrentUser, DbSession
from ..email import send_email
from ..ratelimit import auth_rate_limit, limiter
from ..security import (
  create_access_token,
  hash_password,
  hash_refresh_token,
  new_email_code,
  new_refresh_token,
  burn_password_check,
  verify_email_code,
  verify_password,
)


logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


def _to_datetime(d):
  return datetime.combine(d, datetime.min.time())


# ---------- yardımcılar ----------

def _issue_tokens(db: Session, user: models.User) -> schemas.Token:
  settings = get_settings()
  raw, token_hash = new_refresh_token()
  db.add(
    models.RefreshToken(
      user_id=user.id,
      token_hash=token_hash,
      expires_at=utcnow() + timedelta(days=settings.refresh_token_expire_days),
    )
  )
  db.commit()
  return schemas.Token(access_token=create_access_token(subject=user.email), refresh_token=raw)


def _revoke_all_refresh_tokens(db: Session, user_id: int) -> None:
  db.query(models.RefreshToken).filter(
    models.RefreshToken.user_id == user_id, models.RefreshToken.revoked.is_(False)
  ).update({"revoked": True})


def _deliver(to: str, subject: str, body: str) -> None:
  """E-postayı arka planda gönderir; hata kullanıcıya sızdırılmaz (yalnızca loglanır)."""
  try:
    send_email(to, subject, body)
  except Exception as e:
    logger.error("E-posta gönderilemedi: %s", e)


def _send_code(db: Session, user: models.User, purpose: str, background: BackgroundTasks) -> None:
  """Eski kodları geçersiz kılıp yeni bir kod üretir; e-postayı arka planda gönderir.

  Gönderim yanıtı geciktirmez; böylece hesap var olsun olmasın yanıt süresi aynıdır.
  """
  settings = get_settings()
  db.query(models.EmailCode).filter(
    models.EmailCode.user_id == user.id, models.EmailCode.purpose == purpose
  ).delete()
  raw, code_hash = new_email_code()
  db.add(
    models.EmailCode(
      user_id=user.id,
      purpose=purpose,
      code_hash=code_hash,
      expires_at=utcnow() + timedelta(minutes=settings.email_code_ttl_minutes),
    )
  )
  db.commit()
  if purpose == "verify":
    subject, intro = "E-posta doğrulama kodun", "E-posta adresini doğrulamak için kodun:"
  else:
    subject, intro = "Şifre sıfırlama kodun", "Şifreni sıfırlamak için kodun:"
  body = (
    f"{intro}\n\n    {raw}\n\nKod {settings.email_code_ttl_minutes} dakika geçerlidir. "
    "Bu isteği sen yapmadıysan bu e-postayı yok sayabilirsin."
  )
  background.add_task(_deliver, user.email, subject, body)


def _consume_code(db: Session, user: models.User | None, purpose: str, code: str) -> bool:
  """Kodu doğrular; başarılıysa tek kullanımlık olarak siler. Deneme sayısı sınırlıdır."""
  settings = get_settings()
  if user is None:
    return False
  record = (
    db.query(models.EmailCode)
    .filter(models.EmailCode.user_id == user.id, models.EmailCode.purpose == purpose)
    .first()
  )
  if record is None or record.expires_at < utcnow():
    return False
  if record.attempts >= settings.email_code_max_attempts:
    return False
  if not verify_email_code(code, record.code_hash):
    record.attempts += 1
    db.commit()
    return False
  db.delete(record)
  db.commit()
  return True


def _user_by_email(db: Session, email: str) -> models.User | None:
  return db.query(models.User).filter(models.User.email == email.lower()).first()


# ---------- kayıt / giriş ----------

@router.post(
  "/register",
  response_model=schemas.UserRead,
  status_code=status.HTTP_201_CREATED,
  dependencies=[Depends(auth_rate_limit)],
)
def register(user_in: schemas.UserCreate, db: DbSession, background: BackgroundTasks):
  settings = get_settings()
  email = user_in.email.lower()
  if _user_by_email(db, email) is not None:
    raise HTTPException(
      status_code=status.HTTP_400_BAD_REQUEST,
      detail="Bu e-posta ile zaten kayıt var.",
    )

  db_user = models.User(
    email=email,
    hashed_password=hash_password(user_in.password),
    name=user_in.name,
    birth_date=_to_datetime(user_in.birth_date) if user_in.birth_date else None,
    email_verified=not settings.require_email_verification,
  )
  db.add(db_user)
  db.commit()
  db.refresh(db_user)
  if settings.require_email_verification:
    _send_code(db, db_user, "verify", background)
  return db_user


@router.post("/login", response_model=schemas.Token, dependencies=[Depends(auth_rate_limit)])
def login(
  form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
  db: DbSession,
):
  user = _user_by_email(db, form_data.username)
  if user is None:
    burn_password_check(form_data.password)  # hesap varlığı yanıt süresinden anlaşılmasın
  if user is None or not user.is_active or not verify_password(form_data.password, user.hashed_password):
    raise HTTPException(
      status_code=status.HTTP_401_UNAUTHORIZED,
      detail="E-posta veya şifre hatalı.",
    )
  if not user.email_verified:
    raise HTTPException(
      status_code=status.HTTP_403_FORBIDDEN,
      detail="email_not_verified",
    )
  return _issue_tokens(db, user)


@router.post("/refresh", response_model=schemas.Token, dependencies=[Depends(auth_rate_limit)])
def refresh(body: schemas.RefreshRequest, db: DbSession):
  """Refresh token'ı döndürerek yeni bir erişim + yenileme çifti verir."""
  invalid = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Oturum süresi doldu.")
  record = (
    db.query(models.RefreshToken)
    .filter(models.RefreshToken.token_hash == hash_refresh_token(body.refresh_token))
    .first()
  )
  if record is None:
    raise invalid
  if record.revoked:
    # Kullanılmış bir token tekrar geldi: çalınmış olabilir, tüm oturumları kapat.
    _revoke_all_refresh_tokens(db, record.user_id)
    db.commit()
    raise invalid
  user = db.get(models.User, record.user_id)
  if record.expires_at < utcnow() or user is None or not user.is_active:
    raise invalid
  record.revoked = True
  db.commit()
  return _issue_tokens(db, user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(body: schemas.RefreshRequest, db: DbSession):
  """Bu cihazın refresh token'ını geçersiz kılar (token yoksa/bilinmiyorsa sessizce geçer)."""
  db.query(models.RefreshToken).filter(
    models.RefreshToken.token_hash == hash_refresh_token(body.refresh_token)
  ).update({"revoked": True})
  db.commit()
  return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------- e-posta doğrulama ----------

@router.post("/verify-email", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(auth_rate_limit)])
def verify_email(body: schemas.CodeVerify, db: DbSession):
  user = _user_by_email(db, body.email)
  if not _consume_code(db, user, "verify", body.code):
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Kod geçersiz veya süresi dolmuş.")
  user.email_verified = True
  db.commit()
  return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/resend-verification", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(auth_rate_limit)])
def resend_verification(body: schemas.EmailOnly, db: DbSession, background: BackgroundTasks):
  """Hesap var olsun olmasın aynı yanıtı döner (hesap sızdırmaz)."""
  limiter.check(f"verify:{body.email.lower()}", 3, 3600)
  user = _user_by_email(db, body.email)
  if user is not None and not user.email_verified:
    _send_code(db, user, "verify", background)
  return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------- şifre sıfırlama ----------

@router.post("/forgot-password", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(auth_rate_limit)])
def forgot_password(body: schemas.EmailOnly, db: DbSession, background: BackgroundTasks):
  """Hesap var olsun olmasın aynı yanıtı döner (hesap sızdırmaz)."""
  limiter.check(f"reset:{body.email.lower()}", 3, 3600)
  user = _user_by_email(db, body.email)
  if user is not None and user.is_active:
    _send_code(db, user, "reset", background)
  return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/reset-password", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(auth_rate_limit)])
def reset_password(body: schemas.PasswordReset, db: DbSession):
  user = _user_by_email(db, body.email)
  if not _consume_code(db, user, "reset", body.code):
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Kod geçersiz veya süresi dolmuş.")
  user.hashed_password = hash_password(body.new_password)
  user.email_verified = True  # kod e-postaya gittiği için adres de doğrulanmış sayılır
  _revoke_all_refresh_tokens(db, user.id)
  db.commit()
  return Response(status_code=status.HTTP_204_NO_CONTENT)


# ---------- profil ----------

@router.get("/me", response_model=schemas.UserRead)
def read_me(current_user: CurrentUser):
  return current_user


@router.put("/me", response_model=schemas.UserRead)
def update_me(
  update: schemas.UserUpdate,
  current_user: CurrentUser,
  db: DbSession,
):
  if update.name is not None:
    current_user.name = update.name
  if update.birth_date is not None:
    current_user.birth_date = _to_datetime(update.birth_date)

  db.add(current_user)
  db.commit()
  db.refresh(current_user)
  return current_user


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(auth_rate_limit)])
def change_password(body: schemas.PasswordChange, current_user: CurrentUser, db: DbSession):
  if not verify_password(body.current_password, current_user.hashed_password):
    raise HTTPException(
      status_code=status.HTTP_400_BAD_REQUEST,
      detail="Mevcut şifre hatalı.",
    )
  current_user.hashed_password = hash_password(body.new_password)
  _revoke_all_refresh_tokens(db, current_user.id)  # diğer cihazlardaki oturumlar kapanır
  db.add(current_user)
  db.commit()
  return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(current_user: CurrentUser, db: DbSession):
  """Hesabı ve ona bağlı tüm kayıtları (sohbet, bildirim, token) kalıcı olarak siler."""
  db.delete(current_user)
  db.commit()
  return Response(status_code=status.HTTP_204_NO_CONTENT)
