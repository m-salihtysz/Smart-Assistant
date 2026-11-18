part of '../main.dart';

class RoutinesTab extends StatefulWidget {
  const RoutinesTab({super.key});

  @override
  State<RoutinesTab> createState() => _RoutinesTabState();
}

class _RoutinesTabState extends State<RoutinesTab> {
  DateTime _selectedDate = DateTime.now();
  final Map<int, List<_RoutineItem>> _routinesByDay = {};
  final Map<String, List<bool>> _completions = {};

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<_RoutineItem> _routinesFor(int dayIndex) {
    return _routinesByDay[dayIndex] ?? [];
  }

  List<bool> _completionsFor(DateTime date) {
    final key = dateKey(date);
    final dayIndex = date.weekday - 1;
    final routines = _routinesFor(dayIndex);
    final list = _completions[key] ?? List.filled(routines.length, false);
    if (list.length != routines.length) {
      return List.generate(
        routines.length,
        (i) => i < list.length ? list[i] : false,
      );
    }
    return list;
  }

  void _setCompleted(DateTime date, int routineIndex, bool value) {
    final key = dateKey(date);
    final list = List<bool>.from(_completionsFor(date));
    if (routineIndex >= list.length) return;
    list[routineIndex] = value;
    _completions[key] = list;
    _saveRoutines();
    setState(() {});
  }

  /// Tamamlanma işaretleri rutinin listedeki sırasına göre tutulur; bir rutin silinince
  /// o haftanın gününe ait tüm tarihlerde aynı sıradaki işareti de kaldır ki kayma olmasın.
  void _dropCompletionIndex(int dayIndex, int routineIndex) {
    for (final entry in _completions.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null || date.weekday - 1 != dayIndex) continue;
      if (routineIndex < entry.value.length) {
        entry.value.removeAt(routineIndex);
      }
    }
  }

  Future<void> _loadRoutines() async {
    final data = await UserStore.readMap('routines');
    final byDay = <int, List<_RoutineItem>>{};
    for (final e in data.entries) {
      final dayIndex = int.tryParse(e.key);
      if (dayIndex == null ||
          dayIndex < 0 ||
          dayIndex > 6 ||
          e.value is! List) {
        continue;
      }
      byDay[dayIndex] = [
        for (final x in e.value as List)
          if (x is Map)
            _RoutineItem(
              title: asString(x['title']),
              hour: asInt(x['hour']) ?? 8,
              minute: asInt(x['minute']) ?? 0,
              reminder: asBool(x['reminder']),
              notificationId: asInt(x['notificationId']),
            ),
      ];
    }
    final completions = <String, List<bool>>{};
    final raw = data['completions'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List) {
          completions['$k'] = [for (final c in v) c == true];
        }
      });
    }
    if (!mounted) return;
    setState(() {
      _routinesByDay
        ..clear()
        ..addAll(byDay);
      _completions
        ..clear()
        ..addAll(completions);
    });
  }

  Future<void> _saveRoutines() async {
    final data = <String, dynamic>{};
    _routinesByDay.forEach((dayIndex, list) {
      data['$dayIndex'] = list
          .map(
            (r) => {
              'title': r.title,
              'hour': r.hour,
              'minute': r.minute,
              'reminder': r.reminder,
              'notificationId': r.notificationId,
            },
          )
          .toList();
    });
    // Tamamlanma geçmişi sınırsız büyümesin: 120 günden eski kayıtları at.
    final cutoff = DateTime.now().subtract(const Duration(days: 120));
    _completions.removeWhere((k, _) {
      final d = DateTime.tryParse(k);
      return d != null && d.isBefore(cutoff);
    });
    data['completions'] = _completions;
    await UserStore.setString('routines', jsonEncode(data));
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
                      subtitle: Text(
                        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: pickedTime,
                          );
                          if (t != null) setStateDialog(() => pickedTime = t);
                        },
                        child: Text('Saat seç'.tr(context)),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Vazgeç'.tr(context)),
                ),
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
      await scheduleRoutineReminder(
        notificationId,
        titleController.text.trim(),
        dayIndex + 1,
        pickedTime.hour,
        pickedTime.minute,
      );
    }
    if (mounted) {
      setState(() {
        final list = List<_RoutineItem>.from(_routinesFor(dayIndex));
        list.add(
          _RoutineItem(
            title: titleController.text.trim(),
            hour: pickedTime.hour,
            minute: pickedTime.minute,
            reminder: wantReminder,
            notificationId: notificationId,
          ),
        );
        _routinesByDay[dayIndex] = list;
      });
    }
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
                      decoration: InputDecoration(
                        labelText: 'Rutin adı'.tr(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text('Saat'.tr(context)),
                      subtitle: Text(
                        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: pickedTime,
                          );
                          if (t != null) setStateDialog(() => pickedTime = t);
                        },
                        child: Text('Değiştir'.tr(context)),
                      ),
                    ),
                    const SizedBox(height: 8),
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
      if (item.notificationId != null) {
        await cancelReminderNotification(item.notificationId!);
      }
      if (mounted) {
        setState(() {
          final newList = List<_RoutineItem>.from(list)..removeAt(index);
          _routinesByDay[dayIndex] = newList;
          _dropCompletionIndex(dayIndex, index);
        });
      }
      await _saveRoutines();
    } else if (result == 'save') {
      if (item.notificationId != null) {
        await cancelReminderNotification(item.notificationId!);
      }
      int? notificationId;
      if (wantReminder) {
        notificationId = nextNotificationId();
        await scheduleRoutineReminder(
          notificationId,
          titleController.text.trim(),
          dayIndex + 1,
          pickedTime.hour,
          pickedTime.minute,
        );
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
    final weekDays = weekDaysOf(DateTime.now());
    final dayIndex = _selectedDate.weekday - 1;
    final routines = _routinesFor(dayIndex);
    final completions = _completionsFor(_selectedDate);
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
          child: Text(
            isToday
                ? 'Bugünün Rutinleri'.tr(context)
                : '${_selectedDate.day}.${_selectedDate.month} ${'Rutinleri'.tr(context)}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: context.pal.ink,
            ),
          ),
        ),

        Expanded(
          child: routines.isEmpty
              ? EmptyState(
                  icon: Icons.auto_awesome_rounded,
                  message: 'Bu gün için rutin bulunmuyor.'.tr(context),
                  hint:
                      'Tekrarlayan alışkanlıklarını ekleyip tamamladıkça işaretle.'
                          .tr(context),
                  actionLabel: 'Rutin ekle'.tr(context),
                  onAction: _addRoutine,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: routines.length,
                  itemBuilder: (context, index) {
                    final r = routines[index];
                    final done =
                        index < completions.length && completions[index];
                    final timeStr =
                        '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';

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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Checkbox(
                            value: done,
                            onChanged: (v) =>
                                _setCompleted(_selectedDate, index, v ?? false),
                            activeColor: context.pal.ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          title: Text(
                            r.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: done ? context.pal.muted : context.pal.ink,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            timeStr,
                            style: TextStyle(
                              color: context.pal.ink,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (r.reminder)
                                const Icon(
                                  Icons.notifications_active_rounded,
                                  size: 18,
                                  color: Colors.amber,
                                ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: context.pal.subtle,
                              ),
                            ],
                          ),
                          onTap: () => _editRoutine(index),
                        ),
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
              'Yeni Rutin Ekle'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineItem {
  _RoutineItem({
    required this.title,
    required this.hour,
    required this.minute,
    this.reminder = false,
    this.notificationId,
  });
  final String title;
  final int hour;
  final int minute;
  final bool reminder;
  final int? notificationId;
}
