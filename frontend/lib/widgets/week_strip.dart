import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Haftanın 7 gününü eşit genişlikte gösteren seçici (Pazartesi–Pazar hep görünür).
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.days,
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  }) : assert(days.length == 7 && labels.length == 7);

  final List<DateTime> days;
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final today = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: pal.shadow.withValues(alpha: 0.04), blurRadius: 10),
        ],
      ),
      child: Row(
        children: List.generate(7, (i) {
          final d = days[i];
          final selected = i == selectedIndex;
          final isToday =
              d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: '${labels[i]} ${d.day}',
              child: GestureDetector(
                onTap: () => onSelect(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? pal.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        labels[i],
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          color: selected
                              ? pal.onInk.withValues(alpha: 0.7)
                              : pal.subtle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 18,
                          color: selected ? pal.onInk : pal.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Bugünü işaretleyen nokta
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isToday
                              ? (selected ? pal.onInk : pal.ink)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
