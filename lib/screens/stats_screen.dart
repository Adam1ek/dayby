import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/widgets.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tasks, settings]),
      builder: (context, _) {
        final p = Pal.of(context);
        final today = dateOnly(DateTime.now());
        final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
        final habitsDoneToday =
            tasks.habits.where((h) => tasks.isHabitDone(h, today)).length;

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: Text('Статистика',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              Center(
                child: RingProgress(
                  value: tasks.overallProgress,
                  size: 150,
                  caption: 'всего выполнено',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _Tile('Всего задач', '${tasks.totalCount}')),
                  const SizedBox(width: 10),
                  Expanded(child: _Tile('Выполнено', '${tasks.totalDone}')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _Tile('Серия дней', '${tasks.streak}')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tile(
                      'Привычки сегодня',
                      '$habitsDoneToday/${tasks.habits.length}',
                    ),
                  ),
                ],
              ),
              const SectionTitle('Последние 7 дней'),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                decoration: BoxDecoration(
                  color: p.surface.withAlpha(p.isDark ? 255 : 190),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SizedBox(
                  height: 170,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in days)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                tasks.countOn(d) == 0
                                    ? ''
                                    : '${(tasks.progressFor(d) * 100).round()}%',
                                style: TextStyle(fontSize: 10, color: p.subtext),
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                                width: 22,
                                height: 6 + 100 * tasks.progressFor(d),
                                decoration: BoxDecoration(
                                  color: tasks.countOn(d) == 0
                                      ? p.stroke
                                      : (sameDay(d, today) ? p.ebony : p.accent),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                weekdaysShort[d.weekday - 1],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: sameDay(d, today)
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  const _Tile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.accent.withAlpha(p.isDark ? 110 : 90),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, color: p.subtext)),
        ],
      ),
    );
  }
}
