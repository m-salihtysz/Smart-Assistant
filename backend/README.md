# Smart Assistant - Backend API ⚙️

Smart Assistant uygulamasının arkasındaki güç: FastAPI ile geliştirilmiş, performanslı ve ölçeklenebilir bir asistan backend'i.

## 🚀 Özellikler

- **Hızlı API:** FastAPI sayesinde yüksek performanslı uç noktalar.
- **AI Entegrasyonu:** Google Gemini ve OpenAI modelleri ile doğrudan entegrasyon.
- **Güvenlik:** JWT erişim token'ı + döndürülen (rotating) yenileme token'ı, PBKDF2-SHA256 ile parola saklama, hız sınırı, günlük AI kotası, girdi boyutu sınırları, üretimde zorunlu güçlü `SECRET_KEY`.
- **Hesap akışları:** E-posta kodlu şifre sıfırlama, isteğe bağlı e-posta doğrulama, hesap silme.
- **Bulut yedekleme:** Cihaz verileri sürüm numaralı belgeler olarak saklanır (çakışma algılama).
- **Veritabanı:** SQLAlchemy ORM; geliştirmede SQLite, üretimde PostgreSQL (testler ikisinde de çalışır).
- **Dokümantasyon:** Otomatik oluşturulan Swagger ve ReDoc arayüzleri.

## 🛠️ Teknolojiler

- [Python 3.10+](https://www.python.org/)
- [FastAPI](https://fastapi.tiangolo.com/)
- [SQLAlchemy](https://www.sqlalchemy.org/)
- [Pydantic](https://docs.pydantic.dev/)
- [Jose / Passlib](https://python-jose.readthedocs.io/)
- [Alembic](https://alembic.sqlalchemy.org/) (veritabanı göçleri)

---

## 🏃 Kurulum ve Çalıştırma

### 1. Sanal Ortam Oluşturma

Hataları önlemek için bir sanal ortam (`venv`) kullanmanız önerilir:

```bash
python -m venv .venv
source .venv/bin/activate  # MacOS/Linux
# Windows için: .venv\Scripts\activate
```

### 2. Bağımlılıkları Yükleme

```bash
pip install -r requirements.txt
```

### 3. Yapılandırma (.env)

`backend/` klasöründe `.env.example` dosyasını `.env` olarak kopyalayıp doldurun:

```bash
cp .env.example .env
python -c "import secrets; print(secrets.token_urlsafe(48))"   # SECRET_KEY için
```

| Değişken | Açıklama |
| :--- | :--- |
| `ENVIRONMENT` | `development` (varsayılan) veya `production`. Production'da zayıf/boş `SECRET_KEY` ile sunucu **başlamaz**. |
| `SECRET_KEY` | En az 32 karakter. Boşsa geliştirmede her başlangıçta rastgele üretilir (oturumlar düşer). |
| `DATABASE_URL` | Varsayılan `sqlite:///./app.db` |
| `CORS_ORIGINS` | Web istemcisi için izinli origin'ler (virgülle). Mobil için boş bırakın. |
| `REFRESH_TOKEN_EXPIRE_DAYS` | Oturum yenileme token'ının ömrü (varsayılan 30 gün). Erişim token'ı 60 dakikadır ve uygulama onu sessizce yeniler. |
| `EMAIL_BACKEND` | `console` (geliştirme: kod loga yazılır) veya `smtp`. **Production'da `smtp` zorunlu.** |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASSWORD` | `smtp` için. |
| `REQUIRE_EMAIL_VERIFICATION` | `true` ise e-posta doğrulanmadan giriş yapılamaz. |
| `DAILY_CHAT_LIMIT` | Kullanıcı başına günlük asistan mesajı (varsayılan 100). |
| `GEMINI_API_KEY` / `OPENAI_API_KEY` | Öncelik Gemini'de; hiçbiri yoksa demo mod. |
| `GEMINI_MODEL` / `OPENAI_MODEL` | Model adları (varsayılan `gemini-2.5-flash` / `gpt-4o-mini`). |

> **Üretimde:** `ENVIRONMENT=production` olduğunda sunucu zayıf `SECRET_KEY` ile başlamaz ve AI hatasında sahte "demo" cevabı yerine `503` döner. Uygulama yalnızca HTTPS ile çalışır (release derleme `https://` adres ister); bir ters vekil (nginx/Caddy vb.) ile TLS'i sağla.

### Veritabanı göçleri (Alembic)

Geliştirmede tablolar açılışta otomatik oluşur. Üretimde göç kullanın:

```bash
alembic upgrade head          # yeni veritabanı
alembic stamp head            # create_all ile oluşmuş mevcut veritabanı için bir kez
```

### 4. Uygulamayı Başlatma

```bash
uvicorn app.main:app --reload
```

Sunucu varsayılan olarak `http://localhost:8000` adresinde çalışacaktır.

---

## 📖 API Dokümantasyonu

Uygulama çalışırken dokümanlara şuradan erişebilirsiniz:

- **Swagger UI:** [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc:** [http://localhost:8000/redoc](http://localhost:8000/redoc)

## 📡 Ana Endpoint'ler

| Metot | Yol | Açıklama |
| :--- | :--- | :--- |
| `POST` | `/auth/register` | Yeni kullanıcı kaydı |
| `POST` | `/auth/login` | Giriş yap ve Token al |
| `GET` | `/auth/me` | Mevcut kullanıcı bilgileri |
| `POST` | `/auth/refresh` | Yenileme token'ını döndürerek yeni token çifti al |
| `POST` | `/auth/logout` | Bu cihazın yenileme token'ını geçersiz kıl |
| `POST` | `/auth/forgot-password` | E-postaya 6 haneli sıfırlama kodu gönder (hesap sızdırmaz) |
| `POST` | `/auth/reset-password` | Kod + yeni şifre ile şifreyi sıfırla (tüm oturumlar kapanır) |
| `POST` | `/auth/verify-email` | E-posta doğrulama kodunu onayla |
| `POST` | `/auth/resend-verification` | Doğrulama kodunu yeniden gönder |
| `POST` | `/auth/change-password` | Şifre değiştir (diğer cihazların oturumları kapanır) |
| `PUT` | `/auth/me` | Profili güncelle |
| `DELETE` | `/auth/me` | Hesabı ve tüm sohbet kayıtlarını kalıcı sil |
| `POST` | `/assistant/chat` | AI asistanı ile sohbet et (son mesajlar geçmiş olarak gönderilir) |
| `GET` | `/sync` | Cihaz verilerinin bulut yedeğini al |
| `PUT` | `/sync/{anahtar}` | Bir koleksiyonu yedekle (`base_version` uyuşmazsa 409) |
| `DELETE` | `/sync` | Tüm bulut yedeğini sil |
| `POST` | `/assistant/report` | Uygunsuz/hatalı bir asistan yanıtını bildir |
| `GET` | `/assistant/history` | Sohbet geçmişi |
| `DELETE` | `/assistant/history` | Sohbet geçmişini sil |

Hız sınırı aşılırsa `429` ve `Retry-After` başlığı döner.

## 🧪 Testler

```bash
pip install -r requirements-dev.txt
pytest                                   # SQLite
TEST_DATABASE_URL=postgresql+psycopg://... pytest   # gerçek PostgreSQL'e karşı
```

Sunucuya kurulum için: [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md).

---

