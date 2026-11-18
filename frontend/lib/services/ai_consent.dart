import 'user_store.dart';

/// Kullanıcının, verilerinin üçüncü taraf yapay zeka sağlayıcısına gönderilmesine
/// verdiği izin (hesap bazında, cihazda saklanır).
class AiConsent {
  AiConsent._();

  static const _key = 'ai_consent';

  static Future<bool> isGranted() async =>
      (await UserStore.getString(_key)) == 'granted';

  static Future<void> set(bool granted) =>
      UserStore.setString(_key, granted ? 'granted' : 'denied');
}
