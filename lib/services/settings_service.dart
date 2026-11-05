import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

/// Настройки профиля: тема, цвета, размер текста, блоки главного экрана.
class SettingsService extends ChangeNotifier {
  late SharedPreferences _p;

  int theme = 0; // 0 системная, 1 светлая, 2 тёмная
  int textSize = 1; // 0 маленький, 1 средний, 2 крупный
  int paletteIndex = 0; // 0..5 готовые, 6 — свой цвет
  double customHue = 340;
  bool showNow = true;
  bool showWeek = true;
  bool showHabits = true;
  bool showProgress = true;
  bool showTasks = true;
  int firstDay = 0; // 0 понедельник, 1 воскресенье
  bool is24 = true;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    theme = _p.getInt('theme') ?? 0;
    textSize = _p.getInt('textSize') ?? 1;
    paletteIndex = _p.getInt('palette') ?? 0;
    customHue = _p.getDouble('hue') ?? 340;
    showNow = _p.getBool('showNow') ?? true;
    showWeek = _p.getBool('showWeek') ?? true;
    showHabits = _p.getBool('showHabits') ?? true;
    showProgress = _p.getBool('showProgress') ?? true;
    showTasks = _p.getBool('showTasks') ?? true;
    firstDay = _p.getInt('firstDay') ?? 0;
    is24 = _p.getBool('is24') ?? true;
  }

  ThemeMode get themeMode => const [
        ThemeMode.system,
        ThemeMode.light,
        ThemeMode.dark,
      ][theme];

  double get textScale => const [0.9, 1.0, 1.15][textSize];

  void setTheme(int v) {
    theme = v;
    _p.setInt('theme', v);
    notifyListeners();
  }

  void setTextSize(int v) {
    textSize = v;
    _p.setInt('textSize', v);
    notifyListeners();
  }

  void setPalette(int i) {
    paletteIndex = i;
    persistPalette();
    notifyListeners();
  }

  /// Вызывается во время движения ползунка (без записи на диск).
  void setCustomHue(double v) {
    customHue = v;
    paletteIndex = PalettePreset.customIndex;
    notifyListeners();
  }

  void persistPalette() {
    _p.setInt('palette', paletteIndex);
    _p.setDouble('hue', customHue);
  }

  void setFirstDay(int v) {
    firstDay = v;
    _p.setInt('firstDay', v);
    notifyListeners();
  }

  void setIs24(bool v) {
    is24 = v;
    _p.setBool('is24', v);
    notifyListeners();
  }

  void setBlock(String key, bool v) {
    switch (key) {
      case 'showNow':
        showNow = v;
        break;
      case 'showWeek':
        showWeek = v;
        break;
      case 'showHabits':
        showHabits = v;
        break;
      case 'showProgress':
        showProgress = v;
        break;
      case 'showTasks':
        showTasks = v;
        break;
    }
    _p.setBool(key, v);
    notifyListeners();
  }
}
