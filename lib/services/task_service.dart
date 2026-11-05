import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/utils.dart';
import '../data/database.dart';

/// Задачи, шаги задач и привычки текущего пользователя (SQLite).
class TaskService extends ChangeNotifier {
  int? _uid;
  List<Task> all = [];
  List<Habit> habits = [];
  final Set<String> _logs = {};
  DateTime selected = dateOnly(DateTime.now());

  Future<void> load(int userId) async {
    _uid = userId;
    final db = await AppDatabase.instance.db;
    final t = await db.query('tasks', where: 'user_id = ?', whereArgs: [userId]);
    final s = await db.rawQuery(
      'SELECT s.* FROM subtasks s JOIN tasks t ON t.id = s.task_id '
      'WHERE t.user_id = ? ORDER BY s.position, s.id',
      [userId],
    );
    final byTask = <int, List<Subtask>>{};
    for (final r in s) {
      final st = Subtask.fromMap(r);
      (byTask[st.taskId] ??= []).add(st);
    }
    all = t.map((m) => Task.fromMap(m, byTask[m['id'] as int] ?? const [])).toList();

    final h = await db.query('habits',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'id');
    habits = h.map(Habit.fromMap).toList();
    _logs.clear();
    if (habits.isNotEmpty) {
      final ids = habits.map((e) => e.id).join(',');
      final l = await db
          .rawQuery('SELECT habit_id, date FROM habit_logs WHERE habit_id IN ($ids)');
      for (final r in l) {
        _logs.add('${r['habit_id']}|${r['date']}');
      }
    }
    selected = dateOnly(DateTime.now());
    notifyListeners();
  }

  void clear() {
    _uid = null;
    all = [];
    habits = [];
    _logs.clear();
    selected = dateOnly(DateTime.now());
    notifyListeners();
  }

  void select(DateTime d) {
    selected = dateOnly(d);
    notifyListeners();
  }

  // ---------- Выборки ----------

