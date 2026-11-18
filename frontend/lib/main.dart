import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/en_translations.dart';
import 'services/age.dart';
import 'services/ai_consent.dart';
import 'services/assistant_actions.dart';
import 'services/assistant_context.dart';
import 'services/format.dart';
import 'services/notifications.dart';
import 'services/session_storage.dart';
import 'services/sync_service.dart';
import 'services/user_store.dart';
import 'theme/app_theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/week_strip.dart';

part 'screens/auth_screens.dart';
part 'screens/home_screen.dart';
part 'screens/sport_tab.dart';
part 'screens/finance_tab.dart';
part 'screens/routines_tab.dart';
part 'screens/account_screens.dart';
part 'screens/activities_tab.dart';
part 'screens/notes_tab.dart';
part 'screens/privacy_policy_screen.dart';
part 'screens/settings_screen.dart';
part 'screens/assistant_tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadNotificationPrefs();
  try {
    await initNotifications();
  } catch (e) {
    // Bildirimlerin desteklenmediği platformlarda (ör. web) uygulama yine açılır.
    debugPrint('Bildirimler başlatılamadı: $e');
  }
  runApp(const MyApp());
}

class UserProfile {
  UserProfile({
    required this.email,
    this.name,
    this.birthDate,
    this.isNew = false,
  });

  final String email;
  String? name;
  DateTime? birthDate;
  bool isNew;

  factory UserProfile.fromJson(Map<String, dynamic> me, {bool? isNew}) {
    return UserProfile(
      email: me['email'] as String,
      name: me['name'] as String?,
      birthDate: me['birth_date'] != null
          ? DateTime.tryParse(me['birth_date'] as String)
          : null,
      isNew: isNew ?? (me['name'] == null || me['birth_date'] == null),
    );
  }
}

extension StringLocalization on String {
  String tr(BuildContext context) {
    final appState = context.read<AppState>();
    final lang = appState.locale.languageCode;
    if (lang == 'en') {
      return enTranslations[this] ?? this;
    }
    return this;
  }
}

/// Oturum süresi dolduğunda ya da token geçersiz olduğunda fırlatılır.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'Oturum süresi doldu. Lütfen tekrar giriş yap.';
}

/// Giriş başarılı ama e-posta adresi henüz doğrulanmamış.
class EmailNotVerifiedException implements Exception {
  @override
  String toString() => 'E-posta adresin henüz doğrulanmadı.';
}

class AppState extends ChangeNotifier {
  AppState({http.Client? client, SessionStorage? sessionStorage})
    : _client = client ?? http.Client(),
      _session = sessionStorage ?? const SecureSessionStorage();

