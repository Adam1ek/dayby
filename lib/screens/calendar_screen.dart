import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/widgets.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(tasks.selected.year, tasks.selected.month, 1);

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tasks, settings]),
      builder: (context, _) {
        final p = Pal.of(context);
        final sel = tasks.selected;
        final today = dateOnly(DateTime.now());

        final first = DateTime(_month.year, _month.month, 1);
        final lead = settings.firstDay == 0 ? first.weekday - 1 : first.weekday % 7;
        final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
        final rows = ((lead + daysInMonth) / 7).ceil();
        final labels = weekdayLabels(settings.firstDay);
        final dayTasks = tasks.forDay(sel);

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: p.ebony, size: 30),
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(
                      '${monthsNom[_month.month - 1]} ${_month.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: p.ebony, size: 30),
                    onPressed: () => _shift(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                decoration: BoxDecoration(
                  color: p.surface.withAlpha(p.isDark ? 255 : 190),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final l in labels)
                          Expanded(
                            child: Center(
                              child: Text(
                                l,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.subtext,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (var r = 0; r < rows; r++)
                      Row(
                        children: [
                          for (var c = 0; c < 7; c++)
                            Expanded(
                              child: Builder(builder: (context) {
                                final dayNum = r * 7 + c - lead + 1;
                                if (dayNum < 1 || dayNum > daysInMonth) {
                                  return const SizedBox(height: 46);
                                }
                                final d = DateTime(_month.year, _month.month, dayNum);
                                final isSel = sameDay(d, sel);
                                final isToday = sameDay(d, today);
                                final has = tasks.countOn(d) > 0;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => tasks.select(d),
                                  child: SizedBox(
                                    height: 46,
                                    child: Center(
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSel ? p.accent : Colors.transparent,
                                          border: isToday && !isSel
                                              ? Border.all(color: p.accent, width: 1.5)
                                              : null,
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '$dayNum',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSel || isToday
                                                    ? FontWeight.w800
                                                    : FontWeight.w500,
                                                color: isSel ? onAccent : p.text,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: has
                                                    ? (isSel ? onAccent : p.accent)
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
                        ],
                      ),
                  ],
                ),
              ),
              SectionTitle(fullDate(sel)),
              if (dayTasks.isEmpty)
                const EmptyHint('На этот день задач нет.')
              else
                for (final t in dayTasks) TaskRow(key: ValueKey('r${t.id}'), task: t),
            ],
          ),
        );
      },
    );
  }
}
