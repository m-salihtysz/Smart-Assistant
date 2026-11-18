import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'support/fakes.dart';
import 'package:smart_assistant/services/sync_service.dart';
import 'package:smart_assistant/services/user_store.dart';
import 'package:smart_assistant/theme/app_theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Sunucudaki /sync davranışını taklit eder (sürüm numarası + 409 çakışma).
class FakeSyncServer {
  final Map<String, ({String data, int version})> docs = {};
  int puts = 0;
  int gets = 0;
  int deletes = 0;
  bool offline = false;

  /// Bir sonraki PUT'tan önce başka bir cihaz aynı belgeyi yazmış gibi davran.
  String? raceKey;
  String? raceData;

  void seed(String key, Object data, {int version = 1}) =>
      docs[key] = (data: jsonEncode(data), version: version);

  Object? read(String key) =>
      docs[key] == null ? null : jsonDecode(docs[key]!.data);

  Future<http.Response> request(
    String method,
    String path, {
    Object? body,
  }) async {
    if (offline) throw http.ClientException('offline');
    if (method == 'GET' && path == '/sync') {
      gets++;
      return _json({
        'documents': {
          for (final e in docs.entries)
            e.key: {
              'key': e.key,
              'version': e.value.version,
              'data': e.value.data,
              'updated_at': '2026-01-01T00:00:00',
            },
        },
      });
    }
    if (method == 'DELETE' && path == '/sync') {
      deletes++;
      docs.clear();
      return http.Response('', 204);
    }
    if (method == 'PUT' && path.startsWith('/sync/')) {
      final key = path.substring('/sync/'.length);
      if (raceKey == key) {
        final cur = docs[key];
        docs[key] = (data: raceData!, version: (cur?.version ?? 0) + 1);
        raceKey = null;
      }
      puts++;
      final b = body as Map<String, dynamic>;
      final cur = docs[key];
      final base = b['base_version'] as int?;
      if (cur != null && base != null && base != cur.version) {
        return _json({
          'detail': {'server_version': cur.version},
        }, 409);
      }
      final version = (cur?.version ?? 0) + 1;
      docs[key] = (data: b['data'] as String, version: version);
      return _json({'key': key, 'version': version, 'updated_at': 'x'});
    }
    return _json({}, 404);
  }

  /// AppState testleri için http.Request üzerinden.
  Future<http.Response> http_(http.Request r) async {
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    return request(r.method, r.url.path, body: body);
  }
}

