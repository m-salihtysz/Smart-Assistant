import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcıya özel yerel depolama. Her anahtar aktif kullanıcının e-postasıyla
/// öneklenir; böylece aynı cihazda farklı hesaplar birbirinin verisini görmez.
class UserStore {
  UserStore._();

  static const List<String> dataKeys = [
    'activities',
    'routines',
    'sport_plans',
    'finance_transactions',
    'finance_watchlist',
    'notes_v2',
    'assistant_messages',
    'ai_consent',
  ];

  static String? _user;

  /// Senkronize edilen bir koleksiyon yazıldığında çağrılır (SyncService bağlanır).
  static void Function(String base)? onWrite;

  /// Aktif kullanıcıyı ayarlar (çıkışta `null`).
  static void setUser(String? email) {
    _user = email?.trim().toLowerCase();
  }

  static String? get user => _user;

  /// `base` anahtarının aktif kullanıcıya özel hali.
  static String key(String base) {
    final user = _user;
    if (user == null) {
      throw StateError(
        'UserStore: oturum açık değilken kullanıcı verisine erişildi ($base).',
      );
    }
    return 'u:$user:$base';
  }

  static Future<String?> getString(String base) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key(base));
  }

  /// [notify] false ise yazma, senkron servisine "değişti" bildirimi göndermez
  /// (sunucudan çekilen veri yerele yazılırken kullanılır).
  static Future<void> setString(
    String base,
    String value, {
    bool notify = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key(base), value);
    if (notify) onWrite?.call(base);
  }

  /// JSON liste okur; yoksa veya bozuksa boş liste döner.
  static Future<List<dynamic>> readList(String base) async {
    final raw = await getString(base);
    if (raw == null) return <dynamic>[];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.toList() : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  /// JSON harita okur; yoksa veya bozuksa boş harita döner.
  static Future<Map<String, dynamic>> readMap(String base) async {
    final raw = await getString(base);
    if (raw == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? Map<String, dynamic>.of(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<void> writeJson(String base, Object value) =>
      setString(base, jsonEncode(value));

  /// Hesap silinirken aktif kullanıcının tüm yerel verisini temizler.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final base in dataKeys) {
      await prefs.remove(key(base));
    }
    // Bu kullanıcının senkron üst verisi (sürümler, kirli bayrakları)
    final syncPrefix = 'sync:${_user!}:';
    for (final k
        in prefs.getKeys().where((k) => k.startsWith(syncPrefix)).toList()) {
      await prefs.remove(k);
    }
  }

  /// Eski sürümlerde öneksiz tutulan verileri, ilk giriş yapan kullanıcıya taşır.
  static Future<void> migrateLegacyData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final base in dataKeys) {
      final legacy = prefs.getString(base);
      if (legacy == null) continue;
      if (!prefs.containsKey(key(base))) {
        await prefs.setString(key(base), legacy);
      }
      await prefs.remove(base);
    }
  }
}
