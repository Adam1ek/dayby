import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.wait([
      () async {
        await auth.init();
        if (auth.user != null) await tasks.load(auth.user!.id);
      }(),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) =>
            auth.user != null ? const MainShell() : const LoginScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Scaffold(
      body: AppBackground(
        reverse: true,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 5),
              FadeTransition(
                opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
                child: ScaleTransition(
                  scale: Tween(begin: 0.85, end: 1.0)
                      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
                  child: Column(
                    children: [
                      const LotusLogo(size: 150),
                      const SizedBox(height: 4),
                      Text(
                        'DayBy',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: p.ebony,
                        ),
                      ),
                      Text(
                        'Планировщик дел',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 0.4,
                          color: p.ebony,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 6),
              Text('chotatam company',
                  style: TextStyle(fontSize: 11, color: p.ebony.withAlpha(200))),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
