import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/models.dart';
import '../data/database.dart';

/// Регистрация, вход, выход. Пароли хранятся только в виде хэша с солью.
class AuthService extends ChangeNotifier {
  static const _sessionKey = 'session_user_id';
  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  AppUser? user;

  /// Восстанавливает сессию при запуске приложения.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_sessionKey);
    if (id == null) return;
    final db = await AppDatabase.instance.db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) {
      user = AppUser.fromMap(rows.first);
    } else {
      await prefs.remove(_sessionKey);
    }
  }

  String _salt() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  String _hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    var digest = sha256.convert(bytes);
    for (var i = 0; i < 2000; i++) {
      digest = sha256.convert([...digest.bytes, ...bytes]);
    }
    return digest.toString();
  }

  /// Возвращает текст ошибки или null, если всё прошло успешно.
  Future<String?> register(String name, String email, String password) async {
    final n = name.trim();
    final e = email.trim().toLowerCase();
    if (n.isEmpty) return 'Введите имя';
    if (!_emailRe.hasMatch(e)) return 'Введите корректную почту';
    if (password.length < 6) return 'Пароль — минимум 6 символов';

    final db = await AppDatabase.instance.db;
    final exists = await db.query('users', where: 'email = ?', whereArgs: [e], limit: 1);
    if (exists.isNotEmpty) return 'Аккаунт с такой почтой уже существует';

    final salt = _salt();
    try {
      final id = await db.insert('users', {
        'name': n,
        'email': e,
        'password_hash': _hash(password, salt),
        'salt': salt,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      user = AppUser(id: id, name: n, email: e);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_sessionKey, id);
      notifyListeners();
      return null;
    } on DatabaseException {
      return 'Не удалось создать аккаунт. Попробуйте ещё раз';
    }
  }

  Future<String?> login(String email, String password) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty || password.isEmpty) return 'Введите почту и пароль';

    final db = await AppDatabase.instance.db;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [e], limit: 1);
    const wrong = 'Неверная почта или пароль';
    if (rows.isEmpty) return wrong;
    final row = rows.first;
    final salt = row['salt'] as String;
    if (_hash(password, salt) != row['password_hash']) return wrong;

    user = AppUser.fromMap(row);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionKey, user!.id);
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final n = name.trim();
    if (user == null || n.isEmpty) return;
    final db = await AppDatabase.instance.db;
    await db.update('users', {'name': n}, where: 'id = ?', whereArgs: [user!.id]);
    user = user!.copyWith(name: n);
    notifyListeners();
  }
}
