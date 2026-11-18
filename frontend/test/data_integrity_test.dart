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

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<AppState> _login() async {
  final state = AppState(
    client: MockClient((r) async {
      if (r.url.path == '/auth/login') {
        return http.Response('{"access_token":"t"}', 200);
      }
      if (r.url.path == '/sync') return http.Response('{"documents":{}}', 200);
      return http.Response(
        '{"id":1,"email":"a@x.com","name":"Ali","birth_date":"1999-05-01","created_at":"2026-01-01T00:00:00"}',
        200,
      );
    }),
    sessionStorage: MemorySessionStorage(),
  );
  await state.login('a@x.com', 'password123');
  return state;
}

Widget _app(AppState state, Widget child) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(body: child),
      ),
    );

/// Test yazı tipi (Ahem) geniş olduğundan taşma uyarıları sahte pozitiftir.
void _ignoreOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> phone(WidgetTester tester) async {
    _ignoreOverflow();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'Aktiviteler: saate göre sıralı listede silinen, gerçekten görünen aktivitedir',
    (tester) async {
      await phone(tester);
      final today = _key(DateTime.now());
      // Kayıt sırası: önce 14:00, sonra 09:00. Ekranda 09:00 üstte görünür.
      SharedPreferences.setMockInitialValues({
        'u:a@x.com:activities': jsonEncode([
          {'date': today, 'title': 'Geç', 'hour': 14, 'minute': 0},
          {'date': today, 'title': 'Erken', 'hour': 9, 'minute': 0},
        ]),
      });
      final state = await _login();
      await tester.pumpWidget(_app(state, const ActivitiesTab()));
      await tester.pump(const Duration(milliseconds: 300));

      final titles = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((t) => t == 'Erken' || t == 'Geç')
          .toList();
      expect(titles, [
        'Erken',
        'Geç',
      ], reason: 'liste saate göre sıralı olmalı');

      // İlk satırın (Erken) sil düğmesine bas
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump(const Duration(milliseconds: 300));

      final saved =
          jsonDecode((await UserStore.getString('activities'))!) as List;
      expect(saved.map((e) => e['title']), ['Geç']);
      await state.logout(flush: false);
    },
  );

  testWidgets(
    'Rutinler: bir rutin silinince diğerlerinin "tamamlandı" işaretleri kaymaz',
    (tester) async {
      await phone(tester);
      final now = DateTime.now();
      final today = _key(now);
      final weekday = now.weekday - 1;
      SharedPreferences.setMockInitialValues({
        'u:a@x.com:routines': jsonEncode({
          '$weekday': [
            {'title': 'A', 'hour': 7, 'minute': 0},
            {'title': 'B', 'hour': 8, 'minute': 0},
            {'title': 'C', 'hour': 9, 'minute': 0},
          ],
          // yalnızca C tamamlanmış
          'completions': {
            today: [false, false, true],
          },
        }),
      });
      final state = await _login();
      await tester.pumpWidget(_app(state, const RoutinesTab()));
      await tester.pump(const Duration(milliseconds: 300));

      // A'yı düzenle -> sil
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();

      final data = await UserStore.readMap('routines');
      expect((data['$weekday'] as List).map((r) => r['title']), ['B', 'C']);
      // C hâlâ tamamlanmış olmalı (eskiden B tamamlanmış görünürdü)
      expect(data['completions'][today], [false, true]);
      await state.logout(flush: false);
    },
  );

  testWidgets('Spor: hareket eklenir, düzenlenir ve silinir (ortak pencere)', (
    tester,
  ) async {
    await phone(tester);
    final state = await _login();
    await tester.pumpWidget(_app(state, const SportTab()));
    await tester.pump(const Duration(milliseconds: 300));
    final dayKey = '${DateTime.now().weekday - 1}';

    Future<List> saved() async =>
        ((await UserStore.readMap('sport_plans'))[dayKey]?['exercises']
            as List?) ??
        [];

    // Ekle
    await tester.tap(find.text('Yeni Hareket Ekle'));
    await tester.pumpAndSettle();
    expect(find.text('Hareket ekle'), findsWidgets);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Ekle'));
    await tester.pumpAndSettle();
    var list = await saved();
    expect(list, hasLength(1));
    expect(list.single['reps'], 12);
    expect(list.single['sets'], 3);

    // Geçersiz tekrar sayısı kaydedilmez, pencere açık kalır
    await tester.tap(find.text('Yeni Hareket Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Örn. 12'), '0');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Ekle'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(await saved(), hasLength(1));

    // Düzenle
    await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Hareketi düzenle'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '20');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Kaydet'));
    await tester.pumpAndSettle();
    list = await saved();
    expect(list.single['reps'], 20);

    // Sil
    await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(await saved(), isEmpty);
    await state.logout(flush: false);
  });

  testWidgets('Aktiviteler: bozuk kayıtlar listeyi çökertmez', (tester) async {
    await phone(tester);
    final today = _key(DateTime.now());
    SharedPreferences.setMockInitialValues({
      'u:a@x.com:activities': jsonEncode([
        'bozuk',
        {'title': 'tarihsiz'},
        {'date': today, 'title': 'Sağlam', 'hour': '9', 'minute': 30},
      ]),
    });
    final state = await _login();
    await tester.pumpWidget(_app(state, const ActivitiesTab()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sağlam'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    await state.logout(flush: false);
  });
}
