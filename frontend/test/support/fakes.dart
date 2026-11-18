import 'package:smart_assistant/services/session_storage.dart';

/// Testlerde Keychain yerine bellekte tutulan oturum depolaması.
class MemorySessionStorage implements SessionStorage {
  String? token;
  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String value) async => refreshToken = value;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String value) async => token = value;

  @override
  Future<void> clearToken() async {
    token = null;
    refreshToken = null;
  }
}
