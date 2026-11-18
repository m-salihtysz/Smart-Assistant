import logging
import secrets
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


logger = logging.getLogger(__name__)

_INSECURE_SECRETS = {"", "change-me-in-prod", "generate-a-secure-secret-key-here", "degistir_bu_anahtari"}


class Settings(BaseSettings):
  model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

  environment: str = "development"  # "production" olunca güvenlik kontrolleri zorunlu olur
  secret_key: str = ""
  access_token_expire_minutes: int = 60
  refresh_token_expire_days: int = 30
  database_url: str = "sqlite:///./app.db"

  # Virgülle ayrılmış izinli origin listesi. Mobil uygulama CORS'a ihtiyaç duymaz.
  cors_origins: str = ""

  # Gerçek AI servislerine bağlanmak için
  openai_api_key: str | None = None
  gemini_api_key: str | None = None
  openai_model: str = "gpt-4o-mini"
  gemini_model: str = "gemini-2.5-flash"

  # E-posta: "console" (geliştirme; kodu loga yazar) veya "smtp"
  email_backend: str = "console"
  email_from: str = "Smart Assistant <no-reply@localhost>"
  smtp_host: str = ""
  smtp_port: int = 587
  smtp_user: str = ""
  smtp_password: str = ""
  smtp_starttls: bool = True

  # True ise kayıttan sonra e-posta doğrulanmadan giriş yapılamaz (SMTP gerekir).
  require_email_verification: bool = False
  email_code_ttl_minutes: int = 15
  email_code_max_attempts: int = 5

  # Kullanıcı başına günlük en fazla asistan mesajı (ücretli AI API maliyetini sınırlar)
  daily_chat_limit: int = 100

  # Kullanıcı başına saklanacak en fazla sohbet mesajı
  max_stored_messages: int = 500

  # Senkron belgesi başına en fazla bayt
  max_sync_document_bytes: int = 1_000_000

  # Girdi sınırları
  max_message_length: int = 4000
  max_context_bytes: int = 60_000
  history_messages: int = 10

  # Kaba kuvvet koruması: pencere başına izin verilen deneme
  auth_rate_limit_attempts: int = 10
  auth_rate_limit_window_seconds: int = 300

  @property
  def is_production(self) -> bool:
    return self.environment.lower() == "production"

  @property
  def cors_origin_list(self) -> list[str]:
    return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
  settings = Settings()
  if settings.secret_key in _INSECURE_SECRETS or len(settings.secret_key) < 32:
    if settings.is_production:
      raise RuntimeError(
        "SECRET_KEY tanımlı değil ya da zayıf (en az 32 karakter olmalı). "
        "Üretimde sunucu güvenli bir anahtar olmadan başlamaz."
      )
    logger.warning(
      "SECRET_KEY zayıf/tanımsız; bu süreç için rastgele bir anahtar üretildi. "
      "Sunucu yeniden başlayınca tüm oturumlar düşer. .env içinde güçlü bir SECRET_KEY tanımla."
    )
    settings.secret_key = secrets.token_urlsafe(48)
  if settings.is_production and settings.email_backend != "smtp":
    # Şifre sıfırlama kodları e-postayla gider; "console" üretimde kullanıcıya ulaşmaz.
    raise RuntimeError("Üretimde EMAIL_BACKEND=smtp (ve SMTP_HOST) ayarlanmalı.")
  if settings.email_backend == "smtp" and not settings.smtp_host:
    raise RuntimeError("EMAIL_BACKEND=smtp için SMTP_HOST ayarlanmalı.")
  return settings