  static int _cmp(Task a, Task b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final c = (a.time ?? '99:99').compareTo(b.time ?? '99:99');
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  List<Task> forDay(DateTime d) {
    final k = ymd(d);
    final l = all.where((t) => t.date == k).toList()..sort(_cmp);
    return l;
  }

  int countOn(DateTime d) {
    final k = ymd(d);
    return all.where((t) => t.date == k).length;
  }

  List<Task> get importantOpen {
    final l = all.where((t) => t.important && !t.done).toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : _cmp(a, b);
      });
    return l;
  }

  List<Task> get otherOpen {
    final l = all.where((t) => !t.important && !t.done).toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : _cmp(a, b);
      });
    return l;
  }

  List<Task> get doneList {
    final l = all.where((t) => t.done).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return l;
  }

  // ---------- Статистика (прогресс учитывает выполненные шаги) ----------

  int get totalCount => all.length;
  int get totalDone => all.where((t) => t.done).length;

  double get overallProgress => all.isEmpty
      ? 0
      : all.fold<double>(0, (a, t) => a + t.progress) / all.length;

  double progressFor(DateTime d) {
    final l = forDay(d);
    if (l.isEmpty) return 0;
    return l.fold<double>(0, (a, t) => a + t.progress) / l.length;
  }

  /// Количество подряд идущих дней, в которых выполнены все задачи.
  int get streak {
    bool ok(DateTime d) {
      final l = forDay(d);
      return l.isNotEmpty && l.every((t) => t.done);
    }

    var d = dateOnly(DateTime.now());
    if (!ok(d)) d = addDays(d, -1);
    var s = 0;
    while (ok(d)) {
      s++;
      d = addDays(d, -1);
    }
    return s;
  }

  // ---------- Задачи ----------

  /// Создаёт задачу (existing == null) или сохраняет изменения вместе с шагами.
  Future<void> saveTask({
    Task? existing,
    required String title,
    String note = '',
    required DateTime date,
    String? time,
    bool important = false,
    List<Subtask> subs = const [],
  }) async {
    if (_uid == null) return;
    final db = await AppDatabase.instance.db;
    final done = subs.isNotEmpty ? subs.every((s) => s.done) : (existing?.done ?? false);
    final int id;
    if (existing == null) {
      id = await db.insert('tasks', {
        'user_id': _uid,
        'title': title,
        'note': note,
        'date': ymd(date),
        'time': time,
        'important': important ? 1 : 0,
        'done': done ? 1 : 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      id = existing.id;
      await db.update(
        'tasks',
        {
          'title': title,
          'note': note,
          'date': ymd(date),
          'time': time,
          'important': important ? 1 : 0,
          'done': done ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await db.delete('subtasks', where: 'task_id = ?', whereArgs: [id]);
    }
    final saved = <Subtask>[];
    for (var i = 0; i < subs.length; i++) {
      final sid = await db.insert('subtasks', {
        'task_id': id,
        'title': subs[i].title,
        'done': subs[i].done ? 1 : 0,
        'position': i,
      });
      saved.add(Subtask(id: sid, taskId: id, title: subs[i].title, done: subs[i].done));
    }
    final t = Task(
      id: id,
      title: title,
      note: note,
      date: ymd(date),
      time: time,
      important: important,
      done: done,
      subtasks: saved,
    );
    all = existing == null ? [...all, t] : all.map((e) => e.id == id ? t : e).toList();
    notifyListeners();
  }

  Future<void> _writeTask(Task t) async {
    final db = await AppDatabase.instance.db;
    await db.update(
      'tasks',
      {
        'title': t.title,
        'note': t.note,
        'date': t.date,
        'time': t.time,
        'important': t.important ? 1 : 0,
        'done': t.done ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  void _replace(Task t) {
    all = all.map((e) => e.id == t.id ? t : e).toList();
    notifyListeners();
  }

  /// Отметить всю задачу (и все её шаги) выполненной или нет.
  Future<void> setDone(Task t, bool v) async {
    final subs = t.subtasks.map((s) => s.copyWith(done: v)).toList();
    final nt = t.copyWith(done: v, subtasks: subs);
    _replace(nt);
    final db = await AppDatabase.instance.db;
    await _writeTask(nt);
    if (subs.isNotEmpty) {
      await db.update('subtasks', {'done': v ? 1 : 0},
          where: 'task_id = ?', whereArgs: [t.id]);
    }
  }

  /// Отметить один шаг. Когда выполнены все шаги — задача выполнена.
  Future<void> toggleSubtask(Task t, Subtask s) async {
    final subs = t.subtasks
        .map((e) => e.id == s.id ? e.copyWith(done: !e.done) : e)
        .toList();
    final nt = t.copyWith(subtasks: subs, done: subs.every((e) => e.done));
    _replace(nt);
    final db = await AppDatabase.instance.db;
    await db.update('subtasks', {'done': s.done ? 0 : 1},
        where: 'id = ?', whereArgs: [s.id]);
    await _writeTask(nt);
  }

  Future<void> postpone(Task t) async {
    final nt = t.copyWith(date: ymd(addDays(parseYmd(t.date), 1)));
    _replace(nt);
    await _writeTask(nt);
  }

  Future<void> deleteTask(Task t) async {
    all = all.where((e) => e.id != t.id).toList();
    notifyListeners();
    final db = await AppDatabase.instance.db;
    await db.delete('subtasks', where: 'task_id = ?', whereArgs: [t.id]);
    await db.delete('tasks', where: 'id = ?', whereArgs: [t.id]);
  }

  // ---------- Привычки ----------

  bool isHabitDone(Habit h, DateTime d) => _logs.contains('${h.id}|${ymd(d)}');

  Future<void> addHabit(String title) async {
    if (_uid == null) return;
    final db = await AppDatabase.instance.db;
    final id = await db.insert('habits', {
      'user_id': _uid,
      'title': title,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    habits = [...habits, Habit(id: id, title: title)];
    notifyListeners();
  }

  Future<void> deleteHabit(Habit h) async {
    habits = habits.where((e) => e.id != h.id).toList();
    _logs.removeWhere((k) => k.startsWith('${h.id}|'));
    notifyListeners();
    final db = await AppDatabase.instance.db;
    await db.delete('habit_logs', where: 'habit_id = ?', whereArgs: [h.id]);
    await db.delete('habits', where: 'id = ?', whereArgs: [h.id]);
  }

  Future<void> toggleHabit(Habit h, DateTime d) async {
    final key = '${h.id}|${ymd(d)}';
    final db = await AppDatabase.instance.db;
    if (_logs.contains(key)) {
      _logs.remove(key);
      notifyListeners();
      await db.delete('habit_logs',
          where: 'habit_id = ? AND date = ?', whereArgs: [h.id, ymd(d)]);
    } else {
      _logs.add(key);
      notifyListeners();
      await db.insert('habit_logs', {'habit_id': h.id, 'date': ymd(d)});
    }
  }
}
