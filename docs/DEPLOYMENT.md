# Backend Dağıtım Rehberi

Bu rehber, backend'i tek bir sunucuda (VPS) HTTPS ile yayınlamak içindir. Aşağıdaki adımların temelleri
(PostgreSQL migration'ları, proxy başlıkları, e-posta) gerçek PostgreSQL 16 ve uvicorn ile denenmiştir;
Caddy/systemd örnekleri ise denenmemiş şablonlardır, kendi sunucunda doğrula.

## Mimari

```
iPhone  ──HTTPS──►  Caddy (TLS, 443)  ──HTTP──►  uvicorn (127.0.0.1:8000)  ──►  PostgreSQL
                                                         └──► Gemini / OpenAI, SMTP
```

## 1. Gereksinimler
- Python 3.10+ (3.12 önerilir), PostgreSQL 14+ (SQLite yalnızca geliştirme içindir)
- Bir alan adı (ör. `api.ornek.com`) ve sunucuya yönlenmiş DNS kaydı
- Bir SMTP sağlayıcısı (şifre sıfırlama/doğrulama e-postaları için; production'da zorunlu)

## 2. Kurulum
```bash
cd backend
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements-postgres.txt      # requirements.txt + PostgreSQL sürücüsü
cp .env.example .env                           # aşağıdaki değerleri doldur
alembic upgrade head                           # tabloları oluştur / güncelle
```

### `.env` (production)
```env
ENVIRONMENT=production
SECRET_KEY=<python -c "import secrets; print(secrets.token_urlsafe(48))">
DATABASE_URL=postgresql+psycopg://smart:PAROLA@127.0.0.1:5432/smart_assistant
GEMINI_API_KEY=...            # ücretli/ticari katman
EMAIL_BACKEND=smtp
EMAIL_FROM=Smart Assistant <no-reply@ornek.com>
SMTP_HOST=smtp.ornek.com
SMTP_PORT=587
SMTP_USER=...
SMTP_PASSWORD=...
REQUIRE_EMAIL_VERIFICATION=true
DAILY_CHAT_LIMIT=100
CORS_ORIGINS=                 # mobil uygulama için boş
```
Production'da zayıf `SECRET_KEY` ya da `EMAIL_BACKEND=console` ile sunucu **başlamaz**. Production'da tablolar
otomatik oluşturulmaz; her sürümden sonra `alembic upgrade head` çalıştır. `SECRET_KEY`'i değiştirmek tüm
oturumları ve bekleyen e-posta kodlarını geçersiz kılar.

## 3. Çalıştırma — önemli: proxy başlıkları ve işçi sayısı

```bash
uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1 \
  --proxy-headers --forwarded-allow-ips=127.0.0.1
```

- **`--proxy-headers`**: Ters vekil (Caddy/nginx) arkasında istemci IP'sini `X-Forwarded-For`'dan alır.
  Bu olmazsa hız sınırı **tüm kullanıcıları tek IP (vekil) sayar**: biri 10 kez yanlış şifre girince herkes 5 dakika
  giriş yapamaz. (Vekil aynı makinedeyse uvicorn bunu varsayılan olarak yapar; farklı makinedeyse
  `--forwarded-allow-ips=<vekilin IP'si>` ver. Yalnızca güvendiğin vekilleri yaz.)
- **`--workers 1`**: Hız sınırı süreç belleğinde tutulur. Birden fazla işçi çalıştırırsan sınırlar işçi başına
  ayrı sayılır; o zaman Redis gibi paylaşılan bir depoya geçmek gerekir. Tek işçi, AI çağrıları dışında yeterlidir
  (ağır işler iş parçacığı havuzunda çalışır).
- Uvicorn'u yalnızca `127.0.0.1`'e bağla; dışarıya yalnızca Caddy açık olsun.

## 4. Caddy (otomatik HTTPS) — şablon
`/etc/caddy/Caddyfile`:
```
api.ornek.com {
    reverse_proxy 127.0.0.1:8000
}
```

## 5. systemd — şablon
`/etc/systemd/system/smart-assistant.service`:
```ini
[Unit]
Description=Smart Assistant API
After=network.target postgresql.service

[Service]
User=smart
WorkingDirectory=/srv/smart_assistant/backend
EnvironmentFile=/srv/smart_assistant/backend/.env
ExecStart=/srv/smart_assistant/backend/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 1 --proxy-headers --forwarded-allow-ips=127.0.0.1
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl enable --now smart-assistant
```

## 6. Güncelleme
```bash
git pull && source .venv/bin/activate
pip install -r requirements-postgres.txt
alembic upgrade head
sudo systemctl restart smart-assistant
```

## 7. Yedekleme ve güvenlik
- **Veritabanı yedeği:** `pg_dump` ile günlük yedek al ve sunucu dışında sakla. Kullanıcıların bulut yedekleri
  (`sync_documents`) bu veritabanındadır.
- **Şifreleme:** Yedekler veritabanında düz metin JSON'dur (uygulama düzeyinde şifreleme yok). Disk şifreleme
  ya da yönetilen veritabanının at-rest şifrelemesini kullan; yedekleri de şifrele.
- **Bildirimler:** Kullanıcıların "Bildir" ile gönderdiği yapay zeka yanıtları `reports` tablosunda birikir;
  düzenli incele.
- **Loglar:** Sunucu AI hatalarını ve bildirimleri loga yazar; kişisel veri (mesaj içeriği) loglanmaz.
- **Hesap silme:** `DELETE /auth/me` hesabı, sohbeti, bildirimleri, token'ları ve bulut yedeğini siler.

## 8. Mobil uygulamayı bu sunucuya bağlama
```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.ornek.com \
  --dart-define=SUPPORT_EMAIL=destek@ornek.com
```
Release derleme `https://` olmayan adresi reddeder.
