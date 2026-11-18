import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'support/fakes.dart';
import 'package:smart_assistant/services/user_store.dart';
import 'package:smart_assistant/theme/app_theme.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

const _me = {
  'id': 1,
  'email': 'a@example.com',
  'name': 'Ali',
  'birth_date': '1999-05-01',
  'created_at': '2026-01-01T00:00:00',
  'email_verified': true,
};

/// Basit sahte sunucu: hangi erişim token'ı geçerli, refresh token ne döndürür vb. test başına ayarlanır.
class FakeServer {
  String validAccess = 'access-1';
  String validRefresh = 'refresh-1';
  int refreshCalls = 0;
  bool refreshWorks = true;
  final List<String> paths = [];
  final List<String> logoutBodies = [];
  int _n = 1;

  Future<http.Response> handle(http.Request r) async {
    paths.add('${r.method} ${r.url.path}');
    switch (r.url.path) {
      case '/auth/login':
        final form = Uri.splitQueryString(r.body);
        if (form['password'] == 'unverified') {
          return _json({'detail': 'email_not_verified'}, 403);
        }
        if (form['password'] != 'password123' &&
            form['password'] != 'new-password1') {
          return _json({'detail': 'hatalı'}, 401);
        }
        return _json({
          'access_token': validAccess,
          'refresh_token': validRefresh,
          'token_type': 'bearer',
        });
      case '/auth/refresh':
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (!refreshWorks ||
            jsonDecode(r.body)['refresh_token'] != validRefresh) {
          return _json({'detail': 'Oturum süresi doldu.'}, 401);
        }
        _n++;
        validAccess = 'access-$_n';
        validRefresh = 'refresh-$_n';
        return _json({
          'access_token': validAccess,
          'refresh_token': validRefresh,
        });
      case '/auth/logout':
        logoutBodies.add(r.body);
        return http.Response('', 204);
      case '/auth/register':
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        return _json({
          ..._me,
          'email': body['email'],
          'email_verified': !(body['email'] as String).startsWith('strict'),
        }, 201);
      case '/auth/change-password':
        if (r.headers['Authorization'] != 'Bearer $validAccess') {
          return _json({'detail': 'x'}, 401);
        }
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        if (body['current_password'] != 'password123') {
          return _json({'detail': 'Mevcut şifre hatalı.'}, 400);
        }
        _n++;
        validAccess = 'access-$_n';
        validRefresh = 'refresh-$_n';
        return http.Response('', 204);
      case '/auth/forgot-password':
      case '/auth/resend-verification':
        return http.Response('', 204);
      case '/auth/reset-password':
      case '/auth/verify-email':
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        return body['code'] == '123456'
            ? http.Response('', 204)
            : _json({'detail': 'Kod geçersiz veya süresi dolmuş.'}, 400);
      case '/auth/me':
        return r.headers['Authorization'] == 'Bearer $validAccess'
            ? _json(_me)
            : _json({'detail': 'expired'}, 401);
      case '/sync':
        return _json({'documents': {}});
      case '/assistant/history':
        return r.headers['Authorization'] == 'Bearer $validAccess'
            ? http.Response('', 204)
            : _json({'detail': 'expired'}, 401);
    }
    return _json({}, 404);
  }
}

