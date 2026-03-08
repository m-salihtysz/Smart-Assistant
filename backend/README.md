# Smart Assistant - Backend API ⚙️

Smart Assistant uygulamasının arkasındaki güç: FastAPI ile geliştirilmiş, performanslı ve ölçeklenebilir bir asistan backend'i.

## 🚀 Özellikler

- **Hızlı API:** FastAPI sayesinde yüksek performanslı uç noktalar.
- **AI Entegrasyonu:** Google Gemini ve OpenAI modelleri ile doğrudan entegrasyon.
- **Güvenlik:** JWT tabanlı kimlik doğrulama ve şifrelenmiş parola saklama (BCrypt).
- **Veritabanı:** SQLAlchemy ORM ile SQLite yönetimi.
- **Dokümantasyon:** Otomatik oluşturulan Swagger ve ReDoc arayüzleri.

## 🛠️ Teknolojiler

- [Python 3.10+](https://www.python.org/)
- [FastAPI](https://fastapi.tiangolo.com/)
- [SQLAlchemy](https://www.sqlalchemy.org/)
- [Pydantic](https://docs.pydantic.dev/)
- [Jose / Passlib](https://python-jose.readthedocs.io/)

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

Kök dizinde bir `.env` dosyası oluşturun ve gerekli anahtarları ekleyin:

```env
SECRET_KEY=degistir_bu_anahtari
DATABASE_URL=sqlite:///./app.db
GEMINI_API_KEY=YOUR_GEMINI_API_KEY
# Opsiyonel: OPENAI_API_KEY=YOUR_OPENAI_API_KEY
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
| `POST` | `/assistant/chat` | AI asistanı ile sohbet et |

---

