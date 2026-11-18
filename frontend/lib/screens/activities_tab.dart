part of '../main.dart';

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

  Future<void> _loadActivities() async {
    final data = await UserStore.readList('activities');
    final loaded = <String, List<_Activity>>{};
    for (final item in data) {
      if (item is! Map) continue; // bozuk kayıt tüm listeyi çökertmesin
      final date = asString(item['date']);
      if (date.isEmpty) continue;
      loaded
          .putIfAbsent(date, () => [])
          .add(
            _Activity(
              title: asString(item['title']),
              time: TimeOfDay(
                hour: asInt(item['hour']) ?? 0,
                minute: asInt(item['minute']) ?? 0,
              ),
              reminder: asBool(item['reminder']),
              notificationId: asInt(item['notificationId']),
            ),
          );
    }
    if (!mounted) return;
    setState(() {
      _activities
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _saveActivities() async {
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
    await UserStore.setString('activities', jsonEncode(data));
  }

  List<_Activity> get _currentActivities {
    final key = dateKey(_selectedDate);
    final list = List<_Activity>.from(_activities[key] ?? []);
    list.sort(
      (a, b) => a.time.hour != b.time.hour
          ? a.time.hour.compareTo(b.time.hour)
          : a.time.minute.compareTo(b.time.minute),
    );
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
                      decoration: InputDecoration(
                        labelText: 'Başlık'.tr(context),
                      ),
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
                            if (time != null) {
                              setStateDialog(() => pickedTime = time);
                            }
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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Vazgeç'.tr(context)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty ||
                        pickedTime == null) {
                      return;
                    }
                    final key = dateKey(_selectedDate);
                    final list = _activities[key] ?? [];
                    final wantReminder = wantReminderRef[0];
                    int? notificationId;
                    if (wantReminder) {
                      notificationId = nextNotificationId();
                      final when = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        pickedTime!.hour,
                        pickedTime!.minute,
                      );
                      await scheduleActivityReminder(
                        notificationId,
                        titleController.text.trim(),
                        when,
                      );
                    }
                    list.add(
                      _Activity(
                        title: titleController.text.trim(),
                        time: pickedTime!,
                        reminder: wantReminder,
                        notificationId: notificationId,
                      ),
                    );
                    _activities[key] = list;
                    await _saveActivities();
                    if (!mounted || !context.mounted) return;
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

  /// Seçili tarihin haftası (Pzt–Paz).

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
        dateKey: dateKey,
      ),
    );
    if (picked != null) {
      if (mounted) setState(() => _selectedDate = picked);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final activities = _currentActivities;
    final weekDays = weekDaysOf(DateTime.now());
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeekStrip(
          days: weekDays,
          labels: [for (final l in kWeekdayShortTr) l.tr(context)],
          selectedIndex: weekDays.indexWhere(
            (d) => _isSameDay(d, _selectedDate),
          ),
          onSelect: (i) => setState(() => _selectedDate = weekDays[i]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToday
                    ? 'Günün Aktiviteleri'
                    : '${_selectedDate.day}.${_selectedDate.month} Aktiviteleri',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: context.pal.ink,
                ),
              ),
              IconButton(
                onPressed: _openCalendar,
                icon: Icon(
                  Icons.calendar_month_rounded,
                  color: context.pal.ink,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: context.pal.surface,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: activities.isEmpty
              ? EmptyState(
                  icon: Icons.explore_outlined,
                  message: 'Bu gün için aktivite bulunmuyor.'.tr(context),
                  hint:
                      'Randevularını ve planlarını ekle, istersen hatırlatıcı kur.'
                          .tr(context),
                  actionLabel: 'Aktivite ekle'.tr(context),
                  onAction: _addActivity,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final act = activities[index];
                    final timeStr =
                        '${act.time.hour.toString().padLeft(2, '0')}:${act.time.minute.toString().padLeft(2, '0')}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: context.pal.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: context.pal.shadow.withValues(alpha: 0.04),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.pal.ink.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.rocket_launch_rounded,
                              color: context.pal.ink,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            act.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: context.pal.ink,
                            ),
                          ),
                          subtitle: Text(
                            timeStr,
                            style: TextStyle(
                              color: context.pal.ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: context.pal.subtle,
                            ),
                            onPressed: () => _deleteActivity(act),
                          ),
                          onTap: () => _editActivity(act),
                        ),
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
              backgroundColor: context.pal.ink,
              foregroundColor: context.pal.onInk,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'Yeni Aktivite Ekle'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Not: ekrandaki liste saate göre sıralıdır, saklanan liste ise ekleme sırasındadır.
  /// Bu yüzden satır numarası değil aktivitenin kendisi alınır.
  Future<void> _deleteActivity(_Activity item) async {
    final key = dateKey(_selectedDate);
    final list = _activities[key] ?? [];
    final index = list.indexOf(item);
    if (index < 0) return;
    if (item.notificationId != null) {
      await cancelReminderNotification(item.notificationId!);
    }
    if (mounted) {
      setState(() {
        list.removeAt(index);
        _activities[key] = list;
      });
    }
    await _saveActivities();
  }

  Future<void> _editActivity(_Activity current) async {
    final key = dateKey(_selectedDate);
    final list = _activities[key] ?? [];
    final index = list.indexOf(current);
    if (index < 0) return;

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
                      decoration: InputDecoration(
                        labelText: 'Başlık'.tr(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}',
                        ),
                        TextButton(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: pickedTime,
                            );
                            if (time != null) {
                              setStateDialog(() => pickedTime = time);
                            }
                          },
                          child: Text('Saat değiştir'.tr(context)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: wantReminder,
                      onChanged: (v) =>
                          setStateDialog(() => wantReminder = v ?? false),
                      title: Text('Bildirim hatırlatıcı olsun mu?'.tr(context)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('delete'),
                  child: Text(
                    'Sil'.tr(context),
                    style: TextStyle(color: context.pal.negative),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop('cancel'),
                  child: Text('Vazgeç'.tr(context)),
                ),
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
      await _deleteActivity(current);
    } else if (result == 'save') {
      if (current.notificationId != null) {
        await cancelReminderNotification(current.notificationId!);
      }
      int? notificationId;
      if (wantReminder) {
        notificationId = nextNotificationId();
        final when = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        await scheduleActivityReminder(
          notificationId,
          titleController.text.trim(),
          when,
        );
      }
      if (mounted) {
        setState(() {
          list[index] = _Activity(
            title: titleController.text.trim(),
            time: pickedTime,
            reminder: wantReminder,
            notificationId: notificationId,
          );
          _activities[key] = list;
        });
      }
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
  State<_ActivityCalendarDialog> createState() =>
      _ActivityCalendarDialogState();
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
              children: _weekHeaders
                  .map(
                    (h) => SizedBox(
                      width: 32,
                      child: Center(
                        child: Text(h, style: theme.textTheme.bodySmall),
                      ),
                    ),
                  )
                  .toList(),
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
                                  ? context.pal.ink
                                  : hasActivity
                                  ? context.pal.ink.withValues(alpha: 0.1)
                                  : null,
                              border: Border.all(
                                color: selected
                                    ? context.pal.ink
                                    : hasActivity
                                    ? context.pal.ink.withValues(alpha: 0.8)
                                    : context.pal.subtle,
                                width: hasActivity && !selected ? 2 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? context.pal.onInk
                                    : context.pal.ink,
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
