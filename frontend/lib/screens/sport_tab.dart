part of '../main.dart';

class SportTab extends StatefulWidget {
  const SportTab({super.key});

  @override
  State<SportTab> createState() => _SportTabState();
}

class _SportTabState extends State<SportTab> {
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
    'Göğüs': [
      'Bench Press',
      'Incline Dumbbell Press',
      'Chest Fly (Kablo veya Dumbbell)',
      'Push-up (Şınav)',
      'Dips',
    ],
    'Sırt': [
      'Lat Pulldown',
      'Seated Cable Row',
      'Bent Over Row',
      'Deadlift',
      'Pull-up (Barfiks)',
    ],
    'Omuz': [
      'Overhead Press',
      'Lateral Raise (Yan Açış)',
      'Front Raise (Ön Açış)',
      'Face Pull',
      'Shrug',
    ],
    'Kol': [
      'Biceps: Barbell Curl',
      'Biceps: Hammer Curl',
      'Triceps: Triceps Pushdown',
      'Triceps: Skull Crusher',
      'Ön Kol: Reverse Curl',
    ],
    'Bacak': ['Squat', 'Leg Press', 'Leg Extension', 'Leg Curl', 'Calf Raise'],
    'Kardiyo': [
      'Koşu Bandı',
      'Bisiklet',
      'Eliptik Bisiklet',
      'Kürek Çekme',
      'İp Atlama',
    ],
    'Tüm vücut': [
      'Goblet Squat',
      'Push-up',
      'Dumbbell Row',
      'Shoulder Press',
      'Plank',
    ],
    'Dinlenme': [
      'Hafif Esneme Hareketleri',
      'Kısa Mesafe Yürüyüş',
      'Mobilite Egzersizleri',
      'Vücut Bakımı ve Uyku',
    ],
  };

  int _selectedDayIndex = DateTime.now().weekday - 1; // 0-6

  final Map<int, _WorkoutPlan> _plans = {};

  @override
  void initState() {
    super.initState();
    _loadSportPlans();
  }

  Future<void> _loadSportPlans() async {
    final data = await UserStore.readMap('sport_plans');
    final plans = <int, _WorkoutPlan>{};
    for (final entry in data.entries) {
      final dayIndex = int.tryParse(entry.key);
      final plan = entry.value;
      if (dayIndex == null || dayIndex < 0 || dayIndex > 6 || plan is! Map) {
        continue;
      }
      final exercises = <_WorkoutExercise>[];
      final raw = plan['exercises'];
      if (raw is List) {
        for (final ex in raw) {
          if (ex is! Map) continue;
          exercises.add(
            _WorkoutExercise(
              name: asString(ex['name']),
              reps: asInt(ex['reps']) ?? 12,
              sets: asInt(ex['sets']) ?? 3,
              region: asString(ex['region']).isEmpty
                  ? 'Seçilmedi'
                  : asString(ex['region']),
            ),
          );
        }
      }
      final region = asString(plan['region']);
      plans[dayIndex] = _WorkoutPlan(
        region: region.isEmpty ? 'Seçilmedi' : region,
        exercises: exercises,
      );
    }
    if (!mounted) return;
    setState(() {
      _plans
        ..clear()
        ..addAll(plans);
    });
  }

  Future<void> _saveSportPlans() async {
    final Map<String, dynamic> data = {};
    _plans.forEach((dayIndex, plan) {
      data['$dayIndex'] = {
        'region': plan.region,
        'exercises': plan.exercises
            .map(
              (e) => {
                'name': e.name,
                'reps': e.reps,
                'sets': e.sets,
                'region': e.region,
              },
            )
            .toList(),
      };
    });
    await UserStore.setString('sport_plans', jsonEncode(data));
  }

  _WorkoutPlan _planForDay(int index) {
    return _plans[index] ??
        _WorkoutPlan(region: _regions[0], exercises: <_WorkoutExercise>[]);
  }

  Future<_ExerciseResult?> _showExerciseDialog({_WorkoutExercise? existing}) {
    return showDialog<_ExerciseResult>(
      context: context,
      builder: (_) => _ExerciseDialog(
        existing: existing,
        regions: _regions,
        regionExercises: _regionExercises,
      ),
    );
  }

  Future<void> _addExercise() async {
    final result = await _showExerciseDialog();
    if (result == null || result.deleted || !mounted) return;

    setState(() {
      final current = _planForDay(_selectedDayIndex);
      _plans[_selectedDayIndex] = _WorkoutPlan(
        region: current.region, // Eski alanı uyumluluk için tutuyoruz
        exercises: [...current.exercises, result.toExercise()],
      );
    });
    await _saveSportPlans();
  }

  Future<void> _editExercise(int index) async {
    final current = _planForDay(_selectedDayIndex);
    if (index < 0 || index >= current.exercises.length) return;

    final result = await _showExerciseDialog(
      existing: current.exercises[index],
    );
    if (result == null || !mounted) return;

    setState(() {
      final updated = List<_WorkoutExercise>.from(current.exercises);
      if (result.deleted) {
        updated.removeAt(index);
      } else {
        updated[index] = result.toExercise();
      }
      _plans[_selectedDayIndex] = _WorkoutPlan(
        region: current.region,
        exercises: updated,
      );
    });
    await _saveSportPlans();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _planForDay(_selectedDayIndex);
    final weekDays = weekDaysOf(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeekStrip(
          days: weekDays,
          labels: [for (final l in kWeekdayShortTr) l.tr(context)],
          selectedIndex: _selectedDayIndex,
          onSelect: (i) => setState(() => _selectedDayIndex = i),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Günün Hedefi'.tr(context),
                    style: TextStyle(
                      color: context.pal.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    plan.exercises.isEmpty
                        ? 'Henüz seçilmedi'.tr(context)
                        : plan.exercises
                              .map((e) => e.region)
                              .toSet()
                              .join(' + ')
                              .tr(context),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: context.pal.ink,
                    ),
                  ),
                ],
              ),
              /* _changeRegion butonu kaldırıldı çünkü artık her hareketin kendi bölgesi var */
            ],
          ),
        ),

        Expanded(
          child: plan.exercises.isEmpty
              ? EmptyState(
                  icon: Icons.fitness_center_rounded,
                  message: 'Bugün için hareket eklenmemiş.'.tr(context),
                  hint: 'Antrenman programını oluşturmak için hareket ekle.'.tr(
                    context,
                  ),
                  actionLabel: 'Hareket ekle'.tr(context),
                  onAction: _addExercise,
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
                        color: context.pal.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: context.pal.shadow.withValues(alpha: 0.04),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () => _editExercise(index),
                        borderRadius: BorderRadius.circular(24),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.pal.ink.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.bolt_rounded,
                                color: context.pal.ink,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          ex.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 17,
                                            color: context.pal.ink,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: context.pal.ink.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          ex.region.tr(context),
                                          style: TextStyle(
                                            color: context.pal.ink,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${ex.sets} Set x ${ex.reps} Tekrar'.tr(
                                      context,
                                    ),
                                    style: TextStyle(
                                      color: context.pal.muted,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: context.pal.subtle,
                            ),
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
              backgroundColor: context.pal.ink,
              foregroundColor: context.pal.onInk,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'Yeni Hareket Ekle'.tr(context),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkoutPlan {
  _WorkoutPlan({required this.region, required this.exercises});

  final String region;
  final List<_WorkoutExercise> exercises;
}

class _WorkoutExercise {
  _WorkoutExercise({
    required this.name,
    required this.reps,
    required this.sets,
    required this.region,
  });

  final String name;
  final int reps;
  final int sets;
  final String region;
}

/// Hareket ekleme/düzenleme penceresinin sonucu.
class _ExerciseResult {
  const _ExerciseResult({
    required this.name,
    required this.reps,
    required this.sets,
    required this.region,
  }) : deleted = false;

  const _ExerciseResult.delete()
    : name = '',
      reps = 0,
      sets = 0,
      region = '',
      deleted = true;

  final String name;
  final int reps;
  final int sets;
  final String region;
  final bool deleted;

  _WorkoutExercise toExercise() =>
      _WorkoutExercise(name: name, reps: reps, sets: sets, region: region);
}

/// Hareket ekleme ve düzenleme için ortak pencere. Denetleyicileri kendisi yönetir ve kapatır.
class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog({
    required this.regions,
    required this.regionExercises,
    this.existing,
  });

  final _WorkoutExercise? existing;
  final List<String> regions;
  final Map<String, List<String>> regionExercises;

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  late String _region;
  late String _name;
  late final TextEditingController _reps;
  late final TextEditingController _sets;
  final _nameController = TextEditingController();

  bool get _editing => widget.existing != null;

  List<String> get _exercises => widget.regionExercises[_region] ?? const [];

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _region = ex?.region ?? widget.regions[1]; // varsayılan: Göğüs
    _name = ex?.name ?? (_exercises.isNotEmpty ? _exercises.first : '');
    _nameController.text = _name;
    _reps = TextEditingController(text: '${ex?.reps ?? 12}');
    _sets = TextEditingController(text: '${ex?.sets ?? 3}');
  }

  @override
  void dispose() {
    _reps.dispose();
    _sets.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.trim();
    final reps = int.tryParse(_reps.text.trim());
    final sets = int.tryParse(_sets.text.trim());
    if (name.isEmpty || reps == null || reps < 1 || sets == null || sets < 1) {
      return;
    }
    Navigator.of(
      context,
    ).pop(_ExerciseResult(name: name, reps: reps, sets: sets, region: _region));
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _exercises;
    return AlertDialog(
      title: Text((_editing ? 'Hareketi düzenle' : 'Hareket ekle').tr(context)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              isExpanded: true,
              value: _region,
              items: widget.regions
                  .map(
                    (r) =>
                        DropdownMenuItem(value: r, child: Text(r.tr(context))),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _region = v;
                  _name = _exercises.isNotEmpty ? _exercises.first : '';
                  _nameController.text = _name;
                });
              },
            ),
            const SizedBox(height: 12),
            if (exercises.isNotEmpty)
              DropdownButton<String>(
                isExpanded: true,
                value: exercises.contains(_name) ? _name : exercises.first,
                items: exercises
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.tr(context)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _name = v ?? ''),
              )
            else
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Hareket adı'.tr(context),
                  hintText: 'Örn. Bench press, Squat...'.tr(context),
                ),
                onChanged: (v) => _name = v,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _reps,
              decoration: InputDecoration(
                labelText: 'Tekrar sayısı'.tr(context),
                hintText: 'Örn. 12'.tr(context),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sets,
              decoration: InputDecoration(
                labelText: 'Set sayısı'.tr(context),
                hintText: 'Örn. 3'.tr(context),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        if (_editing)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _ExerciseResult.delete()),
            child: Text(
              'Sil'.tr(context),
              style: TextStyle(color: context.pal.negative),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Vazgeç'.tr(context)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text((_editing ? 'Kaydet' : 'Ekle').tr(context)),
        ),
      ],
    );
  }
}
