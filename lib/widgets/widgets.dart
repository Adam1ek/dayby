import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../screens/task_sheet.dart';

// ---------------------------------------------------------------------------
// Фон
// ---------------------------------------------------------------------------

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool reverse;
  const AppBackground({super.key, required this.child, this.reverse = false});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final colors = reverse ? p.gradient.reversed.toList() : p.gradient;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Анимации
// ---------------------------------------------------------------------------

/// Плавное появление: проявляется и сдвигается снизу вверх.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + math.min(index, 8) * 55),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: c),
      ),
      child: child,
    );
  }
}

/// Тонкая анимированная полоска прогресса.
class AppProgressBar extends StatelessWidget {
  final double value;
  final Color track;
  final Color bar;
  final double height;
  const AppProgressBar({
    super.key,
    required this.value,
    required this.track,
    required this.bar,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: track,
          valueColor: AlwaysStoppedAnimation<Color>(bar),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Логотип-лотос
// ---------------------------------------------------------------------------

class LotusPainter extends CustomPainter {
  final Color tip;
  final Color base;
  const LotusPainter({required this.tip, required this.base});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final origin = Offset(size.width / 2, size.height * 0.88);

    void petal(double angleDeg, double len, double wid) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(angleDeg * math.pi / 180);
      final h = s * len;
      final w = s * wid;
      final path = Path()
        ..moveTo(0, 0)
        ..cubicTo(w, -h * 0.25, w * 0.8, -h * 0.78, 0, -h)
        ..cubicTo(-w * 0.8, -h * 0.78, -w, -h * 0.25, 0, 0)
        ..close();
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tip, base],
        ).createShader(Rect.fromLTWH(-w, -h, w * 2, h));
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    petal(-62, 0.62, 0.26);
    petal(62, 0.62, 0.26);
    petal(-32, 0.82, 0.27);
    petal(32, 0.82, 0.27);
    petal(0, 0.98, 0.30);
    petal(-84, 0.56, 0.24);
    petal(84, 0.56, 0.24);
    petal(-112, 0.40, 0.18);
    petal(112, 0.40, 0.18);
  }

  @override
  bool shouldRepaint(covariant LotusPainter old) =>
      old.tip != tip || old.base != base;
}

class LotusLogo extends StatelessWidget {
  final double size;
  final Color? tip;
  final Color? base;
  const LotusLogo({super.key, this.size = 120, this.tip, this.base});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: LotusPainter(
          tip: tip ?? Color.lerp(p.accent, Colors.white, 0.05)!,
          base: base ?? p.bg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Кольцо прогресса
// ---------------------------------------------------------------------------

class _RingPainter extends CustomPainter {
  final double value;
  final Color track;
  final Color bar;
  final double stroke;
  const _RingPainter(this.value, this.track, this.bar, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = bar;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    if (value > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.track != track || old.bar != bar;
}

class RingProgress extends StatelessWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final String? caption;
  const RingProgress({
    super.key,
    required this.value,
    this.size = 150,
    this.stroke = 8,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, p.surface.withAlpha(220), p.ebony, stroke),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}%',
                  style: TextStyle(
                    fontSize: size * 0.24,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
                if (caption != null)
                  Text(caption!,
                      style: TextStyle(fontSize: size * 0.085, color: p.subtext)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Поля и кнопки
// ---------------------------------------------------------------------------

class AppField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Color? fill;
  final Color? textColor;
  final Color? labelColor;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? action;

  const AppField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.fill,
    this.textColor,
    this.labelColor,
    this.onSubmitted,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final tc = textColor ?? p.text;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textInputAction: action,
        onSubmitted: onSubmitted,
        autocorrect: false,
        style: TextStyle(color: tc, fontSize: 15),
        cursorColor: p.accent,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: labelColor ?? p.subtext,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: TextStyle(
            color: labelColor ?? p.ebony,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: fill ?? p.surface,
          suffixIcon: suffix,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final bool loading;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.textColor,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final bg = color ?? p.ebony;
    final fg = textColor ?? p.onEbony;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withAlpha(160),
          elevation: 3,
          shadowColor: Colors.black.withAlpha(80),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: loading
              ? SizedBox(
                  key: const ValueKey('loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                )
              : Text(
                  label,
                  key: const ValueKey('label'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Мелкие элементы
// ---------------------------------------------------------------------------

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: p.text,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: p.subtext, fontSize: 14),
        ),
      ),
    );
  }
}

class CheckCircle extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final Color borderColor;
  final Color fillColor;
  final Color checkColor;
  final double size;
  const CheckCircle({
    super.key,
    required this.checked,
    required this.onTap,
    required this.borderColor,
    required this.fillColor,
    required this.checkColor,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? fillColor : Colors.transparent,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: AnimatedScale(
            scale: checked ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Icon(Icons.check, size: size * 0.62, color: checkColor),
          ),
        ),
      ),
    );
  }
}

class SquareCheck extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  const SquareCheck({super.key, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: checked ? p.ebony : Colors.transparent,
            border: Border.all(color: p.ebony, width: 2),
          ),
          child: AnimatedScale(
            scale: checked ? 1 : 0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Icon(Icons.check, size: 15, color: p.onEbony),
          ),
        ),
      ),
    );
  }
}

