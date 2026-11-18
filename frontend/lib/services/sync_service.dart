import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';

/// Kimlik doğrulamalı istek gönderici (AppState.authedRequest).
typedef AuthedRequest =
    Future<http.Response> Function(String method, String path, {Object? body});

/// Bir eşitleme turunun sonucu.
class SyncOutcome {
  const SyncOutcome({
    this.ok = true,
    this.changedLocal = false,
    this.error,
    this.skipped = false,
  });

  final bool ok;

  /// Sunucudan gelen veri yerel veriyi değiştirdi (arayüzün yenilenmesi gerekir).
  final bool changedLocal;
  final String? error;

  /// Eşitleme kapalı olduğu için hiçbir şey yapılmadı.
  final bool skipped;
}

/// Cihazdaki koleksiyonları sunucuya yedekler ve cihazlar arasında eşitler.
///
/// Her koleksiyon için son bilinen sunucu sürümü ve "kirli" (henüz gönderilmemiş
/// değişiklik) bayrağı saklanır. Çakışmada liste koleksiyonları birleştirilir,
/// nesne koleksiyonlarında yerel (en son düzenleme) kazanır.
class SyncService {
  SyncService({
    required this.request,
    this.debounce = const Duration(seconds: 2),
  });

  final AuthedRequest request;
  final Duration debounce;

  /// Yedeklenen koleksiyonlar (sunucudaki izin listesiyle aynı).
  static const List<String> keys = [
    'activities',
    'routines',
    'sport_plans',
    'finance_transactions',
    'finance_watchlist',
    'notes_v2',
  ];

  Timer? _timer;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  /// Henüz tamamlanmamış "kirli işaretle" işlemleri; flush bunları bekler.
  final Set<Future<void>> _marking = {};

  /// Her eşitleme turu bittiğinde çağrılır (arayüz durumu için).
  void Function(SyncOutcome outcome)? onFinished;

  // ---------- üst veri (kullanıcıya özel) ----------

