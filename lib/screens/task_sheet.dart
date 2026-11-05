import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/widgets.dart';

/// Открывает окно создания (task == null) или редактирования задачи.
Future<void> showTaskSheet(BuildContext context, {Task? task}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskSheet(task: task),
  );
}

class _Draft {
  final TextEditingController c;
  bool done;
  _Draft(String text, this.done) : c = TextEditingController(text: text);
}

class _TaskSheet extends StatefulWidget {
  final Task? task;
  const _TaskSheet({this.task});

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  final List<_Draft> _subs = [];
  late DateTime _date;
  TimeOfDay? _time;
  bool _important = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _note = TextEditingController(text: t?.note ?? '');
    _date = t != null ? parseYmd(t.date) : tasks.selected;
    if (t?.time != null) {
      final parts = t!.time!.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    _important = t?.important ?? false;
    for (final s in t?.subtasks ?? const <Subtask>[]) {
      _subs.add(_Draft(s.title, s.done));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    for (final d in _subs) {
      d.c.dispose();
    }
    super.dispose();
  }

  String _timeStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = dateOnly(d));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: settings.is24),
        child: child!,
      ),
    );
    if (t != null) setState(() => _time = t);
  }

  void _addSub() => setState(() => _subs.add(_Draft('', false)));

  void _removeSub(_Draft d) {
    setState(() => _subs.remove(d));
    // Удаляем контроллер только после того, как поле исчезло с экрана.
    WidgetsBinding.instance.addPostFrameCallback((_) => d.c.dispose());
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Введите название задачи');
      return;
    }
    final subs = [
      for (final d in _subs)
        if (d.c.text.trim().isNotEmpty)
          Subtask(id: 0, taskId: 0, title: d.c.text.trim(), done: d.done),
    ];
    await tasks.saveTask(
      existing: widget.task,
      title: title,
      note: _note.text.trim(),
      date: _date,
      time: _time == null ? null : _timeStr(_time!),
      important: _important,
      subs: subs,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final t = widget.task;
    if (t == null) return;
    await tasks.deleteTask(t);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final editing = widget.task != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                editing ? 'Редактировать задачу' : 'Новая задача',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              AppField(label: 'Название', controller: _title),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(_error!, style: TextStyle(color: p.accentText, fontSize: 12.5)),
                ),
              const SizedBox(height: 10),
              AppField(label: 'Заметка (необязательно)', controller: _note),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Chip(
                      icon: Icons.calendar_today_outlined,
                      text: '${_date.day} ${monthsGen[_date.month - 1]}',
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Chip(
                      icon: Icons.schedule,
                      text: _time == null
                          ? 'Время'
                          : formatTime(_timeStr(_time!), settings.is24),
                      onTap: _pickTime,
                      onClear: _time == null ? null : () => setState(() => _time = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.star_rounded, color: p.accent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Важная задача',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Switch(
                    value: _important,
                    onChanged: (v) => setState(() => _important = v),
                    trackColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected) ? p.ebony : p.stroke,
                    ),
                    thumbColor: WidgetStatePropertyAll(p.surface),
                    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.checklist_rounded, color: p.ebony),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Шаги — выполняйте постепенно',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (final d in _subs)
                      Padding(
                        key: ObjectKey(d),
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 4),
                              CheckCircle(
                                size: 22,
                                checked: d.done,
                                onTap: () => setState(() => d.done = !d.done),
                                borderColor: p.ebony,
                                fillColor: p.ebony,
                                checkColor: p.onEbony,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: d.c,
                                  autofocus: d.c.text.isEmpty,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => _addSub(),
                                  style: TextStyle(
                                    color: p.text,
                                    fontSize: 14.5,
                                    decoration:
                                        d.done ? TextDecoration.lineThrough : null,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Шаг',
                                    hintStyle: TextStyle(color: p.subtext),
                                    border: InputBorder.none,
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.close_rounded, size: 18, color: p.subtext),
                                onPressed: () => _removeSub(d),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addSub,
                  icon: Icon(Icons.add_rounded, color: p.accentText),
                  label: Text('Добавить шаг', style: TextStyle(color: p.accentText)),
                ),
              ),
              const SizedBox(height: 4),
              PrimaryButton(label: 'Сохранить', onPressed: _save),
              if (editing)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Center(
                    child: TextButton(
                      onPressed: _delete,
                      child: Text('Удалить задачу', style: TextStyle(color: p.accentText)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _Chip({
    required this.icon,
    required this.text,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: p.ebony),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 16, color: p.subtext),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
