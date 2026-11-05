class AppUser {
  final int id;
  final String name;
  final String email;

  const AppUser({required this.id, required this.name, required this.email});

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['id'] as int,
        name: m['name'] as String,
        email: m['email'] as String,
      );

  AppUser copyWith({String? name}) =>
      AppUser(id: id, name: name ?? this.name, email: email);
}

/// Шаг внутри задачи — позволяет выполнять задачу постепенно.
class Subtask {
  final int id;
  final int taskId;
  final String title;
  final bool done;

  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.done = false,
  });

  factory Subtask.fromMap(Map<String, Object?> m) => Subtask(
        id: m['id'] as int,
        taskId: m['task_id'] as int,
        title: m['title'] as String,
        done: (m['done'] as int) == 1,
      );

  Subtask copyWith({bool? done}) =>
      Subtask(id: id, taskId: taskId, title: title, done: done ?? this.done);
}

class Task {
  final int id;
  final String title;
  final String note;
  final String date; // yyyy-MM-dd
  final String? time; // HH:mm
  final bool important;
  final bool done;
  final List<Subtask> subtasks;

  const Task({
    required this.id,
    required this.title,
    this.note = '',
    required this.date,
    this.time,
    this.important = false,
    this.done = false,
    this.subtasks = const [],
  });

  factory Task.fromMap(Map<String, Object?> m, [List<Subtask> subs = const []]) =>
      Task(
        id: m['id'] as int,
        title: m['title'] as String,
        note: (m['note'] as String?) ?? '',
        date: m['date'] as String,
        time: m['time'] as String?,
        important: (m['important'] as int) == 1,
        done: (m['done'] as int) == 1,
        subtasks: subs,
      );

  /// Прогресс задачи 0..1: по шагам, если они есть.
  double get progress {
    if (subtasks.isNotEmpty) {
      return subtasks.where((s) => s.done).length / subtasks.length;
    }
    return done ? 1 : 0;
  }

  Task copyWith({
    String? title,
    String? note,
    String? date,
    String? time,
    bool clearTime = false,
    bool? important,
    bool? done,
    List<Subtask>? subtasks,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
        date: date ?? this.date,
        time: clearTime ? null : (time ?? this.time),
        important: important ?? this.important,
        done: done ?? this.done,
        subtasks: subtasks ?? this.subtasks,
      );
}

class Habit {
  final int id;
  final String title;

  const Habit({required this.id, required this.title});

  factory Habit.fromMap(Map<String, Object?> m) =>
      Habit(id: m['id'] as int, title: m['title'] as String);
}
