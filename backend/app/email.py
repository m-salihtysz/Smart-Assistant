import logging
import smtplib
from email.message import EmailMessage

from .config import get_settings


logger = logging.getLogger(__name__)


def send_email(to: str, subject: str, body: str) -> None:
  """E-posta gönderir. `console` geliştirme içindir (içeriği loga yazar)."""
  settings = get_settings()
  if settings.email_backend == "smtp":
    if not settings.smtp_host:
      raise RuntimeError("EMAIL_BACKEND=smtp için SMTP_HOST ayarlanmalı.")
    msg = EmailMessage()
    msg["From"] = settings.email_from
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(body)
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
      if settings.smtp_starttls:
        smtp.starttls()
      if settings.smtp_user:
        smtp.login(settings.smtp_user, settings.smtp_password)
      smtp.send_message(msg)
    return
  logger.warning("[E-POSTA / console] Kime: %s | Konu: %s\n%s", to, subject, body)
