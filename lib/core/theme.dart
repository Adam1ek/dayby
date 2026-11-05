import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Готовая цветовая схема (первая — из Figma).
class PalettePreset {
  final String name;
  final Color accent;
  final Color top;
  final Color bottom;
  final Color ebony;
  final Color surface;
  final Color bg;

  const PalettePreset(
    this.name,
    this.accent,
    this.top,
    this.bottom,
    this.ebony,
    this.surface,
    this.bg,
  );

  /// Индекс «своего» цвета (выбирается ползунком оттенка).
  static const int customIndex = 6;

  static const List<PalettePreset> all = [
    PalettePreset('Коралл', Color(0xFFDB827F), Color(0xFFF4B8B1), Color(0xFFFFE6D8),
        Color(0xFF5E604D), Color(0xFFFFF8F2), Color(0xFFFFE9DA)),
    PalettePreset('Лаванда', Color(0xFF8A7DBB), Color(0xFFD9D0F0), Color(0xFFF4EFFB),
        Color(0xFF4F4A6B), Color(0xFFFAF8FF), Color(0xFFF1ECFA)),
    PalettePreset('Мята', Color(0xFF5FA386), Color(0xFFBFE3D3), Color(0xFFEAF7F0),
        Color(0xFF3F5E50), Color(0xFFF7FDFA), Color(0xFFE6F5EC)),
    PalettePreset('Персик', Color(0xFFDE8F55), Color(0xFFF8D3B3), Color(0xFFFFF0E2),
        Color(0xFF6B5238), Color(0xFFFFF9F3), Color(0xFFFFEEDD)),
    PalettePreset('Небо', Color(0xFF5A92CC), Color(0xFFBCD6F0), Color(0xFFEAF3FB),
        Color(0xFF3E5670), Color(0xFFF6FAFE), Color(0xFFE5F0FA)),
    PalettePreset('Роза', Color(0xFFCF5C86), Color(0xFFF5B7CC), Color(0xFFFDE6EE),
        Color(0xFF6B3E50), Color(0xFFFFF7FA), Color(0xFFFCE3EC)),
  ];
}

/// Палитра приложения. Хранится в теме, поэтому цвета меняются плавно.
class Pal extends ThemeExtension<Pal> {
  final bool isDark;
  final Color accent;
  final Color bg;
  final Color secondary;
  final Color ebony;
  final Color onEbony;
  final Color deep; // тёмный тон для экрана регистрации
  final Color surface;
  final Color stroke;
  final Color text;
  final Color subtext;
  final List<Color> gradient;

  const Pal({
    required this.isDark,
    required this.accent,
    required this.bg,
    required this.secondary,
    required this.ebony,
    required this.onEbony,
    required this.deep,
    required this.surface,
    required this.stroke,
    required this.text,
    required this.subtext,
    required this.gradient,
  });

  /// Акцентный цвет, подходящий для текста на светлом фоне.
  Color get accentText => isDark
      ? accent
      : HSLColor.fromColor(accent).withLightness(0.36).toColor();

  static Color _hsl(double h, double s, double l) => HSLColor.fromAHSL(
        1,
        h % 360,
        s.clamp(0.0, 1.0).toDouble(),
        l.clamp(0.0, 1.0).toDouble(),
      ).toColor();

  static Pal build(int index, double customHue, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    late final Color accent, top, bottom, ebony, surface, bg;
    final double h;

    if (index >= 0 && index < PalettePreset.all.length) {
      final p = PalettePreset.all[index];
      accent = p.accent;
      top = p.top;
      bottom = p.bottom;
      ebony = p.ebony;
      surface = p.surface;
      bg = p.bg;
      h = HSLColor.fromColor(p.accent).hue;
    } else {
      h = customHue;
      accent = _hsl(h, 0.50, 0.62);
      top = _hsl(h, 0.70, 0.84);
      bottom = _hsl(h, 0.80, 0.94);
      ebony = _hsl(h, 0.14, 0.34);
      surface = _hsl(h, 0.60, 0.98);
      bg = _hsl(h, 0.70, 0.92);
    }

    if (!dark) {
      return Pal(
        isDark: false,
        accent: accent,
        bg: bg,
        secondary: const Color(0xFFA19DA4),
        ebony: ebony,
        onEbony: bg,
        deep: ebony,
        surface: surface,
        stroke: _hsl(h, 0.12, 0.83),
        text: const Color(0xFF2B2B2B),
        subtext: const Color(0xFF6E6A6C),
        gradient: [top, bottom],
      );
    }
    return Pal(
      isDark: true,
      accent: accent,
      bg: _hsl(h, 0.18, 0.10),
      secondary: const Color(0xFFA19DA4),
      ebony: _hsl(h, 0.22, 0.68),
      onEbony: _hsl(h, 0.20, 0.10),
      deep: _hsl(h, 0.14, 0.30),
      surface: _hsl(h, 0.15, 0.17),
      stroke: _hsl(h, 0.12, 0.27),
      text: _hsl(h, 0.60, 0.92),
      subtext: _hsl(h, 0.10, 0.70),
      gradient: [_hsl(h, 0.20, 0.19), _hsl(h, 0.18, 0.10)],
    );
  }

  @override
  Pal copyWith({
    bool? isDark,
    Color? accent,
    Color? bg,
    Color? secondary,
    Color? ebony,
    Color? onEbony,
    Color? deep,
    Color? surface,
    Color? stroke,
    Color? text,
    Color? subtext,
    List<Color>? gradient,
  }) =>
      Pal(
        isDark: isDark ?? this.isDark,
        accent: accent ?? this.accent,
        bg: bg ?? this.bg,
        secondary: secondary ?? this.secondary,
        ebony: ebony ?? this.ebony,
        onEbony: onEbony ?? this.onEbony,
        deep: deep ?? this.deep,
        surface: surface ?? this.surface,
        stroke: stroke ?? this.stroke,
        text: text ?? this.text,
        subtext: subtext ?? this.subtext,
        gradient: gradient ?? this.gradient,
      );

  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) {
    if (other is! Pal) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Pal(
      isDark: t < 0.5 ? isDark : other.isDark,
      accent: l(accent, other.accent),
      bg: l(bg, other.bg),
      secondary: l(secondary, other.secondary),
      ebony: l(ebony, other.ebony),
      onEbony: l(onEbony, other.onEbony),
      deep: l(deep, other.deep),
      surface: l(surface, other.surface),
      stroke: l(stroke, other.stroke),
      text: l(text, other.text),
      subtext: l(subtext, other.subtext),
      gradient: [l(gradient[0], other.gradient[0]), l(gradient[1], other.gradient[1])],
    );
  }

  static Pal of(BuildContext context) => Theme.of(context).extension<Pal>()!;
}

/// Цвет текста на акцентных карточках.
const Color onAccent = Color(0xFFFFF8F2);

ThemeData buildTheme(Brightness brightness, Pal p) {
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[p],
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: brightness,
    ).copyWith(primary: p.accent, surface: p.surface),
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final t in TargetPlatform.values)
          t: const CupertinoPageTransitionsBuilder(),
      },
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      thumbColor: p.accent,
      inactiveTrackColor: p.accent.withAlpha(60),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ebony,
      contentTextStyle: TextStyle(color: p.onEbony),
    ),
    datePickerTheme: DatePickerThemeData(backgroundColor: p.surface),
    timePickerTheme: TimePickerThemeData(backgroundColor: p.surface),
  );
}
