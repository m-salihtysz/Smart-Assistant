part of '../main.dart';

/// Derleme zamanında verilebilir: `--dart-define=SUPPORT_EMAIL=destek@ornek.com`
const String _supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

class _PolicySection {
  const _PolicySection(this.title, this.body);
  final String title;
  final String body;
}

List<_PolicySection> _policySections({required bool en}) {
  final contact = _supportEmail.isEmpty
      ? ''
      : (en ? '\n\nContact: $_supportEmail' : '\n\nİletişim: $_supportEmail');
  if (en) {
    return [
      const _PolicySection(
        'What this app is',
        'Smart Assistant is a personal planning assistant: activities, routines, workouts, finances, notes and an AI chat.',
      ),
      const _PolicySection(
        'Data we collect',
        '• Account: email address, password (stored only as a salted hash), name and date of birth. Your email is used only to verify your account and send password-reset codes; we send no marketing email.\n'
            '• Chat: the messages you exchange with the assistant are stored on our server so the assistant can follow the conversation.\n'
            '• Your plans: activities, routines, workout plans, finance records and notes are stored on your device. With cloud backup (on by default, can be turned off in Settings > Cloud backup) a copy is also stored on our server so it can be restored if you lose your device and synced across your devices. When you turn it off you can also delete the server copy.',
      ),
      const _PolicySection(
        'Sharing with AI providers',
        'Only if you give your explicit consent, when you send the assistant a message, we forward that message together with a summary of what is needed to answer it '
            '(today\'s and upcoming activities and routines, workout plan, finance totals, note titles and short previews) through our server to a third-party AI provider '
            '(Google Gemini or OpenAI). This data is used only to produce the answer. It is not used for advertising or tracking.\n\n'
            'You can withdraw this consent at any time in Settings > Assistant data sharing. Without consent the assistant does not send anything.',
      ),
      const _PolicySection(
        'Retention and deletion',
        '• "New chat" deletes your chat history on our server.\n'
            '• Settings > Delete Account permanently deletes your account, chat history and cloud backup from our server and clears all data stored on this device.',
      ),
      const _PolicySection(
        'Sharing and security',
        'We do not sell your data. The only recipients are the AI providers listed above (with your consent) and authorities where the law requires. '
            'Communication with our server uses an encrypted connection and your session key is kept in the device keychain.',
      ),
      const _PolicySection(
        'Age',
        'You must be at least 13 years old to use this app.',
      ),
      _PolicySection(
        'Your rights',
        'You can view and edit your profile in Settings, delete your data at any time, and ask us questions about your data.$contact',
      ),
    ];
  }
  return [
    const _PolicySection(
      'Uygulama hakkında',
      'Smart Assistant; aktivite, rutin, spor, finans, not ve yapay zeka sohbeti sunan kişisel bir planlama asistanıdır.',
    ),
    const _PolicySection(
      'Topladığımız veriler',
      '• Hesap: e-posta adresi, şifre (yalnızca tuzlu özet olarak saklanır), ad ve doğum tarihi. E-posta adresin yalnızca hesabını doğrulamak ve şifre sıfırlama kodu göndermek için kullanılır; pazarlama e-postası göndermeyiz.\n'
          '• Sohbet: asistanla yazışmaların, asistanın konuşmayı takip edebilmesi için sunucumuzda saklanır.\n'
          '• Planların: aktiviteler, rutinler, spor planları, finans kayıtları ve notlar cihazında saklanır. Bulut yedekleme açıkken (varsayılan açık; Ayarlar > Bulut yedekleme\'den kapatılabilir) bir kopyası cihaz kaybında geri yüklenebilmesi ve cihazların arasında eşitlenmesi için sunucumuzda da saklanır. Kapatırken sunucudaki kopyayı da silebilirsin.',
    ),
    const _PolicySection(
      'Yapay zeka sağlayıcılarıyla paylaşım',
      'Yalnızca açık izin verirsen, asistana mesaj gönderdiğinde bu mesajı ve cevap üretmek için gereken özet bilgileri '
          '(bugünkü ve yaklaşan aktivite/rutinler, spor planı, finans toplamları, not başlıkları ve kısa önizlemeleri) '
          'sunucumuz üzerinden üçüncü taraf bir yapay zeka sağlayıcısına (Google Gemini veya OpenAI) iletiriz. '
          'Bu veriler yalnızca cevabı üretmek için kullanılır; reklam veya takip amacıyla kullanılmaz.\n\n'
          'İznini istediğin zaman Ayarlar > Asistan veri paylaşımı bölümünden geri alabilirsin. İzin yoksa asistan hiçbir şey göndermez.',
    ),
    const _PolicySection(
      'Saklama ve silme',
      '• "Yeni Sohbet" sunucudaki sohbet geçmişini siler.\n'
          '• Ayarlar > Hesabı Sil, hesabını, sohbet geçmişini ve bulut yedeğini sunucumuzdan kalıcı olarak siler ve bu cihazdaki tüm verileri temizler.',
    ),
    const _PolicySection(
      'Paylaşım ve güvenlik',
      'Verilerini satmayız. Yalnızca yukarıdaki yapay zeka sağlayıcıları (iznin varsa) ve yasal zorunluluk halinde yetkili makamlar veriye erişebilir. '
          'Sunucuyla iletişim şifreli bağlantı üzerinden yapılır ve oturum anahtarın cihazın Keychain\'inde saklanır.',
    ),
    const _PolicySection(
      'Yaş sınırı',
      'Uygulamayı kullanmak için en az 13 yaşında olmalısın.',
    ),
    _PolicySection(
      'Haklarını kullanma',
      'Profilini Ayarlar\'dan görüntüleyip düzenleyebilir, verilerini istediğin zaman silebilir ve verilerinle ilgili bize soru sorabilirsin.$contact',
    ),
  ];
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final en = context.read<AppState>().locale.languageCode == 'en';
    final sections = _policySections(en: en);
    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        title: Text('Gizlilik Politikası'.tr(context)),
        backgroundColor: pal.surface,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          children: [
            for (final s in sections) ...[
              Text(
                s.title,
                style: TextStyle(
                  color: pal.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.body,
                style: TextStyle(color: pal.muted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asistan verilerinin üçüncü taraf yapay zekaya gönderilmesi için izin ister.
/// Daha önce izin verildiyse sormadan `true` döner.
Future<bool> ensureAiConsent(BuildContext context) async {
  if (await AiConsent.isGranted()) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text('Yapay zeka ile veri paylaşımı'.tr(ctx)),
      content: SingleChildScrollView(
        child: Text(
          'Asistan, sorularını yanıtlamak için mesajını ve uygulamadaki planlarını, rutinlerini, spor programını, finans özetini ve not başlıklarını sunucumuz üzerinden Google Gemini veya OpenAI gibi üçüncü taraf yapay zeka hizmetlerine gönderir. Veriler reklam için kullanılmaz. İznini istediğin zaman Ayarlar\'dan geri alabilirsin.'
              .tr(ctx),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => const PrivacyPolicyScreen(),
            ),
          ),
          child: Text('Gizlilik Politikası'.tr(ctx)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Vazgeç'.tr(ctx)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Kabul Et'.tr(ctx)),
        ),
      ],
    ),
  );

  if (accepted == true) {
    await AiConsent.set(true);
    return true;
  }
  return false;
}
