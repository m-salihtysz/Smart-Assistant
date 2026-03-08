from functools import lru_cache

from pydantic import AnyUrl
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
  secret_key: str = "change-me-in-prod"
  access_token_expire_minutes: int = 60
  database_url: AnyUrl | str = "sqlite:///./app.db"

  # Gerçek AI servislerine bağlanmak için
  openai_api_key: str | None = None
  gemini_api_key: str | None = None

  class Config:
    env_file = ".env"
    env_file_encoding = "utf-8"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
  return Settings()

