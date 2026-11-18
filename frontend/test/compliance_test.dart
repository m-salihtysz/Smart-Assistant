import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'package:smart_assistant/services/age.dart';
import 'package:smart_assistant/services/ai_consent.dart';
import 'support/fakes.dart';
import 'package:smart_assistant/services/user_store.dart';
import 'package:smart_assistant/theme/app_theme.dart';

Future<AppState> _login({
  required void Function(http.Request) onChat,
  void Function(http.Request)? onReport,
}) async {
  final state = AppState(
    client: MockClient((r) async {
      if (r.url.path == '/auth/login') {
        return http.Response('{"access_token":"t"}', 200);
      }
      if (r.url.path == '/assistant/report') {
        onReport?.call(r);
        return http.Response('', 204);
      }
      if (r.url.path == '/assistant/chat') {
        onChat(r);
        return http.Response('{"reply":"Tamam","action":null}', 200);
      }
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

Widget _app(AppState state, Widget home) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(body: home),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('yaş sınırı', () {
    final now = DateTime(2026, 11, 18);

    test('tam 13 yaşında olan kabul edilir, bir gün eksik reddedilir', () {
      expect(isOldEnough(DateTime(2013, 11, 18), now: now), isTrue);
      expect(isOldEnough(DateTime(2013, 11, 19), now: now), isFalse);
      expect(isOldEnough(DateTime(1999, 5, 1), now: now), isTrue);
      expect(isOldEnough(DateTime(2020, 1, 1), now: now), isFalse);
    });

    test('latestAllowedBirthDate bugünden 13 yıl öncesi', () {
      expect(latestAllowedBirthDate(now: now), DateTime(2013, 11, 18));
    });
  });

  test('AiConsent hesaba özeldir ve varsayılan olarak verilmemiştir', () async {
    UserStore.setUser('a@x.com');
    expect(await AiConsent.isGranted(), isFalse);
    await AiConsent.set(true);
    expect(await AiConsent.isGranted(), isTrue);

    UserStore.setUser('b@x.com');
    expect(await AiConsent.isGranted(), isFalse);

    UserStore.setUser('a@x.com');
    await AiConsent.set(false);
    expect(await AiConsent.isGranted(), isFalse);
  });

  Future<void> sizePhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    'Asistan: izin verilmeden mesaj sunucuya gitmez, reddedince hiçbir şey gönderilmez',
    (tester) async {
      await sizePhone(tester);
      var chatCalls = 0;
      final state = await _login(onChat: (_) => chatCalls++);
      await tester.pumpWidget(_app(state, const AssistantTab()));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Bugün neler yapmalıyım?'));
      await tester.pumpAndSettle();
      expect(find.text('Yapay zeka ile veri paylaşımı'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(chatCalls, 0);
      expect(await AiConsent.isGranted(), isFalse);
      // mesaj sohbete eklenmedi
      expect(find.text('Smart AI ile Konuş'), findsOneWidget);
    },
  );

  testWidgets(
    'Asistan: izin verilince mesaj gönderilir ve izin bir daha sorulmaz',
    (tester) async {
      await sizePhone(tester);
      final bodies = <String>[];
      final state = await _login(onChat: (r) => bodies.add(r.body));
      await tester.pumpWidget(_app(state, const AssistantTab()));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Bugün neler yapmalıyım?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kabul Et'));
      await tester.pumpAndSettle();

      expect(await AiConsent.isGranted(), isTrue);
      expect(bodies, hasLength(1));
      expect(bodies.single, contains('Bugün neler yapmalıyım?'));
      expect(find.text('Tamam'), findsOneWidget);

      // İkinci mesajda diyalog çıkmaz
      await tester.enterText(find.byType(TextField), 'ikinci');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.text('Yapay zeka ile veri paylaşımı'), findsNothing);
      expect(bodies, hasLength(2));
    },
  );

  testWidgets(
    'Ayarlar: veri paylaşımı izni geri alınabilir ve politika açılır',
    (tester) async {
      await sizePhone(tester);
      final state = await _login(onChat: (_) {});
      await AiConsent.set(true);
      await tester.pumpWidget(_app(state, const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      final toggle = find.text('Asistan veri paylaşımı');
      await tester.scrollUntilVisible(
        toggle,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Asistan veri paylaşımı'),
            )
            .value,
        isTrue,
      );

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(await AiConsent.isGranted(), isFalse);

      final policy = find.widgetWithText(ListTile, 'Gizlilik Politikası');
      await tester.scrollUntilVisible(
        policy,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(policy);
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(find.text('Topladığımız veriler'), findsOneWidget);
      final age = find.text('Yaş sınırı');
      await tester.scrollUntilVisible(
        age,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('en az 13 yaşında', skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('Gizlilik politikası İngilizce de gösterilir', (tester) async {
    await sizePhone(tester);
    final state = await _login(onChat: (_) {});
    await state.setLocale(const Locale('en'));
    await tester.pumpWidget(_app(state, const PrivacyPolicyScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Data we collect'), findsOneWidget);
    expect(
      find.text('Sharing with AI providers', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('Asistan yanıtı bildirilebilir', (tester) async {
    await sizePhone(tester);
    final reports = <String>[];
    final state = await _login(
      onChat: (_) {},
      onReport: (r) => reports.add(r.body),
    );
    await AiConsent.set(true);
    await tester.pumpWidget(_app(state, const AssistantTab()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Bugün neler yapmalıyım?'));
    await tester.pumpAndSettle();
    expect(find.text('Tamam'), findsOneWidget);

    await tester.tap(find.text('Bildir'));
    await tester.pumpAndSettle();
    expect(find.text('Yanıtı bildir'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Bildir'));
    await tester.pumpAndSettle();

    expect(reports, hasLength(1));
    expect(reports.single, contains('Tamam'));
    expect(find.text('Bildirimin alındı. Teşekkürler.'), findsOneWidget);
  });
}
