from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import relationship, Mapped, mapped_column

from .db import Base


class User(Base):
  __tablename__ = "users"

  id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
  email: Mapped[str] = mapped_column(String, unique=True, index=True, nullable=False)
  hashed_password: Mapped[str] = mapped_column(String, nullable=False)
  name: Mapped[str | None] = mapped_column(String, nullable=True)
  birth_date: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
  is_active: Mapped[bool] = mapped_column(Boolean, default=True)
  created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

  messages: Mapped[list["Message"]] = relationship("Message", back_populates="user")


class Message(Base):
  __tablename__ = "messages"

  id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
  user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
  role: Mapped[str] = mapped_column(String, nullable=False)  # "user" | "assistant"
  content: Mapped[str] = mapped_column(String, nullable=False)
  created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

  user: Mapped[User] = relationship("User", back_populates="messages")

