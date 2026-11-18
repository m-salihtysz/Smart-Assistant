import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'support/fakes.dart';
import 'package:smart_assistant/services/user_store.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _me({String? name, String? birth}) => {
  'id': 1,
  'email': 'a@example.com',
  'name': name,
  'birth_date': birth,
  'created_at': '2026-01-01T00:00:00',
};

void main() {
  late MemorySessionStorage session;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserStore.setUser(null);
    session = MemorySessionStorage();
  });

  AppState build(MockClientHandler handler) =>
      AppState(client: MockClient(handler), sessionStorage: session);

  test(
    'login başarılı: token saklanır, kullanıcı ve veri kapsamı ayarlanır',
    () async {
      final state = build((req) async {
        if (req.url.path == '/auth/login') {
          return _json({'access_token': 'tok', 'token_type': 'bearer'});
        }
        if (req.url.path == '/auth/me') {
          expect(req.headers['Authorization'], 'Bearer tok');
          return _json(_me(name: 'Ali', birth: '1999-05-01'));
        }
        return _json({}, 404);
      });

      expect(await state.login('A@Example.com ', 'password123'), isTrue);
      expect(state.isLoggedIn, isTrue);
      expect(state.currentUser!.isNew, isFalse);
      expect(await session.readToken(), 'tok');
      expect(UserStore.user, 'a@example.com');
    },
  );

  test(
    'login: yanlış şifre false, 429 hata mesajı, ağ hatası anlaşılır mesaj',
    () async {
      var status = 401;
      final state = build((req) async {
        if (status == -1) throw http.ClientException('ağ yok');
        return _json({
          'detail': status == 429 ? 'Çok fazla deneme.' : 'hatalı',
        }, status);
      });
      expect(await state.login('a@example.com', 'x'), isFalse);
      expect(state.isLoggedIn, isFalse);

      status = 429;
      await expectLater(
        state.login('a@example.com', 'x'),
        throwsA(predicate((e) => e.toString().contains('Çok fazla'))),
      );

      status = -1;
      await expectLater(
        state.login('a@example.com', 'x'),
        throwsA(predicate((e) => e.toString().contains('ulaşılamadı'))),
      );
    },
  );

  test('restoreSession: geçerli token oturumu geri getirir', () async {
    session.token = 'tok';
    final state = build(
      (req) async => _json(_me(name: 'Ali', birth: '1999-05-01')),
    );
    await state.restoreSession();
    expect(state.isRestoring, isFalse);
    expect(state.currentUser?.email, 'a@example.com');
  });

  test('restoreSession: süresi dolmuş token (401) temizlenir', () async {
    session.token = 'eski';
    final state = build((req) async => _json({'detail': 'Geçersiz'}, 401));
    await state.restoreSession();
    expect(state.isLoggedIn, isFalse);
    expect(session.token, isNull);
  });

  test('restoreSession: sunucuya ulaşılamazsa token korunur', () async {
    session.token = 'tok';
    final state = build((req) async => throw http.ClientException('offline'));
    await state.restoreSession();
    expect(state.isLoggedIn, isFalse);
    expect(state.isRestoring, isFalse);
    expect(session.token, 'tok');
  });

  test('tema modu kalıcıdır ve açılışta geri yüklenir', () async {
    final state = build((req) async => _json({}, 401));
    expect(state.themeMode, ThemeMode.light);
    await state.setThemeMode(ThemeMode.dark);
    expect(state.themeMode, ThemeMode.dark);

    final next = build((req) async => _json({}, 401));
    await next.restoreSession();
    expect(next.themeMode, ThemeMode.dark);
  });

  test('restoreSession: kayıtlı dil geri yüklenir', () async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final state = build((req) async => _json({}, 401));
    await state.restoreSession();
    expect(state.locale.languageCode, 'en');
  });

  Future<AppState> loggedIn(MockClientHandler extra) async {
    final state = build((req) async {
      if (req.url.path == '/auth/login') return _json({'access_token': 'tok'});
      if (req.url.path == '/auth/me' && req.method == 'GET') {
        return _json(_me());
      }
      if (req.url.path == '/sync') return _json({'documents': {}});
      return extra(req);
    });
    await state.login('a@example.com', 'password123');
    return state;
  }

  test(
    '401 alan istek oturumu kapatır ve SessionExpiredException fırlatır',
    () async {
      final state = await loggedIn(
        (req) async => _json({'detail': 'expired'}, 401),
      );
      await expectLater(
        state.authedRequest('POST', '/assistant/chat', body: {'message': 'x'}),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(state.isLoggedIn, isFalse);
      expect(session.token, isNull);
      expect(UserStore.user, isNull);
    },
  );

  test(
    'updateProfile: sunucu hatasında exception, başarıda profil güncellenir',
    () async {
      var ok = false;
      final state = await loggedIn((req) async {
        if (!ok) return _json({'detail': 'x'}, 500);
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['birth_date'], '1999-05-01');
        return _json(_me(name: body['name'] as String, birth: '1999-05-01'));
      });

      await expectLater(
        state.updateProfile(name: 'Ali', birthDate: DateTime(1999, 5, 1)),
        throwsException,
      );
      expect(state.currentUser!.name, isNull);

      ok = true;
      await state.updateProfile(name: 'Ali', birthDate: DateTime(1999, 5, 1));
      expect(state.currentUser!.name, 'Ali');
      expect(state.currentUser!.isNew, isFalse);
    },
  );

  test(
    'deleteAccount: sunucuda siler, yerel veriyi temizler ve çıkış yapar',
    () async {
      final state = await loggedIn((req) async {
        expect(req.method, 'DELETE');
        return http.Response('', 204);
      });
      await UserStore.writeJson('notes_v2', [
        {'title': 'x'},
      ]);

      await state.deleteAccount();
      expect(state.isLoggedIn, isFalse);
      expect(session.token, isNull);

      UserStore.setUser('a@example.com');
      expect(await UserStore.readList('notes_v2'), isEmpty);
    },
  );

  test('logout sonrası başka kullanıcı eski verileri görmez', () async {
    final state = await loggedIn((req) async => _json({}));
    await UserStore.writeJson('notes_v2', [
      {'title': 'a'},
    ]);
    await state.logout();
    UserStore.setUser('b@example.com');
    expect(await UserStore.readList('notes_v2'), isEmpty);
  });
}
