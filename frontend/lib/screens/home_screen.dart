part of '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // ortadaki sekme varsayılan

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Sunucudan veri geldiğinde sekmeler yeni veriyle yeniden yüklensin.
      body: KeyedSubtree(
        key: ValueKey(context.select<AppState, int>((a) => a.dataRevision)),
        child: _buildBody(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: pal.surface,
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: pal.border),
              boxShadow: [
                BoxShadow(
                  color: pal.shadow.withValues(alpha: 0.08),
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
                  label: 'Asistan'.tr(context),
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Ana Sayfa'.tr(context),
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _BottomNavItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Ayarlar'.tr(context),
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
        return _HomeDashboard(
          onOpenAssistant: () => setState(() => _selectedIndex = 0),
        );
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
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 88,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? pal.ink.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? pal.ink : pal.muted,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? pal.ink : pal.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ana sayfa: kategori kartları, bugünün özeti ve hızlı bakış.
class _HomeDashboard extends StatefulWidget {
  const _HomeDashboard({this.onOpenAssistant});

  final VoidCallback? onOpenAssistant;

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _TodayActivity {
  const _TodayActivity(this.title, this.hour, this.minute);
  final String title;
  final int hour;
  final int minute;

  String get time =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class _HomeDashboardState extends State<_HomeDashboard> {
  int? _selectedCategory;

  static const List<_HomeCategory> _categories = [
    _HomeCategory(
      label: 'Aktiviteler',
      icon: Icons.explore_rounded,
      asset: 'assets/home/activities.jpg',
    ),
    _HomeCategory(
      label: 'Rutinler',
      icon: Icons.calendar_month_rounded,
      asset: 'assets/home/routines.jpg',
    ),
    _HomeCategory(
      label: 'Spor',
      icon: Icons.fitness_center_rounded,
      asset: 'assets/home/sport.jpg',
    ),
    _HomeCategory(
      label: 'Finans',
      icon: Icons.account_balance_wallet_rounded,
      asset: 'assets/home/finance.jpg',
    ),
    _HomeCategory(
      label: 'Notlar',
      icon: Icons.edit_note_rounded,
      asset: 'assets/home/notes.jpg',
    ),
  ];

  static const List<String> _monthsTr = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  static const List<String> _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const List<String> _weekdaysTr = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  static const List<String> _weekdaysEn = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  List<_TodayActivity> _todayActivities = [];
  int _routineTotal = 0;
  int _routineDone = 0;
  double _todaySpending = 0.0;
  int _routineReminderCount = 0;

  double get _completionRate =>
      _routineTotal == 0 ? 0 : _routineDone / _routineTotal * 100;

  @override
  void initState() {
    super.initState();
    _loadQuickGlanceData();
  }

  Future<void> _loadQuickGlanceData() async {
    final now = DateTime.now();
    final todayKey = dateKey(now);

    final activities = <_TodayActivity>[];
    for (final item in await UserStore.readList('activities')) {
      if (item is! Map || item['date'] != todayKey) continue;
      activities.add(
        _TodayActivity(
          asString(item['title']),
          asInt(item['hour']) ?? 0,
          asInt(item['minute']) ?? 0,
        ),
      );
    }
    activities.sort(
      (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
    );

    var total = 0;
    var done = 0;
    var reminders = 0;
    final routines = await UserStore.readMap('routines');
    final todays = routines['${now.weekday - 1}'];
    if (todays is List) {
      total = todays.length;
      final completions = routines['completions'];
      final day = completions is Map ? completions[todayKey] : null;
      if (day is List) {
        for (var i = 0; i < todays.length && i < day.length; i++) {
          if (day[i] == true) done++;
        }
      }
      reminders = todays.where((r) => r is Map && asBool(r['reminder'])).length;
    }

    var spending = 0.0;
    for (final tx in await UserStore.readList('finance_transactions')) {
      if (tx is Map &&
          tx['date'] == todayKey &&
          normalizeTxType(tx['type']) == 'gider') {
        spending += asDouble(tx['amount']) ?? 0;
      }
    }

    if (!mounted) return;
    setState(() {
      _todayActivities = activities;
      _routineTotal = total;
      _routineDone = done;
      _routineReminderCount = reminders;
      _todaySpending = spending;
    });
  }

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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler,'.tr(context);
    if (h < 12) return 'Günaydın,'.tr(context);
    if (h < 18) return 'İyi günler,'.tr(context);
    return 'İyi akşamlar,'.tr(context);
  }

  String _todayLabel() {
    final now = DateTime.now();
    final en = context.read<AppState>().locale.languageCode == 'en';
    final month = (en ? _monthsEn : _monthsTr)[now.month - 1];
    final weekday = (en ? _weekdaysEn : _weekdaysTr)[now.weekday - 1];
    return en ? '$weekday, $month ${now.day}' : '${now.day} $month $weekday';
  }

  Widget _buildHeader(String name) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting(),
            style: TextStyle(
              color: pal.muted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            name,
            style: TextStyle(
              color: pal.ink,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Bugünün özeti: aktivite/rutin sayısı ve sıradaki aktivite.
  Widget _buildTodayCard() {
    final pal = context.pal;
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    _TodayActivity? next;
    for (final a in _todayActivities) {
      if (a.hour * 60 + a.minute >= nowMinutes) {
        next = a;
        break;
      }
    }
    final isEmpty = _todayActivities.isEmpty && _routineTotal == 0;

    final String summary;
    if (isEmpty) {
      summary = 'Bugün için planın boş.'.tr(context);
    } else {
      summary =
          '${_todayActivities.length} ${'aktivite'.tr(context)} · $_routineTotal ${'rutin'.tr(context)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: pal.ink,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: pal.shadow.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _todayLabel(),
            style: TextStyle(
              color: pal.onInk.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(
              color: pal.onInk,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.3,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: pal.onInk.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${'Sıradaki:'.tr(context)} ${next.time} · ${next.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pal.onInk,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isEmpty && widget.onOpenAssistant != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onOpenAssistant,
              style: FilledButton.styleFrom(
                backgroundColor: pal.onInk,
                foregroundColor: pal.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                'Asistana planla'.tr(context),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAllCategories() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final pal = sheetContext.pal;
        return Container(
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: pal.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Tüm Kategoriler'.tr(sheetContext),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: pal.ink,
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(_categories.length, (index) {
                final cat = _categories[index];
                return ListTile(
                  leading: Icon(cat.icon, color: pal.ink),
                  title: Text(
                    cat.label.tr(sheetContext),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: pal.ink,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: pal.muted,
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() => _selectedCategory = index);
                  },
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final userName =
        context.watch<AppState>().currentUser?.name ?? 'Kullanıcı'.tr(context);

    if (_selectedCategory != null) {
      return Column(
        children: [
          AppBar(
            backgroundColor: pal.surface,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Geri'.tr(context),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: pal.ink,
              ),
              onPressed: () {
                setState(() => _selectedCategory = null);
                _loadQuickGlanceData();
              },
            ),
            title: Text(
              _categories[_selectedCategory!].label.tr(context),
              style: TextStyle(color: pal.ink, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: _contentFor(_selectedCategory!)),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQuickGlanceData,
      color: pal.ink,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildHeader(userName),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: _buildTodayCard(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Kategoriler'.tr(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pal.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _showAllCategories,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Tümünü Gör'.tr(context),
                            style: TextStyle(
                              color: pal.link,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: pal.link,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 230,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) => _CategoryCard(
                  category: _categories[index],
                  onTap: () => setState(() => _selectedCategory = index),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Text(
                'Hızlı Bakış'.tr(context),
                style: TextStyle(
                  color: pal.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildGoalCard(),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    'Finansal Durum'.tr(context),
                    '₺${_todaySpending.toStringAsFixed(0)} ${'Harcandı'.tr(context)}',
                    Icons.wallet_rounded,
                  ),
                  if (_routineReminderCount > 0) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      'Hatırlatıcılar'.tr(context),
                      '$_routineReminderCount ${'rutin için hatırlatıcı açık'.tr(context)}',
                      Icons.notifications_active_rounded,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 110),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    final pal = context.pal;
    final hasRoutines = _routineTotal > 0;
    final subtitle = hasRoutines
        ? '${_completionRate.toStringAsFixed(0)}% ${'Tamamlandı'.tr(context)}'
        : 'Bugün için rutin yok'.tr(context);
    return _InfoCard(
      icon: Icons.auto_graph_rounded,
      title: 'Günlük Hedef'.tr(context),
      subtitle: subtitle,
      footer: hasRoutines
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _completionRate / 100,
                    minHeight: 8,
                    backgroundColor: pal.fill,
                    color: pal.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_routineDone/$_routineTotal ${'rutin tamamlandı'.tr(context)}',
                  style: TextStyle(
                    color: pal.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildInfoCard(String title, String subtitle, IconData icon) =>
      _InfoCard(icon: icon, title: title, subtitle: subtitle);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.fill,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: pal.ink, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: pal.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: pal.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ?footer,
        ],
      ),
    );
  }
}

/// Kategori kartı: görsel uygulamaya gömülüdür; yüklenemezse gradient + büyük ikon gösterir.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final _HomeCategory category;
  final VoidCallback onTap;

  Widget _fallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A3A40), Color(0xFF16161A)],
      ),
    ),
    child: Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Icon(
          category.icon,
          size: 96,
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.label.tr(context),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 170,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (category.asset != null)
                  Image.asset(
                    category.asset!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallback(),
                  )
                else
                  _fallback(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(category.icon, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        category.label.tr(context),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCategory {
  const _HomeCategory({required this.label, required this.icon, this.asset});
  final String label;
  final IconData icon;
  final String? asset;
}
