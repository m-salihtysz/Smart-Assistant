import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  String content = file.readAsStringSync();

  // 1. Remove double .tr(context)
  while (content.contains('.tr(context).tr(context)')) {
    content = content.replaceAll('.tr(context).tr(context)', '.tr(context)');
  }

  // 2. Remove const before widgets that now have .tr(context)
  content = content.replaceAllMapped(
      RegExp(r"const\s+Text\('([^']+)'\.tr\(context\)\)"),
      (m) => "Text('${m.group(1)}'.tr(context))"
  );
  content = content.replaceAllMapped(
      RegExp(r"const\s+InputDecoration\(([^)]*)\.tr\(context\)([^)]*)\)"),
      (m) => "InputDecoration(${m.group(1)}.tr(context)${m.group(2)})"
  );
  // Remove const for Text with style
  content = content.replaceAllMapped(
      RegExp(r"const\s+Text\('([^']+)'\.tr\(context\),\s*style:"),
      (m) => "Text('${m.group(1)}'.tr(context), style:"
  );

  // 3. Inject the `tr` extension at the very top of the file, after imports.
  if (!content.contains('extension StringLocalization')) {
    final injectIndex = content.indexOf('class AppState');
    if (injectIndex != -1) {
      final ext = '''
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
  'Kişisel Asistan': 'Personal Assistant',
  'Giriş yap': 'Sign in',
  'Kayıt ol': 'Sign up',
  'Hesabın yok mu?': 'Don\\'t have an account?',
  'Hesabın var mı?': 'Already have an account?',
  'E-posta': 'Email',
  'Şifre': 'Password',
  'E-posta veya şifre hatalı.': 'Incorrect email or password.',
  'Seni Tanıyalım': 'Let\\'s get to know you',
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
  'Henüz notun yok. Yeni bir not oluştur.': 'You don\\'t have any notes. Create a new note.',
  'Başlık': 'Title',
  'Not içeriği...': 'Note content...',
  'Aktiviteyi düzenle': 'Edit activity',
  'Hareketi düzenle': 'Edit exercise',
  'Rutin ekle': 'Add routine',
  'Rutin adı': 'Routine name',
  'Günün Notu': 'Note of the day',
};

''';
      content = content.substring(0, injectIndex) + ext + content.substring(injectIndex);
    }
  }

  file.writeAsStringSync(content);
  print('Done fixing main.dart translations');
}
