# App Store'a Çıkış Kontrol Listesi

Kodla çözülebilenler yapıldı (✅). Geri kalanı senin hesabın, sunucun ve cihazın gerektiriyor (⬜).

## ✅ Kodda yapılanlar
- Bundle ID `com.msalihtysz.smartassistant` (Xcode > Runner > Signing & Capabilities'ten değiştirilebilir; Apple hesabında benzersiz olmalı).
- Minimum iOS 17.0, yalnızca iPhone, yalnızca dikey.
- `ITSAppUsesNonExemptEncryption = false` (yalnızca standart HTTPS kullanılıyor).
- `PrivacyInfo.xcprivacy` (toplanan veri türleri + `UserDefaults` gerekçesi CA92.1).
- Yapay zekaya veri gönderilmeden önce açık izin ekranı; Ayarlar'dan geri alınabilir.
- Uygulama içi Gizlilik Politikası ekranı (TR/EN).
- 13 yaş sınırı (istemci + sunucu doğrulaması).
- Hesap silme (uygulamadan, sunucu verisiyle birlikte).
- Yapay zeka yanıtlarını "Bildir" ile raporlama (`POST /assistant/report`) ve "yanıtlar hatalı olabilir" uyarısı.
- Bildirim izni, ilk hatırlatıcı kurulurken istenir.
- Oturum: erişim token'ı sessizce yenilenir (kullanıcı saat başı atılmaz); çıkış, şifre değişimi ve şifre sıfırlama diğer cihazların oturumlarını sunucuda kapatır; çalınmış token yeniden kullanımı algılanır.
- Şifre sıfırlama (e-postayla 6 haneli kod), isteğe bağlı e-posta doğrulama (`REQUIRE_EMAIL_VERIFICATION`), uygulamadan şifre değiştirme.
- Kategori görselleri uygulamaya gömülü (internet gerekmez).
- Sohbet geçmişi kullanıcı başına en fazla 500 mesajla sınırlı; günlük asistan kotası (varsayılan 100 mesaj) AI maliyetini sınırlar.
- **Bulut yedekleme/senkron:** aktivite, rutin, spor, finans, not verileri sunucuya yedeklenir ve cihazlar arasında eşitlenir (Ayarlar'dan kapatılabilir, kapatırken sunucu kopyası silinebilir; hesap silinince yedek de silinir). Çakışmada listeler birleştirilir, nesnelerde son düzenleme kazanır.
- PostgreSQL desteği doğrulandı (migration'lar + tüm testler gerçek PostgreSQL 16 üzerinde geçiyor).
- Release derlemede `API_BASE_URL` zorunlu ve `https://` olmalı (localhost ile yayına çıkılamaz).
- Üretimde backend, AI hatasında sahte "demo" cevabı yerine 503 döner.

## ⬜ Yapman gerekenler
1. **Backend'i yayınla** (HTTPS): `ENVIRONMENT=production`, en az 32 karakterlik `SECRET_KEY`, `GEMINI_API_KEY` veya `OPENAI_API_KEY` ve **SMTP ayarları** (`EMAIL_BACKEND=smtp`, `SMTP_HOST`...; yoksa production'da sunucu başlamaz). Veritabanı migration'larını çalıştır: `alembic upgrade head`. Üretimde ücretli/ticari API katmanı kullan (ücretsiz katmanlar verileri ürün geliştirmede kullanabilir). Veritabanını yedekle.
2. **Gizlilik politikası** (`docs/PRIVACY_POLICY.md`): boşlukları doldur, doğrulat, herkese açık bir URL'de yayınla.
3. **Destek URL'si ve e-postası** hazırla; derlemede `--dart-define=SUPPORT_EMAIL=...` ver.
4. **Apple Developer** hesabında Bundle ID'yi oluştur, App Store Connect'te uygulamayı ekle.
5. **App Privacy etiketleri:** E-posta, Ad, Diğer kullanıcı içeriği (sohbet, notlar, aktivite/rutin/spor yedekleri), Diğer finansal bilgi (finans yedeği) → "Uygulama işlevselliği", kullanıcıya bağlı, takip yok. Üçüncü taraf AI paylaşımını belirt.
6. **Yaş derecelendirme anketi:** yapay zeka sohbetini ve kullanıcı tarafından üretilen içeriği işaretle.
7. **Ekran görüntüleri** (6,7" iPhone zorunlu), açıklama, anahtar kelimeler, destek URL'si.
8. **Bildirimleri izle:** kullanıcı bildirimleri `reports` tablosunda birikir; düzenli kontrol et ve uygunsuz içeriğe karşı aksiyon al.
9. **App Review notları:** uygulamada kayıt serbest; istersen bir test hesabı ver. Asistanın bir AI sağlayıcısına bağlandığını ve izin ekranını belirt.
10. **Gerçek cihazda test:** kayıt/giriş, oturum geri yükleme, hatırlatıcı bildirimleri (rutinlerin haftalık tekrarı), asistan, hesap silme, koyu tema.
11. `cd frontend/ios && pod install`, ardından:
    ```bash
    flutter build ipa --release \
      --dart-define=API_BASE_URL=https://api.senin-alan-adin.com \
      --dart-define=SUPPORT_EMAIL=destek@senin-alan-adin.com
    ```
    İmzalama için Xcode'da Team'i seçili tut (`DEVELOPMENT_TEAM` tanımlı).

## Bilinen eksikler (zorunlu değil)
- Çeviri sistemi Türkçe metin anahtarlı bir tablo (ARB/`intl` değil). Bir test, koddaki her `.tr()` metninin İngilizce karşılığı olduğunu denetler.
- Hız sınırı süreç belleğinde tutulur (tek sunucu süreci için yeterli).
- Sunucudaki yedekler veritabanında düz metin JSON olarak durur (uygulama düzeyinde şifreleme yok). Diski/veritabanını şifrele (disk şifreleme, yönetilen DB'nin at-rest şifrelemesi).
- Aynı koleksiyonun iki cihazda aynı anda düzenlenmesi nadiren eski bir silmenin geri gelmesine yol açabilir (liste birleştirme).
