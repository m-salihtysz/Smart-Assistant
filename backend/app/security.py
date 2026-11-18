import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import jwt
from passlib.context import CryptContext

from .config import get_settings


# pbkdf2_sha256: bcrypt'in 72 byte sınırı ve platform bağımlılığı sorunları olmadan çalışır.
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
settings = get_settings()

ALGORITHM = "HS256"


def hash_password(password: str) -> str:
  return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
  return pwd_context.verify(plain_password, hashed_password)


# Hesap yokken de aynı maliyette bir doğrulama yapılsın (yanıt süresinden hesap varlığı anlaşılmasın).
_DUMMY_HASH = pwd_context.hash("dummy-password-for-timing")


def burn_password_check(plain_password: str) -> None:
  pwd_context.verify(plain_password, _DUMMY_HASH)


def create_access_token(subject: str, expires_delta: Optional[timedelta] = None) -> str:
  if expires_delta is None:
    expires_delta = timedelta(minutes=settings.access_token_expire_minutes)
  to_encode = {
    "sub": subject,
    "exp": datetime.now(timezone.utc) + expires_delta,
  }
  return jwt.encode(to_encode, settings.secret_key, algorithm=ALGORITHM)


def _digest(value: str) -> str:
  return hmac.new(settings.secret_key.encode(), value.encode(), hashlib.sha256).hexdigest()


def new_refresh_token() -> tuple[str, str]:
  """(düz token, saklanacak özet) döndürür."""
  raw = secrets.token_urlsafe(48)
  return raw, _digest(raw)


def hash_refresh_token(raw: str) -> str:
  return _digest(raw)


def new_email_code() -> tuple[str, str]:
  """6 haneli kod ve özeti."""
  raw = f"{secrets.randbelow(1_000_000):06d}"
  return raw, _digest(f"code:{raw}")


def verify_email_code(raw: str, code_hash: str) -> bool:
  return hmac.compare_digest(_digest(f"code:{raw}"), code_hash)
