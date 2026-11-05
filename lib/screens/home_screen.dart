import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/widgets.dart';
import 'profile_screen.dart';
import 'task_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tasks, settings, auth]),
      builder: (context, _) {
        final p = Pal.of(context);
        final sel = tasks.selected;
        final dayTasks = tasks.forDay(sel);
        final doneCount = dayTasks.where((t) => t.done).length;
        final progress = tasks.progressFor(sel);

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
            children: [
              _Header(selected: sel),
              if (settings.showWeek) _WeekStrip(selected: sel),
              if (settings.showNow) ...[
                const SizedBox(height: 14),
                _NowCard(selected: sel, dayTasks: dayTasks),
              ],
              if (settings.showProgress) ...[
                const SizedBox(height: 22),
                Center(
                  child: RingProgress(
                    value: progress,
                    size: 150,
                    caption: dayTasks.isEmpty
                        ? 'нет задач'
                        : '$doneCount из ${dayTasks.length}',
                  ),
                ),
              ],
              if (settings.showHabits) _HabitsSection(selected: sel),
              if (settings.showTasks) ...[
                SectionTitle(
                  sameDay(sel, DateTime.now()) ? 'Задачи на сегодня' : 'Задачи на день',
                ),
                if (dayTasks.isEmpty)
                  const EmptyHint('На этот день задач нет.\nНажмите «+», чтобы добавить.')
                else
                  for (var i = 0; i < dayTasks.length; i++)
                    TaskCard(
                      key: ValueKey('tc${dayTasks[i].id}'),
                      task: dayTasks[i],
                      index: i,
                    ),
              ],
              if (!settings.showNow &&
                  !settings.showWeek &&
                  !settings.showProgress &&
                  !settings.showHabits &&
                  !settings.showTasks)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Text(
                    'Все блоки главного экрана скрыты.\nВключить их можно в профиле.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.subtext),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime selected;
  const _Header({required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final name = auth.user?.name ?? '';
    final initial =
        name.isNotEmpty ? String.fromCharCode(name.runes.first).toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${greeting(DateTime.now())}, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: p.accentText),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                          .animate(a),
                      child: c,
                    ),
                  ),
                  child: Text(
                    fullDate(selected),
                    key: ValueKey(ymd(selected)),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color.lerp(p.accent, Colors.white, 0.2)!, p.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: p.accent.withAlpha(90),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: onAccent,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final DateTime selected;
  const _WeekStrip({required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final back = settings.firstDay == 0 ? selected.weekday - 1 : selected.weekday % 7;
    final start = addDays(selected, -back);
    final labels = weekdayLabels(settings.firstDay);
    final today = dateOnly(DateTime.now());

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (context) {
              final d = addDays(start, i);
              final isSel = sameDay(d, selected);
              final hasTasks = tasks.countOn(d) > 0;
              return GestureDetector(
                onTap: () => tasks.select(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.fromLTRB(2.5, isSel ? 0 : 4, 2.5, isSel ? 4 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? p.accent : p.accent.withAlpha(60),
                    borderRadius: BorderRadius.circular(14),
                    border: sameDay(d, today) && !isSel
                        ? Border.all(color: p.accent, width: 1.4)
                        : null,
                    boxShadow: isSel
                        ? [
                            BoxShadow(
                              color: p.accent.withAlpha(110),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSel ? onAccent : p.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSel ? onAccent : p.subtext,
                        ),
                      ),
                      const SizedBox(height: 3),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasTasks
                              ? (isSel ? onAccent : p.accent)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _NowCard extends StatelessWidget {
  final DateTime selected;
  final List<Task> dayTasks;
  const _NowCard({required this.selected, required this.dayTasks});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final open = dayTasks.where((t) => !t.done).toList();
    final Task? current = open.isEmpty ? null : open.first;
    final isToday = sameDay(selected, DateTime.now());

    // Следующий невыполненный шаг текущей задачи
    final pending =
        current?.subtasks.where((s) => !s.done).toList() ?? const <Subtask>[];
    final Subtask? nextStep = pending.isEmpty ? null : pending.first;

    return AnimatedSize(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.accent.withAlpha(p.isDark ? 90 : 85),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isToday ? 'Сейчас' : 'Первая задача дня',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: p.accentText,
              ),
            ),
            const SizedBox(height: 6),
            if (current == null) ...[
              Text(
                dayTasks.isEmpty ? 'Свободный день' : 'Всё выполнено 🎉',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _NowButton(
                label: 'Добавить задачу',
                filled: true,
                onTap: () => showTaskSheet(context),
              ),
            ] else ...[
              Text(
                current.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              if (current.time != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    formatTime(current.time!, settings.is24),
                    style: TextStyle(color: p.subtext, fontSize: 13),
                  ),
                ),
              if (current.subtasks.isNotEmpty) ...[
                const SizedBox(height: 10),
                AppProgressBar(
                  value: current.progress,
                  track: p.surface.withAlpha(180),
                  bar: p.accent,
                  height: 6,
                ),
                if (nextStep != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Следующий шаг: ${nextStep.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.subtext, fontSize: 13),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _NowButton(
                      label: nextStep != null ? 'Шаг выполнен' : 'Готово',
                      filled: true,
                      onTap: () => nextStep != null
                          ? tasks.toggleSubtask(current, nextStep)
                          : tasks.setDone(current, true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NowButton(
                      label: 'Перенести',
                      filled: false,
                      onTap: () => tasks.postpone(current),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NowButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _NowButton({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Material(
      color: filled ? p.accent : p.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: filled ? onAccent : p.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HabitsSection extends StatelessWidget {
  final DateTime selected;
  const _HabitsSection({required this.selected});

  Future<void> _add(BuildContext context) async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая привычка'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Например: Пить воду'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    final n = name?.trim() ?? '';
    if (n.isNotEmpty) await tasks.addHabit(n);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Привычки',
          trailing: IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.add_circle_outline, color: p.ebony),
            onPressed: () => _add(context),
          ),
        ),
        if (tasks.habits.isEmpty)
          const EmptyHint('Добавьте привычку, чтобы отмечать её каждый день.')
        else
          for (var i = 0; i < tasks.habits.length; i++)
            FadeSlideIn(
              key: ValueKey('hf${tasks.habits[i].id}'),
              index: i,
              child: _HabitCard(habit: tasks.habits[i], selected: selected),
            ),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final DateTime selected;
  const _HabitCard({required this.habit, required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final done = tasks.isHabitDone(habit, selected);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('habit_${habit.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: p.ebony,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.delete_outline, color: p.onEbony),
        ),
        onDismissed: (_) => tasks.deleteHabit(habit),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(
            color: p.accent.withAlpha(done ? 140 : 255),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  habit.title,
                  style: TextStyle(
                    color: onAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: onAccent,
                  ),
                ),
              ),
              CheckCircle(
                checked: done,
                onTap: () => tasks.toggleHabit(habit, selected),
                borderColor: onAccent,
                fillColor: onAccent,
                checkColor: p.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
