import json
from datetime import datetime, date
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from .config import get_settings


_settings = get_settings()

MINIMUM_AGE = 13


def _check_birth_date(v: date | None) -> date | None:
  """Doğum tarihi gelecekte olamaz ve kullanıcı en az 13 yaşında olmalıdır."""
  if v is None:
    return v
  today = date.today()
  if v > today:
    raise ValueError("Doğum tarihi gelecekte olamaz")
  age = today.year - v.year - ((today.month, today.day) < (v.month, v.day))
  if age < MINIMUM_AGE:
    raise ValueError(f"Uygulamayı kullanmak için en az {MINIMUM_AGE} yaşında olmalısın")
  return v


class UserBase(BaseModel):
  email: EmailStr
  name: Optional[str] = Field(default=None, max_length=100)
  birth_date: Optional[date] = None


class UserCreate(UserBase):
  password: str = Field(min_length=8, max_length=128)

  @field_validator("birth_date")
  @classmethod
  def _birth_date(cls, v: date | None) -> date | None:
    return _check_birth_date(v)


class UserRead(UserBase):
  model_config = ConfigDict(from_attributes=True)

  id: int
  created_at: datetime
  email_verified: bool = True


class UserUpdate(BaseModel):
  name: Optional[str] = Field(default=None, max_length=100)
  birth_date: Optional[date] = None

  @field_validator("birth_date")
  @classmethod
  def _birth_date(cls, v: date | None) -> date | None:
    return _check_birth_date(v)


class PasswordChange(BaseModel):
  current_password: str
  new_password: str = Field(min_length=8, max_length=128)


class Token(BaseModel):
  access_token: str
  token_type: str = "bearer"
  refresh_token: Optional[str] = None


class ChatRequest(BaseModel):
  message: str = Field(min_length=1)
  context: dict[str, Any] | None = None

  @field_validator("message")
  @classmethod
  def _message_limits(cls, v: str) -> str:
    v = v.strip()
    if not v:
      raise ValueError("Mesaj boş olamaz")
    if len(v) > _settings.max_message_length:
      raise ValueError(f"Mesaj en fazla {_settings.max_message_length} karakter olabilir")
    return v

  @field_validator("context")
  @classmethod
  def _context_limits(cls, v: dict[str, Any] | None) -> dict[str, Any] | None:
    if v is not None and len(json.dumps(v, ensure_ascii=False).encode("utf-8")) > _settings.max_context_bytes:
      raise ValueError("Bağlam verisi çok büyük")
    return v


class ChatResponse(BaseModel):
  reply: str
  action: dict[str, Any] | None = None


class MessageRead(BaseModel):
  model_config = ConfigDict(from_attributes=True)

  id: int
  role: str
  content: str
  created_at: datetime


class ReportCreate(BaseModel):
  content: str = Field(min_length=1, max_length=8000)
  reason: Optional[str] = Field(default=None, max_length=500)


class RefreshRequest(BaseModel):
  refresh_token: str = Field(min_length=10, max_length=512)


class EmailOnly(BaseModel):
  email: EmailStr


class CodeVerify(BaseModel):
  email: EmailStr
  code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


class PasswordReset(CodeVerify):
  new_password: str = Field(min_length=8, max_length=128)


class SyncDocumentRead(BaseModel):
  model_config = ConfigDict(from_attributes=True)

  key: str
  version: int
  data: str
  updated_at: datetime


class SyncSnapshot(BaseModel):
  documents: dict[str, SyncDocumentRead]


class SyncWrite(BaseModel):
  data: str = Field(min_length=1)
  # İstemcinin son bildiği sürüm. Verilirse ve sunucudaki sürümle uyuşmazsa 409 döner.
  # `None` ilk kez yazmak (ya da zorla üzerine yazmak) anlamına gelir.
  base_version: Optional[int] = Field(default=None, ge=0)
  force: bool = False


class SyncWriteResult(BaseModel):
  key: str
  version: int
  updated_at: datetime