void main() {
  late FakeServer server;
  late MemorySessionStorage session;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserStore.setUser(null);
    server = FakeServer();
    session = MemorySessionStorage();
  });

  AppState build() =>
      AppState(client: MockClient(server.handle), sessionStorage: session);

  test('login hem erişim hem yenileme token\'ını saklar', () async {
    final state = build();
    expect(await state.login('a@example.com', 'password123'), isTrue);
    expect(session.token, 'access-1');
    expect(session.refreshToken, 'refresh-1');
  });

  test(
    'süresi dolan erişim token\'ı sessizce yenilenir ve istek tekrar denenir',
    () async {
      final state = build();
      await state.login('a@example.com', 'password123');

      server.validAccess = 'rotated-on-server'; // eski token artık geçersiz
      final resp = await state.authedRequest('DELETE', '/assistant/history');
      // Yenileme sonrası sunucu access-2 verdi ve istek onunla başarılı oldu
      expect(resp.statusCode, 204);
      expect(server.refreshCalls, 1);
      expect(session.token, 'access-2');
      expect(session.refreshToken, 'refresh-2');
      expect(state.isLoggedIn, isTrue);
    },
  );

  test('eşzamanlı 401\'ler tek bir yenileme isteğinde birleşir', () async {
    final state = build();
    await state.login('a@example.com', 'password123');
    server.validAccess = 'rotated-on-server';

    final results = await Future.wait([
      state.authedRequest('DELETE', '/assistant/history'),
      state.authedRequest('DELETE', '/assistant/history'),
      state.authedRequest('DELETE', '/assistant/history'),
    ]);
    expect(results.map((r) => r.statusCode), everyElement(204));
    expect(server.refreshCalls, 1);
  });

  test('yenileme başarısızsa oturum kapanır', () async {
    final state = build();
    await state.login('a@example.com', 'password123');
    server.validAccess = 'rotated-on-server';
    server.refreshWorks = false;

    await expectLater(
      state.authedRequest('DELETE', '/assistant/history'),
      throwsA(isA<SessionExpiredException>()),
    );
    expect(state.isLoggedIn, isFalse);
    expect(session.token, isNull);
    expect(session.refreshToken, isNull);
  });

  test(
    'açılışta süresi dolmuş erişim token\'ı yenilenir, kullanıcı giriş yapmış kalır',
    () async {
      session
        ..token = 'expired-access'
        ..refreshToken = 'refresh-1';
      final state = build();
      await state.restoreSession();
      expect(state.isLoggedIn, isTrue);
      expect(server.refreshCalls, 1);
      expect(session.token, 'access-2');
    },
  );

  test('açılışta yenileme de geçersizse token\'lar temizlenir', () async {
    session
      ..token = 'expired-access'
      ..refreshToken = 'revoked-refresh';
    final state = build();
    await state.restoreSession();
    expect(state.isLoggedIn, isFalse);
    expect(session.token, isNull);
    expect(session.refreshToken, isNull);
  });

  test('çıkış yapınca sunucuda refresh token iptal edilir', () async {
    final state = build();
    await state.login('a@example.com', 'password123');
    await state.logout();
    expect(server.logoutBodies, hasLength(1));
    expect(
      jsonDecode(server.logoutBodies.single)['refresh_token'],
      'refresh-1',
    );
    expect(session.refreshToken, isNull);
  });

  test('doğrulanmamış hesapla giriş EmailNotVerifiedException verir', () async {
    final state = build();
    await expectLater(
      state.login('a@example.com', 'unverified'),
      throwsA(isA<EmailNotVerifiedException>()),
    );
    expect(state.isLoggedIn, isFalse);
  });

  test('register doğrulama gerekip gerekmediğini döndürür', () async {
    final state = build();
    expect(await state.register('ok@example.com', 'password123'), isTrue);
    expect(await state.register('strict@example.com', 'password123'), isFalse);
  });

  test('şifre değişince bu cihaz yeni şifreyle yeniden giriş yapar', () async {
    final state = build();
    await state.login('a@example.com', 'password123');
    final before = session.refreshToken;

    await state.changePassword('password123', 'new-password1');
    expect(state.isLoggedIn, isTrue);
    expect(session.refreshToken, isNot(before));
    expect(session.token, server.validAccess);
  });

  test(
    'yanlış mevcut şifre sunucu mesajıyla hata verir, oturum sürer',
    () async {
      final state = build();
      await state.login('a@example.com', 'password123');
      await expectLater(
        state.changePassword('wrong', 'new-password1'),
        throwsA(predicate((e) => e.toString().contains('Mevcut şifre hatalı'))),
      );
      expect(state.isLoggedIn, isTrue);
    },
  );

  test('forgot/reset/verify hata mesajlarını sunucudan alır', () async {
    final state = build();
    await state.forgotPassword('a@example.com');
    await state.resetPassword('a@example.com', '123456', 'new-password1');
    await state.verifyEmail('a@example.com', '123456');
    await state.resendVerification('a@example.com');
    await expectLater(
      state.resetPassword('a@example.com', '000000', 'new-password1'),
      throwsA(predicate((e) => e.toString().contains('Kod geçersiz'))),
    );
  });

  // ---------------- Ekranlar ----------------

  Widget app(AppState state, Widget home) =>
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(theme: buildAppTheme(Brightness.light), home: home),
      );

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('Şifremi unuttum: kod gönder -> kod + yeni şifre -> sıfırla', (
    tester,
  ) async {
    await phone(tester);
    final state = build();
    await tester.pumpWidget(app(state, const ForgotPasswordScreen()));

    await tester.enterText(find.byType(TextFormField).first, 'a@example.com');
    await tester.tap(find.text('Kod gönder'));
    await tester.pumpAndSettle();
    expect(server.paths, contains('POST /auth/forgot-password'));
    expect(find.text('Şifreyi sıfırla'), findsOneWidget);

    // yanlış kod -> hata gösterilir
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Doğrulama kodu'),
      '000000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Yeni şifre'),
      'new-password1',
    );
    await tester.tap(find.text('Şifreyi sıfırla'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Kod geçersiz'), findsOneWidget);

    // kısa şifre -> doğrulama mesajı
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Yeni şifre'),
      'short',
    );
    await tester.tap(find.text('Şifreyi sıfırla'));
    await tester.pumpAndSettle();
    expect(find.text('Şifre en az 8 karakter olmalı'), findsOneWidget);
  });

  testWidgets(
    'E-posta doğrulama: doğru kodla doğrular ve otomatik giriş yapar',
    (tester) async {
      await phone(tester);
      final state = build();
      await tester.pumpWidget(
        app(
          state,
          VerifyEmailScreen(email: 'a@example.com', password: 'password123'),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();

      expect(
        server.paths,
        containsAllInOrder(['POST /auth/verify-email', 'POST /auth/login']),
      );
      expect(state.isLoggedIn, isTrue);
    },
  );

  testWidgets(
    'E-posta doğrulama: yanlış kod hata gösterir, kod yeniden gönderilebilir',
    (tester) async {
      await phone(tester);
      final state = build();
      await tester.pumpWidget(
        app(
          state,
          VerifyEmailScreen(email: 'a@example.com', password: 'password123'),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '000000');
      await tester.tap(find.text('Doğrula'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kod geçersiz'), findsOneWidget);
      expect(state.isLoggedIn, isFalse);

      await tester.tap(find.text('Kodu tekrar gönder'));
      await tester.pumpAndSettle();
      expect(server.paths, contains('POST /auth/resend-verification'));
      expect(find.text('Yeni kod gönderildi.'), findsOneWidget);
    },
  );

  testWidgets(
    'Karşılama/giriş ekranında "Şifremi unuttum" bağlantısı var ve ekranı açar',
    (tester) async {
      await phone(tester);
      final state = build();
      await tester.pumpWidget(app(state, const WelcomeScreen()));
      await tester.tap(find.text('Şifremi unuttum'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    },
  );

  testWidgets('Giriş: doğrulanmamış hesap doğrulama ekranına yönlendirir', (
    tester,
  ) async {
    await phone(tester);
    final state = build();
    await tester.pumpWidget(app(state, const WelcomeScreen()));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-posta'),
      'a@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifre'),
      'unverified',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await tester.pumpAndSettle();
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
  });

  testWidgets('Kayıt: 8 karakterden kısa şifre reddedilir', (tester) async {
    await phone(tester);
    final state = build();
    await tester.pumpWidget(app(state, const RegisterScreen()));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-posta'),
      'a@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Şifre'),
      'short',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await tester.pumpAndSettle();
    expect(find.text('Şifre en az 8 karakter olmalı'), findsOneWidget);
    expect(server.paths, isNot(contains('POST /auth/register')));
  });

  testWidgets(
    'Ayarlar: şifre değiştirme penceresi açılır ve başarıyla tamamlanır',
    (tester) async {
      await phone(tester);
      final state = build();
      await state.login('a@example.com', 'password123');
      await tester.pumpWidget(
        app(state, const Scaffold(body: SettingsScreen())),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final button = find.text('Şifreyi değiştir');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mevcut şifre'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Yeni şifre'),
        'new-password1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Değiştir'));
      await tester.pumpAndSettle();

      expect(server.paths, contains('POST /auth/change-password'));
      expect(find.text('Şifren değiştirildi.'), findsOneWidget);
      expect(state.isLoggedIn, isTrue);
    },
  );
}
