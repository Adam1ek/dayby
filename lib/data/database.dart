import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Локальная база данных SQLite (файл dayby.db создаётся на устройстве
/// автоматически при первом запуске).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'dayby.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (d, oldV, newV) async {
        if (oldV < 2) await _createSubtasks(d);
      },
      onCreate: (d, version) async {
        await d.execute('''
          CREATE TABLE users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await d.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            date TEXT NOT NULL,
            time TEXT,
            important INTEGER NOT NULL DEFAULT 0,
            done INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
          )
        ''');
        await d.execute('CREATE INDEX idx_tasks_user_date ON tasks(user_id, date)');
        await _createSubtasks(d);
        await d.execute('''
          CREATE TABLE habits(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
          )
        ''');
        await d.execute('''
          CREATE TABLE habit_logs(
            habit_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            PRIMARY KEY(habit_id, date),
            FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<void> _createSubtasks(Database d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS subtasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
  }
}
