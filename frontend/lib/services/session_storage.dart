import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Oturum token'ının saklandığı yer. Testlerde sahte bir uygulamayla değiştirilebilir.
abstract class SessionStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);

  /// Erişim token'ı süresi dolunca yeni bir tane almak için kullanılan uzun ömürlü token.
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);

  /// Hem erişim hem yenileme token'ını siler.
  Future<void> clearToken();
}

/// iOS Keychain / Android Keystore üzerinde saklar.
class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage();

  static const _key = 'auth_token';
  static const _refreshKey = 'refresh_token';
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeToken(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {}
  }

  @override
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshKey, value: token);
    } catch (_) {}
  }

  @override
  Future<void> clearToken() async {
    try {
      await _storage.delete(key: _key);
      await _storage.delete(key: _refreshKey);
    } catch (_) {}
  }
}
