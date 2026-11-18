// Tanıtım görsellerini üretir (normal `flutter test` içinde atlanır):
//
//   flutter test test/tool/showcase_test.dart \
//     --dart-define=SHOWCASE_DIR=../docs/screenshots \
//     --dart-define=FONT_DIR=<flutter-sdk>/bin/cache/artifacts/material_fonts
//
// Gerçek ekranları demo verisiyle çizer, her ekranı açık ve koyu temada PNG olarak yazar.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/main.dart';
import 'package:smart_assistant/services/format.dart';
import 'package:smart_assistant/theme/app_theme.dart';

import '../support/fakes.dart';

const _outDir = String.fromEnvironment('SHOWCASE_DIR');
const _fontDir = String.fromEnvironment('FONT_DIR');

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(
        File('$_fontDir/$f').readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

String _key(int daysFromToday) =>
    dateKey(DateTime.now().add(Duration(days: daysFromToday)));

Map<String, Object> _demoData() {
  const u = 'u:ali@ornek.com:';
  final now = DateTime.now();
  final today = now.weekday - 1;
  Map<String, dynamic> routine(String t, int h, int m, bool rem) =>
      {'title': t, 'hour': h, 'minute': m, 'reminder': rem, 'notificationId': 1};
  final routines = <String, dynamic>{
    for (var d = 0; d < 7; d++)
      '$d': [
        routine('Sabah yürüyüşü', 7, 30, true),
        routine('Su iç (2 litre)', 10, 0, false),
        routine('Kitap oku', 21, 30, true),
        if (d % 2 == 0) routine('İngilizce çalış', 19, 0, false),
      ],
    'completions': {
      _key(0): [true, true, false, false],
      _key(-1): [true, true, true, true],
      _key(-2): [true, false, true, true],
    },
  };
  Map<String, dynamic> ex(String n, int r, int s, String region) =>
      {'name': n, 'reps': r, 'sets': s, 'region': region};
  final sport = <String, dynamic>{
    '$today': {
      'region': 'Göğüs',
      'exercises': [
        ex('Bench press', 10, 4, 'Göğüs'),
        ex('Şınav', 15, 3, 'Göğüs'),
        ex('Incline dumbbell press', 12, 3, 'Göğüs'),
        ex('Dips', 10, 3, 'Göğüs'),
      ],
    },
    '${(today + 1) % 7}': {
      'region': 'Sırt',
      'exercises': [ex('Barfiks', 8, 4, 'Sırt'), ex('Kürek çekme', 12, 3, 'Sırt')],
    },
  };
  Map<String, dynamic> tx(String t, double a, String title, int d, String cat) =>
      {'type': t, 'amount': a, 'title': title, 'date': _key(d), 'category': cat};
  final finance = [
    tx('gelir', 28500, 'Maaş', -9, 'Maaş'),
    tx('gider', 8200, 'Kira', -8, 'Kira'),
    tx('gider', 1240.5, 'Market alışverişi', -3, 'Market'),
    tx('gider', 320, 'Akşam yemeği', -2, 'Yemek'),
    tx('gider', 185, 'Ulaşım kartı', -1, 'Ulaşım'),
    tx('gider', 96.75, 'Kahve ve atıştırmalık', 0, 'Yemek'),
    tx('gelir', 2400, 'Serbest iş', 0, 'Diğer'),
  ];
  Map<String, dynamic> act(String t, int h, int m, int d, bool r) =>
      {'date': _key(d), 'title': t, 'hour': h, 'minute': m, 'reminder': r, 'notificationId': h * 100 + m};
  final activities = [
    act('Ekip toplantısı', 10, 0, 0, true),
    act('Diş randevusu', 14, 30, 0, true),
    act('Arkadaşla akşam yemeği', 19, 30, 0, false),
    act('Sunum hazırlığı', 11, 0, 1, true),
    act('Anneyi ara', 18, 0, 2, false),
  ];
  final notes = [
    {'title': 'Alışveriş listesi', 'body': 'Süt, yumurta, zeytinyağı, tam buğday ekmeği'},
    {'title': 'Proje fikirleri', 'body': 'Haftalık özet e-postası ve hedef takibi'},
    {'title': 'Okunacak kitaplar', 'body': 'Atomik Alışkanlıklar, Derin Çalışma'},
    {'title': 'Hedefler', 'body': 'Haftada 4 gün spor, ayda 3 bin lira birikim'},
  ];
  final t0 = now.millisecondsSinceEpoch;
  final chat = [
    {'text': 'Bu hafta ne kadar harcadım?', 'fromUser': true, 'ts': t0 - 600000},
    {
      'text': 'Bu hafta toplam 1.842,25 ₺ harcadın. En büyük kalem 1.240,50 ₺ ile market. '
          'Dilersen kategorilere göre ayrıntıyı çıkarayım.',
      'fromUser': false,
      'ts': t0 - 590000,
    },
    {'text': 'Yarın 11:00 için sunum hazırlığı hatırlatıcısı ekle', 'fromUser': true, 'ts': t0 - 300000},
    {
      'text': 'Tamamdır, yarın 11:00 için "Sunum hazırlığı" aktivitesini hatırlatıcıyla ekledim.',
      'fromUser': false,
      'ts': t0 - 290000,
    },
  ];
  return {
    '${u}activities': jsonEncode(activities),
    '${u}routines': jsonEncode(routines),
    '${u}sport_plans': jsonEncode(sport),
    '${u}finance_transactions': jsonEncode(finance),
    '${u}finance_watchlist': jsonEncode([
      {'name': 'Bitcoin', 'symbol': 'BTC'},
      {'name': 'Altın', 'symbol': 'XAU'},
    ]),
    '${u}notes_v2': jsonEncode(notes),
    '${u}assistant_messages': jsonEncode(chat),
    '${u}ai_consent': 'true',
  };
}

Future<AppState> _loggedIn() async {
  const me =
      '{"id":1,"email":"ali@ornek.com","name":"Ali","birth_date":"1999-05-01","created_at":"2026-01-01T00:00:00"}';
  final state = AppState(
    client: MockClient(
      (r) async => r.url.path == '/auth/login'
          ? http.Response('{"access_token":"t","refresh_token":"r"}', 200)
          : http.Response(me, 200),
    ),
    sessionStorage: MemorySessionStorage(),
  );
  await state.login('ali@ornek.com', 'password123');
  return state;
}

class _Shot {
  _Shot(this.name, this.caption, this.build);
  final String name;
  final String caption;
  final Widget Function() build;
}

void main() {
  final enabled = _outDir.isNotEmpty && _fontDir.isNotEmpty;

  testWidgets('tanıtım görselleri', skip: !enabled, timeout: const Timeout(Duration(minutes: 5)), (tester) async {
    await tester.runAsync(_loadFonts);
    FlutterError.onError = (_) {}; // test yazı tipi/ağ kaynaklı gürültü
    Directory(_outDir).createSync(recursive: true);

    final shots = [
      _Shot('home', 'Bugün bir bakışta', () => const HomeScreen()),
      _Shot('sport', 'Spor planı', () => const SportTab()),
      _Shot('finance', 'Gelir ve gider', () => const FinanceTab()),
      _Shot('routines', 'Günlük rutinler', () => const RoutinesTab()),
      _Shot('assistant', 'Yapay zeka asistanı', () => const AssistantTab()),
      _Shot('activities', 'Aktiviteler ve hatırlatıcılar', () => const ActivitiesTab()),
      _Shot('notes', 'Notlar', () => const NotesTab()),
      _Shot('settings', 'Ayarlar', () => const SettingsScreen()),
    ];

    final images = <String, Map<Brightness, ui.Image>>{};

    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final shot in shots) {
        SharedPreferences.setMockInitialValues(_demoData());
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        final boundary = GlobalKey();
        final state = await _loggedIn();
        await tester.pumpWidget(
          ChangeNotifierProvider<AppState>.value(
            value: state,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
              theme: buildAppTheme(Brightness.light).copyWith(
                textTheme: buildAppTheme(Brightness.light).textTheme.apply(fontFamily: 'Roboto'),
              ),
              darkTheme: buildAppTheme(Brightness.dark).copyWith(
                textTheme: buildAppTheme(Brightness.dark).textTheme.apply(fontFamily: 'Roboto'),
              ),
              builder: (context, child) => RepaintBoundary(
                key: boundary,
                child: Container(
                  color: context.pal.bg,
                  child: DefaultTextStyle(
                    style: TextStyle(fontFamily: 'Roboto', color: context.pal.ink),
                    child: child!,
                  ),
                ),
              ),
              home: Scaffold(body: SafeArea(child: shot.build())),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 120)));
          await tester.pump(const Duration(milliseconds: 200));
        }
        final image = await tester.runAsync(() async {
          final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          return ro.toImage(pixelRatio: 3);
        });
        final tag = brightness == Brightness.dark ? 'dark' : 'light';
        final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        File('$_outDir/${shot.name}_$tag.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        images.putIfAbsent(shot.name, () => {})[brightness] = image!;
      }
    }
  });
}
