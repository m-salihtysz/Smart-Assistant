from datetime import datetime, timezone

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from .config import get_settings


settings = get_settings()

engine = create_engine(
  settings.database_url,
  connect_args={"check_same_thread": False} if settings.database_url.startswith("sqlite") else {},
)


class Base(DeclarativeBase):
  pass


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def utcnow() -> datetime:
  """Saat dilimsiz UTC zaman (SQLite DateTime ile uyumlu)."""
  return datetime.now(timezone.utc).replace(tzinfo=None)


def get_db():
  db = SessionLocal()
  try:
    yield db
  finally:
    db.close()
