from __future__ import annotations

import json
from typing import Any, Dict, List

from google import genai
from openai import OpenAI

from .config import get_settings


_openai_client: OpenAI | None = None


def _get_openai_client() -> OpenAI:
  global _openai_client
  if _openai_client is None:
    settings = get_settings()
    if not settings.openai_api_key:
      raise RuntimeError(
        "OpenAI API anahtarı bulunamadı. "
        "Lütfen .env dosyasında OPENAI_API_KEY değişkenini ayarla."
      )
    _openai_client = OpenAI(api_key=settings.openai_api_key)
  return _openai_client


def _build_prompt(
  message: str,
  user_name: str | None,
  context: Dict[str, Any] | None,
) -> str:
  system_parts: List[str] = [
    "Sen bir mobil kişisel asistan uygulaması için tasarlanmış, Türkçe konuşan bir yapay zekâ asistansın.",
    "Kullanıcının spor planları, günlük aktiviteleri, rutinleri ve finans kayıtları gibi kişisel verileri üzerinden yardımcı olursun.",
    "Cevaplarında net, sakin ve motive edici bir üslup kullan.",
    "Kısa ama açıklayıcı cevaplar ver; gerektiğinde madde madde öneriler sun.",
  ]

  if user_name:
    system_parts.append(f"Kullanıcının adı: {user_name}. Ona adıyla hitap edebilirsin.")

  if context:
    pretty_context = json.dumps(context, ensure_ascii=False, indent=2)
    system_parts.append(
      "Aşağıda kullanıcının planları, aktiviteleri, rutinleri, spor planları, finans özeti ve not özetleri JSON formatında verilmiştir. "
      "Bu bilgileri cevabında mutlaka dikkate al."
    )
    system_parts.append(pretty_context)

  system_parts.append(
    "ÇOK ÖNEMLİ: Cevabını her zaman SADECE GEÇERLİ BİR JSON NESNESİ olarak döndür. "
    "Hiçbir açıklama, markdown veya ekstra metin ekleme. Sadece JSON.\n\n"
    "{\n"
    '  "reply": "Kullanıcıya göstereceğin doğal dil Türkçe cevap",\n'
    '  "action": null veya {\n'
    '    "type": "add_activity" | "add_routine" | "add_finance_transaction" | "add_note" | "set_sport_plan_for_day",\n'
    '    "payload": {...}\n'
    "  }\n"
    "}\n\n"
    "Action örnekleri:\n"
    "1) Yeni bir aktivite eklemek için:\n"
    '{\n'
    '  "type": "add_activity",\n'
    '  "payload": {\n'
    '    "date": "2026-03-06",\n'
    '    "title": "Dişçi randevusu",\n'
    '    "hour": 14,\n'
    '    "minute": 30,\n'
    '    "reminder": true\n'
    "  }\n"
    "}\n"
    "2) Yeni bir günlük rutin eklemek için:\n"
    '{\n'
    '  "type": "add_routine",\n'
    '  "payload": {\n'
    '    "weekday": 0,\n'
    '    "title": "Sabah yürüyüşü",\n'
    '    "hour": 7,\n'
    '    "minute": 0,\n'
    '    "reminder": true\n'
    "  }\n"
    "}\n"
    "3) Finans kaydı eklemek için:\n"
    '{\n'
    '  "type": "add_finance_transaction",\n'
    '  "payload": {\n'
    '    "kind": "expense",\n'
    '    "amount": 150.0,\n'
    '    "title": "Market alışverişi",\n'
    '    "date": "2026-03-06"\n'
    "  }\n"
    "}\n"
    "4) Yeni not eklemek için:\n"
    '{\n'
    '  "type": "add_note",\n'
    '  "payload": {\n'
    '    "title": "Hafta sonu planı",\n'
    '    "body": "Cumartesi spor, Pazar aile ziyareti..."\n'
    "  }\n"
    "}\n"
    "5) Belirli bir gün için spor planını ayarlamak için:\n"
    '{\n'
    '  "type": "set_sport_plan_for_day",\n'
    '  "payload": {\n'
    '    "weekday": 5,\n'
    '    "region": "Tüm vücut",\n'
    '    "exercises": [\n'
    '      {"name": "Şınav", "reps": 12, "sets": 3},\n'
    '      {"name": "Squat", "reps": 15, "sets": 3}\n'
    "    ]\n"
    "  }\n"
    "}\n\n"
    "Kullanıcı açıkça yeni bir kayıt eklemek istiyorsa uygun action'ı doldur. "
    "Sadece soruya cevap veriyorsan action alanını null yap."
  )

  system_prompt = "\n\n".join(system_parts)

  user_content = (
    f"Kullanıcının sorusu:\n{message}\n\n"
    "Yukarıdaki bağlamı kullanarak Türkçe bir cevap üret. "
    "Gereksiz tekrar yapma, direkt yardımcı ol."
  )

  return system_prompt + "\n\n" + user_content


def generate_assistant_reply(
  message: str,
  user_name: str | None,
  context: Dict[str, Any] | None = None,
  model: str = "gpt-4o-mini",
) -> tuple[str, Dict[str, Any] | None]:
  """
  Kullanıcı mesajı ve isteğe bağlı bağlamdan gerçek bir AI cevabı üretir.
  Herhangi bir hata durumunda exception fırlatır; çağıran fonksiyon fallback
  mesajı ile durumu ele almalıdır.
  """
  settings = get_settings()
  prompt = _build_prompt(message, user_name, context)

  # Öncelik: GEMINI (ücretsiz kota için daha uygun), ardından OpenAI
  if settings.gemini_api_key:
    client = genai.Client(api_key=settings.gemini_api_key)
    # Yeni Gemini API için önerilen metin modeli: gemini-2.5-flash
    response = client.models.generate_content(
      model="gemini-2.5-flash",
      contents=prompt,
    )
    raw = getattr(response, "text", None)
    if not raw:
      raise RuntimeError("Gemini cevabı boş döndü.")
    text = raw.strip()
    try:
      data = json.loads(text)
      if isinstance(data, dict) and "reply" in data:
        reply_text = str(data.get("reply", "")).strip()
        action = data.get("action")
        if not isinstance(action, dict):
          action = None
        if reply_text:
          return reply_text, action
    except Exception:
      # JSON parse edilemezse, tüm cevabı metin olarak kullan.
      pass
    return text, None

  if settings.openai_api_key:
    client = _get_openai_client()
    messages = [
      {"role": "system", "content": prompt},
    ]
    completion = client.chat.completions.create(
      model=model,
      messages=messages,
      temperature=0.4,
    )
    raw = completion.choices[0].message.content
    if not raw:
      raise RuntimeError("OpenAI cevabı boş döndü.")
    text = raw.strip()
    try:
      data = json.loads(text)
      if isinstance(data, dict) and "reply" in data:
        reply_text = str(data.get("reply", "")).strip()
        action = data.get("action")
        if not isinstance(action, dict):
          action = None
        if reply_text:
          return reply_text, action
    except Exception:
      pass
    return text, None

  raise RuntimeError(
    "Herhangi bir AI API anahtarı tanımlı değil. "
    "Lütfen .env dosyasında GEMINI_API_KEY veya OPENAI_API_KEY ayarla."
  )

