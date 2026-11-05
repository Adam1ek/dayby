import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/widgets.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'lists_screen.dart';
import 'stats_screen.dart';
import 'task_sheet.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final PageController _pc = PageController();
  int _index = 0;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Главная'),
    (Icons.format_list_bulleted_rounded, Icons.format_list_bulleted_rounded, 'Списки'),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Статистика'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Календарь'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _pc.animateToPage(
      i,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final showFab = _index != 2;

    return Scaffold(
      body: AppBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView(
                controller: _pc,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _KeepAlive(child: HomeScreen()),
                  _KeepAlive(child: ListsScreen()),
                  _KeepAlive(child: StatsScreen()),
                  _KeepAlive(child: CalendarScreen()),
                ],
              ),
            ),
            // Кнопка «+»
            Positioned(
              right: 20,
              bottom: bottomInset + 12 + 64 + 14,
              child: AnimatedScale(
                scale: showFab ? 1 : 0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: IgnorePointer(
                  ignoring: !showFab,
                  child: Material(
                    color: p.ebony,
                    elevation: 6,
                    shadowColor: Colors.black.withAlpha(90),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => showTaskSheet(context),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: Icon(Icons.add_rounded, color: p.onEbony, size: 30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Плавающая навигация
            Positioned(
              left: 16,
              right: 16,
              bottom: bottomInset + 12,
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(p.isDark ? 90 : 38),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth / _items.length;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                          left: w * _index + 6,
                          top: 6,
                          bottom: 6,
                          width: w - 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: p.accent.withAlpha(p.isDark ? 90 : 55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < _items.length; i++)
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _go(i),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TweenAnimationBuilder<Color?>(
                                        tween: ColorTween(
                                          end: i == _index ? p.accentText : p.ebony,
                                        ),
                                        duration: const Duration(milliseconds: 300),
                                        builder: (_, col, __) => Icon(
                                          i == _index ? _items[i].$2 : _items[i].$1,
                                          color: col,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 300),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: i == _index
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: i == _index ? p.accentText : p.ebony,
                                        ),
                                        child: Text(_items[i].$3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Сохраняет состояние вкладки при переключении.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
