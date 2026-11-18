// Gerçek bir backend'e karşı uçtan uca test. Varsayılan olarak atlanır.
//
// Çalıştırmak için (backend 8001'de, ACCESS_TOKEN_EXPIRE_MINUTES=0 ile çalışmalı):
//   flutter test test/live_backend_e2e_test.dart \
//     --dart-define=E2E=true --dart-define=API_BASE_URL=http://127.0.0.1:8001
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'support/fakes.dart';
import 'package:smart_assistant/services/user_store.dart';

const _e2e = bool.fromEnvironment('E2E');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = null; // gerçek ağ isteklerine izin ver
    SharedPreferences.setMockInitialValues({});
    UserStore.setUser(null);
  });

  test(
    'iki cihaz: kayıt, giriş, eşitleme, sessiz token yenileme, şifre değişimi, hesap silme',
    () async {
      final email = 'e2e${DateTime.now().millisecondsSinceEpoch}@example.com';
      const password = 'password123';

      // ---- Cihaz A: kayıt + giriş + veri
      final a = AppState(sessionStorage: MemorySessionStorage());
      expect(await a.register(email, password), isTrue);
      expect(await a.login(email, password), isTrue);
      await UserStore.setString(
        'notes_v2',
        jsonEncode([
          {'title': 'cihaz A notu', 'body': 'merhaba'},
        ]),
      );
      await UserStore.setString(
        'finance_transactions',
        jsonEncode([
          {
            'type': 'gelir',
            'amount': 100,
            'title': 'Maaş',
            'date': '2026-01-01',
          },
        ]),
      );
      await a.logout(); // bekleyenleri gönderir

      // ---- Cihaz B: temiz depolama, aynı hesap
      SharedPreferences.setMockInitialValues({});
      UserStore.setUser(null);
      final b = AppState(sessionStorage: MemorySessionStorage());
      expect(await b.login(email, password), isTrue);
      final notes =
          jsonDecode((await UserStore.getString('notes_v2'))!) as List;
      expect(notes.single['title'], 'cihaz A notu');
      final tx =
          jsonDecode((await UserStore.getString('finance_transactions'))!)
              as List;
      expect(tx.single['title'], 'Maaş');
      expect(b.lastSyncError, isNull);

      // ---- Erişim token'ı 0 dakikada sona erer: istek sessizce yenilenir
      await Future<void>.delayed(const Duration(seconds: 2));
      final me = await b.authedRequest('GET', '/auth/me');
      expect(me.statusCode, 200);
      expect(b.isLoggedIn, isTrue);

      // ---- B değiştirir, A (yeni oturum) çeker
      await UserStore.setString(
        'notes_v2',
        jsonEncode([
          {'title': 'cihaz A notu', 'body': 'merhaba'},
          {'title': 'cihaz B notu', 'body': ''},
        ]),
      );
      await b.syncNow();
      await b.logout();

      SharedPreferences.setMockInitialValues({});
      UserStore.setUser(null);
      final a2 = AppState(sessionStorage: MemorySessionStorage());
      expect(await a2.login(email, password), isTrue);
      final merged =
          jsonDecode((await UserStore.getString('notes_v2'))!) as List;
      expect(
        merged.map((e) => e['title']),
        containsAll(['cihaz A notu', 'cihaz B notu']),
      );

      // ---- Şifre değiştir: bu cihaz oturumda kalır, eski şifre geçmez
      await a2.changePassword(password, 'new-password99');
      expect(a2.isLoggedIn, isTrue);
      await a2.logout();
      final bad = AppState(sessionStorage: MemorySessionStorage());
      expect(await bad.login(email, password), isFalse);
      final relogin = AppState(sessionStorage: MemorySessionStorage());
      expect(await relogin.login(email, 'new-password99'), isTrue);

      // ---- Yedeği sil + hesabı sil
      await relogin.setSyncEnabled(false, deleteRemote: true);
      await relogin.deleteAccount();
      expect(relogin.isLoggedIn, isFalse);
      final gone = AppState(sessionStorage: MemorySessionStorage());
      expect(await gone.login(email, 'new-password99'), isFalse);
    },
    skip: !_e2e ? 'E2E=true ve çalışan bir backend gerekir' : false,
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
