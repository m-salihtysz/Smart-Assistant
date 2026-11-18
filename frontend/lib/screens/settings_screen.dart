part of '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  DateTime? _birthDate;
  bool _aiConsent = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    AiConsent.isGranted().then((v) {
      if (mounted) setState(() => _aiConsent = v);
    });
    final user = context.read<AppState>().currentUser;
    if (user != null) {
      _nameController.text = user.name ?? '';
      _birthDate = user.birthDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: latestAllowedBirthDate(),
      helpText: 'Doğum tarihini seç'.tr(context),
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hesabı silmek istediğine emin misin?'.tr(ctx)),
        content: Text(
          'Bu işlem geri alınamaz. Hesabın, sohbet geçmişin, bulut yedeğin ve bu cihazdaki tüm verilerin silinir.'
              .tr(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Vazgeç'.tr(ctx)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.pal.negative),
            child: Text('Sil'.tr(ctx)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await appState.deleteAccount();
    } on SessionExpiredException {
      // oturum zaten kapandı
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
    if (!isOldEnough(_birthDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uygulamayı kullanmak için en az 13 yaşında olmalısın.'.tr(context),
          ),
        ),
      );
      return;
    }
    final appState = context.read<AppState>();
    try {
      await appState.updateProfile(
        name: _nameController.text.trim(),
        birthDate: _birthDate!,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (!context.mounted) return;
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
      backgroundColor: context.pal.bg,
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
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    color: context.pal.ink,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hesap bilgilerini buradan yönetebilirsin.'.tr(context),
                  style: TextStyle(
                    color: context.pal.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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
                _buildFieldLabel('Görünüm'.tr(context)),
                _buildThemeSelector(appState),

                const SizedBox(height: 32),
                _buildFieldLabel('Bildirimler'.tr(context)),
                _buildNotificationToggle(appState),

                const SizedBox(height: 32),
                _buildFieldLabel('Bulut yedekleme'.tr(context)),
                _buildSyncSection(appState),

                const SizedBox(height: 32),
                _buildFieldLabel('Gizlilik'.tr(context)),
                _buildPrivacySection(),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: () => _save(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.pal.ink,
                    foregroundColor: context.pal.onInk,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Değişiklikleri Kaydet'.tr(context),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextButton.icon(
                  onPressed: appState.logout,
                  style: TextButton.styleFrom(
                    foregroundColor: context.pal.negative,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(
                    'Çıkış Yap'.tr(context),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showChangePasswordDialog(context),
                  style: TextButton.styleFrom(foregroundColor: context.pal.ink),
                  icon: const Icon(Icons.lock_reset_rounded, size: 20),
                  label: Text('Şifreyi değiştir'.tr(context)),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDeleteAccount(context),
                  style: TextButton.styleFrom(
                    foregroundColor: context.pal.muted,
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 20),
                  label: Text('Hesabı Sil'.tr(context)),
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
      child: Text(
        label,
        style: TextStyle(
          color: context.pal.muted,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: context.pal.fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.pal.border),
      ),
      child: Text(
        text,
        style: TextStyle(color: context.pal.muted, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: context.pal.ink, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: context.pal.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: context.pal.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: context.pal.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: context.pal.ink, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: context.pal.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.pal.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _birthDate == null
                  ? 'Doğum tarihinizi seçin'.tr(context)
                  : formatDate(_birthDate!),
              style: TextStyle(
                color: _birthDate == null
                    ? context.pal.subtle
                    : context.pal.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              Icons.calendar_month_rounded,
              color: context.pal.subtle,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(AppState appState) {
    final pal = context.pal;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: ThemeMode.light,
            icon: const Icon(Icons.light_mode_rounded, size: 18),
            label: Text('Açık'.tr(context)),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: const Icon(Icons.dark_mode_rounded, size: 18),
            label: Text('Koyu'.tr(context)),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: const Icon(Icons.brightness_auto_rounded, size: 18),
            label: Text('Sistem'.tr(context)),
          ),
        ],
        selected: {appState.themeMode},
        onSelectionChanged: (v) => appState.setThemeMode(v.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? pal.ink : pal.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? pal.onInk : pal.ink,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: pal.border)),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(AppState appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: context.pal.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.pal.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: appState.locale.languageCode,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: context.pal.subtle,
          ),
          items: [
            DropdownMenuItem(
              value: 'tr',
              child: Text(
                'Türkçe'.tr(context),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            DropdownMenuItem(
              value: 'en',
              child: Text(
                'English'.tr(context),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          onChanged: (v) {
            if (v != null) appState.setLocale(Locale(v));
          },
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(AppState appState) {
    final pal = context.pal;
    return Material(
      color: pal.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: pal.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        title: Text(
          'Bildirimleri Etkinleştir'.tr(context),
          style: TextStyle(
            color: pal.ink,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        value: appState.notificationsEnabled,
        activeThumbColor: pal.onInk,
        activeTrackColor: pal.ink,
        onChanged: (v) => appState.setNotificationsEnabled(v),
      ),
    );
  }

  Widget _buildPrivacySection() {
    final pal = context.pal;
    return Material(
      color: pal.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: pal.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            title: Text(
              'Asistan veri paylaşımı'.tr(context),
              style: TextStyle(
                color: pal.ink,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              'Verilerin yanıt üretmek için yapay zeka sağlayıcısına gönderilir.'
                  .tr(context),
              style: TextStyle(color: pal.muted, fontSize: 12),
            ),
            value: _aiConsent,
            activeThumbColor: pal.onInk,
            activeTrackColor: pal.ink,
            onChanged: (v) async {
              await AiConsent.set(v);
              if (mounted) setState(() => _aiConsent = v);
            },
          ),
          Divider(height: 1, color: pal.border),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              'Gizlilik Politikası'.tr(context),
              style: TextStyle(
                color: pal.ink,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            trailing: Icon(Icons.chevron_right_rounded, color: pal.muted),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _syncStatus(AppState appState) {
    if (appState.isSyncing) return 'Eşitleniyor…'.tr(context);
    if (appState.lastSyncError != null) {
      return 'Eşitlenemedi. Tekrar denemek için dokun.'.tr(context);
    }
    final at = appState.lastSyncAt;
    if (at == null) return 'Henüz eşitlenmedi'.tr(context);
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${'Son eşitleme:'.tr(context)} $hh:$mm';
  }

  Future<void> _toggleSync(AppState appState, bool enable) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = 'İşlem tamamlanamadı. Bağlantını kontrol et.'.tr(context);
    if (enable) {
      await appState.setSyncEnabled(true);
      return;
    }
    // Kapatırken sunucudaki yedeğin de silinip silinmeyeceğini sor.
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bulut yedeklemeyi kapat'.tr(ctx)),
        content: Text(
          'Verilerin bu cihazda kalır. Sunucudaki yedeği de silmek ister misin?'
              .tr(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: Text('Vazgeç'.tr(ctx)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: Text('Yedeği koru'.tr(ctx)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            style: TextButton.styleFrom(foregroundColor: ctx.pal.negative),
            child: Text('Yedeği sil'.tr(ctx)),
          ),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') return;
    try {
      await appState.setSyncEnabled(false, deleteRemote: choice == 'delete');
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Widget _buildSyncSection(AppState appState) {
    final pal = context.pal;
    return Material(
      color: pal.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: pal.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            title: Text(
              'Bulut yedekleme'.tr(context),
              style: TextStyle(
                color: pal.ink,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              'Verilerin cihaz kaybında geri yüklenir ve cihazlar arasında eşitlenir.'
                  .tr(context),
              style: TextStyle(color: pal.muted, fontSize: 12),
            ),
            value: appState.syncEnabled,
            activeThumbColor: pal.onInk,
            activeTrackColor: pal.ink,
            onChanged: (v) => _toggleSync(appState, v),
          ),
          if (appState.syncEnabled) ...[
            Divider(height: 1, color: pal.border),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(
                _syncStatus(appState),
                style: TextStyle(
                  color: appState.lastSyncError != null
                      ? pal.negative
                      : pal.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: appState.isSyncing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: pal.ink,
                      ),
                    )
                  : Icon(Icons.sync_rounded, color: pal.ink),
              onTap: appState.isSyncing ? null : appState.syncNow,
            ),
          ],
        ],
      ),
    );
  }
}
