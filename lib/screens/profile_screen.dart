import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final c = TextEditingController(text: auth.user?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить имя'),
        content: TextField(
          controller: c,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name != null) await auth.updateName(name);
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Ваши задачи сохранятся на устройстве.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Выйти')),
        ],
      ),
    );
    if (ok != true) return;
    await auth.logout();
    tasks.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([settings, auth, tasks]),
      builder: (context, _) {
        final p = Pal.of(context);
        final user = auth.user;
        final initial = (user?.name.isNotEmpty ?? false)
            ? String.fromCharCode(user!.name.runes.first).toUpperCase()
            : '?';

        return Scaffold(
          body: AppBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: p.ebony, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Text(
                        'DayBy',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: p.ebony,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: p.accent,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: onAccent,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.name ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 17, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(user?.email ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: p.subtext)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _editName(context),
                            child: Text('изменить', style: TextStyle(color: p.accentText)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                      child: Row(
                        children: [
                          _Stat('${tasks.totalCount}', 'задач'),
                          _Stat('${tasks.totalDone}', 'выполнено'),
                          _Stat('${tasks.streak}', 'дней подряд'),
                        ],
                      ),
                    ),
                  ),
                  const _Heading('Цвета приложения'),
                  const _Card(child: _PalettePicker()),
                  const _Heading('Персонализация'),
                  _Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _IconLabel(Icons.palette_outlined, 'Тема'),
                          const SizedBox(height: 8),
                          PillToggle(
                            labels: const ['системная', 'светлая', 'тёмная'],
                            index: settings.theme,
                            onChanged: settings.setTheme,
                          ),
                          const Divider(height: 26),
                          const _IconLabel(Icons.text_fields_rounded, 'Размер текста'),
                          const SizedBox(height: 8),
                          PillToggle(
                            labels: const ['маленький', 'средний', 'крупный'],
                            index: settings.textSize,
                            onChanged: settings.setTextSize,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const _Heading('ГЛАВНЫЙ ЭКРАН', big: true),
                  _Card(
                    child: Column(
                      children: [
                        _SwitchRow(Icons.bolt_rounded, 'Блок "Сейчас"', settings.showNow,
                            (v) => settings.setBlock('showNow', v)),
                        const Divider(height: 1),
                        _SwitchRow(Icons.view_week_rounded, 'Полоса недели', settings.showWeek,
                            (v) => settings.setBlock('showWeek', v)),
                        const Divider(height: 1),
                        _SwitchRow(Icons.self_improvement_rounded, 'Привычки',
                            settings.showHabits, (v) => settings.setBlock('showHabits', v)),
                        const Divider(height: 1),
                        _SwitchRow(Icons.donut_large_rounded, 'Выполнение задач',
                            settings.showProgress,
                            (v) => settings.setBlock('showProgress', v)),
                        const Divider(height: 1),
                        _SwitchRow(Icons.checklist_rounded, 'Вид по умолчанию',
                            settings.showTasks, (v) => settings.setBlock('showTasks', v)),
                      ],
                    ),
                  ),
                  const _Heading('Планирование'),
                  _Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _IconLabel(Icons.event_note_outlined, 'Первый день недели'),
                          const SizedBox(height: 8),
                          PillToggle(
                            labels: const ['понедельник', 'воскресенье'],
                            index: settings.firstDay,
                            onChanged: settings.setFirstDay,
                          ),
                          const Divider(height: 26),
                          const _IconLabel(Icons.schedule, 'Формат времени'),
                          const SizedBox(height: 8),
                          PillToggle(
                            labels: const ['24 часа', '12 часов'],
                            index: settings.is24 ? 0 : 1,
                            onChanged: (i) => settings.setIs24(i == 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Выйти из аккаунта',
                    onPressed: () => _logout(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PalettePicker extends StatelessWidget {
  const _PalettePicker();

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final custom = settings.paletteIndex == PalettePreset.customIndex;
    final rainbow = SweepGradient(colors: [
      for (var h = 0; h <= 360; h += 60)
        HSLColor.fromAHSL(1, (h % 360).toDouble(), 0.6, 0.65).toColor(),
    ]);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              for (var i = 0; i < PalettePreset.all.length; i++)
                _Swatch(
                  color: PalettePreset.all[i].accent,
                  label: PalettePreset.all[i].name,
                  selected: settings.paletteIndex == i,
                  onTap: () => settings.setPalette(i),
                ),
              _Swatch(
                gradient: rainbow,
                label: 'Свой',
                selected: custom,
                onTap: () => settings.setPalette(PalettePreset.customIndex),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: custom
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Text('Оттенок', style: TextStyle(color: p.subtext, fontSize: 13)),
                      Slider(
                        value: settings.customHue.clamp(0.0, 360.0).toDouble(),
                        min: 0,
                        max: 360,
                        onChanged: settings.setCustomHue,
                        onChangeEnd: (_) => settings.persistPalette(),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color? color;
  final Gradient? gradient;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({
    this.color,
    this.gradient,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 46,
              height: 46,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? p.text : Colors.transparent,
                  width: 2.4,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  gradient: gradient,
                ),
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: p.subtext)),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  final bool big;
  const _Heading(this.text, {this.big = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 22, 8, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: big ? 17 : 13.5,
          fontWeight: big ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconLabel(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: p.accent.withAlpha(50),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: p.ebony),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow(this.icon, this.text, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          Expanded(child: _IconLabel(icon, text)),
          Switch(
            value: value,
            onChanged: onChanged,
            trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? p.ebony : p.stroke,
            ),
            thumbColor: WidgetStatePropertyAll(p.surface),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: p.subtext)),
        ],
      ),
    );
  }
}
