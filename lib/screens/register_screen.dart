import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/theme.dart';
import '../widgets/widgets.dart';
import 'main_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _cream = Color(0xFFFFE9DA);
  static const _fieldText = Color(0xFF1F2016);
  static const _fieldLabel = Color(0xFF2E2F22);

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await auth.register(_name.text, _email.text, _pass.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
      return;
    }
    await tasks.load(auth.user!.id);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final bg = p.deep;
    final bgBottom = Color.lerp(p.deep, Colors.white, 0.22)!;
    final fieldFill = Color.lerp(p.deep, Colors.white, 0.55)!;

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bg, bgBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const Text(
                      'DayBy',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: _cream,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Давайте создадим вам аккаунт',
                      style: TextStyle(fontSize: 12.5, color: _cream),
                    ),
                    const SizedBox(height: 36),
                    AppField(
                      label: 'Имя',
                      controller: _name,
                      fill: fieldFill,
                      textColor: _fieldText,
                      labelColor: _fieldLabel,
                      action: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppField(
                      label: 'Электронная почта',
                      controller: _email,
                      fill: fieldFill,
                      textColor: _fieldText,
                      labelColor: _fieldLabel,
                      keyboardType: TextInputType.emailAddress,
                      action: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    AppField(
                      label: 'Пароль',
                      controller: _pass,
                      fill: fieldFill,
                      textColor: _fieldText,
                      labelColor: _fieldLabel,
                      obscure: _obscure,
                      action: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: _fieldLabel,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFFC9C0),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 26),
                    PrimaryButton(
                      label: 'Зарегистрироваться',
                      onPressed: _submit,
                      loading: _loading,
                      color: _cream,
                      textColor: const Color(0xFF3B3C2D),
                    ),
                    const SizedBox(height: 40),
                    const LotusLogo(
                      size: 64,
                      tip: Color(0xFFFFE9DA),
                      base: Color(0xFFFFE9DA),
                    ),
                    const SizedBox(height: 26),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Уже есть аккаунт? ',
                          style: TextStyle(color: _cream, fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'Войти',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
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
