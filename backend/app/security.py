from datetime import datetime, timedelta
from typing import Optional

from jose import jwt
from passlib.context import CryptContext

from .config import get_settings


# bcrypt bazı ortamlarda 72 byte sınırı ve ek sorunlar çıkarabiliyor.
# Bu backend için daha basit ve sorunsuz olan pbkdf2_sha256 kullanalım.
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
settings = get_settings()


def hash_password(password: str) -> str:
  return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
  return pwd_context.verify(plain_password, hashed_password)


def create_access_token(subject: str, expires_delta: Optional[timedelta] = None) -> str:
  if expires_delta is None:
    expires_delta = timedelta(minutes=settings.access_token_expire_minutes)
  to_encode = {
    "sub": subject,
    "exp": datetime.utcnow() + expires_delta,
  }
  encoded_jwt = jwt.encode(
    to_encode,
    settings.secret_key,
    algorithm="HS256",
  )
  return encoded_jwt

