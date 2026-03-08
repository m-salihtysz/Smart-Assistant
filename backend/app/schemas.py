from datetime import datetime, date
from typing import Any, Optional

from pydantic import BaseModel, EmailStr


class UserBase(BaseModel):
  email: EmailStr
  name: Optional[str] = None
  birth_date: Optional[date] = None


class UserCreate(UserBase):
  password: str


class UserRead(UserBase):
  id: int
  created_at: datetime

  class Config:
    from_attributes = True


class UserUpdate(BaseModel):
  name: Optional[str] = None
  birth_date: Optional[date] = None


class Token(BaseModel):
  access_token: str
  token_type: str = "bearer"


class TokenData(BaseModel):
  email: Optional[str] = None


class ChatRequest(BaseModel):
  message: str
  context: dict[str, Any] | None = None


class ChatResponse(BaseModel):
  reply: str
  action: dict[str, Any] | None = None


class MessageRead(BaseModel):
  id: int
  role: str
  content: str
  created_at: datetime

  class Config:
    from_attributes = True