Widget _deleteBackground(Pal p, double radius) => Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: p.ebony,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(Icons.delete_outline, color: p.onEbony),
    );

String _subtitle(Task t, {bool withDate = false, bool withSteps = false}) {
  final parts = <String>[];
  if (withDate) {
    final d = parseYmd(t.date);
    parts.add('${d.day} ${monthsGen[d.month - 1]}');
  }
  if (t.time != null) parts.add(formatTime(t.time!, settings.is24));
  if (withSteps && t.subtasks.isNotEmpty) {
    parts.add('${t.subtasks.where((s) => s.done).length}/${t.subtasks.length} шагов');
  }
  if (t.note.isNotEmpty) parts.add(t.note);
  return parts.join(' · ');
}

/// Карточка задачи (главный экран): шаги раскрываются, прогресс виден сразу.
class TaskCard extends StatefulWidget {
  final Task task;
  final int index;
  const TaskCard({super.key, required this.task, this.index = 0});

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final task = widget.task;
    final sub = _subtitle(task);
    final subs = task.subtasks;
    final hasSubs = subs.isNotEmpty;
    final doneSubs = subs.where((s) => s.done).length;
    final lighter = Color.lerp(p.accent, Colors.white, 0.18)!;

    return FadeSlideIn(
      index: widget.index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Dismissible(
          key: ValueKey('card_${task.id}'),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(p, 20),
          onDismissed: (_) => tasks.deleteTask(task),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: task.done ? 0.62 : 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [lighter, p.accent],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: p.accent.withAlpha(task.done ? 0 : 80),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => showTaskSheet(context, task: task),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (task.important)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(Icons.star_rounded,
                                              size: 16, color: onAccent),
                                        ),
                                      Flexible(
                                        child: AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 250),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: onAccent,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            decoration: task.done
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                            decorationColor: onAccent,
                                          ),
                                          child: Text(task.title),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (sub.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        sub,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: onAccent.withAlpha(225),
                                            fontSize: 12.5),
                                      ),
                                    ),
                                  if (hasSubs)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 9),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: AppProgressBar(
                                              value: task.progress,
                                              track: onAccent.withAlpha(80),
                                              bar: onAccent,
                                              height: 6,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '$doneSubs/${subs.length}',
                                            style: const TextStyle(
                                              color: onAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (hasSubs)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _open = !_open),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: AnimatedRotation(
                                    turns: _open ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                    child: const Icon(Icons.expand_more_rounded,
                                        color: onAccent, size: 26),
                                  ),
                                ),
                              ),
                            CheckCircle(
                              checked: task.done,
                              onTap: () => tasks.setDone(task, !task.done),
                              borderColor: onAccent,
                              fillColor: onAccent,
                              checkColor: p.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: (_open && hasSubs)
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 10, 10),
                              child: Column(
                                children: [
                                  for (final s in subs)
                                    InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => tasks.toggleSubtask(task, s),
                                      child: Row(
                                        children: [
                                          CheckCircle(
                                            size: 22,
                                            checked: s.done,
                                            onTap: () => tasks.toggleSubtask(task, s),
                                            borderColor: onAccent,
                                            fillColor: onAccent,
                                            checkColor: p.accent,
                                          ),
                                          Expanded(
                                            child: Text(
                                              s.title,
                                              style: TextStyle(
                                                color: onAccent,
                                                fontSize: 14,
                                                decoration: s.done
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                decorationColor: onAccent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка задачи с квадратным чекбоксом справа (списки, календарь).
class TaskRow extends StatelessWidget {
  final Task task;
  final bool showDate;
  const TaskRow({super.key, required this.task, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final sub = _subtitle(task, withDate: showDate, withSteps: true);
    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Dismissible(
          key: ValueKey('row_${task.id}'),
          direction: DismissDirection.endToStart,
          background: _deleteBackground(p, 16),
          onDismissed: (_) => tasks.deleteTask(task),
          child: Material(
            color: p.surface.withAlpha(p.isDark ? 255 : 200),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => showTaskSheet(context, task: task),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.text.withAlpha(task.done ? 140 : 255),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration:
                                  task.done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (sub.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.subtext, fontSize: 12),
                              ),
                            ),
                          if (task.subtasks.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 7, right: 8),
                              child: AppProgressBar(
                                value: task.progress,
                                track: p.accent.withAlpha(60),
                                bar: p.accent,
                                height: 4,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (task.important && !task.done)
                      Icon(Icons.star_rounded, size: 18, color: p.accent),
                    SquareCheck(
                      checked: task.done,
                      onTap: () => tasks.setDone(task, !task.done),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Переключатель из нескольких вариантов.
class PillToggle extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const PillToggle({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.accent.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? p.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: i == index ? onAccent : p.text,
                    ),
                    child: Text(labels[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
