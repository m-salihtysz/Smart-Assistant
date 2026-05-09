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
    final appState = context.read<AppState>();
    final lang = appState.locale.languageCode;
    if (lang == 'en') {
      return _enTranslations[this] ?? this;
    }
    return this;
  }
}

const Map<String, String> _enTranslations = {
  'Giriş yap veya yeni hesap oluştur': 'Sign in or create a new account',
  'Hesabın yok mu? Kayıt ol': 'Don\'t have an account? Sign up',
  'Hoş geldin.': 'Welcome.',
  'Lütfen e-posta gir': 'Please enter email',
  'Geçerli bir e-posta gir': 'Please enter a valid email',
  'Lütfen şifre gir': 'Please enter password',
  'Şifre en az 4 karakter olmalı': 'Password must be at least 4 characters',
  'Hoş geldin,': 'Welcome,',
  'Kullanıcı': 'User',
  'Aktiviteler': 'Activities',
  'Tüm Kategoriler': 'All Categories',
  'Doğum tarihinizi seçin': 'Select your birth date',
  'Bildirimleri Etkinleştir': 'Enable Notifications',
  'Çıkış Yap': 'Log Out',
  'Pzt': 'Mon', 'Sal': 'Tue', 'Çar': 'Wed', 'Per': 'Thu', 'Cum': 'Fri', 'Cmt': 'Sat', 'Paz': 'Sun',
  'Seçilmedi': 'Not selected', 'Göğüs': 'Chest', 'Sırt': 'Back', 'Omuz': 'Shoulder', 'Kol': 'Arm', 'Bacak': 'Leg', 'Kardiyo': 'Cardio', 'Tüm vücut': 'Full body', 'Dinlenme': 'Rest',
  'Notu düzenle': 'Edit note',
  'Not başlığı': 'Note title',
  'Notunu yaz...': 'Write your note...',
  'Hoş geldin': 'Welcome',
  'Hoş Geldin!': 'Welcome!',
  'Smart Assistant Premium dünyasına hoş geldin.': 'Welcome to Smart Assistant Premium world.',
  'Yeni hesap oluştur': 'Create new account',
  'Kayıt başarısız:': 'Registration failed:',
  'E-posta girin': 'Enter email',
  'Geçerli bir e-posta girin': 'Enter a valid email',
  'Şifre girin': 'Enter password',
  'Notlarım': 'My Notes',
  'Yeni Rutin Ekle': 'Add New Routine',
  'Borsa Takip Listesi': 'Watchlist',
  'Gelir/Gider': 'Income/Expense',
  'İşlem Geçmişi': 'Transaction History',
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
  'Hesap bilgilerini buradan yönetebilirsin.': 'Manage your account information here.',
  'E-posta Adresi': 'Email Address',
  'Ad Soyad': 'Full Name',
  'Adınızı girin': 'Enter your name',
  'Doğum Tarihi': 'Date of Birth',
  'Dil Seçeneği': 'Language Option',
  'Bildirimler': 'Notifications',
  'Değişiklikleri Kaydet': 'Save Changes',
  'Hızlı Bakış': 'Quick Glance',
  'Günlük Hedef': 'Daily Goal',
  'Finansal Durum': 'Financial Status',
  'Tamamlandı': 'Completed',
  'Harcandı': 'Spent',
  'Asistanı kullanmak için önce giriş yapmalısın. Profil sekmesinden giriş yapmayı dene.': 'You must log in first to use the assistant. Try logging in from the Profile tab.',
  'Asistan şu an beklenmedik bir cevap döndürdü.': 'The assistant returned an unexpected response.',
  'Asistan şu an yanıt veremiyor (hata kodu: ': 'The assistant cannot respond right now (error code: ',
  'Bir süre sonra tekrar dene.': 'Try again after a while.',
  'Asistan ile bağlantı kurarken bir hata oluştu: ': 'An error occurred while connecting to the assistant: ',
  'Harika Gidiyorsun!': 'You are doing great!',
  'Bugünkü hedeflerinin %': 'Your goals for today are %',
  'ini tamamladın. Devam et!': ' completed. Keep going!',
  'Tümünü Gör': 'See All',
  'Kategoriler': 'Categories',
  'Hoş Geldin': 'Welcome',
  'Zaten hesabın var mı? Giriş yap': 'Already have an account? Sign in',
  'Sana daha iyi yardımcı olabilmem için birkaç bilgi isteyeceğim.': 'I will ask for some information to help you better.',
  'Yeni': 'New',
  'Bilgilerin güncellendi': 'Information updated',
  'Tarih': 'Date',
  'Borsam': 'My Stocks',
  'Gelir-Gider': 'Income-Expense',
  'Henüz bir işlem yok.': 'No transactions yet.',
  'Yeni İşlem Ekle': 'Add New Transaction',
  'Takip Listem': 'My Watchlist',
  'Takip listen boş.': 'Watchlist is empty.',
  'Hisse / Endeks Ekle': 'Add Stock / Index',
  'Bugünün Rutinleri': 'Today\'s Routines',
  'Rutinleri': 'Routines',
  'Bu gün için rutin bulunmuyor.': 'No routines for today.',
  'Set x': 'Set x',
  'Tekrar': 'Reps',
  'Yeni Hareket Ekle': 'Add New Exercise',
  'Henüz seçilmedi': 'Not selected yet',
  'Düzenle': 'Edit',
  'Günün Hedefi': 'Today\'s Goal',
  'Bugün için hareket eklenmemiş.': 'No exercises added for today.',
  'Merhaba': 'Hello',
  'Antrenman programların, hedeflerin ve ilerlemeni burada takip edeceksin.': 'Track your workout programs, goals and progress here.',
  'Gelir-giderlerin, bütçe planların ve hedeflerin için alan.': 'Area for your income-expenses, budget plans and goals.',
  'Günlük alışkanlıklarını ve yapılacaklarını burada organize edeceksin.': 'Organize your daily habits and to-dos here.',
  'Önemli notlar ve fikirler için hızlı alan.': 'Quick space for important notes and ideas.',
  // Finance Categories
  'Kategori': 'Category',
  'Market': 'Market',
  'Yemek': 'Food',
  'Ulaşım': 'Transport',
  'Eğlence': 'Entertainment',
  'Sağlık': 'Health',
  'Eğitim': 'Education',
  'Fatura': 'Bill',
  'Maaş': 'Salary',
  'Diğer': 'Other',
  'Günlük Gider': 'Daily Expense',
  'Aylık Gider': 'Monthly Expense',
  // Exercise Names
  'Bench Press': 'Bench Press',
  'Incline Dumbbell Press': 'Incline Dumbbell Press',
  'Chest Fly (Kablo veya Dumbbell)': 'Chest Fly (Cable or Dumbbell)',
  'Push-up (Şınav)': 'Push-up',
  'Dips': 'Dips',
  'Lat Pulldown': 'Lat Pulldown',
  'Seated Cable Row': 'Seated Cable Row',
  'Bent Over Row': 'Bent Over Row',
  'Deadlift': 'Deadlift',
  'Pull-up (Barfiks)': 'Pull-up',
  'Overhead Press': 'Overhead Press',
  'Lateral Raise (Yan Açış)': 'Lateral Raise',
  'Front Raise (Ön Açış)': 'Front Raise',
  'Face Pull': 'Face Pull',
  'Shrug': 'Shrug',
  'Biceps: Barbell Curl': 'Biceps: Barbell Curl',
  'Biceps: Hammer Curl': 'Biceps: Hammer Curl',
  'Triceps: Triceps Pushdown': 'Triceps: Triceps Pushdown',
  'Triceps: Skull Crusher': 'Triceps: Skull Crusher',
  'Ön Kol: Reverse Curl': 'Forearm: Reverse Curl',
  'Squat': 'Squat',
  'Leg Press': 'Leg Press',
  'Leg Extension': 'Leg Extension',
  'Leg Curl': 'Leg Curl',
  'Calf Raise': 'Calf Raise',
  'Koşu Bandı': 'Treadmill',
  'Bisiklet': 'Bicycle',
  'Eliptik Bisiklet': 'Elliptical',
  'Kürek Çekme': 'Rowing',
  'İp Atlama': 'Jump Rope',
  'Goblet Squat': 'Goblet Squat',
  'Push-up': 'Push-up',
  'Dumbbell Row': 'Dumbbell Row',
  'Shoulder Press': 'Shoulder Press',
  'Plank': 'Plank',
  'Hafif Esneme Hareketleri': 'Light Stretching',
  'Kısa Mesafe Yürüyüş': 'Short Walk',
  'Mobilite Egzersizleri': 'Mobility Exercises',
  'Vücut Bakımı ve Uyku': 'Body Care and Sleep',
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

  bool notificationsEnabled = true;
  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
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
            themeMode: ThemeMode.light,
            builder: (context, child) {
              return Container(
                color: const Color(0xFFF8F9FA),
                child: DefaultTextStyle(
                  style: const TextStyle(color: Color(0xFF1A1A1A)),
                  child: child!,
                ),
              );
            },
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1A1A1A),
                primary: const Color(0xFF1A1A1A),
                secondary: const Color(0xFF757575),
                surface: Colors.white,
              ),
              textTheme: const TextTheme(
                headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -1),
                headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
                titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                bodyLarge: TextStyle(color: Color(0xFF424242), fontSize: 16),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                titleTextStyle: TextStyle(color: Color(0xFF1A1A1A), fontSize: 20, fontWeight: FontWeight.w800),
              ),
              cardTheme: CardThemeData(
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                color: Colors.white,
              ),
            ),
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
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Giriş yap veya yeni hesap oluştur'.tr(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
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
                              'Giriş yap'.tr(context),
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
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(
                                      color: colorScheme.outlineVariant),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'E-posta girin'.tr(context);
                                }
                                if (!v.contains('@')) {
                                  return 'Geçerli bir e-posta girin'.tr(context);
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
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide(
                                      color: colorScheme.outlineVariant),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Şifre girin'.tr(context);
                                }
                                if (v.trim().length < 4) {
                                  return 'Şifre en az 4 karakter olmalı'.tr(context);
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
                      'Hesabın yok mu? Kayıt ol'.tr(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
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
        _errorText = 'E-posta veya şifre hatalı.'.tr(context);
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
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen e-posta gir'.tr(context);
                    }
                    if (!value.contains('@')) {
                      return 'Geçerli bir e-posta gir'.tr(context);
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
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen şifre gir'.tr(context);
                    }
                    if (value.trim().length < 4) {
                      return 'Şifre en az 4 karakter olmalı'.tr(context);
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
                            'Kayıt ol'.tr(context),
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
                                borderRadius: BorderRadius.circular(28),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(color: colorScheme.outlineVariant),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'E-posta girin'.tr(context);
                              if (!v.contains('@')) return 'Geçerli bir e-posta girin'.tr(context);
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
                                borderRadius: BorderRadius.circular(28),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide(color: colorScheme.outlineVariant),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Şifre belirleyin'.tr(context);
                              if (v.trim().length < 4) return 'Şifre en az 4 karakter olmalı'.tr(context);
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
                    'Zaten hesabın var mı? Giriş yap'.tr(context),
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
                        'Merhaba'.tr(context) + ', $emailText',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                const SizedBox(height: 8),
                Text(
                  'Sana daha iyi yardımcı olabilmem için birkaç bilgi isteyeceğim.'.tr(context),
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
                      return 'Lütfen adını gir'.tr(context);
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
                          ? 'Seç'.tr(context)
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
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _BottomNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
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
    required this.activeIcon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A).withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFF1A1A1A) : Colors.black26,
          size: 26,
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

  static const List<_HomeCategory> _categories = [
    _HomeCategory(label: 'Aktiviteler', icon: Icons.explore_rounded, imageUrl: 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800&q=80'),
    _HomeCategory(label: 'Rutinler', icon: Icons.calendar_month_rounded, imageUrl: 'https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?w=800&q=80'),
    _HomeCategory(label: 'Spor', icon: Icons.fitness_center_rounded, imageUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&q=80'),
    _HomeCategory(label: 'Finans', icon: Icons.account_balance_wallet_rounded, imageUrl: 'https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?w=800&q=80'),
    _HomeCategory(label: 'Notlar', icon: Icons.edit_note_rounded, imageUrl: 'https://images.unsplash.com/photo-1455390582262-044cdead277a?w=800&q=80'),
  ];

  Widget _contentFor(int index) {
    switch (index) {
      case 0: return const ActivitiesTab();
      case 1: return const RoutinesTab();
      case 2: return const SportTab();
      case 3: return const FinanceTab();
      case 4: return const NotesTab();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildHeader(String name) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hoş geldin,'.tr(context),
            style: TextStyle(color: Colors.grey.shade800, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          Text(
            name,
            style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  double _completionRate = 0.0;
  double _todaySpending = 0.0;

  @override
  void initState() {
    super.initState();
    _loadQuickGlanceData();
  }

  Future<void> _loadQuickGlanceData() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    final routinesJson = prefs.getString('routines');
    if (routinesJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(routinesJson);
        final weekday = now.weekday - 1;
        final routines = (data['$weekday'] as List? ?? []);
        final completions = (data['completions'] as Map? ?? {});
        final dateKey = '${now.year}-${now.month}-${now.day}';
        final dayCompletions = (completions[dateKey] as List? ?? []);
        
        if (routines.isNotEmpty) {
          int completedCount = 0;
          for (int i = 0; i < routines.length; i++) {
            if (i < dayCompletions.length && dayCompletions[i] == true) {
              completedCount++;
            }
          }
          _completionRate = (completedCount / routines.length) * 100;
        }
      } catch (_) {}
    }

    final financeJson = prefs.getString('finance_transactions');
    if (financeJson != null) {
      try {
        final List data = jsonDecode(financeJson);
        final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        double total = 0;
        for (var tx in data) {
          if (tx['date'] == dateKey && tx['type'] == 'expense') {
            total += (tx['amount'] as num).toDouble();
          }
        }
        _todaySpending = total;
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _showAllCategories() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('Tüm Kategoriler'.tr(context), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 24),
            ...List.generate(_categories.length, (index) {
              final cat = _categories[index];
              return ListTile(
                leading: Icon(cat.icon, color: const Color(0xFF1A1A1A)),
                title: Text(cat.label.tr(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedCategory = index);
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userName = context.watch<AppState>().currentUser?.name ?? 'Kullanıcı'.tr(context);

    if (_selectedCategory != null) {
      return Column(
        children: [
          AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1A1A1A)),
              onPressed: () => setState(() => _selectedCategory = null),
            ),
            title: Text(_categories[_selectedCategory!].label.tr(context), style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800)),
          ),
          Expanded(child: _contentFor(_selectedCategory!)),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQuickGlanceData,
      color: const Color(0xFF1A1A1A),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildHeader(userName),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kategoriler'.tr(context), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  GestureDetector(
                    onTap: _showAllCategories,
                    child: Text('Tümünü Gör'.tr(context), style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ),
            ),
  
            SizedBox(
              height: 320,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = index),
                    child: Container(
                      width: 220,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        image: DecorationImage(
                          image: NetworkImage(cat.imageUrl!),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(cat.icon, color: Colors.white, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              cat.label.tr(context),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
  
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Text('Hızlı Bakış'.tr(context), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            ),
  
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildSuggestionItem(
                    'Hoş Geldin!'.tr(context),
                    'Smart Assistant Premium dünyasına hoş geldin.'.tr(context),
                    Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildVerticalInfoCard('Günlük Hedef'.tr(context), '${_completionRate.toStringAsFixed(0)}% ' + 'Tamamlandı'.tr(context), Icons.auto_graph_rounded, Colors.orange.shade50),
                  const SizedBox(height: 12),
                  _buildVerticalInfoCard('Finansal Durum'.tr(context), '₺${_todaySpending.toStringAsFixed(0)} ' + 'Harcandı'.tr(context), Icons.wallet_rounded, Colors.blue.shade50),
                  const SizedBox(height: 12),
                  if (_completionRate > 0 && _completionRate < 100)
                    _buildSuggestionItem(
                      'Harika Gidiyorsun!'.tr(context),
                      'Bugünkü hedeflerinin %'.tr(context) + _completionRate.toStringAsFixed(0) + 'ini tamamladın. Devam et!'.tr(context),
                      Icons.insights_rounded,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(String title, String body, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF1A1A1A), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1A1A))),
                Text(body, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalInfoCard(String title, String subtitle, IconData icon, Color bg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: const Color(0xFF1A1A1A), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCategory {
  const _HomeCategory({required this.label, required this.icon, this.imageUrl});
  final String label;
  final IconData icon;
  final String? imageUrl;
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
        children: [
          _SimplePlaceholder(
            title: 'Spor'.tr(context),
            description:
                'Antrenman programların, hedeflerin ve ilerlemeni burada takip edeceksin.'.tr(context),
            icon: Icons.fitness_center,
          ),
          const SizedBox(height: 16),
          _SimplePlaceholder(
            title: 'Finans'.tr(context),
            description:
                'Gelir-giderlerin, bütçe planların ve hedeflerin için alan.'.tr(context),
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 16),
          _SimplePlaceholder(
            title: 'Rutinler'.tr(context),
            description:
                'Günlük alışkanlıklarını ve yapılacaklarını burada organize edeceksin.'.tr(context),
            icon: Icons.repeat,
          ),
          const SizedBox(height: 16),
          _SimplePlaceholder(
            title: 'Notlar'.tr(context),
            description: 'Önemli notlar ve fikirler için hızlı alan.'.tr(context),
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
  
  static const Map<String, List<String>> _regionExercises = {
    'Göğüs': ['Bench Press', 'Incline Dumbbell Press', 'Chest Fly (Kablo veya Dumbbell)', 'Push-up (Şınav)', 'Dips'],
    'Sırt': ['Lat Pulldown', 'Seated Cable Row', 'Bent Over Row', 'Deadlift', 'Pull-up (Barfiks)'],
    'Omuz': ['Overhead Press', 'Lateral Raise (Yan Açış)', 'Front Raise (Ön Açış)', 'Face Pull', 'Shrug'],
    'Kol': ['Biceps: Barbell Curl', 'Biceps: Hammer Curl', 'Triceps: Triceps Pushdown', 'Triceps: Skull Crusher', 'Ön Kol: Reverse Curl'],
    'Bacak': ['Squat', 'Leg Press', 'Leg Extension', 'Leg Curl', 'Calf Raise'],
    'Kardiyo': ['Koşu Bandı', 'Bisiklet', 'Eliptik Bisiklet', 'Kürek Çekme', 'İp Atlama'],
    'Tüm vücut': ['Goblet Squat', 'Push-up', 'Dumbbell Row', 'Shoulder Press', 'Plank'],
    'Dinlenme': ['Hafif Esneme Hareketleri', 'Kısa Mesafe Yürüyüş', 'Mobilite Egzersizleri', 'Vücut Bakımı ve Uyku'],
  };

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
            region: m['region'] as String? ?? 'Seçilmedi',
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
            .map((e) => {'name': e.name, 'reps': e.reps, 'sets': e.sets, 'region': e.region})
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

  // Artık günün hedefi otomatik hesaplanacak, _changeRegion'a gerek kalmayabilir 
  // ama yine de genel bir not/hedef olarak tutabiliriz.

  Future<void> _addExercise() async {
    String tempRegion = _regions[1]; // Varsayılan Göğüs
    final availableExercises = () => _regionExercises[tempRegion] ?? [];
    String selectedName = availableExercises().isNotEmpty ? availableExercises().first : '';
    final repsController = TextEditingController(text: '12');
    final setsController = TextEditingController(text: '3');

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Hareket ekle'.tr(context)),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              final currentExercises = availableExercises();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    value: tempRegion,
                    items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r.tr(context)))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setStateDialog(() {
                        tempRegion = v;
                        final newExercises = _regionExercises[tempRegion] ?? [];
                        selectedName = newExercises.isNotEmpty ? newExercises.first : '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (currentExercises.isNotEmpty)
                    DropdownButton<String>(
                      isExpanded: true,
                      value: currentExercises.contains(selectedName) ? selectedName : currentExercises.first,
                      items: currentExercises.map((e) => DropdownMenuItem(value: e, child: Text(e.tr(context)))).toList(),
                      onChanged: (v) => setStateDialog(() => selectedName = v ?? ''),
                    )
                  else
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Hareket adı'.tr(context),
                        hintText: 'Örn. Bench press, Squat...'.tr(context),
                      ),
                      onChanged: (v) => selectedName = v,
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
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text('Vazgeç'.tr(context)),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedName.trim().isEmpty) return;
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
        ..add(_WorkoutExercise(name: selectedName.trim(), reps: reps, sets: sets, region: tempRegion));
      _plans[_selectedDayIndex] = _WorkoutPlan(
        region: current.region, // Eski alanı uyumluluk için tutuyoruz
        exercises: updated,
      );
    });
    await _saveSportPlans();
  }

  Future<void> _editExercise(int index) async {
    final current = _planForDay(_selectedDayIndex);
    if (index < 0 || index >= current.exercises.length) return;

    final ex = current.exercises[index];
    String tempRegion = ex.region;
    final availableExercises = () => _regionExercises[tempRegion] ?? [];
    String selectedName = ex.name;
    final repsController = TextEditingController(text: '${ex.reps}');
    final setsController = TextEditingController(text: '${ex.sets}');

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Hareketi düzenle'.tr(context)),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              final currentExercises = availableExercises();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    value: tempRegion,
                    items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r.tr(context)))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setStateDialog(() {
                        tempRegion = v;
                        final newExercises = _regionExercises[tempRegion] ?? [];
                        selectedName = newExercises.isNotEmpty ? newExercises.first : '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (currentExercises.isNotEmpty)
                    DropdownButton<String>(
                      isExpanded: true,
                      value: currentExercises.contains(selectedName) ? selectedName : currentExercises.first,
                      items: currentExercises.map((e) => DropdownMenuItem(value: e, child: Text(e.tr(context)))).toList(),
                      onChanged: (v) => setStateDialog(() => selectedName = v ?? ''),
                    )
                  else
                    TextField(
                      decoration: InputDecoration(labelText: 'Hareket adı'.tr(context)),
                      onChanged: (v) => selectedName = v,
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
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('delete'),
              child: Text(
                'Sil'.tr(context),
                style: const TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: Text('Vazgeç'.tr(context)),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedName.trim().isEmpty) return;
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
        updated[index] = _WorkoutExercise(name: selectedName.trim(), reps: reps, sets: sets, region: tempRegion);
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
    final plan = _planForDay(_selectedDayIndex);
    final weekDays = _weekDays();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Modern Week Selector Capsule
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(7, (i) {
                final d = weekDays[i];
                final selected = i == _selectedDayIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1A1A1A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _dayLabels[i].tr(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white70 : Colors.black38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 18,
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w800,
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

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Günün Hedefi'.tr(context), style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    plan.exercises.isEmpty 
                      ? 'Henüz seçilmedi'.tr(context) 
                      : plan.exercises.map((e) => e.region).toSet().join(' + ').tr(context),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF1A1A1A)),
                  ),
                ],
              ),
              /* _changeRegion butonu kaldırıldı çünkü artık her hareketin kendi bölgesi var */
            ],
          ),
        ),

        Expanded(
          child: plan.exercises.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fitness_center_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Bugün için hareket eklenmemiş.'.tr(context), style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: plan.exercises.length,
                  itemBuilder: (context, index) {
                    final ex = plan.exercises[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                      ),
                      child: InkWell(
                        onTap: () => _editExercise(index),
                        borderRadius: BorderRadius.circular(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.bolt_rounded, color: Color(0xFF1A1A1A), size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        ex.name,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1A1A1A)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          ex.region.tr(context),
                                          style: TextStyle(color: Colors.blue.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${ex.sets} Set x ${ex.reps} Tekrar'.tr(context),
                                    style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w500, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black26),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ElevatedButton.icon(
            onPressed: _addExercise,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text('Yeni Hareket Ekle'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
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
  _WorkoutExercise({required this.name, required this.reps, required this.sets, required this.region});

  final String name;
  final int reps;
  final int sets;
  final String region;
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
            category: m['category'] as String? ?? 'Diğer',
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
      'category': t.category,
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

  double get _dailyGider {
    final now = DateTime.now();
    final todayKey = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _transactions.where((t) => t.type == 'gider' && t.dateKey == todayKey).fold(0, (s, t) => s + t.amount);
  }

  double get _monthlyGider {
    final now = DateTime.now();
    final monthPrefix = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    return _transactions.where((t) => t.type == 'gider' && t.dateKey.startsWith(monthPrefix)).fold(0, (s, t) => s + t.amount);
  }

  static const List<String> _expenseCategories = ['Market', 'Yemek', 'Ulaşım', 'Eğlence', 'Sağlık', 'Eğitim', 'Fatura', 'Diğer'];
  static const List<String> _incomeCategories = ['Maaş', 'Yeni', 'Diğer'];

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Market': return Icons.shopping_cart_rounded;
      case 'Yemek': return Icons.restaurant_rounded;
      case 'Ulaşım': return Icons.directions_car_rounded;
      case 'Eğlence': return Icons.sports_esports_rounded;
      case 'Sağlık': return Icons.medical_services_rounded;
      case 'Eğitim': return Icons.school_rounded;
      case 'Fatura': return Icons.receipt_rounded;
      case 'Maaş': return Icons.payments_rounded;
      default: return Icons.category_rounded;
    }
  }

  Future<void> _addTransaction() async {
    String type = 'gider';
    String category = 'Market';
    final amountController = TextEditingController();
    final titleController = TextEditingController();
    final date = DateTime.now();
    String dateKey = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final categories = type == 'gelir' ? _incomeCategories : _expenseCategories;
            if (!categories.contains(category)) category = categories.first;

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
                      onSelectionChanged: (s) {
                        setStateDialog(() {
                          type = s.first;
                          category = (type == 'gelir' ? _incomeCategories : _expenseCategories).first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: InputDecoration(labelText: 'Kategori'.tr(context)),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.tr(context)))).toList(),
                      onChanged: (v) => setStateDialog(() => category = v ?? category),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(labelText: 'Açıklama'.tr(context), hintText: 'Örn. Market alışverişi'.tr(context)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Tutar (₺)'.tr(context)),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text('${'Tarih'.tr(context)}: $dateKey'),
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
      _transactions.insert(0, _Transaction(type: type, amount: amount, title: titleController.text.trim(), dateKey: dateKey, category: category));
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
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1A1A1A),
            unselectedLabelColor: Colors.black38,
            indicatorColor: const Color(0xFF1A1A1A),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            tabs: [
              Tab(text: 'Gelir-Gider'.tr(context)),
              Tab(text: 'Borsam'.tr(context)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGelirGider(),
              _buildBorsam(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGelirGider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildFinanceStat('Bakiye'.tr(context), _balance, _balance >= 0 ? Colors.blue.shade600 : Colors.red.shade600, Icons.account_balance_wallet_rounded)),
                  Expanded(child: _buildFinanceStat('Günlük Gider'.tr(context), _dailyGider, Colors.orange.shade700, Icons.today_rounded)),
                  Expanded(child: _buildFinanceStat('Aylık Gider'.tr(context), _monthlyGider, Colors.purple.shade600, Icons.calendar_month_rounded)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('${'Gelir'.tr(context)}: +₺${_totalGelir.toStringAsFixed(0)}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${'Gider'.tr(context)}: -₺${_totalGider.toStringAsFixed(0)}', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Henüz bir işlem yok.'.tr(context), style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _transactions.length,
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    final isGelir = t.type == 'gelir';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (isGelir ? Colors.green : Colors.red).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getCategoryIcon(t.category),
                              color: isGelir ? Colors.green.shade700 : Colors.red.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A1A1A)),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      t.category.tr(context),
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${t.dateKey}',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isGelir ? '+' : '-'}₺${t.amount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: isGelir ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteTransaction(index),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ElevatedButton.icon(
            onPressed: _addTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.add_card_rounded),
            label: Text('Yeni İşlem Ekle'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceStat(String label, double amount, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
        Text(
          '₺${amount.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A1A1A)),
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

  Widget _buildBorsam() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            'Takip Listem'.tr(context),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF1A1A1A)),
          ),
        ),
        Expanded(
          child: _watchlist.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stacked_line_chart_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Takip listen boş.'.tr(context), style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _watchlist.length,
                  itemBuilder: (context, index) {
                    final w = _watchlist[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.show_chart_rounded, color: Color(0xFF1A1A1A), size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1A1A1A)),
                                ),
                                if (w.symbol.isNotEmpty)
                                  Text(
                                    w.symbol,
                                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.black26),
                            onPressed: () => _removeWatchlist(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ElevatedButton.icon(
            onPressed: _addWatchlist,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.add_chart_rounded),
            label: Text('Hisse / Endeks Ekle'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _Transaction {
  _Transaction({required this.type, required this.amount, required this.title, required this.dateKey, required this.category});

  final String type;
  final double amount;
  final String title;
  final String dateKey;
  final String category;
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
                TextButton(onPressed: () => Navigator.of(context).pop('delete'), child: Text('Sil'.tr(context), style: const TextStyle(color: Colors.red))),
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
    final weekDays = _weekDays();
    final dayIndex = _selectedDate.weekday - 1;
    final routines = _routinesFor(dayIndex);
    final completions = _completionsFor(_selectedDate);
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Premium Week Selector
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(7, (i) {
                final d = weekDays[i];
                final selected = _isSameDay(d, _selectedDate);
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1A1A1A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _dayLabels[i].tr(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white70 : Colors.black38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 18,
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w800,
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

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Text(
            isToday ? 'Bugünün Rutinleri'.tr(context) : '${_selectedDate.day}.${_selectedDate.month} ${'Rutinleri'.tr(context)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF1A1A1A)),
          ),
        ),

        Expanded(
          child: routines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Bu gün için rutin bulunmuyor.'.tr(context), style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: routines.length,
                  itemBuilder: (context, index) {
                    final r = routines[index];
                    final done = index < completions.length && completions[index];
                    final timeStr = '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Checkbox(
                          value: done,
                          onChanged: (v) => _setCompleted(_selectedDate, index, v ?? false),
                          activeColor: const Color(0xFF1A1A1A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        title: Text(
                          r.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: done ? Colors.grey : const Color(0xFF1A1A1A),
                            decoration: done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                          timeStr,
                          style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (r.reminder) const Icon(Icons.notifications_active_rounded, size: 18, color: Colors.amber),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                          ],
                        ),
                        onTap: () => _editRoutine(index),
                      ),
                    );
                  },
                ),
        ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ElevatedButton.icon(
            onPressed: _addRoutine,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni Rutin Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
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
    final weekDays = _weekDays();
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Premium Week Selector
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(7, (i) {
                final d = weekDays[i];
                final selected = _isSameDay(d, _selectedDate);
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1A1A1A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _dayNames[i],
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? Colors.white70 : Colors.black38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 18,
                            color: selected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w800,
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

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToday ? 'Günün Aktiviteleri' : '${_selectedDate.day}.${_selectedDate.month} Aktiviteleri',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF1A1A1A)),
              ),
              IconButton(
                onPressed: _openCalendar,
                icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF1A1A1A)),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explore_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Bu gün için aktivite bulunmuyor.', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final act = activities[index];
                    final timeStr = '${act.time.hour.toString().padLeft(2, '0')}:${act.time.minute.toString().padLeft(2, '0')}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A).withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF1A1A1A), size: 22),
                        ),
                        title: Text(
                          act.title,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1A1A1A)),
                        ),
                        subtitle: Text(
                          timeStr,
                          style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.black26),
                          onPressed: () => _deleteActivity(index),
                        ),
                        onTap: () => _editActivity(index),
                      ),
                    );
                  },
                ),
        ),
        
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ElevatedButton.icon(
            onPressed: _addActivity,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni Aktivite Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteActivity(int index) async {
    final key = _dateKey(_selectedDate);
    final list = _activities[key] ?? [];
    if (index < 0 || index >= list.length) return;
    final item = list[index];
    if (item.notificationId != null) await cancelReminderNotification(item.notificationId!);
    setState(() {
      list.removeAt(index);
      _activities[key] = list;
    });
    await _saveActivities();
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
      await _deleteActivity(index);
    } else if (result == 'save') {
      if (current.notificationId != null) await cancelReminderNotification(current.notificationId!);
      int? notificationId;
      if (wantReminder) {
        notificationId = nextNotificationId();
        final when = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, pickedTime.hour, pickedTime.minute);
        await scheduleActivityReminder(notificationId, titleController.text.trim(), when);
      }
      setState(() {
        list[index] = _Activity(
          title: titleController.text.trim(),
          time: pickedTime,
          reminder: wantReminder,
          notificationId: notificationId,
        );
        _activities[key] = list;
      });
      await _saveActivities();
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
                                  ? const Color(0xFF1A1A1A)
                                  : hasActivity
                                      ? const Color(0xFF1A1A1A).withOpacity(0.1)
                                      : null,
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF1A1A1A)
                                    : hasActivity
                                        ? const Color(0xFF1A1A1A).withOpacity(0.8)
                                        : Colors.grey.shade300,
                                width: hasActivity && !selected ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : const Color(0xFF1A1A1A),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Text(
            'Notlarım'.tr(context),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Color(0xFF1A1A1A), letterSpacing: -1),
          ),
        ),
        Expanded(
          child: _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.note_alt_rounded, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Henüz bir notun yok.', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final displayTitle = note.title.isEmpty ? (note.body.isEmpty ? 'Başlıksız' : note.body) : note.title;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _editNote(index),
                          borderRadius: BorderRadius.circular(24),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1A).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Icons.description_rounded, color: Color(0xFF1A1A1A), size: 22),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayTitle,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF1A1A1A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (note.body.isNotEmpty && note.title.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            note.body,
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black26),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ElevatedButton.icon(
            onPressed: _addNote,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Yeni Not Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
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
      setState(() => _birthDate = picked);
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
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ayarlar'.tr(context),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hesap bilgilerini buradan yönetebilirsin.'.tr(context),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 32),
                
                _buildFieldLabel('E-posta Adresi'.tr(context)),
                _buildReadOnlyField(email),
                const SizedBox(height: 20),
                
                _buildFieldLabel('Ad Soyad'.tr(context)),
                _buildTextField(_nameController, 'Adınızı girin'.tr(context)),
                const SizedBox(height: 20),
                
                _buildFieldLabel('Doğum Tarihi'.tr(context)),
                _buildDatePickerField(),
                const SizedBox(height: 32),
                
                _buildFieldLabel('Dil Seçeneği'.tr(context)),
                _buildLanguageSelector(appState),
                
                const SizedBox(height: 32),
                _buildFieldLabel('Bildirimler'.tr(context)),
                _buildNotificationToggle(appState),
                
                const SizedBox(height: 40),
                
                ElevatedButton(
                  onPressed: () => _save(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text('Değişiklikleri Kaydet'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                
                const SizedBox(height: 16),
                
                TextButton.icon(
                  onPressed: appState.logout,
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text('Çıkış Yap'.tr(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5)),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _birthDate == null ? 'Doğum tarihinizi seçin'.tr(context) : '${_birthDate!.day}.${_birthDate!.month}.${_birthDate!.year}',
              style: TextStyle(
                color: _birthDate == null ? Colors.grey.shade400 : const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.calendar_month_rounded, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: appState.locale.languageCode,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400),
          items: [
            DropdownMenuItem(value: 'tr', child: Text('Türkçe'.tr(context), style: const TextStyle(fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'en', child: Text('English'.tr(context), style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
          onChanged: (v) {
            if (v != null) appState.setLocale(Locale(v));
          },
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        title: Text('Bildirimleri Etkinleştir'.tr(context), style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600, fontSize: 15)),
        value: appState.notificationsEnabled,
        activeColor: const Color(0xFF1A1A1A),
        onChanged: (v) => appState.setNotificationsEnabled(v),
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
              borderRadius: BorderRadius.circular(32),
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
                  'Asistanı kullanmak için önce giriş yapmalısın. Profil sekmesinden giriş yapmayı dene.'.tr(context),
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
            'Asistan şu an beklenmedik bir cevap döndürdü.'.tr(context);
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
                  'Asistan şu an yanıt veremiyor (hata kodu: '.tr(context) + '${response.statusCode}). ' +
                  'Bir süre sonra tekrar dene.'.tr(context),
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
                'Asistan ile bağlantı kurarken bir hata oluştu: '.tr(context) + e.toString(),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Premium Background Watermark
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.03,
              child: const Icon(Icons.auto_awesome_rounded, size: 320, color: Color(0xFF1A1A1A)),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        itemCount: _messages.length + (_isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isSending) {
                            return _buildTypingIndicator();
                          }
                          final msg = _messages[index];
                          return _buildMessageBubble(msg);
                        },
                      ),
              ),
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Smart AI ile Konuş',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Sana bugün nasıl yardımcı olabilirim?',
            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isMe = msg.fromUser;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(isMe ? 24 : 6),
            bottomRight: Radius.circular(isMe ? 6 : 24),
          ),
          boxShadow: isMe ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isMe ? Colors.white : const Color(0xFF1A1A1A),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_messages.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _clearChat,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.black38),
                label: const Text('Yeni Sohbet', style: TextStyle(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Asistanına bir şey sor...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w400),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
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

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Bildirim Merkezi', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildNotificationItem(
            'Hoş Geldin!',
            'Smart Assistant Premium dünyasına hoş geldin. Tüm özellikler emrine amade.',
            'Az Önce',
            Icons.auto_awesome_rounded,
          ),
          _buildNotificationItem(
            'Günlük Hedef Yakın',
            'Bugünkü hedeflerinin %80\'ini tamamladın. Harika gidiyorsun!',
            '2 Saat Önce',
            Icons.auto_graph_rounded,
          ),
          _buildNotificationItem(
            'Yeni Özellik: Asistan',
            'Artık asistanınla sesli veya yazılı konuşarak rutin ekleyebilirsin.',
            'Dün',
            Icons.assistant_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String body, String time, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF1A1A1A), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A1A1A))),
                    Text(time, style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(body, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
