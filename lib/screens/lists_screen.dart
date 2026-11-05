import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../widgets/widgets.dart';
import 'profile_screen.dart';

class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([tasks, settings]),
      builder: (context, _) {
        final p = Pal.of(context);
        final important = tasks.importantOpen;
        final other = tasks.otherOpen;
        final done = tasks.doneList;
        final empty = important.isEmpty && other.isEmpty && done.isEmpty;

        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.surface.withAlpha(p.isDark ? 255 : 150),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: RingProgress(
                      value: tasks.overallProgress,
                      size: 84,
                      stroke: 7,
                      caption: 'выполнено',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.account_circle_outlined, size: 30, color: p.ebony),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
                    ),
                  ),
                ],
              ),
              const SectionTitle('Важные задачи'),
              if (important.isEmpty)
                const EmptyHint('Важных невыполненных задач нет.')
              else
                for (final t in important)
                  TaskRow(key: ValueKey('r${t.id}'), task: t, showDate: true),
              if (other.isNotEmpty) ...[
                const SectionTitle('Остальные задачи'),
                for (final t in other)
                  TaskRow(key: ValueKey('r${t.id}'), task: t, showDate: true),
              ],
              if (done.isNotEmpty) ...[
                SectionTitle('Выполненные (${done.length})'),
                for (final t in done.take(30))
                  TaskRow(key: ValueKey('r${t.id}'), task: t, showDate: true),
              ],
              if (empty)
                const EmptyHint('Пока пусто.\nНажмите «+», чтобы создать первую задачу.'),
            ],
          ),
        );
      },
    );
  }
}
