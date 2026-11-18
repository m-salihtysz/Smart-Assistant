from datetime import datetime

from sqlalchemy import Integer, String, Text, DateTime, Boolean, ForeignKey, UniqueConstraint, false, true
from sqlalchemy.orm import relationship, Mapped, mapped_column

from .db import Base, utcnow


class User(Base):
  __tablename__ = "users"

  id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
  email: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
  hashed_password: Mapped[str] = mapped_column(String, nullable=False)
  name: Mapped[str | None] = mapped_column(String, nullable=True)
  birth_date: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
  is_active: Mapped[bool] = mapped_column(Boolean, default=True)
  email_verified: Mapped[bool] = mapped_column(Boolean, default=True, server_default=true())
  created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

  messages: Mapped[list["Message"]] = relationship(
    "Message", back_populates="user", cascade="all, delete-orphan"
  )
  reports: Mapped[list["Report"]] = relationship(
    "Report", back_populates="user", cascade="all, delete-orphan"
  )
  refresh_tokens: Mapped[list["RefreshToken"]] = relationship(
    "RefreshToken", back_populates="user", cascade="all, delete-orphan"
  )
  email_codes: Mapped[list["EmailCode"]] = relationship(
    "EmailCode", back_populates="user", cascade="all, delete-orphan"
  )
  sync_documents: Mapped[list["SyncDocument"]] = relationship(
    "SyncDocument", back_populates="user", cascade="all, delete-orphan"
  )


class Message(Base):
  __tablename__ = "messages"

  id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
  user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
  role: Mapped[str] = mapped_column(String, nullable=False)  # "user" | "assistant"
  content: Mapped[str] = mapped_column(String, nullable=False)
  created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

  user: Mapped[User] = relationship("User", back_populates="messages")


class Report(Base):
  """Kullanıcının uygunsuz/hatalı bulduğu asistan yanıtı bildirimi."""

  __tablename__ = "reports"

  id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
  user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
  content: Mapped[str] = mapped_column(String, nullable=False)
  reason: Mapped[str | None] = mapped_column(String, nullable=True)
  created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

  user: Mapped[User] = relationship("User", back_populates="reports")


class RefreshToken(Base):
  """Oturum yenileme token'ı (yalnızca özeti saklanır; kullanımda döndürülür)."""

  __tablename__ = "refresh_tokens"

  id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
  user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
  token_hash: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
  expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
  revoked: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
  created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

  user: Mapped[User] = relationship("User", back_populates="refresh_tokens")


class EmailCode(Base):
  """E-posta doğrulama / şifre sıfırlama için tek kullanımlık, kısa ömürlü kod."""

  __tablename__ = "email_codes"

  id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
  user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
  purpose: Mapped[str] = mapped_column(String, nullable=False)  # "verify" | "reset"
  code_hash: Mapped[str] = mapped_column(String, nullable=False)
  expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
  attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
  created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

  user: Mapped[User] = relationship("User", back_populates="email_codes")


class SyncDocument(Base):
  """Kullanıcının cihazdaki bir veri koleksiyonunun (ör. notlar) yedeği.

  İçerik sunucu için opaktır (JSON metni). `version` her yazmada artar ve
  cihazlar arası çakışmaları algılamak için kullanılır.
  """

  __tablename__ = "sync_documents"
  __table_args__ = (UniqueConstraint("user_id", "key", name="uq_sync_user_key"),)

  id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
  user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False, index=True)
  key: Mapped[str] = mapped_column(String, nullable=False)
  data: Mapped[str] = mapped_column(Text, nullable=False)
  version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
  updated_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, onupdate=utcnow)

  user: Mapped[User] = relationship("User", back_populates="sync_documents")
