# Smart Assistant 🚀

Akıllı ve kişiselleştirilmiş bir asistan deneyimi sunan, modern teknolojilerle geliştirilmiş tam kapsamlı (full-stack) bir projedir.

---

![Smart Assistant Showcase](./showcase.png)

---

### 📥 [**Uygulama Tanıtımını ve Ekran Görüntülerini Görüntüle (PDF)**](./app.pdf)

---

## 📌 Proje Hakkında

Smart Assistant, kullanıcıların günlük görevlerini yönetmelerine, not almalarına ve en önemlisi gelişmiş Yapay Zeka (AI) modelleri ile (Gemini veya OpenAI) sohbet ederek yardım almasına olanak tanıyan bir asistan ekosistemidir.

### 🛠️ Teknolojik Altyapı

Bu proje iki ana bölümden oluşmaktadır:

1.  **[Frontend (Flutter)](./frontend):** iOS platformu için optimize edilmiş kullanıcı dostu arayüz, yerel bildirimler, çoklu dil desteği (TR/EN) ve dinamik kullanıcı deneyimi sağlar.
2.  **[Backend (FastAPI)](./backend):** Kullanıcı kimlik doğrulama (JWT), veri kalıcılığı (SQLite + SQLAlchemy) ve AI entegrasyonu (Gemini/OpenAI) sağlar.

---

## 📂 Dosya Yapısı

```text
smart_assistant/
├── frontend/          # Flutter Mobil Uygulaması (iOS Odaklı)
│   ├── lib/           # Uygulama kaynak kodları (Single-file main.dart)
│   └── ios/           # iOS projesi yapılandırması
├── backend/           # FastAPI Sunucusu
│   ├── app/           # API mantığı, modeller ve yönlendiriciler
│   └── .env           # Yapılandırma dosyası
└── README.md          # Ana dokümantasyon
```

---

## 🚀 Hızlı Başlangıç

Projeyi yerel ortamınızda ayağa kaldırmak için aşağıdaki adımları izleyin:

### 1. Backend Kurulumu
Backend dizinine gidin ve sunucuyu çalıştırın:
- Detaylı adımlar için: **[Backend README](./backend/README.md)**

### 2. Frontend Kurulumu
Frontend dizinine gidin ve Flutter uygulamasını başlatın (MacOS/Xcode gereklidir):
- Detaylı adımlar için: **[Frontend README](./frontend/README.md)**

---

## ✨ Temel Özellikler

- 🤖 **AI Sohbet:** Gemini veya OpenAI modelleriyle doğrudan etkileşim.
- 🔐 **Kimlik Doğrulama:** JWT tabanlı güvenli kayıt ve giriş sistemi.
- 🔔 **Hatırlatıcılar:** Yerel bildirimlerle aktivite ve rutin takibi.
- 💼 **Modüller:** Spor planı, borsa takibi, finans yönetimi ve notlar.
- 🌐 **Dil Desteği:** Tamamen Türkçe ve İngilizce desteği.

---

## 📄 Lisans

Bu proje eğitim ve kişisel gelişim amaçlı geliştirilmiştir.

---
