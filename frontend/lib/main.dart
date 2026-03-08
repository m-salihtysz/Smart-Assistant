import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'dart:convert';

final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
int _notificationIdCounter = 1000;

Future<void> _initNotifications() async {
  tz_data.initializeTimeZones();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(requestAlertPermission: true);
  await _notificationsPlugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
    onDidReceiveNotificationResponse: (_) {},
  );
  await _notificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true);
}

Future<void> scheduleActivityReminder(int id, String title, DateTime when) async {
  if (when.isBefore(DateTime.now())) return;
  final tzDate = tz.TZDateTime.from(when, tz.local);
  await _notificationsPlugin.zonedSchedule(
    id,
    'Hatırlatıcı',
    title,
    tzDate,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'activities',
        'Aktivite hatırlatıcıları',
        channelDescription: 'Aktivite bildirimleri',
        importance: Importance.defaultImportance,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> scheduleRoutineReminder(int id, String title, int weekday, int hour, int minute) async {
  var when = DateTime.now();
  var days = (weekday - when.weekday) % 7;
  if (days < 0) days += 7;
  if (days == 0 && (when.hour > hour || (when.hour == hour && when.minute >= minute))) days = 7;
  when = DateTime(when.year, when.month, when.day + days, hour, minute);
  if (when.isBefore(DateTime.now())) return;
  final tzDate = tz.TZDateTime.from(when, tz.local);
  await _notificationsPlugin.zonedSchedule(
    id,
    'Rutin hatırlatıcı',
    title,
    tzDate,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'routines',
        'Rutin hatırlatıcıları',
        channelDescription: 'Rutin bildirimleri',
        importance: Importance.defaultImportance,
      ),
      iOS: const DarwinNotificationDetails(),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> cancelReminderNotification(int id) async {
  await _notificationsPlugin.cancel(id);
}

int nextNotificationId() => _notificationIdCounter++;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initNotifications();
  runApp(const MyApp());
}

class UserProfile {
  UserProfile({
    required this.email,
    this.name,
    this.birthDate,
    this.isNew = false,
    this.token,
  });

  final String email;
  String? name;
  DateTime? birthDate;
  bool isNew;
  String? token;
}

extension StringLocalization on String {
  String tr(BuildContext context) {
    if (this == 'Ad (Örn. Apple, BIST 100)' || this == 'Örn. Market') return this;
    final appState = context.watch<AppState>();
    final lang = appState.locale.languageCode;
    if (lang == 'en') {
      return _enTranslations[this] ?? this;
    }
    return this;
  }
}

const Map<String, String> _enTranslations = {
  'Smart Assistant': 'Smart Assistant',
  'Giriş yap': 'Sign in',
  'Kayıt ol': 'Sign up',
  'Hesabın yok mu?': 'Don\'t have an account?',
  'Hesabın var mı?': 'Already have an account?',
  'E-posta': 'Email',
  'Şifre': 'Password',
  'E-posta veya şifre hatalı.': 'Incorrect email or password.',
  'Seni Tanıyalım': 'Let\'s get to know you',
  'Adın': 'Name',
  'Doğum tarihin': 'Birth date',
  'Lütfen adını gir': 'Please enter your name',
  'Seç': 'Select',
  'Lütfen doğum tarihini seç': 'Please select your birth date',
  'Devam et': 'Continue',
  'Karanlık mod': 'Dark mode',
  'Dil': 'Language',
  'Türkçe': 'Turkish',
  'English': 'English',
  'Kaydet': 'Save',
  'Çıkış yap': 'Log out',
  'Ayarlar': 'Settings',
  'Yeni sohbet': 'New chat',
  'Asistanına bir şey sor...': 'Ask your assistant something...',
  'Rutinler': 'Routines',
  'Spor': 'Sports',
  'Finans': 'Finance',
  'Notlar': 'Notes',
  'Aktivite ekle': 'Add activity',
  'Yeni not ekle': 'Add new note',
  'Gelir / Gider ekle': 'Add Income / Expense',
  'Gelir': 'Income',
  'Gider': 'Expense',
  'Açıklama': 'Description',
  'Tutar (₺)': 'Amount (₺)',
  'Ekle': 'Add',
  'Vazgeç': 'Cancel',
  'Sil': 'Delete',
  'Değiştir': 'Change',
  'Saat değiştir': 'Change time',
  'Bildirim hatırlatıcı olsun mu?': 'Set a reminder?',
  'Hareket ekle': 'Add exercise',
  'Hareket adı': 'Exercise name',
  'Tekrar sayısı': 'Reps',
  'Set sayısı': 'Sets',
  'Planını düzenle': 'Edit plan',
  'Bölge seç': 'Select region',
  'Haftalık spor planın': 'Weekly sport plan',
  'Bu gün için eklenmiş hareket yok.': 'No exercises added for today.',
  'Borsa takip listesine ekle': 'Add to watchlist',
  'Ad (Örn. Apple, BIST 100)': 'Name (e.g. Apple, S&P 500)',
  'Sembol (isteğe bağlı)': 'Symbol (optional)',
  'Henüz kayıt yok. Gelir veya gider ekleyebilirsin.': 'No records yet. You can add income or expense.',
  'Borsa takip listen boş. Hisse veya endeks ekleyebilirsin.': 'Watchlist is empty. You can add stocks or indices.',
  'Bugün': 'Today',
  'Tüm rutinler tamamlandı!': 'All routines completed!',
  'Henüz notun yok. Yeni bir not oluştur.': 'You don\'t have any notes. Create a new note.',
  'Başlık': 'Title',
  'Not içeriği...': 'Note content...',
  'Aktiviteyi düzenle': 'Edit activity',
  'Hareketi düzenle': 'Edit exercise',
  'Rutin ekle': 'Add routine',
  'Rutin adı': 'Routine name',
  'Günün Notu': 'Note of the day',
};

class AppState extends ChangeNotifier {
  UserProfile? currentUser;

  static const String _baseUrl = 'http://127.0.0.1:8000';

  bool get isLoggedIn => currentUser != null;

  bool isDarkMode = false;
  Locale locale = const Locale('tr');

  void setDarkMode(bool value) {
    isDarkMode = value;
    notifyListeners();
  }

  void setLocale(Locale newLocale) {
    locale = newLocale;
    notifyListeners();
  }

  bool emailExists(String email) {
    // Backend ile kullandığımız flow'da artık bu fonksiyon sadece
    // "lokal olarak bildiğimiz bir user var mı" kontrolü için kullanılıyor.
    return false;
  }

  Future<void> register(String email, String password) async {
    final normalized = email.toLowerCase().trim();
    final uri = Uri.parse('$_baseUrl/auth/register');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': normalized,
        'password': password,
      }),
    );

    if (response.statusCode != 201) {
      String message = 'Bilinmeyen hata';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['detail']?.toString() ?? message;
      } catch (_) {
        message = response.body;
      }
      throw Exception(message);
    }
  }

  Future<bool> login(String email, String password) async {
    final normalized = email.toLowerCase().trim();
    final uri = Uri.parse('$_baseUrl/auth/login');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'username': normalized,
        'password': password,
      },
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String;

    final meUri = Uri.parse('$_baseUrl/auth/me');
    final meResp = await http.get(
      meUri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (meResp.statusCode != 200) {
      return false;
    }

    final me = jsonDecode(meResp.body) as Map<String, dynamic>;
    currentUser = UserProfile(
      email: me['email'] as String,
      name: me['name'] as String?,
      birthDate: me['birth_date'] != null
          ? DateTime.tryParse(me['birth_date'] as String)
          : null,
      isNew: (me['name'] == null || me['birth_date'] == null),
      token: token,
    );
    notifyListeners();
    return true;
  }

  Future<void> updateProfile({
    required String name,
    required DateTime birthDate,
  }) async {
    if (currentUser == null || currentUser!.token == null) {
      // Backend ile henüz giriş yapılmamışsa, sadece lokal güncelle.
      currentUser!
        ..name = name
        ..birthDate = birthDate
        ..isNew = false;
      notifyListeners();
      return;
    }

    final uri = Uri.parse('$_baseUrl/auth/me');
    final response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${currentUser!.token}',
      },
      body: jsonEncode({
        'name': name,
        'birth_date':
            '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
      }),
    );

    if (response.statusCode != 200) {
      // Yine de lokal state'i güncelle, ama hata loglamak mümkün.
      currentUser!
        ..name = name
        ..birthDate = birthDate
        ..isNew = false;
      notifyListeners();
      return;
    }

    final me = jsonDecode(response.body) as Map<String, dynamic>;
    currentUser = UserProfile(
      email: me['email'] as String,
      name: me['name'] as String?,
      birthDate: me['birth_date'] != null
          ? DateTime.tryParse(me['birth_date'] as String)
          : null,
      isNew: false,
      token: currentUser!.token,
    );
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return MaterialApp(
            title: 'Smart Assistant',
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              final isDark = appState.isDarkMode;
              final String bgImage = isDark ? 'assets/bg_dark.png' : 'assets/bg_light.png';
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    bgImage,
                    fit: BoxFit.cover,
                  ),
                  ?child,
                ],
              );
            },
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E7D6E),
                brightness: Brightness.light,
              ).copyWith(
                surface: Colors.white.withOpacity(0.1),
                surfaceContainerHighest: const Color(0xFFF0F2F3).withOpacity(0.3),
                surfaceContainerHigh: const Color(0xFFF4F5F6).withOpacity(0.3),
                surfaceContainer: const Color(0xFFF6F7F8).withOpacity(0.3),
                surfaceContainerLow: const Color(0xFFF8F9FA).withOpacity(0.3),
                primaryContainer: const Color(0xFFE8F5F2).withOpacity(0.4),
                onPrimaryContainer: const Color(0xFF1A2E2A),
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.transparent,
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.white.withOpacity(0.5),
              ),
              canvasColor: Colors.white,
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white.withOpacity(0.4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF2E7D6E).withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E7D6E), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                labelStyle: const TextStyle(color: Colors.black54),
                hintStyle: const TextStyle(color: Colors.black38),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF4DB6AC),
                brightness: Brightness.dark,
              ).copyWith(
                surface: const Color(0xFF121212).withOpacity(0.2),
                surfaceContainerHighest: const Color(0xFF1E1E1E).withOpacity(0.3),
                primaryContainer: const Color(0xFF1E3A35).withOpacity(0.3),
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.transparent,
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: const Color(0xFF1E1E1E).withOpacity(0.6),
              ),
              canvasColor: const Color(0xFF1E1E1E),
              dialogTheme: DialogThemeData(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4DB6AC), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                labelStyle: const TextStyle(color: Colors.white70),
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: appState.locale,
            supportedLocales: const [
              Locale('tr'),
              Locale('en'),
            ],
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

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(BuildContext context) async {
    final appState = context.read<AppState>();
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final ok = await appState.login(email, password);
    if (!ok) {
      setState(() => _errorText = 'E-posta veya şifre hatalı.');
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    Text(
                      'Smart Assistant',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Giriş yap veya yeni hesap oluştur'.tr(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Giriş yap',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'E-posta'.tr(context),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: colorScheme.outlineVariant),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'E-posta girin';
                                }
                                if (!v.contains('@')) {
                                  return 'Geçerli bir e-posta girin';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Şifre'.tr(context),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: colorScheme.outlineVariant),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Şifre girin';
                                }
                                if (v.trim().length < 4) {
                                  return 'Şifre en az 4 karakter olmalı';
                                }
                                return null;
                              },
                            ),
                            if (_errorText != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorText!,
                                style: TextStyle(
                                    color: colorScheme.error, fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () => _handleLogin(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text('Giriş yap'.tr(context)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                    TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: Text(
                      'Hesabın yok mu? Kayıt ol',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(BuildContext context) async {
    final appState = context.read<AppState>();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final ok = await appState.login(email, password);
    if (!ok) {
      setState(() {
        _errorText = 'E-posta veya şifre hatalı.';
      });
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Giriş yap'.tr(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                  margin: const EdgeInsets.only(top: 60),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                padding: const EdgeInsets.all(24),
                child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hoş geldin.'.tr(context),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                        ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-posta'.tr(context),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen e-posta gir';
                    }
                    if (!value.contains('@')) {
                      return 'Geçerli bir e-posta gir';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Şifre'.tr(context),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen şifre gir';
                    }
                    if (value.trim().length < 4) {
                      return 'Şifre en az 4 karakter olmalı';
                    }
                    return null;
                  },
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => _handleLogin(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('Giriş yap'.tr(context)),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      await appState.register(email, password);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt başarısız: ${e.toString()}'.tr(context))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                margin: const EdgeInsets.only(top: 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Yeni hesap oluştur'.tr(context),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Kayıt ol',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'E-posta'.tr(context),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outlineVariant),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'E-posta girin';
                              if (!v.contains('@')) return 'Geçerli bir e-posta girin';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Şifre'.tr(context),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: colorScheme.outlineVariant),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Şifre belirleyin';
                              if (v.trim().length < 4) return 'Şifre en az 4 karakter olmalı';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () => _handleRegister(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text('Kayıt ol'.tr(context)),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Zaten hesabın var mı? Giriş yap',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _completeOnboarding(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen doğum tarihini seç'.tr(context))),
      );
      return;
    }
    final appState = context.read<AppState>();
    await appState.updateProfile(
      name: _nameController.text.trim(),
      birthDate: _selectedDate!,
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final emailText = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Seni Tanıyalım'.tr(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                margin: const EdgeInsets.only(top: 40),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Merhaba, $emailText',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                const SizedBox(height: 8),
                Text(
                  'Sana daha iyi yardımcı olabilmem için birkaç bilgi isteyeceğim.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Adın'.tr(context),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen adını gir';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Doğum tarihin'.tr(context),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _selectedDate == null
                          ? 'Seç'
                          : '${_selectedDate!.day.toString().padLeft(2, '0')}.'
                              '${_selectedDate!.month.toString().padLeft(2, '0')}.'
                              '${_selectedDate!.year}',
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => _completeOnboarding(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text('Devam et'.tr(context)),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // ortadaki sekme varsayılan

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _BottomNavItem(
                  icon: Icons.chat_bubble_outline,
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _BottomNavItem(
                  icon: Icons.home_rounded,
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _BottomNavItem(
                  icon: Icons.settings_rounded,
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const AssistantTab();
      case 1:
        return const _HomeDashboard();
      case 2:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFF4DB6AC) : Colors.white70;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4DB6AC).withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: color,
          size: 22,
        ),
      ),
    );
  }
}

/// Ana sayfa: ortada seçenek grid'i, tıklanınca ilgili sekme içeriği açılır.
class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard();

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  int? _selectedCategory;

  // Sıra: sol üst Aktivite, sağ üst Rutin, sol alt Spor, sağ alt Finans, en alt Notlar
  static const List<_HomeCategory> _categories = [
    _HomeCategory(label: 'Aktiviteler', icon: Icons.today_rounded),
    _HomeCategory(label: 'Rutinler', icon: Icons.repeat_rounded),
    _HomeCategory(label: 'Spor', icon: Icons.fitness_center),
    _HomeCategory(label: 'Finans', icon: Icons.account_balance_wallet_rounded),
    _HomeCategory(label: 'Notlar', icon: Icons.note_rounded),
  ];

  Widget _contentFor(int index) {
    switch (index) {
      case 0:
        return const ActivitiesTab();
      case 1:
        return const RoutinesTab();
      case 2:
        return const SportTab();
      case 3:
        return const FinanceTab();
      case 4:
        return const NotesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_selectedCategory != null) {
      return Column(
        children: [
          Material(
            elevation: 0,
            color: Colors.black.withValues(alpha: 0.3),
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                      onPressed: () => setState(() => _selectedCategory = null),
                    ),
                    Text(
                      _categories[_selectedCategory!].label,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _contentFor(_selectedCategory!)),
        ],
      );
    }

    final userName = context.watch<AppState>().currentUser?.name ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (userName.isNotEmpty)
                  Text(
                    'Hoşgeldin, $userName',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                if (userName.isNotEmpty) const SizedBox(height: 6),
                Text(
                  'Neye bakalım?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 2;
              const spacing = 12.0;
              final width = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.center,
                children: List.generate(_categories.length, (index) {
                  final cat = _categories[index];
                    return SizedBox(
                    width: width,
                    child: Material(
                      elevation: 0,
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      child: InkWell(
                        onTap: () => setState(() => _selectedCategory = index),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.icon,
                                size: 32,
                                color: const Color(0xFF4DB6AC),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                cat.label,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HomeCategory {
  const _HomeCategory({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// Eski ortadaki ana sayfa (referans)
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _SimplePlaceholder(
            title: 'Spor',
            description:
                'Antrenman programların, hedeflerin ve ilerlemeni burada takip edeceksin.',
            icon: Icons.fitness_center,
          ),
          SizedBox(height: 16),
          _SimplePlaceholder(
            title: 'Finans',
            description:
                'Gelir-giderlerin, bütçe planların ve hedeflerin için alan.',
            icon: Icons.account_balance_wallet,
          ),
          SizedBox(height: 16),
          _SimplePlaceholder(
            title: 'Rutinler',
            description:
                'Günlük alışkanlıklarını ve yapılacaklarını burada organize edeceksin.',
            icon: Icons.repeat,
          ),
          SizedBox(height: 16),
          _SimplePlaceholder(
            title: 'Notlar',
            description: 'Önemli notlar ve fikirler için hızlı alan.',
            icon: Icons.note,
          ),
        ],
      ),
    );
  }
}

class SportTab extends StatefulWidget {
  const SportTab({super.key});

  @override
  State<SportTab> createState() => _SportTabState();
}

class _SportTabState extends State<SportTab> {
  static const List<String> _dayLabels = [
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  static const List<String> _regions = [
    'Seçilmedi',
    'Göğüs',
    'Sırt',
    'Omuz',
    'Kol',
    'Bacak',
    'Kardiyo',
    'Tüm vücut',
    'Dinlenme',
  ];

  int _selectedDayIndex = DateTime.now().weekday - 1; // 0-6

  final Map<int, _WorkoutPlan> _plans = {};

  @override
  void initState() {
    super.initState();
    _loadSportPlans();
  }

  Future<void> _loadSportPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('sport_plans');
    if (jsonStr == null) return;
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr) as Map<String, dynamic>;
      _plans.clear();
      for (final entry in data.entries) {
        final dayIndex = int.tryParse(entry.key);
        if (dayIndex == null || dayIndex < 0 || dayIndex > 6) continue;
        final map = entry.value as Map<String, dynamic>;
        final region = map['region'] as String? ?? 'Seçilmedi';
        final exercisesList = map['exercises'] as List<dynamic>? ?? [];
        final exercises = <_WorkoutExercise>[];
        for (final ex in exercisesList) {
          final m = ex as Map<String, dynamic>;
          exercises.add(_WorkoutExercise(
            name: m['name'] as String? ?? '',
            reps: m['reps'] as int? ?? 12,
            sets: m['sets'] as int? ?? 3,
          ));
        }
        _plans[dayIndex] = _WorkoutPlan(region: region, exercises: exercises);
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveSportPlans() async {
    final Map<String, dynamic> data = {};
    _plans.forEach((dayIndex, plan) {
      data['$dayIndex'] = {
        'region': plan.region,
        'exercises': plan.exercises
            .map((e) => {'name': e.name, 'reps': e.reps, 'sets': e.sets})
            .toList(),
      };
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sport_plans', jsonEncode(data));
  }

  _WorkoutPlan _planForDay(int index) {
    return _plans[index] ??
        _WorkoutPlan(
          region: _regions[0],
          exercises: <_WorkoutExercise>[],
        );
  }

  /// Seçili haftanın günleri (Pzt–Paz) tarih olarak.
  List<DateTime> _weekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  Future<void> _changeRegion() async {
    final current = _planForDay(_selectedDayIndex);
    String tempRegion = current.region;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bölge seç'.tr(context)),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return DropdownButton<String>(
                isExpanded: true,
                value: tempRegion,
                items: _regions
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setStateDialog(() {
                    tempRegion = value;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Vazgeç'.tr(context)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Kaydet'.tr(context)),
            ),
          ],
        );
      },
    );

    setState(() {
      final existing = _planForDay(_selectedDayIndex);
      _plans[_selectedDayIndex] = _WorkoutPlan(
        region: tempRegion,
        exercises: existing.exercises,
      );
    });
    await _saveSportPlans();
  }

  Future<void> _addExercise() async {
    final nameController = TextEditingController();
    final repsController = TextEditingController(text: '12');
    final setsController = TextEditingController(text: '3');

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Hareket ekle'.tr(context)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Hareket adı'.tr(context),
                  hintText: 'Örn. Bench press, Squat...'.tr(context),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repsController,
                decoration: InputDecoration(
                  labelText: 'Tekrar sayısı'.tr(context),
                  hintText: 'Örn. 12'.tr(context),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: setsController,
                decoration: InputDecoration(
                  labelText: 'Set sayısı'.tr(context),
                  hintText: 'Örn. 3'.tr(context),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text('Vazgeç'.tr(context)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                final reps = int.tryParse(repsController.text.trim());
                if (reps == null || reps < 1) return;
                final sets = int.tryParse(setsController.text.trim());
                if (sets == null || sets < 1) return;
                Navigator.of(context).pop('ok');
              },
              child: Text('Ekle'.tr(context)),
            ),
          ],
        );
      },
    );

    if (result != 'ok') return;

    final reps = int.tryParse(repsController.text.trim()) ?? 12;
    final sets = int.tryParse(setsController.text.trim()) ?? 3;

    setState(() {
      final current = _planForDay(_selectedDayIndex);
      final updated = List<_WorkoutExercise>.from(current.exercises)
        ..add(_WorkoutExercise(name: nameController.text.trim(), reps: reps, sets: sets));
      _plans[_selectedDayIndex] = _WorkoutPlan(
        region: current.region,
        exercises: updated,
      );
    });
    await _saveSportPlans();
  }

  Future<void> _editExercise(int index) async {
    final current = _planForDay(_selectedDayIndex);
    if (index < 0 || index >= current.exercises.length) return;

    final ex = current.exercises[index];
    final nameController = TextEditingController(text: ex.name);
    final repsController = TextEditingController(text: '${ex.reps}');
    final setsController = TextEditingController(text: '${ex.sets}');

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Hareketi düzenle'.tr(context)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Hareket adı'.tr(context)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: repsController,
                decoration: InputDecoration(labelText: 'Tekrar sayısı'.tr(context)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: setsController,
                decoration: InputDecoration(labelText: 'Set sayısı'.tr(context)),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('delete'),
              child: const Text(
                'Sil',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text('Vazgeç'.tr(context)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                final reps = int.tryParse(repsController.text.trim());
                if (reps == null || reps < 1) return;
                final sets = int.tryParse(setsController.text.trim());
                if (sets == null || sets < 1) return;
                Navigator.of(context).pop('save');
              },
              child: Text('Kaydet'.tr(context)),
            ),
          ],
        );
      },
    );

    if (result == 'delete') {
      setState(() {
        final updated = List<_WorkoutExercise>.from(current.exercises)..removeAt(index);
        _plans[_selectedDayIndex] = _WorkoutPlan(
          region: current.region,
          exercises: updated,
        );
      });
      await _saveSportPlans();
    } else if (result == 'save') {
      final reps = int.tryParse(repsController.text.trim()) ?? ex.reps;
      final sets = int.tryParse(setsController.text.trim()) ?? ex.sets;
      setState(() {
        final updated = List<_WorkoutExercise>.from(current.exercises);
        updated[index] = _WorkoutExercise(name: nameController.text.trim(), reps: reps, sets: sets);
        _plans[_selectedDayIndex] = _WorkoutPlan(
          region: current.region,
          exercises: updated,
        );
      });
      await _saveSportPlans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final plan = _planForDay(_selectedDayIndex);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Haftalık spor planın',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final weekDays = _weekDays();
              final cellWidth = constraints.maxWidth / 7;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: List.generate(7, (index) {
                    final d = weekDays[index];
                    final isSelected = index == _selectedDayIndex;
                    return SizedBox(
                      width: cellWidth,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDayIndex = index),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dayLabels[index],
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? colorScheme.primary : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? colorScheme.primary : Colors.white38,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${d.day}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bu günün bölgesi',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: _changeRegion,
                        child: Text('Planını düzenle'.tr(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.region == _regions[0] ? 'Henüz seçilmedi' : plan.region,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: plan.exercises.isEmpty
                ? Center(
                    child: Text(
                      'Bu gün için eklenmiş hareket yok.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: plan.exercises.length,
                    itemBuilder: (context, index) {
                      final ex = plan.exercises[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(ex.name),
                          subtitle: Text('${ex.sets} set x ${ex.reps} tekrar'.tr(context)),
                          onTap: () => _editExercise(index),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: Text('Hareket ekle'.tr(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutPlan {
  _WorkoutPlan({
    required this.region,
    required this.exercises,
  });

  final String region;
  final List<_WorkoutExercise> exercises;
}

class _WorkoutExercise {
  _WorkoutExercise({required this.name, required this.reps, required this.sets});

  final String name;
  final int reps;
  final int sets;
}

class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<_Transaction> _transactions = [];
  final List<_WatchlistItem> _watchlist = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFinance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFinance() async {
    final prefs = await SharedPreferences.getInstance();
    final txJson = prefs.getString('finance_transactions');
    if (txJson != null) {
      try {
        final list = jsonDecode(txJson) as List<dynamic>;
        _transactions.clear();
        for (final x in list) {
          final m = x as Map<String, dynamic>;
          _transactions.add(_Transaction(
            type: m['type'] as String? ?? 'gider',
            amount: (m['amount'] as num?)?.toDouble() ?? 0,
            title: m['title'] as String? ?? '',
            dateKey: m['date'] as String? ?? '',
          ));
        }
      } catch (_) {}
    }
    final watchJson = prefs.getString('finance_watchlist');
    if (watchJson != null) {
      try {
        final list = jsonDecode(watchJson) as List<dynamic>;
        _watchlist.clear();
        for (final x in list) {
          final m = x as Map<String, dynamic>;
          _watchlist.add(_WatchlistItem(
            name: m['name'] as String? ?? '',
            symbol: m['symbol'] as String? ?? '',
          ));
        }
      } catch (_) {}
    }
    setState(() {});
  }

  Future<void> _saveFinance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('finance_transactions', jsonEncode(_transactions.map((t) => {
      'type': t.type,
      'amount': t.amount,
      'title': t.title,
      'date': t.dateKey,
    }).toList()));
    await prefs.setString('finance_watchlist', jsonEncode(_watchlist.map((w) => {
      'name': w.name,
      'symbol': w.symbol,
    }).toList()));
  }

  double get _totalGelir =>
      _transactions.where((t) => t.type == 'gelir').fold(0, (s, t) => s + t.amount);
  double get _totalGider =>
      _transactions.where((t) => t.type == 'gider').fold(0, (s, t) => s + t.amount);
  double get _balance => _totalGelir - _totalGider;

  Future<void> _addTransaction() async {
    String type = 'gider';
    final amountController = TextEditingController();
    final titleController = TextEditingController();
    final date = DateTime.now();
    String dateKey = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Gelir / Gider ekle'.tr(context)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'gelir', label: Text('Gelir'.tr(context)), icon: const Icon(Icons.arrow_downward, size: 18)),
                        ButtonSegment(value: 'gider', label: Text('Gider'.tr(context)), icon: const Icon(Icons.arrow_upward, size: 18)),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) => setStateDialog(() => type = s.first),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: 'Açıklama'.tr(context), hintText: 'Örn. Maaş, Market'.tr(context)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Tutar (₺)'.tr(context)),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text('Tarih: $dateKey'.tr(context)),
                      trailing: TextButton(
                        onPressed: () async {
                          final p = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (p != null) {
                            setStateDialog(() {
                            dateKey = '${p.year.toString().padLeft(4, '0')}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}';
                          });
                          }
                        },
                        child: Text('Değiştir'.tr(context)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Vazgeç'.tr(context))),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    if (double.tryParse(amountController.text.replaceAll(',', '.')) == null) return;
                    Navigator.pop(context, true);
                  },
                  child: Text('Ekle'.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
    setState(() {
      _transactions.insert(0, _Transaction(type: type, amount: amount, title: titleController.text.trim(), dateKey: dateKey));
    });
    await _saveFinance();
  }

  Future<void> _deleteTransaction(int index) async {
    setState(() => _transactions.removeAt(index));
    await _saveFinance();
  }

  Future<void> _addWatchlist() async {
    final nameController = TextEditingController();
    final symbolController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Borsa takip listesine ekle'.tr(context)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Ad (Örn. Apple, BIST 100)'.tr(context)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: symbolController,
                decoration: InputDecoration(labelText: 'Sembol (isteğe bağlı)'.tr(context), hintText: 'AAPL, XU100'.tr(context)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Vazgeç'.tr(context))),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: Text('Ekle'.tr(context)),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    setState(() {
      _watchlist.add(_WatchlistItem(name: nameController.text.trim(), symbol: symbolController.text.trim()));
    });
    await _saveFinance();
  }

  Future<void> _removeWatchlist(int index) async {
    setState(() => _watchlist.removeAt(index));
    await _saveFinance();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'Gelir-Gider'),
            Tab(text: 'Borsam'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGelirGider(theme, colorScheme),
              _buildBorsam(theme, colorScheme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGelirGider(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryChip('Gelir', _totalGelir, Colors.green, colorScheme),
                      _summaryChip('Gider', _totalGider, Colors.red, colorScheme),
                      _summaryChip('Bakiye', _balance, _balance >= 0 ? Colors.green : Colors.red, colorScheme),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addTransaction,
              icon: const Icon(Icons.add),
              label: Text('Gelir / Gider ekle'.tr(context)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _transactions.isEmpty
              ? Center(
                  child: Text(
                    'Henüz kayıt yok. Gelir veya gider ekleyebilirsin.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    final isGelir = t.type == 'gelir';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isGelir ? Colors.green : Colors.red).withOpacity(0.2),
                          child: Icon(isGelir ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isGelir ? Colors.green : Colors.red, size: 20),
                        ),
                        title: Text(t.title),
                        subtitle: Text(t.dateKey),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isGelir ? '+' : '-'} ${t.amount.toStringAsFixed(2)} ₺',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isGelir ? Colors.green : Colors.red,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteTransaction(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, double value, Color color, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colorScheme.outline)),
        const SizedBox(height: 4),
        Text(
          '${value >= 0 ? '' : '-'}${value.abs().toStringAsFixed(0)} ₺',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color),
        ),
      ],
    );
  }

  Widget _buildBorsam(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Takip listem',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addWatchlist,
              icon: const Icon(Icons.add_chart),
              label: Text('Hisse / endeks ekle'.tr(context)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _watchlist.isEmpty
              ? Center(
                  child: Text(
                    'Borsa takip listen boş. Hisse veya endeks ekleyebilirsin.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _watchlist.length,
                  itemBuilder: (context, index) {
                    final w = _watchlist[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.show_chart, color: colorScheme.onPrimaryContainer, size: 20),
                        ),
                        title: Text(w.name),
                        subtitle: w.symbol.isNotEmpty ? Text(w.symbol) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _removeWatchlist(index),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Transaction {
  _Transaction({required this.type, required this.amount, required this.title, required this.dateKey});
  final String type;
  final double amount;
  final String title;
  final String dateKey;
}

class _WatchlistItem {
  _WatchlistItem({required this.name, required this.symbol});
  final String name;
  final String symbol;
}

class RoutinesTab extends StatefulWidget {
  const RoutinesTab({super.key});

  @override
  State<RoutinesTab> createState() => _RoutinesTabState();
}

class _RoutinesTabState extends State<RoutinesTab> {
  static const List<String> _dayLabels = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  DateTime _selectedDate = DateTime.now();
  final Map<int, List<_RoutineItem>> _routinesByDay = {};
  final Map<String, List<bool>> _completions = {};

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List<DateTime> _weekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<_RoutineItem> _routinesFor(int dayIndex) {
    return _routinesByDay[dayIndex] ?? [];
  }

  List<bool> _completionsFor(DateTime date) {
    final key = _dateKey(date);
    final dayIndex = date.weekday - 1;
    final routines = _routinesFor(dayIndex);
    final list = _completions[key] ?? List.filled(routines.length, false);
    if (list.length != routines.length) {
      return List.generate(routines.length, (i) => i < list.length ? list[i] : false);
    }
    return list;
  }

  void _setCompleted(DateTime date, int routineIndex, bool value) {
    final key = _dateKey(date);
    final list = List<bool>.from(_completionsFor(date));
    if (routineIndex >= list.length) return;
    list[routineIndex] = value;
    _completions[key] = list;
    _saveRoutines();
    setState(() {});
  }

  Future<void> _loadRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('routines');
    if (jsonStr != null) {
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        _routinesByDay.clear();
        for (final e in data.entries) {
          if (e.key == 'completions') continue;
          final dayIndex = int.tryParse(e.key);
          if (dayIndex == null || dayIndex < 0 || dayIndex > 6) continue;
          final list = (e.value as List<dynamic>).map((x) {
            final m = x as Map<String, dynamic>;
            return _RoutineItem(
              title: m['title'] as String? ?? '',
              hour: m['hour'] as int? ?? 8,
              minute: m['minute'] as int? ?? 0,
              reminder: m['reminder'] as bool? ?? false,
              notificationId: m['notificationId'] as int?,
            );
          }).toList();
          _routinesByDay[dayIndex] = list;
        }
        final comp = data['completions'] as Map<String, dynamic>?;
        if (comp != null) {
          _completions.clear();
          comp.forEach((k, v) {
            _completions[k] = (v as List<dynamic>).cast<bool>();
          });
        }
      } catch (_) {}
    }
    setState(() {});
  }

  Future<void> _saveRoutines() async {
    final data = <String, dynamic>{};
    _routinesByDay.forEach((dayIndex, list) {
      data['$dayIndex'] = list.map((r) => {'title': r.title, 'hour': r.hour, 'minute': r.minute, 'reminder': r.reminder, 'notificationId': r.notificationId}).toList();
    });
    data['completions'] = _completions.map((k, v) => MapEntry(k, v));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('routines', jsonEncode(data));
  }

  Future<void> _addRoutine() async {
    final dayIndex = _selectedDate.weekday - 1;
    final titleController = TextEditingController();
    TimeOfDay pickedTime = const TimeOfDay(hour: 8, minute: 0);
    bool wantReminder = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Rutin ekle'.tr(context)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Rutin adı'.tr(context),
                        hintText: 'Örn. Diş fırçala, İlaç al'.tr(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text('Gün içinde hangi saatte?'.tr(context)),
                      subtitle: Text('${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}'),
                      trailing: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: pickedTime);
                          if (t != null) setStateDialog(() => pickedTime = t);
                        },
                        child: Text('Saat seç'.tr(context)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: wantReminder,
                      onChanged: (v) => setStateDialog(() => wantReminder = v ?? false),
                      title: Text('Bildirim hatırlatıcı olsun mu?'.tr(context)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Vazgeç'.tr(context))),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.of(context).pop(true);
                  },
                  child: Text('Ekle'.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    int? notificationId;
    if (wantReminder) {
      notificationId = nextNotificationId();
      await scheduleRoutineReminder(notificationId, titleController.text.trim(), dayIndex + 1, pickedTime.hour, pickedTime.minute);
    }
    setState(() {
      final list = List<_RoutineItem>.from(_routinesFor(dayIndex));
      list.add(_RoutineItem(
        title: titleController.text.trim(),
        hour: pickedTime.hour,
        minute: pickedTime.minute,
        reminder: wantReminder,
        notificationId: notificationId,
      ));
      _routinesByDay[dayIndex] = list;
    });
    await _saveRoutines();
  }

  Future<void> _editRoutine(int index) async {
    final dayIndex = _selectedDate.weekday - 1;
    final list = _routinesFor(dayIndex);
    if (index < 0 || index >= list.length) return;

    final item = list[index];
    final titleController = TextEditingController(text: item.title);
    TimeOfDay pickedTime = TimeOfDay(hour: item.hour, minute: item.minute);
    bool wantReminder = item.reminder;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Rutini düzenle'.tr(context)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: 'Rutin adı'.tr(context)),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text('Saat'.tr(context)),
                      subtitle: Text('${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}'),
                      trailing: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: pickedTime);
                          if (t != null) setStateDialog(() => pickedTime = t);
                        },
                        child: Text('Değiştir'.tr(context)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: wantReminder,
                      onChanged: (v) => setStateDialog(() => wantReminder = v ?? false),
                      title: Text('Bildirim hatırlatıcı olsun mu?'.tr(context)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop('delete'), child: Text('Sil'.tr(context), style: TextStyle(color: Colors.red))),
                TextButton(onPressed: () => Navigator.of(context).pop('cancel'), child: Text('Vazgeç'.tr(context))),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.of(context).pop('save');
                  },
                  child: Text('Kaydet'.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == 'delete') {
      if (item.notificationId != null) await cancelReminderNotification(item.notificationId!);
      setState(() {
        final newList = List<_RoutineItem>.from(list)..removeAt(index);
        _routinesByDay[dayIndex] = newList;
      });
      await _saveRoutines();
    } else if (result == 'save') {
      if (item.notificationId != null) await cancelReminderNotification(item.notificationId!);
      int? notificationId;
      if (wantReminder) {
        notificationId = nextNotificationId();
        await scheduleRoutineReminder(notificationId, titleController.text.trim(), dayIndex + 1, pickedTime.hour, pickedTime.minute);
      }
      setState(() {
        final newList = List<_RoutineItem>.from(list);
        newList[index] = _RoutineItem(
          title: titleController.text.trim(),
          hour: pickedTime.hour,
          minute: pickedTime.minute,
          reminder: wantReminder,
          notificationId: notificationId,
        );
        _routinesByDay[dayIndex] = newList;
      });
      await _saveRoutines();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final weekDays = _weekDays();
    final dayIndex = _selectedDate.weekday - 1;
    final routines = _routinesFor(dayIndex);
    final completions = _completionsFor(_selectedDate);
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isToday ? 'Bugün' : '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = constraints.maxWidth / 7;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: List.generate(7, (index) {
                    final d = weekDays[index];
                    final selected = _isSameDay(d, _selectedDate);
                    return SizedBox(
                      width: cellWidth,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDate = d),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dayLabels[index],
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: selected ? Colors.white : Colors.white70,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected ? colorScheme.primary : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected ? colorScheme.primary : Colors.white38,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${d.day}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: routines.isEmpty
                ? Center(
                    child: Text(
                      'Bu gün için rutin yok.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: routines.length,
                    itemBuilder: (context, index) {
                      final r = routines[index];
                      final done = index < completions.length && completions[index];
                      final timeStr = '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Checkbox(
                            value: done,
                            onChanged: (v) => _setCompleted(_selectedDate, index, v ?? false),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          title: Text(
                            r.title,
                            style: TextStyle(
                              decoration: done ? TextDecoration.lineThrough : null,
                              color: done ? colorScheme.outline : null,
                            ),
                          ),
                          subtitle: Text(timeStr),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (r.reminder) Icon(Icons.alarm, size: 20, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 20),
                            ],
                          ),
                          onTap: () => _editRoutine(index),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addRoutine,
              icon: const Icon(Icons.add),
              label: Text('Rutin ekle'.tr(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineItem {
  _RoutineItem({required this.title, required this.hour, required this.minute, this.reminder = false, this.notificationId});
  final String title;
  final int hour;
  final int minute;
  final bool reminder;
  final int? notificationId;
}

class ActivitiesTab extends StatefulWidget {
  const ActivitiesTab({super.key});

  @override
  State<ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<ActivitiesTab> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, List<_Activity>> _activities = {};

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('activities');
    if (jsonStr == null) return;
    final List<dynamic> data = jsonDecode(jsonStr) as List<dynamic>;
    _activities.clear();
    for (final item in data) {
      final map = item as Map<String, dynamic>;
      final dateKey = map['date'] as String;
      final title = map['title'] as String? ?? '';
      final hour = map['hour'] as int? ?? 0;
      final minute = map['minute'] as int? ?? 0;
      final list = _activities[dateKey] ?? [];
      list.add(
        _Activity(
          title: title,
          time: TimeOfDay(hour: hour, minute: minute),
          reminder: map['reminder'] as bool? ?? false,
          notificationId: map['notificationId'] as int?,
        ),
      );
      _activities[dateKey] = list;
    }
    setState(() {});
  }

  Future<void> _saveActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> data = [];
    _activities.forEach((dateKey, list) {
      for (final activity in list) {
        data.add({
          'date': dateKey,
          'title': activity.title,
          'hour': activity.time.hour,
          'minute': activity.time.minute,
          'reminder': activity.reminder,
          'notificationId': activity.notificationId,
        });
      }
    });
    await prefs.setString('activities', jsonEncode(data));
  }

  List<_Activity> get _currentActivities {
    final key = _dateKey(_selectedDate);
    final list = List<_Activity>.from(_activities[key] ?? []);
    list.sort((a, b) => a.time.hour != b.time.hour
        ? a.time.hour.compareTo(b.time.hour)
        : a.time.minute.compareTo(b.time.minute));
    return list;
  }
  Future<void> _addActivity() async {
    final titleController = TextEditingController();
    TimeOfDay? pickedTime;
    final wantReminderRef = <bool>[false];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Aktivite ekle'.tr(context)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: 'Başlık'.tr(context)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pickedTime == null
                              ? 'Saat seçilmedi'
                              : '${pickedTime!.hour.toString().padLeft(2, '0')}:${pickedTime!.minute.toString().padLeft(2, '0')}',
                        ),
                        TextButton(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: pickedTime ?? TimeOfDay.now(),
                            );
                            if (time != null) setStateDialog(() => pickedTime = time);
                          },
                          child: Text('Saat seç'.tr(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: wantReminderRef[0],
                      onChanged: (v) {
                        wantReminderRef[0] = v ?? false;
                        setStateDialog(() {});
                      },
                      title: Text('Bildirim hatırlatıcı olsun mu?'.tr(context)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Vazgeç'.tr(context))),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty || pickedTime == null) return;
                    final key = _dateKey(_selectedDate);
                    final list = _activities[key] ?? [];
                    final wantReminder = wantReminderRef[0];
                    int? notificationId;
                    if (wantReminder) {
                      notificationId = nextNotificationId();
                      final when = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, pickedTime!.hour, pickedTime!.minute);
                      await scheduleActivityReminder(notificationId, titleController.text.trim(), when);
                    }
                    list.add(_Activity(
                      title: titleController.text.trim(),
                      time: pickedTime!,
                      reminder: wantReminder,
                      notificationId: notificationId,
                    ));
                    _activities[key] = list;
                    await _saveActivities();
                    if (!mounted) return;
                    setState(() {});
                    Navigator.of(context).pop();
                  },
                  child: Text('Ekle'.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static const List<String> _dayNames = [
    'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz',
  ];

  /// Seçili tarihin haftası (Pzt–Paz).
  List<DateTime> _weekDays() {
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  Future<void> _openCalendar() async {
    final datesWithActivities = <String>{};
    for (final entry in _activities.entries) {
      if (entry.value.isNotEmpty) datesWithActivities.add(entry.key);
    }
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _ActivityCalendarDialog(
        initialDate: _selectedDate,
        datesWithActivities: datesWithActivities,
        dateKey: _dateKey,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final activities = _currentActivities;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final weekDays = _weekDays();
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isToday ? 'Bugün' : '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(7, (i) {
                      final d = weekDays[i];
                      final selected = _isSameDay(d, _selectedDate);
                      final hasActivity = (_activities[_dateKey(d)] ?? []).isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDate = d),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayNames[i],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: selected ? Colors.white : Colors.white70,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 32,
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? colorScheme.primary
                                      : hasActivity
                                          ? colorScheme.primaryContainer.withOpacity(0.4)
                                          : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? colorScheme.primary
                                        : hasActivity
                                            ? colorScheme.primary.withOpacity(0.8)
                                            : Colors.white38,
                                    width: hasActivity && !selected ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  '${d.day}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: colorScheme.primaryContainer.withOpacity(0.6),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _openCalendar,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.calendar_today, size: 20, color: colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.nightlight_round_outlined,
                        size: 80,
                        color: Colors.white38,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bu gün için aktivite yok',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    final timeText =
                        '${activity.time.hour.toString().padLeft(2, '0')}:${activity.time.minute.toString().padLeft(2, '0')}';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Text(timeText, style: const TextStyle(fontWeight: FontWeight.w500)),
                        title: Text(activity.title),
                        trailing: activity.reminder
                            ? Icon(Icons.alarm, size: 22, color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () => _editActivity(index),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addActivity,
              icon: const Icon(Icons.add),
              label: Text('Aktivite ekle'.tr(context)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editActivity(int index) async {
    final key = _dateKey(_selectedDate);
    final list = _activities[key] ?? [];
    if (index < 0 || index >= list.length) return;
    final current = list[index];

    final titleController = TextEditingController(text: current.title);
    TimeOfDay pickedTime = current.time;
    bool wantReminder = current.reminder;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Aktiviteyi düzenle'.tr(context)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: 'Başlık'.tr(context)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}'),
                        TextButton(
                          onPressed: () async {
                            final time = await showTimePicker(context: context, initialTime: pickedTime);
                            if (time != null) setStateDialog(() => pickedTime = time);
                          },
                          child: Text('Saat değiştir'.tr(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: wantReminder,
                      onChanged: (v) => setStateDialog(() => wantReminder = v ?? false),
                      title: Text('Bildirim hatırlatıcı olsun mu?'.tr(context)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop('delete'), child: Text('Sil'.tr(context), style: TextStyle(color: Colors.red))),
                TextButton(onPressed: () => Navigator.of(context).pop('cancel'), child: Text('Vazgeç'.tr(context))),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.of(context).pop('save');
                  },
                  child: Text('Kaydet'.tr(context)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == 'delete') {
      if (current.notificationId != null) await cancelReminderNotification(current.notificationId!);
      list.removeAt(index);
      _activities[key] = list;
      await _saveActivities();
      if (!mounted) return;
      setState(() {});
    } else if (result == 'save') {
      if (current.notificationId != null) await cancelReminderNotification(current.notificationId!);
      int? notificationId;
      if (wantReminder) {
        notificationId = nextNotificationId();
        final when = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, pickedTime.hour, pickedTime.minute);
        await scheduleActivityReminder(notificationId, titleController.text.trim(), when);
      }
      list[index] = _Activity(
        title: titleController.text.trim(),
        time: pickedTime,
        reminder: wantReminder,
        notificationId: notificationId,
      );
      _activities[key] = list;
      await _saveActivities();
      if (!mounted) return;
      setState(() {});
    }
  }
}

/// Takvim ikonuna tıklanınca açılan takvim; aktivitesi olan günleri vurgular.
class _ActivityCalendarDialog extends StatefulWidget {
  const _ActivityCalendarDialog({
    required this.initialDate,
    required this.datesWithActivities,
    required this.dateKey,
  });

  final DateTime initialDate;
  final Set<String> datesWithActivities;
  final String Function(DateTime) dateKey;

  @override
  State<_ActivityCalendarDialog> createState() => _ActivityCalendarDialogState();
}

class _ActivityCalendarDialogState extends State<_ActivityCalendarDialog> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  static const List<String> _weekHeaders = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  bool _hasActivity(DateTime d) =>
      widget.datesWithActivities.contains(widget.dateKey(d));

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final daysInMonth = last.day;
    final firstWeekday = first.weekday;
    final leadingEmpty = firstWeekday - 1;
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final monthNames = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];

    return AlertDialog(
      title: Text('Tarih seçin'.tr(context)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(year, month - 1);
                    });
                  },
                ),
                Text(
                  '${monthNames[month - 1]} $year',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(year, month + 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _weekHeaders.map((h) => SizedBox(width: 32, child: Center(child: Text(h, style: theme.textTheme.bodySmall)))).toList(),
            ),
            const SizedBox(height: 4),
            ...List.generate(rows, (row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (col) {
                    final cellIndex = row * 7 + col;
                    if (cellIndex < leadingEmpty) {
                      return const SizedBox(width: 32, height: 32);
                    }
                    final day = cellIndex - leadingEmpty + 1;
                    if (day > daysInMonth) {
                      return const SizedBox(width: 32, height: 32);
                    }
                    final date = DateTime(year, month, day);
                    final selected = _isSameDay(date, widget.initialDate);
                    final hasActivity = _hasActivity(date);
                    return SizedBox(
                      width: 32,
                      height: 32,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(date),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? colorScheme.primary
                                  : hasActivity
                                      ? colorScheme.primaryContainer.withOpacity(0.4)
                                      : null,
                              border: Border.all(
                                color: selected
                                    ? colorScheme.primary
                                    : hasActivity
                                        ? colorScheme.primary.withOpacity(0.8)
                                        : colorScheme.outline.withOpacity(0.3),
                                width: hasActivity && !selected ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('İptal'.tr(context)),
        ),
      ],
    );
  }
}

class _Activity {
  _Activity({
    required this.title,
    required this.time,
    this.reminder = false,
    this.notificationId,
  });

  final String title;
  final TimeOfDay time;
  final bool reminder;
  final int? notificationId;
}

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NoteItem {
  _NoteItem({required this.title, required this.body});
  final String title;
  final String body;
}

class _NotesTabState extends State<NotesTab> {
  final List<_NoteItem> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    _notes.clear();
    final jsonStr = prefs.getString('notes_v2');
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        for (final item in list) {
          final m = item as Map<String, dynamic>;
          _notes.add(_NoteItem(
            title: m['title'] as String? ?? '',
            body: m['body'] as String? ?? '',
          ));
        }
      } catch (_) {}
    }
    if (_notes.isEmpty) {
      final oldList = prefs.getStringList('notes');
      if (oldList != null) {
        for (final s in oldList) {
          _notes.add(_NoteItem(title: '', body: s));
        }
      }
    }
    setState(() {});
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _notes.map((n) => {'title': n.title, 'body': n.body}).toList();
    await prefs.setString('notes_v2', jsonEncode(list));
  }

  Future<void> _addNote() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Yeni not'.tr(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Başlık'.tr(context),
                    hintText: 'Not başlığı'.tr(context),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Not'.tr(context),
                    hintText: 'Notunu yaz...'.tr(context),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Vazgeç'.tr(context)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty && bodyController.text.trim().isEmpty) return;
                setState(() {
                  _notes.insert(0, _NoteItem(
                    title: titleController.text.trim(),
                    body: bodyController.text.trim(),
                  ));
                });
                await _saveNotes();
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              child: Text('Kaydet'.tr(context)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _notes.isEmpty
              ? Center(
                  child: Text(
                    'Henüz not yok.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final displayTitle = note.title.isEmpty ? (note.body.isEmpty ? 'Başlıksız not' : note.body) : note.title;
                    final displaySubtitle = note.title.isEmpty ? null : (note.body.isEmpty ? null : note.body);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: displaySubtitle != null ? Text(displaySubtitle, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                        onTap: () => _editNote(index),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addNote,
              icon: const Icon(Icons.add),
              label: Text('Yeni not ekle'.tr(context)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editNote(int index) async {
    if (index < 0 || index >= _notes.length) return;
    final note = _notes[index];
    final titleController = TextEditingController(text: note.title);
    final bodyController = TextEditingController(text: note.body);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Notu düzenle'.tr(context)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Başlık'.tr(context),
                    hintText: 'Not başlığı'.tr(context),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Not'.tr(context),
                    hintText: 'Notunu yaz...'.tr(context),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('delete'),
              child: const Text(
                'Sil',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text('Vazgeç'.tr(context)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('save'),
              child: Text('Kaydet'.tr(context)),
            ),
          ],
        );
      },
    );

    if (result == 'delete') {
      setState(() {
        _notes.removeAt(index);
      });
      await _saveNotes();
    } else if (result == 'save') {
      setState(() {
        _notes[index] = _NoteItem(
          title: titleController.text.trim(),
          body: bodyController.text.trim(),
        );
      });
      await _saveNotes();
    }
  }
}

/// Sağdaki ayarlar ekranı
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  DateTime? _birthDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().currentUser;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _birthDate = user.birthDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _save(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen doğum tarihini seç'.tr(context))),
      );
      return;
    }
    final appState = context.read<AppState>();
    await appState.updateProfile(
      name: _nameController.text.trim(),
      birthDate: _birthDate!,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bilgilerin güncellendi'.tr(context))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final email = user?.email ?? '';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ayarlar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hesap bilgilerini burada düzenleyebilirsin.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: email,
                  readOnly: true,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  decoration: InputDecoration(
                    labelText: 'E-posta'.tr(context),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  decoration: InputDecoration(
                    labelText: 'Adın'.tr(context),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen adını gir';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Doğum tarihin'.tr(context),
                    ),
                    child: Text(
                      _birthDate == null
                          ? 'Seç'
                          : '${_birthDate!.day.toString().padLeft(2, '0')}.'
                              '${_birthDate!.month.toString().padLeft(2, '0')}.'
                              '${_birthDate!.year}',
                      style: TextStyle(
                        color: _birthDate == null 
                          ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5) 
                          : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  labelText: 'Şifre'.tr(context),
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: Text('Karanlık mod'.tr(context)),
                value: context.watch<AppState>().isDarkMode,
                onChanged: (value) {
                  context.read<AppState>().setDarkMode(value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: context.watch<AppState>().locale.languageCode,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  labelText: 'Dil'.tr(context),
                ),
                dropdownColor: Theme.of(context).canvasColor,
                items: [
                  DropdownMenuItem(value: 'tr', child: Text('Türkçe'.tr(context))),
                  DropdownMenuItem(value: 'en', child: Text('English'.tr(context))),
                ],
                onChanged: (code) {
                  if (code == null) return;
                  context.read<AppState>().setLocale(Locale(code));
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _save(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4DB6AC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('Kaydet'.tr(context)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.read<AppState>().logout(),
                icon: const Icon(Icons.logout, size: 20),
                label: Text('Çıkış yap'.tr(context)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimplePlaceholder extends StatelessWidget {
  const _SimplePlaceholder({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AssistantTab extends StatefulWidget {
  const AssistantTab({super.key});

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('assistant_messages');
    if (jsonStr == null) return;
    try {
      final List<dynamic> data = jsonDecode(jsonStr) as List<dynamic>;
      final loaded = data.map((e) {
        final m = e as Map<String, dynamic>;
        return _ChatMessage(
          text: m['text'] as String? ?? '',
          fromUser: m['fromUser'] as bool? ?? false,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(loaded);
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _messages
        .map((m) => {'text': m.text, 'fromUser': m.fromUser})
        .toList();
    await prefs.setString('assistant_messages', jsonEncode(data));
  }

  Future<void> _clearChat() async {
    if (!mounted) return;
    setState(() {
      _messages.clear();
    });
    await _saveMessages();
  }

  Future<Map<String, dynamic>> _buildContextForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Tüm aktiviteler ve bugünün aktiviteleri
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final activitiesJson = prefs.getString('activities');
    final List<Map<String, dynamic>> todayActivities = [];
    final List<Map<String, dynamic>> allActivities = [];
    if (activitiesJson != null) {
      try {
        final List<dynamic> data =
            jsonDecode(activitiesJson) as List<dynamic>;
        for (final item in data) {
          final m = item as Map<String, dynamic>;
          final entry = {
            'date': m['date'],
            'title': m['title'],
            'hour': m['hour'],
            'minute': m['minute'],
            'reminder': m['reminder'],
          };
          allActivities.add(entry);
          if (m['date'] == todayKey) {
            todayActivities.add(entry);
          }
        }
      } catch (_) {}
    }

    // Tüm rutinler ve bugünün rutinleri
    final routinesJson = prefs.getString('routines');
    final List<Map<String, dynamic>> todayRoutines = [];
    final Map<String, List<Map<String, dynamic>>> routinesByWeekday = {};
    if (routinesJson != null) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(routinesJson) as Map<String, dynamic>;
        final weekdayIndex = now.weekday - 1; // 0 = Pazartesi
        for (final entry in data.entries) {
          if (entry.key == 'completions') continue;
          final dayIndex = int.tryParse(entry.key);
          if (dayIndex == null || dayIndex < 0 || dayIndex > 6) continue;
          final list = entry.value as List<dynamic>;
          final dayList = <Map<String, dynamic>>[];
          for (final item in list) {
            final m = item as Map<String, dynamic>;
            final routineEntry = {
              'weekday': dayIndex,
              'title': m['title'],
              'hour': m['hour'],
              'minute': m['minute'],
              'reminder': m['reminder'],
            };
            dayList.add(routineEntry);
            if (dayIndex == weekdayIndex) {
              todayRoutines.add(routineEntry);
            }
          }
          routinesByWeekday['$dayIndex'] = dayList;
        }
      } catch (_) {}
    }

    // Spor planları (haftanın her günü için)
    final sportJson = prefs.getString('sport_plans');
    Map<String, dynamic>? sportPlans;
    if (sportJson != null) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(sportJson) as Map<String, dynamic>;
        final Map<String, dynamic> result = {};
        data.forEach((dayKey, value) {
          final m = value as Map<String, dynamic>;
          final exercises = <Map<String, dynamic>>[];
          final rawExercises = m['exercises'] as List<dynamic>? ?? [];
          for (final ex in rawExercises) {
            final em = ex as Map<String, dynamic>;
            exercises.add({
              'name': em['name'],
              'reps': em['reps'],
              'sets': em['sets'],
            });
          }
          result[dayKey] = {
            'region': m['region'],
            'exercises': exercises,
          };
        });
        sportPlans = result;
      } catch (_) {}
    }

    // Finans özeti (sadece sayı ve toplamlar)
    final financeJson = prefs.getString('finance_transactions');
    Map<String, dynamic>? financeSummary;
    if (financeJson != null) {
      try {
        final List<dynamic> data =
            jsonDecode(financeJson) as List<dynamic>;
        double income = 0;
        double expense = 0;
        for (final item in data) {
          final m = item as Map<String, dynamic>;
          final amount = (m['amount'] as num?)?.toDouble() ?? 0;
          final type = m['type'] as String? ?? 'expense';
          if (type == 'income') {
            income += amount;
          } else {
            expense += amount;
          }
        }
        financeSummary = {
          'total_income': income,
          'total_expense': expense,
          'net': income - expense,
          'transaction_count': data.length,
        };
      } catch (_) {}
    }

    // Not başlıkları (içeriğin tamamını göndermeyelim, sadece özet)
    final notesJson = prefs.getString('notes_v2');
    final List<Map<String, String>> notesSummary = [];
    if (notesJson != null) {
      try {
        final List<dynamic> data =
            jsonDecode(notesJson) as List<dynamic>;
        for (final item in data) {
          final m = item as Map<String, dynamic>;
          final title = (m['title'] as String? ?? '').trim();
          final body = (m['body'] as String? ?? '').trim();
          final preview =
              body.length > 120 ? '${body.substring(0, 117)}...' : body;
          notesSummary.add({
            'title': title,
            'preview': preview,
          });
        }
      } catch (_) {}
    }

    return {
      'today_date': todayKey,
      'today_activities': todayActivities,
      'today_routines': todayRoutines,
      'all_activities': allActivities,
      'routines_by_weekday': routinesByWeekday,
      'sport_plans_by_weekday': sportPlans,
      'finance_summary': financeSummary,
      'notes_summary': notesSummary,
    };
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _controller.clear();
    });
    _scrollToBottom();
    // Kullanıcı mesajını kaydet
    _saveMessages();

    if (_isSending) return;
    setState(() {
      _isSending = true;
    });

    try {
      final appState = context.read<AppState>();
      final token = appState.currentUser?.token;
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _messages.add(
            _ChatMessage(
              text:
                  'Asistanı kullanmak için önce giriş yapmalısın. Profil sekmesinden giriş yapmayı dene.',
              fromUser: false,
            ),
          );
        });
        _scrollToBottom();
        _saveMessages();
        return;
      }

      final uri =
          Uri.parse('${AppState._baseUrl}/assistant/chat');
      final contextPayload = await _buildContextForToday();
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': text,
          'context': contextPayload,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body) as Map<String, dynamic>;
        String reply = data['reply']?.toString() ??
            'Asistan şu an beklenmedik bir cevap döndürdü.';
        var action = data['action'];

        // Backend bazen doğrudan markdown json formatında yanıt verebiliyor, bunu temizleyip tekrar çözümleyelim
        final rawReply = reply.trim();
        if (rawReply.startsWith('```json') || rawReply.startsWith('{')) {
          try {
            var cleanStr = rawReply;
            if (cleanStr.startsWith('```json')) {
              cleanStr = cleanStr.replaceAll('```json', '').replaceAll('```', '').trim();
            }
            final innerParsed = jsonDecode(cleanStr);
            if (innerParsed is Map<String, dynamic>) {
              if (innerParsed.containsKey('reply')) {
                reply = innerParsed['reply'].toString();
              }
              if (innerParsed.containsKey('action')) {
                action = innerParsed['action'];
              }
            }
          } catch (_) {
            // Json parse edilemezse orijinal metni bırak
          }
        }
        setState(() {
          _messages.add(
            _ChatMessage(
              text: reply,
              fromUser: false,
            ),
          );
        });
        _saveMessages();
        if (action is Map<String, dynamic>) {
          await _handleAction(action);
        }
      } else {
        setState(() {
          _messages.add(
            _ChatMessage(
              text:
                  'Asistan şu an yanıt veremiyor (hata kodu: ${response.statusCode}). '
                  'Bir süre sonra tekrar dene.',
              fromUser: false,
            ),
          );
        });
        _saveMessages();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text:
                'Asistan ile bağlantı kurarken bir hata oluştu: $e',
            fromUser: false,
          ),
        );
      });
      _saveMessages();
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleAction(Map<String, dynamic> action) async {
    final type = action['type'] as String?;
    final payload = action['payload'];
    if (type == null || payload is! Map<String, dynamic>) return;

    try {
      switch (type) {
        case 'add_activity':
          await _handleAddActivity(payload);
          break;
        case 'add_routine':
          await _handleAddRoutine(payload);
          break;
        case 'add_finance_transaction':
          await _handleAddFinanceTransaction(payload);
          break;
        case 'add_note':
          await _handleAddNote(payload);
          break;
        case 'set_sport_plan_for_day':
          await _handleSetSportPlanForDay(payload);
          break;
      }
    } catch (_) {
      // Sessizce yut; kullanıcıya sadece metin cevabı gösteriliyor.
    }
  }

  Future<void> _handleAddActivity(Map<String, dynamic> payload) async {
    final dateStr = payload['date'] as String? ?? '';
    final title = payload['title'] as String? ?? '';
    final hour = payload['hour'] as int? ?? 0;
    final minute = payload['minute'] as int? ?? 0;
    final reminder = payload['reminder'] as bool? ?? false;
    if (dateStr.isEmpty || title.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('activities');
    final List<dynamic> data =
        jsonStr != null ? (jsonDecode(jsonStr) as List<dynamic>) : [];

    int? notificationId;
    if (reminder) {
      notificationId = nextNotificationId();
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]) ?? DateTime.now().year;
        final m = int.tryParse(parts[1]) ?? DateTime.now().month;
        final d = int.tryParse(parts[2]) ?? DateTime.now().day;
        final when = DateTime(y, m, d, hour, minute);
        await scheduleActivityReminder(notificationId, title, when);
      }
    }

    data.add({
      'date': dateStr,
      'title': title,
      'hour': hour,
      'minute': minute,
      'reminder': reminder,
      'notificationId': notificationId,
    });

    await prefs.setString('activities', jsonEncode(data));
  }

  Future<void> _handleAddRoutine(Map<String, dynamic> payload) async {
    final weekday = payload['weekday'] as int?; // 0-6
    final title = payload['title'] as String? ?? '';
    final hour = payload['hour'] as int? ?? 8;
    final minute = payload['minute'] as int? ?? 0;
    final reminder = payload['reminder'] as bool? ?? false;
    if (weekday == null || weekday < 0 || weekday > 6) return;
    if (title.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('routines');
    final Map<String, dynamic> data = jsonStr != null
        ? (jsonDecode(jsonStr) as Map<String, dynamic>)
        : <String, dynamic>{};

    final key = '$weekday';
    final List<dynamic> list =
        (data[key] as List<dynamic>?)?.toList() ?? <dynamic>[];

    int? notificationId;
    if (reminder) {
      notificationId = nextNotificationId();
      await scheduleRoutineReminder(
          notificationId, title, weekday + 1, hour, minute);
    }

    list.add({
      'title': title,
      'hour': hour,
      'minute': minute,
      'reminder': reminder,
      'notificationId': notificationId,
    });
    data[key] = list;

    data.putIfAbsent('completions', () => <String, dynamic>{});

    await prefs.setString('routines', jsonEncode(data));
  }

  Future<void> _handleAddFinanceTransaction(
      Map<String, dynamic> payload) async {
    final kind = payload['kind'] as String? ?? 'expense'; // income | expense
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    final title = payload['title'] as String? ?? '';
    final date = payload['date'] as String? ?? '';
    if (amount == 0 || title.trim().isEmpty || date.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('finance_transactions');
    final List<dynamic> data =
        jsonStr != null ? (jsonDecode(jsonStr) as List<dynamic>) : [];

    data.add({
      'type': kind == 'income' ? 'income' : 'expense',
      'amount': amount,
      'title': title,
      'date': date,
    });

    await prefs.setString('finance_transactions', jsonEncode(data));
  }

  Future<void> _handleAddNote(Map<String, dynamic> payload) async {
    final title = payload['title'] as String? ?? '';
    final body = payload['body'] as String? ?? '';
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('notes_v2');
    final List<dynamic> data =
        jsonStr != null ? (jsonDecode(jsonStr) as List<dynamic>) : [];

    data.add({
      'title': title,
      'body': body,
    });

    await prefs.setString('notes_v2', jsonEncode(data));
  }

  Future<void> _handleSetSportPlanForDay(
      Map<String, dynamic> payload) async {
    final weekday = payload['weekday'] as int?; // 0-6
    final region = payload['region'] as String? ?? 'Seçilmedi';
    final exercisesRaw = payload['exercises'] as List<dynamic>? ?? [];
    if (weekday == null || weekday < 0 || weekday > 6) return;

    final exercises = <Map<String, dynamic>>[];
    for (final ex in exercisesRaw) {
      if (ex is! Map<String, dynamic>) continue;
      final name = ex['name'] as String? ?? '';
      if (name.trim().isEmpty) continue;
      exercises.add({
        'name': name,
        'reps': ex['reps'] as int? ?? 12,
        'sets': ex['sets'] as int? ?? 3,
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('sport_plans');
    final Map<String, dynamic> data = jsonStr != null
        ? (jsonDecode(jsonStr) as Map<String, dynamic>)
        : <String, dynamic>{};

    data['$weekday'] = {
      'region': region,
      'exercises': exercises,
    };

    await prefs.setString('sport_plans', jsonEncode(data));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isSending) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ?? Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4DB6AC)),
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                final alignment =
                    msg.fromUser ? Alignment.centerRight : Alignment.centerLeft;
                final color = msg.fromUser
                    ? const Color(0xFF4DB6AC)
                    : Theme.of(context).cardTheme.color ?? Colors.white.withValues(alpha: 0.9);
                final textColor = msg.fromUser
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;

                return Align(
                  alignment: alignment,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12)
                  .copyWith(bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed:
                          _messages.isEmpty ? null : () => _clearChat(),
                      icon: Icon(Icons.chat_bubble_outline, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.7)),
                      label: Text('Yeni sohbet'.tr(context), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7))),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Asistanına bir şey sor...'.tr(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send),
                        color: const Color(0xFF4DB6AC),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.fromUser,
  });

  final String text;
  final bool fromUser;
}