void main() {
  late FakeSyncServer server;
  late SyncService sync;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserStore.setUser('a@example.com');
    UserStore.onWrite = null;
    server = FakeSyncServer();
    sync = SyncService(
      request: server.request,
      debounce: const Duration(milliseconds: 20),
    );
  });

  tearDown(() {
    sync.dispose();
    UserStore.onWrite = null;
  });

  Future<Object?> local(String key) async {
    final raw = await UserStore.getString(key);
    return raw == null ? null : jsonDecode(raw);
  }

  test('sunucuda yoksa yerel veri ilk yedek olarak gönderilir', () async {
    await UserStore.setString(
      'notes_v2',
      jsonEncode([
        {'title': 'a'},
      ]),
      notify: false,
    );

    final out = await sync.syncAll();
    expect(out.ok, isTrue);
    expect(server.read('notes_v2'), [
      {'title': 'a'},
    ]);
    expect(server.docs['notes_v2']!.version, 1);
    expect(server.puts, 1);

    // ikinci tur: değişiklik yok, tekrar gönderme
    await sync.syncAll();
    expect(server.puts, 1);
  });

  test(
    'boş/olmayan yerel veri için sunucuya gereksiz yazma yapılmaz',
    () async {
      await sync.syncAll();
      expect(server.puts, 0);
      await UserStore.setString('notes_v2', '[]', notify: false);
      await sync.syncAll();
      expect(server.puts, 0);
    },
  );

  test(
    'yeni cihaz sunucudaki veriyi çeker ve bunu "değişiklik" saymaz',
    () async {
      server.seed('activities', [
        {'title': 'Dişçi'},
      ], version: 3);
      var notified = 0;
      UserStore.onWrite = (_) => notified++;

      final out = await sync.syncAll();
      expect(out.changedLocal, isTrue);
      expect(await local('activities'), [
        {'title': 'Dişçi'},
      ]);
      expect(notified, 0, reason: 'çekilen veri tekrar yedeğe gönderilmemeli');
      expect(server.puts, 0);
    },
  );

  test('yerel değişiklik (kirli) bilinen sürümle gönderilir', () async {
    server.seed('notes_v2', [
      {'title': 'eski'},
    ]);
    await sync.syncAll(); // sürüm 1 öğrenildi

    sync.markDirty('notes_v2');
    await UserStore.setString(
      'notes_v2',
      jsonEncode([
        {'title': 'yeni'},
      ]),
      notify: false,
    );
    await sync.syncAll();

    expect(server.read('notes_v2'), [
      {'title': 'yeni'},
    ]);
    expect(server.docs['notes_v2']!.version, 2);
  });

  test(
    'sunucu daha yeniyse ve yerelde değişiklik yoksa sunucu verisi alınır',
    () async {
      server.seed('routines', {'0': []});
      await sync.syncAll();
      server.seed('routines', {
        '0': [
          {'title': 'Yürüyüş'},
        ],
      }, version: 2);

      final out = await sync.syncAll();
      expect(out.changedLocal, isTrue);
      expect((await local('routines') as Map)['0'], hasLength(1));
    },
  );

  test('iki cihaz da liste düzenlediyse kayıtlar birleştirilir', () async {
    server.seed('finance_transactions', [
      {'title': 'ortak'},
    ]);
    await sync.syncAll();

    // Telefon yerelde ekler, tablet sunucuya ekler
    sync.markDirty('finance_transactions');
    await UserStore.setString(
      'finance_transactions',
      jsonEncode([
        {'title': 'ortak'},
        {'title': 'telefon'},
      ]),
      notify: false,
    );
    server.seed('finance_transactions', [
      {'title': 'ortak'},
      {'title': 'tablet'},
    ], version: 2);

    await sync.syncAll();
    final titles = (server.read('finance_transactions') as List)
        .map((e) => e['title'])
        .toSet();
    expect(titles, {'ortak', 'telefon', 'tablet'});
    expect((await local('finance_transactions') as List).length, 3);
    expect(server.docs['finance_transactions']!.version, 3);
  });

  test(
    'iki cihaz da nesne düzenlediyse yerel (son düzenleme) kazanır',
    () async {
      server.seed('sport_plans', {'0': 'eski'});
      await sync.syncAll();
      sync.markDirty('sport_plans');
      await UserStore.setString(
        'sport_plans',
        jsonEncode({'0': 'telefon'}),
        notify: false,
      );
      server.seed('sport_plans', {'0': 'tablet'}, version: 2);

      await sync.syncAll();
      expect(server.read('sport_plans'), {'0': 'telefon'});
    },
  );

  test(
    'bu cihaz hiç eşitlenmediyse yerel ve sunucu listeleri birleştirilir (veri kaybı yok)',
    () async {
      await UserStore.setString(
        'notes_v2',
        jsonEncode([
          {'title': 'yerel'},
        ]),
        notify: false,
      );
      server.seed('notes_v2', [
        {'title': 'sunucu'},
      ], version: 4);

      await sync.syncAll();
      final titles = (server.read('notes_v2') as List)
          .map((e) => e['title'])
          .toList();
      expect(titles, containsAll(['yerel', 'sunucu']));
      expect((await local('notes_v2') as List).length, 2);
    },
  );

  test(
    'gönderirken araya başka cihaz girerse (409) tur yeniden çalışır ve veri korunur',
    () async {
      server.seed('notes_v2', [
        {'title': 'a'},
      ]);
      await sync.syncAll();

      sync.markDirty('notes_v2');
      await UserStore.setString(
        'notes_v2',
        jsonEncode([
          {'title': 'a'},
          {'title': 'yerel-yeni'},
        ]),
        notify: false,
      );
      server
        ..raceKey = 'notes_v2'
        ..raceData = jsonEncode([
          {'title': 'a'},
          {'title': 'diger-cihaz'},
        ]);

      final out = await sync.syncAll();
      expect(out.ok, isTrue);
      final titles = (server.read('notes_v2') as List)
          .map((e) => e['title'])
          .toSet();
      expect(titles, {'a', 'yerel-yeni', 'diger-cihaz'});
    },
  );

  test('eşitleme kapalıyken hiçbir istek yapılmaz', () async {
    await SyncService.setEnabled(false);
    sync.markDirty('notes_v2');
    final out = await sync.syncAll();
    expect(out.skipped, isTrue);
    expect(server.gets + server.puts, 0);
  });

  test(
    'ağ hatasında değişiklik kaybolmaz, bağlantı gelince gönderilir',
    () async {
      await UserStore.setString(
        'notes_v2',
        jsonEncode([
          {'title': 'x'},
        ]),
        notify: false,
      );
      sync.markDirty('notes_v2');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      server.offline = true;
      final failed = await sync.syncAll();
      expect(failed.ok, isFalse);
      expect(await sync.hasPendingChanges(), isTrue);

      server.offline = false;
      final ok = await sync.syncAll();
      expect(ok.ok, isTrue);
      expect(server.read('notes_v2'), [
        {'title': 'x'},
      ]);
      expect(await sync.hasPendingChanges(), isFalse);
    },
  );

  test(
    'UserStore yazmaları kısa beklemeden sonra tek istekte gönderilir',
    () async {
      UserStore.onWrite = sync.markDirty;
      await UserStore.setString('notes_v2', jsonEncode([1]));
      await UserStore.setString('notes_v2', jsonEncode([1, 2]));
      await UserStore.setString('notes_v2', jsonEncode([1, 2, 3]));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(server.puts, 1);
      expect(server.read('notes_v2'), [1, 2, 3]);
    },
  );

  test('eşitlenmeyen anahtarlar (sohbet, izin) yedeğe gitmez', () async {
    UserStore.onWrite = sync.markDirty;
    await UserStore.setString('assistant_messages', '[1]');
    await UserStore.setString('ai_consent', 'granted');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.puts, 0);
  });

  test('üst veri kullanıcıya özeldir', () async {
    server.seed('notes_v2', [
      {'title': 'a'},
    ], version: 5);
    await sync.syncAll();

    UserStore.setUser('b@example.com');
    // b kullanıcısı bu koleksiyonu hiç eşitlememiş sayılır, yerel verisi boş
    expect(await local('notes_v2'), isNull);
    await sync.syncAll();
    expect(await local('notes_v2'), [
      {'title': 'a'},
    ]);
  });

  test('deleteRemote sunucudaki tüm yedekleri siler', () async {
    server.seed('notes_v2', []);
    server.seed('routines', {});
    await sync.deleteRemote();
    expect(server.docs, isEmpty);
    expect(server.deletes, 1);
  });

  // ---------------- AppState entegrasyonu ----------------

  Future<AppState> login(
    FakeSyncServer srv, {
    MemorySessionStorage? storage,
  }) async {
    final state = AppState(
      client: MockClient((r) async {
        if (r.url.path == '/auth/login') {
          return _json({'access_token': 't', 'refresh_token': 'r'});
        }
        if (r.url.path == '/auth/me') {
          return _json({
            'id': 1,
            'email': 'a@example.com',
            'name': 'Ali',
            'birth_date': '1999-05-01',
            'created_at': '2026-01-01T00:00:00',
          });
        }
        if (r.url.path == '/auth/logout') return http.Response('', 204);
        if (r.url.path == '/auth/me' && r.method == 'DELETE') {
          return http.Response('', 204);
        }
        if (r.url.path.startsWith('/sync')) return srv.http_(r);
        return _json({}, 404);
      }),
      sessionStorage: storage ?? MemorySessionStorage(),
    );
    await state.login('a@example.com', 'password123');
    return state;
  }

  test(
    'giriş sunucudaki yedeği yerele çeker ve ekranları yenilemek için revizyonu artırır',
    () async {
      server.seed('notes_v2', [
        {'title': 'başka cihazdan'},
      ]);
      final state = await login(server);
      expect(await local('notes_v2'), [
        {'title': 'başka cihazdan'},
      ]);
      expect(state.lastSyncAt, isNotNull);
      expect(state.dataRevision, greaterThan(0));
      await state.logout(flush: false);
    },
  );

  test('yerel yazma, oturum açıkken sunucuya yedeklenir', () async {
    final state = await login(server);
    await UserStore.setString(
      'notes_v2',
      jsonEncode([
        {'title': 'yeni'},
      ]),
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(server.read('notes_v2'), [
      {'title': 'yeni'},
    ]);
    await state.logout(flush: false);
  });

  test('çıkış yaparken bekleyen değişiklikler önce gönderilir', () async {
    final state = await login(server);
    await UserStore.setString(
      'notes_v2',
      jsonEncode([
        {'title': 'son dakika'},
      ]),
    );
    // debounce (2 sn) dolmadan çık
    await state.logout();
    expect(server.read('notes_v2'), [
      {'title': 'son dakika'},
    ]);
    // çıkıştan sonra yazma artık yedeklenmez
    UserStore.setUser('a@example.com');
    final before = server.puts;
    await UserStore.setString('notes_v2', jsonEncode([1]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.puts, before);
  });

  test(
    'yedekleme kapatılıp sunucu kopyası silinebilir; kapalıyken yazmalar gönderilmez',
    () async {
      server.seed('notes_v2', [
        {'title': 'a'},
      ]);
      final state = await login(server);
      await state.setSyncEnabled(false, deleteRemote: true);
      expect(server.docs, isEmpty);
      expect(state.syncEnabled, isFalse);

      final puts = server.puts;
      await UserStore.setString('notes_v2', jsonEncode([1]));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(server.puts, puts);

      // tekrar açınca eşitler
      await state.setSyncEnabled(true);
      expect(server.read('notes_v2'), [1]);
      await state.logout(flush: false);
    },
  );

  test('sunucuya ulaşılamasa da giriş çalışır (çevrimdışı)', () async {
    server.offline = true;
    final state = await login(server);
    expect(state.isLoggedIn, isTrue);
    expect(state.lastSyncError, isNotNull);
    await state.logout(flush: false);
  });

  // ---------------- Ayarlar arayüzü ----------------

  Widget app(AppState state) => ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const Scaffold(body: SettingsScreen()),
    ),
  );

  testWidgets(
    'Ayarlar: yedekleme anahtarı kapatılırken sunucu kopyası silinebilir',
    (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      server.seed('notes_v2', [
        {'title': 'a'},
      ]);
      final state = await login(server);
      await tester.pumpWidget(app(state));
      await tester.pump(const Duration(milliseconds: 300));

      final tile = find.widgetWithText(SwitchListTile, 'Bulut yedekleme');
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      expect(find.textContaining('Son eşitleme:'), findsOneWidget);

      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('Bulut yedeklemeyi kapat'), findsOneWidget);
      await tester.tap(find.text('Yedeği sil'));
      await tester.pumpAndSettle();

      expect(server.docs, isEmpty);
      expect(state.syncEnabled, isFalse);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
      await state.logout(flush: false);
    },
  );

  testWidgets('Ayarlar: "Vazgeç" yedeklemeyi açık bırakır', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = await login(server);
    await tester.pumpWidget(app(state));
    await tester.pump(const Duration(milliseconds: 300));
    final tile = find.widgetWithText(SwitchListTile, 'Bulut yedekleme');
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(state.syncEnabled, isTrue);
    await state.logout(flush: false);
  });
}