  /// Backend adresi. Gerçek cihaz/üretim için:
  /// `flutter run --dart-define=API_BASE_URL=https://api.ornek.com`
  ///
  /// Release derlemede adres zorunludur ve `https://` ile başlamalıdır; böylece
  /// uygulama yanlışlıkla `127.0.0.1` ya da şifresiz bir adresle yayınlanamaz.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get _baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    return kReleaseMode ? '' : 'http://127.0.0.1:8000';
  }

  /// Adres geçerli değilse kullanıcıya anlaşılır bir hata verir.
  static void _requireBaseUrl() {
    final url = _baseUrl;
    if (url.isEmpty) {
      throw Exception('Sunucu adresi ayarlanmamış (API_BASE_URL).');
    }
    if (kReleaseMode && !url.startsWith('https://')) {
      throw Exception('Güvenlik için sunucu adresi https:// ile başlamalı.');
    }
  }

  static const Duration _timeout = Duration(seconds: 30);

  final http.Client _client;
  final SessionStorage _session;
  String? _token;
  String? _refreshToken;
  Future<bool>? _refreshing;

  SyncService? _sync;

  /// Sunucudan gelen veri yerel veriyi değiştirdikçe artar; ekranlar bununla yenilenir.
  int dataRevision = 0;

  /// Son başarılı eşitleme zamanı ve son hata (Ayarlar'da gösterilir).
  DateTime? lastSyncAt;
  String? lastSyncError;
  bool isSyncing = false;
  bool syncEnabled = true;

  UserProfile? currentUser;

  /// Uygulama açılışında kayıtlı oturum denenirken true.
  bool isRestoring = false;

  bool get isLoggedIn => currentUser != null;

  Locale locale = const Locale('tr');
  ThemeMode themeMode = ThemeMode.light;

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  Future<void> setLocale(Locale newLocale) async {
    locale = newLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', newLocale.languageCode);
  }

  bool get notificationsEnabled => areNotificationsEnabled;

  Future<void> setNotificationsEnabled(bool value) async {
    await applyNotificationsEnabled(value);
    notifyListeners();
  }

  /// Kayıtlı dil ve oturumu geri yükler (uygulama açılışı).
  @override
  void dispose() {
    UserStore.onWrite = null;
    _sync?.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> restoreSession() async {
    isRestoring = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('locale');
      if (lang == 'tr' || lang == 'en') locale = Locale(lang!);
      final theme = prefs.getString('theme_mode');
      themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == theme,
        orElse: () => ThemeMode.light,
      );

      var token = await _session.readToken();
      _refreshToken = await _session.readRefreshToken();
      if (token == null && _refreshToken == null) return;

      Future<http.Response> fetchMe(String? t) => _client
          .get(
            Uri.parse('$_baseUrl/auth/me'),
            headers: {if (t != null) 'Authorization': 'Bearer $t'},
          )
          .timeout(_timeout);

      var resp = await fetchMe(token);
      if (resp.statusCode == 401 && _refreshToken != null) {
        // Erişim token'ının süresi dolmuş: sessizce yenile.
        if (await _refresh()) {
          token = _token;
          resp = await fetchMe(token);
        }
      }
      if (resp.statusCode == 200) {
        _token = token;
        await _startSession(
          UserProfile.fromJson(jsonDecode(resp.body) as Map<String, dynamic>),
        );
      } else if (resp.statusCode == 401) {
        await _session.clearToken();
        _refreshToken = null;
      }
    } catch (_) {
      // Sunucuya ulaşılamadı: token saklı kalır, kullanıcı giriş ekranını görür.
    } finally {
      isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> _startSession(UserProfile user) async {
    UserStore.setUser(user.email);
    await UserStore.migrateLegacyData();

    syncEnabled = await SyncService.isEnabled();
    final sync = SyncService(request: authedRequest)
      ..onFinished = _onSyncFinished;
    _sync?.dispose();
    _sync = sync;
    UserStore.onWrite = sync.markDirty;
    // İlk eşitlemeyi kısa bir süre bekle: yeni cihazda veriler arayüz açılmadan gelsin.
    await _runSync(wait: const Duration(seconds: 3));

    currentUser = user;
    notifyListeners();
    await rescheduleAllReminders();
  }

  void _onSyncFinished(SyncOutcome outcome) {
    if (outcome.skipped) return;
    isSyncing = false;
    if (outcome.ok) {
      lastSyncAt = DateTime.now();
      lastSyncError = null;
    } else {
      lastSyncError = outcome.error;
    }
    if (outcome.changedLocal) {
      dataRevision++;
      // Başka cihazdan gelen hatırlatıcılar bu cihazda da kurulsun.
      unawaited(rescheduleAllReminders());
    }
    notifyListeners();
  }

  Future<void> _runSync({Duration? wait}) async {
    final sync = _sync;
    if (sync == null) return;
    isSyncing = true;
    final run = sync.syncAll();
    try {
      await (wait == null ? run : run.timeout(wait));
    } catch (_) {
      // zaman aşımı/ağ hatası: eşitleme arka planda sürer ya da sonra yeniden denenir
    }
  }

  /// Elle ya da uygulama öne gelince eşitleme.
  Future<void> syncNow() async {
    if (_sync == null) return;
    notifyListeners();
    await _runSync();
  }

  /// Uygulama yeniden öne geldiğinde: uzakta yapılan değişiklikleri çek, bekleyenleri gönder.
  Future<void> onAppResumed() async {
    if (isLoggedIn && syncEnabled) await syncNow();
  }

  /// Bulut yedeklemeyi açar/kapatır. Kapatırken [deleteRemote] true ise sunucudaki yedek de silinir.
  Future<void> setSyncEnabled(bool enabled, {bool deleteRemote = false}) async {
    final sync = _sync;
    if (!enabled && deleteRemote && sync != null) {
      await sync.deleteRemote();
    }
    await SyncService.setEnabled(enabled);
    syncEnabled = enabled;
    if (!enabled) {
      lastSyncError = null;
    }
    notifyListeners();
    if (enabled) await syncNow();
  }

  static String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is List && detail.isNotEmpty && detail.first is Map) {
        final msg =
            (detail.first as Map)['msg']?.toString() ?? 'Bilinmeyen hata';
        return msg.replaceFirst('Value error, ', '');
      }
      return detail?.toString() ?? 'Bilinmeyen hata';
    } catch (_) {
      return response.body.isEmpty ? 'Bilinmeyen hata' : response.body;
    }
  }

  /// Ağ hatalarını kullanıcıya anlaşılır bir mesaja çevirir.
  static Future<T> _network<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on TimeoutException {
      throw Exception('Sunucu yanıt vermedi. Lütfen tekrar dene.');
    } on http.ClientException {
      throw Exception('Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.');
    }
  }

  /// Kayıt başarılıysa e-posta adresinin doğrulanmış olup olmadığını döndürür.
  Future<bool> register(String email, String password) =>
      _network(() => _register(email, password));

  Future<bool> login(String email, String password) =>
      _network(() => _login(email, password));

  Future<bool> _register(String email, String password) async {
    _requireBaseUrl();
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.toLowerCase().trim(),
            'password': password,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['email_verified'] as bool? ?? true;
  }

  Future<bool> _login(String email, String password) async {
    _requireBaseUrl();
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/auth/login'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'username': email.toLowerCase().trim(), 'password': password},
        )
        .timeout(_timeout);

    if (response.statusCode == 429) throw Exception(_errorMessage(response));
    if (response.statusCode == 403) throw EmailNotVerifiedException();
    if (response.statusCode != 200) return false;

    final tokens = jsonDecode(response.body) as Map<String, dynamic>;
    final token = tokens['access_token'] as String;
    final refresh = tokens['refresh_token'] as String?;
    final meResp = await _client
        .get(
          Uri.parse('$_baseUrl/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
    if (meResp.statusCode != 200) return false;

    _token = token;
    _refreshToken = refresh;
    await _session.writeToken(token);
    if (refresh != null) await _session.writeRefreshToken(refresh);
    await _startSession(
      UserProfile.fromJson(jsonDecode(meResp.body) as Map<String, dynamic>),
    );
    return true;
  }

  /// Refresh token ile yeni bir erişim token'ı alır. Aynı anda gelen çağrılar tek istekte birleşir.
  Future<bool> _refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null) return false;
    try {
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        _token = data['access_token'] as String;
        _refreshToken = data['refresh_token'] as String?;
        await _session.writeToken(_token!);
        if (_refreshToken != null) {
          await _session.writeRefreshToken(_refreshToken!);
        }
        return true;
      }
      if (resp.statusCode == 401) {
        _refreshToken = null; // geçersiz: tekrar denemenin anlamı yok
      }
    } catch (_) {
      // ağ hatası: oturumu düşürme, çağıran hatayı görsün
    }
    return false;
  }

  /// Kimlik doğrulamalı istek. Erişim token'ının süresi dolmuşsa sessizce yenileyip bir kez tekrar dener;
  /// yenilenemezse oturumu kapatır ve [SessionExpiredException] fırlatır.
  Future<http.Response> authedRequest(
    String method,
    String path, {
    Object? body,
    Duration? timeout,
  }) async {
    if (_token == null) throw SessionExpiredException();
    _requireBaseUrl();

    Future<http.Response> send() async {
      final request = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers['Authorization'] = 'Bearer $_token';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(timeout ?? _timeout);
      return http.Response.fromStream(streamed);
    }

    var response = await send();
    if (response.statusCode == 401 && _refreshToken != null) {
      if (await _refresh()) response = await send();
    }
    if (response.statusCode == 401) {
      await logout(flush: false);
      throw SessionExpiredException();
    }
    return response;
  }

  // ---------- Hesap: şifre sıfırlama, e-posta doğrulama, şifre değiştirme ----------

  Future<void> _postPublic(
    String path,
    Map<String, dynamic> body, {
    int expect = 204,
  }) {
    return _network(() async {
      _requireBaseUrl();
      final resp = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (resp.statusCode != expect) throw Exception(_errorMessage(resp));
    });
  }

  /// Hesap var olsun olmasın başarılı döner (sunucu hesap sızdırmaz).
  Future<void> forgotPassword(String email) => _postPublic(
    '/auth/forgot-password',
    {'email': email.toLowerCase().trim()},
  );

  Future<void> resetPassword(String email, String code, String newPassword) =>
      _postPublic('/auth/reset-password', {
        'email': email.toLowerCase().trim(),
        'code': code.trim(),
        'new_password': newPassword,
      });

  Future<void> verifyEmail(String email, String code) => _postPublic(
    '/auth/verify-email',
    {'email': email.toLowerCase().trim(), 'code': code.trim()},
  );

  Future<void> resendVerification(String email) => _postPublic(
    '/auth/resend-verification',
    {'email': email.toLowerCase().trim()},
  );

  /// Şifreyi değiştirir. Sunucu tüm oturumları kapattığı için bu cihaz yeni şifreyle yeniden giriş yapar.
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = currentUser;
    if (user == null) throw SessionExpiredException();
    final resp = await authedRequest(
      'POST',
      '/auth/change-password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
    if (resp.statusCode != 204) throw Exception(_errorMessage(resp));
    await _network(() => _login(user.email, newPassword));
  }

  Future<void> updateProfile({
    required String name,
    required DateTime birthDate,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı. Lütfen tekrar giriş yap.');
    }

    final response = await authedRequest(
      'PUT',
      '/auth/me',
      body: {'name': name, 'birth_date': dateKey(birthDate)},
    );

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response));
    }

    currentUser = UserProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      isNew: false,
    );
    notifyListeners();
  }

  /// Sunucudaki sohbet geçmişini siler.
  Future<void> clearRemoteChatHistory() async {
    try {
      await authedRequest('DELETE', '/assistant/history');
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      // Çevrimdışıyken yerel temizlik yine de yapılır.
    }
  }

  /// Hesabı sunucuda kalıcı siler ve bu cihazdaki kullanıcı verisini temizler.
  Future<void> deleteAccount() async {
    final response = await authedRequest('DELETE', '/auth/me');
    if (response.statusCode != 204) {
      throw Exception('Hesap silinemedi (hata kodu: ${response.statusCode}).');
    }
    UserStore.onWrite = null; // silinen hesabın yedeği yeniden oluşmasın
    await UserStore.clearAll();
    await logout(flush: false);
  }

  /// [flush] true ise (kullanıcı çıkışı) bekleyen değişiklikler önce sunucuya gönderilir.
  Future<void> logout({bool flush = true}) async {
    if (flush && _token != null) {
      try {
        await (_sync?.flush() ?? Future<void>.value()).timeout(
          const Duration(seconds: 4),
        );
      } catch (_) {}
    }
    UserStore.onWrite = null;
    _sync?.dispose();
    _sync = null;
    final refresh = _refreshToken;
    _token = null;
    _refreshToken = null;
    if (refresh != null) {
      // Bu cihazın oturumunu sunucuda da geçersiz kıl (ağ yoksa yerel çıkış yine yapılır).
      try {
        await _client
            .post(
              Uri.parse('$_baseUrl/auth/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refresh}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    await _session.clearToken();
    try {
      await cancelAllReminders();
    } catch (_) {}
    UserStore.setUser(null);
    currentUser = null;
    notifyListeners();
  }
}

class MyApp extends StatefulWidget {
  /// [appState] yalnızca testlerde verilir; verilmezse oturum geri yüklenir.
  const MyApp({super.key, this.appState});

  final AppState? appState;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppState _state =
      widget.appState ?? (AppState()..restoreSession());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.appState == null) _state.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Uygulama öne gelince başka cihazdaki değişiklikleri çek, bekleyenleri gönder.
    if (lifecycle == AppLifecycleState.resumed) {
      unawaited(_state.onAppResumed());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: _state,
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'Smart Assistant',
            debugShowCheckedModeBanner: false,
            themeMode: appState.themeMode,
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            builder: (context, child) {
              final pal = context.pal;
              return Container(
                color: pal.bg,
                child: DefaultTextStyle(
                  style: TextStyle(color: pal.ink),
                  child: child!,
                ),
              );
            },
            locale: appState.locale,
            supportedLocales: const [Locale('tr'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (appState.isRestoring) {
      return Scaffold(
        backgroundColor: context.pal.bg,
        body: Center(child: CircularProgressIndicator(color: context.pal.ink)),
      );
    }

    if (!appState.isLoggedIn) {
      return const WelcomeScreen();
    }

    final user = appState.currentUser!;
    if (user.isNew || user.name == null || user.birthDate == null) {
      return const OnboardingScreen();
    }

    return const HomeScreen();
  }
}