  static String _meta(String key, String field) =>
      'sync:${UserStore.user}:$key:$field';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('sync:${UserStore.user}:enabled') ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync:${UserStore.user}:enabled', value);
    if (!value) {
      for (final k in keys) {
        await prefs.remove(_meta(k, 'version'));
        await prefs.remove(_meta(k, 'dirty'));
      }
    }
  }

  Future<void> _setDirty(String key, bool dirty) async {
    final prefs = await SharedPreferences.getInstance();
    if (dirty) {
      await prefs.setBool(_meta(key, 'dirty'), true);
    } else {
      await prefs.remove(_meta(key, 'dirty'));
    }
  }

  Future<bool> hasPendingChanges() async {
    final prefs = await SharedPreferences.getInstance();
    return keys.any((k) => prefs.getBool(_meta(k, 'dirty')) ?? false);
  }

  // ---------- değişiklik bildirimi ----------

  /// [UserStore.onWrite] buraya bağlanır: koleksiyonu kirli işaretler ve kısa bir
  /// bekleme sonrası eşitler (art arda yazmalar tek istekte birleşir).
  void markDirty(String key) {
    if (_disposed || !keys.contains(key)) return;
    late final Future<void> task;
    task = () async {
      if (!await isEnabled()) return;
      await _setDirty(key, true);
      if (_disposed) return;
      _timer?.cancel();
      _timer = Timer(debounce, () => unawaited(syncAll()));
    }().whenComplete(() => _marking.remove(task));
    _marking.add(task);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }

  // ---------- eşitleme ----------

  /// Sunucuyla tam eşitleme: önce çek, sonra bekleyen yerel değişiklikleri gönder.
  Future<SyncOutcome> syncAll() async {
    if (_disposed) return const SyncOutcome(skipped: true);
    if (!await isEnabled()) return const SyncOutcome(skipped: true);
    if (_running) {
      _again = true; // çalışan tur bitince bir tur daha
      return const SyncOutcome();
    }
    _running = true;
    var outcome = const SyncOutcome();
    try {
      var changed = false;
      for (var pass = 0; pass < 3; pass++) {
        _again = false;
        final result = await _runOnce();
        changed = changed || result.changedLocal;
        outcome = SyncOutcome(changedLocal: changed);
        if (!_again && !result.retry) break;
      }
    } catch (e) {
      outcome = SyncOutcome(ok: false, error: e.toString());
    } finally {
      _running = false;
    }
    onFinished?.call(outcome);
    return outcome;
  }

  /// Yalnızca bekleyen yerel değişiklikler varsa gönderir (çıkıştan önce).
  Future<void> flush() async {
    // Az önce yapılmış yazmaların "kirli" işareti tamamlansın.
    await Future.wait(_marking.toList());
    if (await hasPendingChanges()) await syncAll();
  }

  Future<_Pass> _runOnce() async {
    final resp = await request('GET', '/sync');
    if (resp.statusCode != 200) {
      throw Exception('Eşitleme başarısız (${resp.statusCode}).');
    }
    final docs =
        ((jsonDecode(utf8.decode(resp.bodyBytes))
                as Map<String, dynamic>)['documents']
            as Map<String, dynamic>? ??
        {});

    final prefs = await SharedPreferences.getInstance();
    var changed = false;
    var retry = false;

    for (final key in keys) {
      final local = await UserStore.getString(key);
      final server = docs[key] as Map<String, dynamic>?;
      final knownVersion = prefs.getInt(_meta(key, 'version'));
      final dirty = prefs.getBool(_meta(key, 'dirty')) ?? false;
      final serverVersion = server?['version'] as int?;

      if (server == null) {
        // Sunucuda yok: yerelde veri varsa ilk yedeği gönder.
        if (local != null && _hasContent(local)) {
          retry = await _push(key, local, baseVersion: null) || retry;
        }
        continue;
      }

      final serverData = server['data'] as String;

      if (knownVersion == null) {
        // Bu cihaz bu koleksiyonu daha önce eşitlemedi.
        if (local == null || !_hasContent(local)) {
          await _writeLocal(key, serverData, serverVersion!);
          changed = true;
        } else {
          final merged = _merge(local, serverData, preferLocal: false);
          if (merged != serverData) {
            await _writeLocal(key, merged, serverVersion!);
            changed = changed || merged != local;
            retry =
                await _push(key, merged, baseVersion: serverVersion) || retry;
          } else {
            await _writeLocal(key, merged, serverVersion!);
            changed = changed || merged != local;
          }
        }
      } else if (serverVersion! > knownVersion) {
        if (dirty && local != null) {
          // İki taraf da değişti: birleştir, yerel düzenleme öncelikli.
          final merged = _merge(local, serverData, preferLocal: true);
          await _writeLocal(key, merged, serverVersion);
          changed = changed || merged != local;
          retry = await _push(key, merged, baseVersion: serverVersion) || retry;
        } else {
          await _writeLocal(key, serverData, serverVersion);
          changed = true;
        }
      } else if (dirty && local != null) {
        retry = await _push(key, local, baseVersion: knownVersion) || retry;
      }
    }
    return _Pass(changedLocal: changed, retry: retry);
  }

  static bool _hasContent(String json) {
    try {
      final v = jsonDecode(json);
      if (v is List) return v.isNotEmpty;
      if (v is Map) return v.isNotEmpty;
    } catch (_) {}
    return false;
  }

  /// Çekilen veriyi, değişiklik bildirimi tetiklemeden yerele yazar.
  Future<void> _writeLocal(String key, String data, int version) async {
    await UserStore.setString(key, data, notify: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_meta(key, 'version'), version);
    await _setDirty(key, false);
  }

  /// Gönderir. Sürüm çakışması (409) olursa `true` döner: tur yeniden çalıştırılmalı.
  Future<bool> _push(
    String key,
    String data, {
    required int? baseVersion,
  }) async {
    final resp = await request(
      'PUT',
      '/sync/$key',
      body: {'data': data, 'base_version': baseVersion},
    );
    if (resp.statusCode == 200) {
      final version =
          (jsonDecode(utf8.decode(resp.bodyBytes))
                  as Map<String, dynamic>)['version']
              as int;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_meta(key, 'version'), version);
      await _setDirty(key, false);
      return false;
    }
    if (resp.statusCode == 409) return true;
    throw Exception('Yedekleme başarısız (${resp.statusCode}).');
  }

  /// İki sürümü birleştirir. Listeler: sunucu sırası + yalnızca yerelde olanlar.
  /// Nesneler: [preferLocal] ise yerel, değilse sunucu kazanır.
  static String _merge(
    String local,
    String server, {
    required bool preferLocal,
  }) {
    try {
      final l = jsonDecode(local);
      final s = jsonDecode(server);
      if (l is List && s is List) {
        final seen = s.map(jsonEncode).toSet();
        final merged = [...s, ...l.where((e) => !seen.contains(jsonEncode(e)))];
        return jsonEncode(merged);
      }
    } catch (_) {}
    return preferLocal ? local : server;
  }

  /// Sunucudaki tüm yedekleri siler.
  Future<void> deleteRemote() async {
    final resp = await request('DELETE', '/sync');
    if (resp.statusCode != 204) {
      throw Exception('Yedek silinemedi (${resp.statusCode}).');
    }
  }
}

class _Pass {
  const _Pass({required this.changedLocal, required this.retry});
  final bool changedLocal;
  final bool retry;
}
