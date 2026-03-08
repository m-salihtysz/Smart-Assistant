# Smart Assistant - Frontend 📱

Smart Assistant uygulamasının Flutter ile geliştirilmiş mobil arayüzü. Bu uygulama şu an için **iOS** platformuna özel olarak yapılandırılmıştır.

## 🌟 Özellikler

- **Modern & Dinamik Tasarım:** Kullanıcı dostu ve estetik bir arayüz.
- **AI Sohbet:** Backend ile entegre, Gemini/OpenAI destekli akıllı asistan.
- **Zengin Modüller:**
  - 🏋️ **Spor Paneli:** Haftalık spor planı ve egzersiz takibi.
  - 📈 **Finans/Borsa:** Gelir-gider takibi ve borsa takip listesi.
  - 📝 **Notlar:** Günlük notlar ve hızlı kayıtlar.
  - 📅 **Rutinler:** Günlük rutinlerin yönetimi ve takibi.
- **Hatırlatıcılar:** Önemli aktiviteler için yerel bildirim desteği.
- **Dil Desteği:** Dinamik Türkçe ve İngilizce dil seçenekleri.

## 🛠️ Kullanılan Paketler

- [Provider](https://pub.dev/packages/provider): Durum yönetimi (State Management).
- [HTTP](https://pub.dev/packages/http): Sunucu ile iletişim.
- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications): Yerel bildirimler.
- [Timezone](https://pub.dev/packages/timezone): Bildirim zamanlamaları.
- [Shared Preferences](https://pub.dev/packages/shared_preferences): Basit veri depolama.

---

## 🚀 Başlangıç (iOS)

### Ön Gereksinimler

- MacOS
- Flutter SDK (Son sürüm)
- Xcode (iOS geliştirme için)
- iOS Simulator veya takılı bir iPhone

### Kurulum

1. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```

2. Uygulamayı çalıştırın (Simulator açıksa):
   ```bash
   flutter run
   ```

## ⚙️ Yapılandırma

Uygulamanın backend ile iletişim kurabilmesi için `lib/main.dart` içerisindeki `_baseUrl` adresinin backend sunucunuzun adresiyle eşleştiğinden emin olun.

- **iOS Simulator:** `http://127.0.0.1:8000` veya `http://localhost:8000`.

---

## 🎨 Uygulama Görselleri

Uygulamanın arayüz tasarımı ve detaylı kullanımı hakkında görsel bilgi edinmek için ana dizindeki tanıtım dosyasını inceleyebilirsiniz:

👉 **[Uygulama Tanıtımı (PDF)](../app.pdf)**

---
