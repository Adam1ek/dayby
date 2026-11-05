// DayBy — планировщик дел. Flutter + Firebase Auth + Cloud Firestore.
// Положите этот файл в lib/main.dart (см. SETUP.md).
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ───────────────────────── Настройки и палитры ─────────────────────────
class Pal {
  final String name;
  final Color top, bot, dark, acc;
  const Pal(this.name, this.top, this.bot, this.dark, this.acc);
}

const pals = [
  Pal(
    'Роза',
    Color(0xFFF4B9B2),
    Color(0xFFFFE8DC),
    Color(0xFF5C5C4A),
    Color(0xFFD98880),
  ),
  Pal(
    'Лаванда',
    Color(0xFFD8C8F0),
    Color(0xFFF5EEFF),
    Color(0xFF4A4668),
    Color(0xFF9A7FD1),
  ),
  Pal(
    'Мята',
    Color(0xFFBFE3D0),
    Color(0xFFEAF8F0),
    Color(0xFF3F5B4D),
    Color(0xFF5FAE8A),
  ),
  Pal(
    'Небо',
    Color(0xFFBBD7F0),
    Color(0xFFEAF4FF),
    Color(0xFF3F4F68),
    Color(0xFF5B8FCB),
  ),
  Pal(
    'Песок',
    Color(0xFFE8D3B0),
    Color(0xFFFFF4E0),
    Color(0xFF5E5240),
    Color(0xFFC98B3E),
  ),
];

class S extends ChangeNotifier {
  final Map<String, Object> v = {
    'theme': 0,
    'text': 1,
    'pal': 0, // тема: система/светлая/тёмная; текст: мал/сред/круп
    'now': true, 'week': true, 'habits': true, 'tasks': true, 'compact': false,
    'mon': true, 'h24': true, 'notif': true,
  };
  SharedPreferences? _p;
  int gi(String k) => v[k] as int;
  bool gb(String k) => v[k] as bool;
  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    for (final k in v.keys.toList()) {
      final d = v[k]!;
      final r = d is int ? _p!.getInt(k) : _p!.getBool(k);
      if (r != null) v[k] = r;
    }
  }

  void set(String k, Object val) {
    v[k] = val;
    if (val is int) _p?.setInt(k, val);
    if (val is bool) _p?.setBool(k, val);
    notifyListeners();
  }
}

final st = S();
bool fbOk = false;

class C {
  final bool dark;
  final Pal p;
  C(this.dark, this.p);
  Color get top => dark ? const Color(0xFF2B2A2A) : p.top;
  Color get bot => dark ? const Color(0xFF3B3633) : p.bot;
  Color get txt => dark ? const Color(0xFFFFE8DC) : p.dark;
  Color get card => dark ? const Color(0xFF47423F) : const Color(0xFFFCF6F1);
  Color get acc => p.acc;
  Color get btn => dark ? p.acc : p.dark;
}

C cc(BuildContext x) =>
    C(Theme.of(x).brightness == Brightness.dark, pals[st.gi('pal')]);
TextStyle ts(Color c, double s, [FontWeight w = FontWeight.w600]) =>
    TextStyle(color: c, fontSize: s, fontWeight: w);
void toast(BuildContext x, String m) => ScaffoldMessenger.of(x)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(m)));

const wd = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];
const wds = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const mons = [
  'Янв',
  'Фев',
  'Мар',
  'Апр',
  'Мая',
  'Июн',
  'Июл',
  'Авг',
  'Сен',
  'Окт',
  'Ноя',
  'Дек',
];
String dkey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
List<DateTime> weekDays() {
  final n = DateTime.now();
  final d = DateTime(n.year, n.month, n.day);
  final s = d.subtract(
    Duration(days: st.gb('mon') ? d.weekday - 1 : d.weekday % 7),
  );
  return List.generate(7, (i) => DateTime(s.year, s.month, s.day + i));
}

String clock() {
  final n = DateTime.now();
  final m = n.minute.toString().padLeft(2, '0');
  if (st.gb('h24')) return '${n.hour.toString().padLeft(2, '0')}:$m';
  final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
  return '$h:$m ${n.hour < 12 ? 'AM' : 'PM'}';
}

// ───────────────────────── Firestore ─────────────────────────
// users/{uid}  {name, email}
// users/{uid}/lists/{id}  {title, created}
// users/{uid}/tasks/{id}  {title, date, list, done, created}
User get me => FirebaseAuth.instance.currentUser!;
DocumentReference<Map<String, dynamic>> get uref =>
    FirebaseFirestore.instance.collection('users').doc(me.uid);
CollectionReference<Map<String, dynamic>> get listsC =>
    uref.collection('lists');
CollectionReference<Map<String, dynamic>> get tasksC =>
    uref.collection('tasks');

Future<void> saveUser(User u, {String? name}) async {
  final n = name ?? u.displayName;
  await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
    if (n != null) 'name': n,
    'email': u.email,
  }, SetOptions(merge: true));
}

Future<void> addTask(
  String t,
  String date, [
  String? list,
  Map<String, dynamic> extra = const {},
]) => tasksC.add({
  'title': t,
  'date': date,
  'list': list,
  'done': false,
  'prio': 0,
  'note': '',
  'time': null,
  'steps': [],
  'created': FieldValue.serverTimestamp(),
  ...extra,
});

class Step {
  final String t;
  final bool d;
  Step(this.t, this.d);
}

class Task {
  final String id, title, date, note;
  final String? list, time;
  final bool done;
  final int prio;
  final List<Step> steps;
  Task(QueryDocumentSnapshot<Map<String, dynamic>> d)
    : id = d.id,
      title = (d.data()['title'] ?? '') as String,
      date = (d.data()['date'] ?? '') as String,
      note = (d.data()['note'] ?? '') as String,
      list = d.data()['list'] as String?,
      time = d.data()['time'] as String?,
      done = (d.data()['done'] ?? false) as bool,
      prio = ((d.data()['prio'] ?? 0) as num).toInt().clamp(0, 2),
      steps = ((d.data()['steps'] ?? []) as List).map((e) {
        final m = e as Map;
        return Step(m['t'] as String, (m['d'] ?? false) as bool);
      }).toList();
  double get progress => steps.isEmpty
      ? (done ? 1 : 0)
      : steps.where((s) => s.d).length / steps.length;
}

class LList {
  final String id, title;
  LList(QueryDocumentSnapshot<Map<String, dynamic>> d)
    : id = d.id,
      title = (d.data()['title'] ?? '') as String;
}

Future<void> toggleTask(Task t) {
  HapticFeedback.lightImpact();
  final v = !t.done;
  return tasksC.doc(t.id).update({
    'done': v,
    if (t.steps.isNotEmpty)
      'steps': [
        for (final s in t.steps) {'t': s.t, 'd': v},
      ],
  });
}

Future<void> toggleStep(Task t, int i) {
  HapticFeedback.lightImpact();
  final ns = [
    for (var k = 0; k < t.steps.length; k++)
      {'t': t.steps[k].t, 'd': k == i ? !t.steps[k].d : t.steps[k].d},
  ];
  return tasksC.doc(t.id).update({
    'steps': ns,
    'done': ns.every((s) => s['d'] == true),
  });
}

String greetName() {
  final h = DateTime.now().hour;
  final g = h < 5
      ? 'Доброй ночи'
      : h < 12
      ? 'Доброе утро'
      : h < 18
      ? 'Добрый день'
      : 'Добрый вечер';
  final n = (FirebaseAuth.instance.currentUser?.displayName ?? '')
      .trim()
      .split(' ')
      .first;
  return n.isEmpty ? g : '$g, $n';
}

int streak(List<Task> ts) {
  final days = {
    for (final t in ts)
      if (t.done) t.date,
  };
  var d = DateTime.now();
  if (!days.contains(dkey(d))) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (days.contains(dkey(d))) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

String errMsg(String code) {
  switch (code) {
    case 'invalid-email':
      return 'Некорректная почта';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Неверная почта или пароль';
    case 'email-already-in-use':
      return 'Эта почта уже зарегистрирована';
    case 'weak-password':
      return 'Слишком простой пароль';
    case 'network-request-failed':
      return 'Нет соединения с интернетом';
    case 'too-many-requests':
      return 'Слишком много попыток, попробуйте позже';
    case 'requires-recent-login':
      return 'Войдите заново и повторите действие';
    case 'account-exists-with-different-credential':
      return 'Аккаунт с этой почтой уже есть, войдите другим способом';
    default:
      return 'Ошибка: $code';
  }
}

// ───────────────────────── Запуск ─────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    fbOk = true;
  } catch (_) {}
  await st.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: st,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DayBy',
      themeMode: [
        ThemeMode.system,
        ThemeMode.light,
        ThemeMode.dark,
      ][st.gi('theme')],
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: pals[st.gi('pal')].acc,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: pals[st.gi('pal')].acc,
      ),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(
          textScaler: TextScaler.linear([0.88, 1.0, 1.2][st.gi('text')]),
        ),
        child: child!,
      ),
      home: fbOk ? const Root() : const NoFirebase(),
    ),
  );
}

class NoFirebase extends StatelessWidget {
  const NoFirebase({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Firebase не подключён.\nСледуйте инструкции в SETUP.md (google-services.json / GoogleService-Info.plist).',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  bool splash = true;
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => splash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (splash) return const Splash();
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (_, s) {
        if (s.connectionState == ConnectionState.waiting) return const Splash();
        return s.data == null
            ? const AuthPage()
            : Shell(key: ValueKey(s.data!.uid));
      },
    );
  }
}

// ───────────────────────── Общие виджеты ─────────────────────────
class Bg extends StatelessWidget {
  final Widget child;
  const Bg({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.top, c.bot],
        ),
      ),
      child: child,
    );
  }
}

class Btn extends StatelessWidget {
  final String t;
  final VoidCallback? f;
  final Color bg, fg;
  final IconData? icon;
  const Btn(
    this.t,
    this.f, {
    super.key,
    required this.bg,
    required this.fg,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(color: Colors.black26, offset: Offset(0, 3), blurRadius: 3),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: f,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg),
                const SizedBox(width: 12),
              ],
              Text(t, style: ts(fg, 16, FontWeight.w700)),
            ],
          ),
        ),
      ),
    ),
  );
}

class Fld extends StatefulWidget {
  final TextEditingController c;
  final String hint;
  final String? label;
  final bool pass, email;
  final Color txt, fill;
  const Fld(
    this.c,
    this.hint, {
    super.key,
    this.label,
    this.pass = false,
    this.email = false,
    required this.txt,
    required this.fill,
  });
  @override
  State<Fld> createState() => _FldState();
}

class _FldState extends State<Fld> {
  bool hide = true;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.label != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            widget.label!,
            style: ts(widget.txt, 14, FontWeight.w700),
          ),
        ),
      Container(
        decoration: BoxDecoration(
          color: widget.fill,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: widget.c,
          obscureText: widget.pass && hide,
          keyboardType: widget.email
              ? TextInputType.emailAddress
              : TextInputType.text,
          style: ts(widget.txt, 16),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: widget.label == null ? widget.hint : null,
            hintStyle: ts(widget.txt.withOpacity(.85), 16, FontWeight.w700),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            suffixIcon: widget.pass
                ? IconButton(
                    icon: Icon(
                      hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: widget.txt,
                    ),
                    onPressed: () => setState(() => hide = !hide),
                  )
                : null,
          ),
        ),
      ),
    ],
  );
}

Future<String?> askText(
  BuildContext ctx,
  String title, {
  String hint = '',
  String init = '',
}) {
  final t = TextEditingController(text: init);
  return showDialog<String>(
    context: ctx,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: t,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, t.text.trim()),
          child: const Text('Готово'),
        ),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext ctx, String q) async =>
    await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        content: Text(q),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Да'),
          ),
        ],
      ),
    ) ??
    false;

void info(BuildContext ctx, String title, String text) => showDialog(
  context: ctx,
  builder: (d) => AlertDialog(
    title: Text(title),
    content: Text(text),
    actions: [
      TextButton(onPressed: () => Navigator.pop(d), child: const Text('Ок')),
    ],
  ),
);

class Lotus extends StatelessWidget {
  final double s;
  final Color a, b;
  const Lotus(
    this.s, {
    super.key,
    this.a = const Color(0xFFD98880),
    this.b = const Color(0xFFFBE3DA),
  });
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(s, s * .8), painter: _LP(a, b));
}

class _LP extends CustomPainter {
  final Color a, b;
  _LP(this.a, this.b);
  @override
  void paint(Canvas c, Size z) {
    for (final p in [
      [-72.0, .55],
      [72.0, .55],
      [-38.0, .8],
      [38.0, .8],
      [0.0, 1.0],
    ]) {
      c.save();
      c.translate(z.width / 2, z.height);
      c.rotate(p[0] * math.pi / 180);
      final h = z.height * p[1], w = z.width * .17;
      final path = Path()
        ..quadraticBezierTo(w * 1.6, -h * .5, 0, -h)
        ..quadraticBezierTo(-w * 1.6, -h * .5, 0, 0);
      c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [a, b],
          ).createShader(Rect.fromLTWH(-w, -h, w * 2, h)),
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class Ring extends CustomPainter {
  final double v;
  final Color fg, bg;
  Ring(this.v, this.fg, this.bg);
  @override
  void paint(Canvas c, Size s) {
    final r = (Offset.zero & s).deflate(8);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    c.drawArc(r, -math.pi / 2, 2 * math.pi, false, p..color = bg);
    if (v > 0)
      c.drawArc(r, -math.pi / 2, 2 * math.pi * v, false, p..color = fg);
  }

  @override
  bool shouldRepaint(Ring o) => o.v != v || o.fg != fg;
}

// ───────────────────────── Заставка ─────────────────────────
class Splash extends StatelessWidget {
  const Splash({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE8DC), Color(0xFFF4C6BE)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 5),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1200),
            builder: (_, v, ch) => Opacity(
              opacity: v,
              child: Transform.scale(scale: .8 + .2 * v, child: ch),
            ),
            child: Column(
              children: [
                const Lotus(190),
                const SizedBox(height: 6),
                Text(
                  'DayBy',
                  style: ts(const Color(0xFF5C5C4A), 54, FontWeight.w800),
                ),
                Text(
                  'Планировщик дел',
                  style: ts(const Color(0xFF5C5C4A), 18, FontWeight.w500),
                ),
              ],
            ),
          ),
          const Spacer(flex: 6),
          Text(
            'chotatam company',
            style: ts(const Color(0xFF5C5C4A), 13, FontWeight.w400),
          ),
          const SizedBox(height: 40),
        ],
      ),
    ),
  );
}

// ───────────────────────── Вход / регистрация ─────────────────────────
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthState();
}

class _AuthState extends State<AuthPage> {
  bool reg = false, busy = false;
  final n = TextEditingController(),
      e = TextEditingController(),
      p = TextEditingController();
  FirebaseAuth get a => FirebaseAuth.instance;

  Future<void> run(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } on FirebaseAuthException catch (x) {
      if (mounted && !x.code.contains('cancel')) toast(context, errMsg(x.code));
    } catch (_) {
      if (mounted) toast(context, 'Что-то пошло не так. Попробуйте ещё раз');
    }
    if (mounted) setState(() => busy = false);
  }

  void submit() {
    final em = e.text.trim(), pw = p.text, nm = n.text.trim();
    if (em.isEmpty || pw.isEmpty || (reg && nm.isEmpty))
      return toast(context, 'Заполните все поля');
    if (reg && pw.length < 6)
      return toast(context, 'Пароль — минимум 6 символов');
    run(() async {
      if (reg) {
        final cr = await a.createUserWithEmailAndPassword(
          email: em,
          password: pw,
        );
        await cr.user!.updateDisplayName(nm);
        await saveUser(cr.user!, name: nm);
        await cr.user!.reload();
      } else {
        await a.signInWithEmailAndPassword(email: em, password: pw);
      }
    });
  }

  Future<void> forgot() async {
    final em = await askText(
      context,
      'Сброс пароля',
      hint: 'Ваша почта',
      init: e.text.trim(),
    );
    if (em == null || em.isEmpty) return;
    run(() async {
      await a.sendPasswordResetEmail(email: em);
      if (mounted) toast(context, 'Письмо для сброса пароля отправлено');
    });
  }

  void social(AuthProvider pr) => run(() async {
    final cr = await a.signInWithProvider(pr);
    if (cr.user != null) await saveUser(cr.user!);
  });

  @override
  Widget build(BuildContext context) {
    final pl = pals[st.gi('pal')];
    const cream = Color(0xFFFFE8DC), olive = Color(0xFF5C5C4A);
    final txt = reg ? cream : pl.dark;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: reg
                ? const [Color(0xFF666654), Color(0xFF9A9482)]
                : [pl.top, pl.bot],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    Text('DayBy', style: ts(txt, 52, FontWeight.w800)),
                    if (reg)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Давайте создадим вам аккаунт',
                          style: ts(cream, 15, FontWeight.w700),
                        ),
                      ),
                    SizedBox(height: reg ? 40 : 90),
                    if (reg) ...[
                      Fld(
                        n,
                        'Имя',
                        label: 'Имя',
                        txt: cream,
                        fill: Colors.white24,
                      ),
                      const SizedBox(height: 18),
                      Fld(
                        e,
                        'Электронная почта',
                        label: 'Электронная почта',
                        email: true,
                        txt: cream,
                        fill: Colors.white24,
                      ),
                      const SizedBox(height: 18),
                      Fld(
                        p,
                        'Пароль',
                        label: 'Пароль',
                        pass: true,
                        txt: cream,
                        fill: Colors.white24,
                      ),
                      const SizedBox(height: 36),
                      Btn(
                        busy ? 'Подождите…' : 'Зарегистрироваться',
                        busy ? null : submit,
                        bg: cream,
                        fg: olive,
                      ),
                      const SizedBox(height: 36),
                      const Lotus(70, a: cream, b: cream),
                    ] else ...[
                      Fld(
                        e,
                        'Почта',
                        email: true,
                        txt: pl.dark,
                        fill: Colors.white38,
                      ),
                      const SizedBox(height: 18),
                      Fld(
                        p,
                        'Пароль',
                        pass: true,
                        txt: pl.dark,
                        fill: Colors.white38,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: forgot,
                          child: Text('забыли пароль?', style: ts(pl.acc, 13)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Btn(
                        busy ? 'Подождите…' : 'Войти в аккаунт',
                        busy ? null : submit,
                        bg: pl.dark,
                        fg: Colors.white,
                      ),
                      const SizedBox(height: 36),
                      Row(
                        children: [
                          Expanded(child: Divider(color: pl.acc)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'Способы входа',
                              style: ts(pl.acc, 13, FontWeight.w400),
                            ),
                          ),
                          Expanded(child: Divider(color: pl.acc)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _soc(
                            Text(
                              'G',
                              style: ts(Colors.black54, 34, FontWeight.w800),
                            ),
                            () => social(GoogleAuthProvider()),
                          ),
                          _soc(
                            Text(
                              '𝕏',
                              style: ts(Colors.black54, 30, FontWeight.w700),
                            ),
                            () => social(TwitterAuthProvider()),
                          ),
                          _soc(
                            const Icon(
                              Icons.facebook,
                              size: 38,
                              color: Colors.black54,
                            ),
                            () => social(FacebookAuthProvider()),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: () => setState(() => reg = !reg),
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 4),
                        decoration: reg
                            ? BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: cream),
                                ),
                              )
                            : null,
                        child: Text(
                          reg
                              ? 'Уже есть аккаунт?   Войти'
                              : 'Нету аккаунта?  |  Зарегистрироваться',
                          style: ts(txt, 14, FontWeight.w400),
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

  Widget _soc(Widget w, VoidCallback f) => Material(
    color: Colors.white54,
    elevation: 3,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy ? null : f,
      child: SizedBox(width: 92, height: 56, child: Center(child: w)),
    ),
  );
}

// ───────────────────────── Основной экран ─────────────────────────
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  void initState() {
    super.initState();
    saveUser(me).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: st,
    builder: (ctx, _) {
      final c = cc(ctx);
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: listsC.snapshots(),
        builder: (_, ls) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: tasksC.orderBy('created').snapshots(),
          builder: (_, tq) {
            if (ls.hasError || tq.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Ошибка базы данных: ${ls.error ?? tq.error}\nПроверьте, что Firestore создан и правила опубликованы.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            final lists = (ls.data?.docs ?? []).map(LList.new).toList()
              ..sort((a, b) => a.title.compareTo(b.title));
            final tasks = (tq.data?.docs ?? []).map(Task.new).toList();
            final loading = ls.data == null && tq.data == null;
            final pages = [
              Home(
                lists: lists,
                tasks: tasks,
                go: (k) => setState(() => i = k),
              ),
              ListsPage(lists: lists, tasks: tasks),
              ProgressPage(tasks: tasks),
              ProfilePage(tasks: tasks),
            ];
            return Scaffold(
              body: Bg(
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : IndexedStack(index: i, children: pages),
                      ),
                      _nav(c),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Widget _nav(C c) {
    const ic = [
      Icons.home_outlined,
      Icons.format_list_bulleted,
      Icons.bar_chart,
      Icons.account_circle,
    ];
    const lb = ['Главная', 'Мои списки', 'Прогресс', 'Профиль'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.txt, width: 1.5)),
      ),
      child: Row(
        children: [
          for (var k = 0; k < 4; k++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => i = k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == k
                        ? c.card.withOpacity(.55)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(ic[k], color: c.txt, size: 28),
                      const SizedBox(height: 2),
                      Text(lb[k], style: ts(c.txt, 11, FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Главная ─────────────────────────
class Home extends StatefulWidget {
  final List<LList> lists;
  final List<Task> tasks;
  final void Function(int) go;
  const Home({
    super.key,
    required this.lists,
    required this.tasks,
    required this.go,
  });
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  DateTime sel = DateTime.now();

  Future<void> newList() async {
    final t = await askText(context, 'Новый список', hint: 'Название');
    if (t != null && t.isNotEmpty)
      await listsC.add({'title': t, 'created': FieldValue.serverTimestamp()});
  }

  Future<void> newTask() => editTask(context, date: dkey(sel));

  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    if (widget.lists.isEmpty && widget.tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greetName(), style: ts(c.txt, 24, FontWeight.w800)),
            Text('Планировщик дел', style: ts(c.txt, 14, FontWeight.w400)),
            const Spacer(),
            Center(
              child: Text('Привет!', style: ts(c.txt, 42, FontWeight.w800)),
            ),
            Center(
              child: Text(
                'С чего начнем ?',
                style: ts(c.txt, 16, FontWeight.w500),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.card.withOpacity(.35),
                    ),
                  ),
                  Icon(Icons.checklist_rounded, size: 110, color: c.txt),
                  Positioned(
                    top: 10,
                    left: 26,
                    child: Icon(Icons.air, size: 40, color: c.acc),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            Btn(
              'Создать список',
              newList,
              bg: c.btn,
              fg: Colors.white,
              icon: Icons.add,
            ),
            const SizedBox(height: 14),
            Btn(
              'Добавить задачу',
              newTask,
              bg: c.acc.withOpacity(.35),
              fg: c.txt,
              icon: Icons.format_list_bulleted,
            ),
          ],
        ),
      );
    }
    final day = widget.tasks.where((t) => t.date == dkey(sel)).toList();
    day.sort(
      (a, b) => a.done != b.done
          ? (a.done ? 1 : -1)
          : b.prio != a.prio
          ? b.prio.compareTo(a.prio)
          : (a.time ?? '99').compareTo(b.time ?? '99'),
    );
    final done = day.where((t) => t.done).length;
    final pct = day.isEmpty ? 0.0 : done / day.length;
    final today = DateTime.now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Text(greetName(), style: ts(c.txt, 24, FontWeight.w800)),
        const SizedBox(height: 10),
        if (st.gb('week')) ...[
          Row(
            children: [
              for (final d in weekDays())
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => sel = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: dkey(d) == dkey(sel)
                            ? c.acc
                            : c.card.withOpacity(.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            wds[d.weekday - 1].toUpperCase(),
                            style: ts(
                              dkey(d) == dkey(sel) ? Colors.white : c.txt,
                              12,
                              FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${d.day}',
                            style: ts(
                              dkey(d) == dkey(sel) ? Colors.white : c.txt,
                              12,
                              FontWeight.w700,
                            ),
                          ),
                          Text(
                            dkey(d) == dkey(today) ? '•' : ' ',
                            style: ts(
                              dkey(d) == dkey(sel) ? Colors.white : c.acc,
                              12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        Builder(
          builder: (_) {
            final td = dkey(DateTime.now());
            final old = widget.tasks
                .where((t) => !t.done && t.date.compareTo(td) < 0)
                .toList();
            if (old.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: c.acc),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Просрочено: ${old.length}',
                      style: ts(c.txt, 14),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final b = FirebaseFirestore.instance.batch();
                      for (final t in old) {
                        b.update(tasksC.doc(t.id), {'date': td});
                      }
                      await b.commit();
                    },
                    child: Text('Перенести на сегодня', style: ts(c.acc, 13)),
                  ),
                ],
              ),
            );
          },
        ),
        if (st.gb('now'))
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card.withOpacity(.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: pct),
                        duration: const Duration(milliseconds: 500),
                        builder: (_, v, __) => CustomPaint(
                          size: const Size(120, 120),
                          painter: Ring(v, c.txt, c.acc.withOpacity(.6)),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(pct * 100).round()}%',
                            style: ts(c.txt, 24, FontWeight.w700),
                          ),
                          Text(
                            'Выполнено',
                            style: ts(c.txt, 10, FontWeight.w400),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2,
                  height: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: c.txt,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wd[sel.weekday - 1],
                        style: ts(c.txt, 18, FontWeight.w700),
                      ),
                      Text('${sel.day}', style: ts(c.txt, 40, FontWeight.w800)),
                      Text(
                        mons[sel.month - 1],
                        style: ts(c.txt, 30, FontWeight.w800),
                      ),
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(seconds: 20)),
                        builder: (_, __) => Text(
                          clock(),
                          style: ts(c.txt, 13, FontWeight.w400),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (st.gb('habits') && widget.lists.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final l in widget.lists)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(l.title, style: ts(c.txt, 14)),
                      backgroundColor: c.card.withOpacity(.7),
                      side: BorderSide.none,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ListDetail(list: l)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
          child: Row(
            children: [
              Text('Все списки', style: ts(c.txt, 22, FontWeight.w800)),
              const SizedBox(width: 12),
              Icon(Icons.format_list_bulleted, color: c.txt),
            ],
          ),
        ),
        if (st.gb('tasks')) ...[
          if (day.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'На этот день задач нет. Добавьте первую ↓',
                style: ts(c.txt, 14, FontWeight.w400),
              ),
            ),
          for (final t in day) TaskTile(t),
        ],
        const SizedBox(height: 8),
        AddBar(onAdd: (t) => addTask(t, dkey(sel))),
      ],
    );
  }
}

class TaskTile extends StatefulWidget {
  final Task t;
  const TaskTile(this.t, {super.key});
  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final c = cc(context);
    final pad = st.gb('compact') ? 8.0 : 14.0;
    final over = !t.done && t.date.compareTo(dkey(DateTime.now())) < 0;
    final flag = [
      Colors.transparent,
      const Color(0xFFE0A030),
      const Color(0xFFD9534F),
    ][t.prio];
    final sub = [
      if (over) 'Просрочено',
      if (t.time != null) t.time!,
      if (t.note.isNotEmpty) t.note,
    ].join(' · ');
    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        final m = ScaffoldMessenger.of(context);
        final ref = tasksC.doc(t.id);
        final back = {
          'title': t.title,
          'date': t.date,
          'note': t.note,
          'list': t.list,
          'time': t.time,
          'prio': t.prio,
          'done': t.done,
          'steps': [
            for (final s in t.steps) {'t': s.t, 'd': s.d},
          ],
          'created': FieldValue.serverTimestamp(),
        };
        ref.delete();
        m
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Задача удалена'),
              action: SnackBarAction(
                label: 'Отменить',
                onPressed: () => ref.set(back),
              ),
            ),
          );
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: c.acc,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => editTask(context, t: t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: pad),
          decoration: BoxDecoration(
            color: t.done ? c.card.withOpacity(.6) : c.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (t.prio > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.flag_rounded, size: 18, color: flag),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(
                            color: c.txt.withOpacity(t.done ? .5 : 1),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: t.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (sub.isNotEmpty)
                          Text(
                            sub,
                            style: ts(
                              over
                                  ? const Color(0xFFD9534F)
                                  : c.txt.withOpacity(.6),
                              12,
                              FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (t.steps.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => open = !open),
                      child: Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        color: c.txt,
                      ),
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => toggleTask(t),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        t.done
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: t.done ? c.btn : c.txt,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
              if (t.steps.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: t.progress,
                      minHeight: 5,
                      backgroundColor: c.acc.withOpacity(.2),
                      color: c.btn,
                    ),
                  ),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: open
                    ? Column(
                        children: [
                          for (var k = 0; k < t.steps.length; k++)
                            InkWell(
                              onTap: () => toggleStep(t, k),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      t.steps[k].d
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      size: 22,
                                      color: c.btn,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        t.steps[k].t,
                                        style: TextStyle(
                                          color: c.txt,
                                          fontSize: 14,
                                          decoration: t.steps[k].d
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddBar extends StatefulWidget {
  final Future<void> Function(String) onAdd;
  const AddBar({super.key, required this.onAdd});
  @override
  State<AddBar> createState() => _AddBarState();
}

class _AddBarState extends State<AddBar> {
  final t = TextEditingController();
  void add() {
    final s = t.text.trim();
    if (s.isEmpty) return;
    t.clear();
    widget.onAdd(s);
  }

  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: t,
              onSubmitted: (_) => add(),
              style: ts(c.txt, 16),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Новая задача…',
                hintStyle: ts(c.txt.withOpacity(.5), 16, FontWeight.w400),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: c.btn,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: add,
            child: const SizedBox(
              width: 58,
              height: 58,
              child: Icon(Icons.add, color: Colors.white, size: 34),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Списки ─────────────────────────
class ListsPage extends StatelessWidget {
  final List<LList> lists;
  final List<Task> tasks;
  const ListsPage({super.key, required this.lists, required this.tasks});
  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Мои списки', style: ts(c.txt, 30, FontWeight.w800)),
        const SizedBox(height: 14),
        if (lists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                'Списков пока нет',
                style: ts(c.txt, 16, FontWeight.w400),
              ),
            ),
          ),
        for (final l in lists)
          Builder(
            builder: (_) {
              final lt = tasks.where((t) => t.list == l.id).toList();
              final d = lt.where((t) => t.done).length;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ListDetail(list: l)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.format_list_bulleted, color: c.txt),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.title,
                              style: ts(c.txt, 17, FontWeight.w700),
                            ),
                            Text(
                              'Выполнено $d из ${lt.length}',
                              style: ts(
                                c.txt.withOpacity(.6),
                                13,
                                FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: c.txt.withOpacity(.6)),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        Btn(
          'Создать список',
          () async {
            final t = await askText(context, 'Новый список', hint: 'Название');
            if (t != null && t.isNotEmpty)
              await listsC.add({
                'title': t,
                'created': FieldValue.serverTimestamp(),
              });
          },
          bg: c.btn,
          fg: Colors.white,
          icon: Icons.add,
        ),
      ],
    );
  }
}

class ListDetail extends StatelessWidget {
  final LList list;
  const ListDetail({super.key, required this.list});
  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.top,
        foregroundColor: c.txt,
        title: Text(list.title, style: ts(c.txt, 20, FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => editTask(context, list: list.id),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirm(
                context,
                'Удалить список «${list.title}» вместе с задачами?',
              ))
                return;
              final q = await tasksC.where('list', isEqualTo: list.id).get();
              final b = FirebaseFirestore.instance.batch();
              for (final d in q.docs) {
                b.delete(d.reference);
              }
              b.delete(listsC.doc(list.id));
              await b.commit();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Bg(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tasksC.orderBy('created').snapshots(),
            builder: (_, s) {
              final ts_ = (s.data?.docs ?? [])
                  .map(Task.new)
                  .where((t) => t.list == list.id)
                  .toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (ts_.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'В списке пока пусто',
                          style: ts(c.txt, 15, FontWeight.w400),
                        ),
                      ),
                    ),
                  for (final t in ts_) TaskTile(t),
                  const SizedBox(height: 8),
                  AddBar(
                    onAdd: (t) => addTask(t, dkey(DateTime.now()), list.id),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Прогресс ─────────────────────────
class WeekBars extends StatelessWidget {
  final List<Task> tasks;
  const WeekBars(this.tasks, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    final days = weekDays();
    final cnt = [
      for (final d in days)
        tasks.where((t) => t.done && t.date == dkey(d)).length,
    ];
    final mx = math.max(1, cnt.reduce(math.max));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var k = 0; k < 7; k++)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 8 + 90.0 * cnt[k] / mx),
                  duration: const Duration(milliseconds: 500),
                  builder: (_, h, __) => Container(
                    width: 36,
                    height: h,
                    decoration: BoxDecoration(
                      color: dkey(days[k]) == dkey(DateTime.now())
                          ? c.acc
                          : c.btn,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  wds[days[k].weekday - 1],
                  style: ts(c.txt, 12, FontWeight.w500),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class ProgressPage extends StatelessWidget {
  final List<Task> tasks;
  const ProgressPage({super.key, required this.tasks});
  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    final done = tasks.where((t) => t.done).length;
    final pct = tasks.isEmpty ? 0.0 : done / tasks.length;
    Widget stat(String a, String b) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(a, style: ts(c.txt, 28, FontWeight.w800)),
            Text(b, style: ts(c.txt, 12, FontWeight.w400)),
          ],
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Прогресс', style: ts(c.txt, 30, FontWeight.w800)),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 600),
                  builder: (_, v, __) => CustomPaint(
                    size: const Size(170, 170),
                    painter: Ring(v, c.txt, c.acc.withOpacity(.6)),
                  ),
                ),
                Text(
                  '${(pct * 100).round()}%',
                  style: ts(c.txt, 34, FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            stat('${tasks.length}', 'Всего задач'),
            const SizedBox(width: 10),
            stat('$done', 'Выполнено'),
            const SizedBox(width: 10),
            stat('${tasks.length - done}', 'Осталось'),
          ],
        ),
        const SizedBox(height: 18),
        Text('Эта неделя', style: ts(c.txt, 18, FontWeight.w700)),
        const SizedBox(height: 8),
        WeekBars(tasks),
      ],
    );
  }
}

// ───────────────────────── Профиль ─────────────────────────
class ProfilePage extends StatelessWidget {
  final List<Task> tasks;
  const ProfilePage({super.key, required this.tasks});

  Future<void> wipe(BuildContext ctx) async {
    if (!await confirm(
      ctx,
      'Удалить аккаунт и все данные? Это нельзя отменить.',
    ))
      return;
    try {
      final b = FirebaseFirestore.instance.batch();
      for (final q in [await tasksC.get(), await listsC.get()]) {
        for (final d in q.docs) {
          b.delete(d.reference);
        }
      }
      b.delete(uref);
      await b.commit();
      await me.delete();
    } on FirebaseAuthException catch (x) {
      if (ctx.mounted) toast(ctx, errMsg(x.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    final u = FirebaseAuth.instance.currentUser;
    final name = (u?.displayName ?? '').isEmpty
        ? 'Пользователь DayBy'
        : u!.displayName!;
    Widget tile(IconData i, String t, String s, VoidCallback f) =>
        GestureDetector(
          onTap: f,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(i, color: c.txt),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t, style: ts(c.txt, 16, FontWeight.w600)),
                      Text(
                        s,
                        style: ts(c.txt.withOpacity(.55), 12, FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.txt.withOpacity(.6)),
              ],
            ),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Профиль', style: ts(c.txt, 32, FontWeight.w800)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: c.btn,
                backgroundImage: (u?.photoURL != null)
                    ? NetworkImage(u!.photoURL!)
                    : null,
                child: u?.photoURL == null
                    ? const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 36,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: ts(c.txt, 20, FontWeight.w700)),
                    Text(
                      u?.email ?? '',
                      style: ts(c.txt.withOpacity(.55), 14, FontWeight.w400),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final n = await askText(
                          context,
                          'Ваше имя',
                          init: u?.displayName ?? '',
                        );
                        if (n == null || n.isEmpty) return;
                        await u!.updateDisplayName(n);
                        await saveUser(u, name: n);
                        await u.reload();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Редактировать профиль ↗',
                          style: ts(c.acc, 12, FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        WeekBars(tasks),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
          child: Text('Настройки', style: ts(c.txt, 20, FontWeight.w800)),
        ),
        tile(
          Icons.notifications_none,
          'Уведомления',
          'Напоминания о привычках',
          () => showDialog(
            context: context,
            builder: (d) => StatefulBuilder(
              builder: (_, ss) => AlertDialog(
                title: const Text('Уведомления'),
                content: SwitchListTile(
                  title: const Text('Напоминания о задачах'),
                  value: st.gb('notif'),
                  onChanged: (v) {
                    st.set('notif', v);
                    ss(() {});
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(d),
                    child: const Text('Ок'),
                  ),
                ],
              ),
            ),
          ),
        ),
        tile(
          Icons.palette_outlined,
          'Внешний вид',
          'Тема оформления',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
        ),
        tile(
          Icons.language,
          'Язык',
          'Русский',
          () => info(context, 'Язык', 'Сейчас доступен русский язык.'),
        ),
        tile(
          Icons.shield_outlined,
          'Конфиденциальность',
          'Данные и аккаунт',
          () => showDialog(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Конфиденциальность'),
              content: const Text(
                'Ваши списки и задачи хранятся в вашем аккаунте и доступны только вам.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(d);
                    wipe(context);
                  },
                  child: const Text('Удалить аккаунт'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: const Text('Ок'),
                ),
              ],
            ),
          ),
        ),
        tile(
          Icons.help_outline,
          'Помощь',
          'Как пользоваться DayBy',
          () => info(
            context,
            'Помощь',
            'Создавайте списки и задачи на главной. Нажмите на задачу, чтобы отметить её выполненной, смахните влево — чтобы удалить. Внешний вид настраивается в разделе «Внешний вид».',
          ),
        ),
        const SizedBox(height: 8),
        Btn(
          'Выйти из аккаунта',
          () => FirebaseAuth.instance.signOut(),
          bg: c.btn,
          fg: Colors.white,
          icon: Icons.logout,
        ),
      ],
    );
  }
}

// ───────────────────────── Настройки внешнего вида ─────────────────────────
class Seg extends StatelessWidget {
  final List<String> o;
  final int s;
  final ValueChanged<int> f;
  const Seg(this.o, this.s, this.f, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    return Container(
      decoration: BoxDecoration(
        color: c.acc.withOpacity(.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < o.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => f(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: s == i ? c.acc : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    o[i],
                    style: ts(
                      s == i ? Colors.white : c.txt,
                      13,
                      FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: st,
    builder: (ctx, _) {
      final c = cc(ctx);
      Widget box(List<Widget> ch) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ch,
        ),
      );
      Widget head(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
        child: Text(t, style: ts(c.txt, 15, FontWeight.w800)),
      );
      Widget sw(String t, String k) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(t, style: ts(c.txt, 14, FontWeight.w600)),
        value: st.gb(k),
        activeColor: c.btn,
        onChanged: (v) => st.set(k, v),
      );
      return Scaffold(
        appBar: AppBar(
          backgroundColor: c.top,
          foregroundColor: c.txt,
          title: Text('Внешний вид', style: ts(c.txt, 20, FontWeight.w800)),
        ),
        body: Bg(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                head('ПЕРСОНАЛИЗАЦИЯ'),
                box([
                  Text('Тема', style: ts(c.txt, 14)),
                  const SizedBox(height: 8),
                  Seg(
                    const ['системная', 'светлая', 'тёмная'],
                    st.gi('theme'),
                    (v) => st.set('theme', v),
                  ),
                  const SizedBox(height: 16),
                  Text('Размер текста', style: ts(c.txt, 14)),
                  const SizedBox(height: 8),
                  Seg(
                    const ['маленький', 'средний', 'крупный'],
                    st.gi('text'),
                    (v) => st.set('text', v),
                  ),
                  const SizedBox(height: 16),
                  Text('Цвет оформления', style: ts(c.txt, 14)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (var i = 0; i < pals.length; i++)
                        GestureDetector(
                          onTap: () => st.set('pal', i),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [pals[i].top, pals[i].acc],
                                  ),
                                  border: Border.all(
                                    color: st.gi('pal') == i
                                        ? c.txt
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pals[i].name,
                                style: ts(c.txt, 11, FontWeight.w400),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ]),
                head('ГЛАВНЫЙ ЭКРАН'),
                box([
                  sw('Блок «Сейчас»', 'now'),
                  sw('Полоса недели', 'week'),
                  sw('Привычки (списки)', 'habits'),
                  sw('Выполнение задач', 'tasks'),
                  sw('Компактный вид по умолчанию', 'compact'),
                ]),
                head('ПЛАНИРОВАНИЕ'),
                box([
                  Text('Первый день недели', style: ts(c.txt, 14)),
                  const SizedBox(height: 8),
                  Seg(
                    const ['понедельник', 'воскресенье'],
                    st.gb('mon') ? 0 : 1,
                    (v) => st.set('mon', v == 0),
                  ),
                  const SizedBox(height: 16),
                  Text('Формат времени', style: ts(c.txt, 14)),
                  const SizedBox(height: 8),
                  Seg(
                    const ['24 часа', '12 часов'],
                    st.gb('h24') ? 0 : 1,
                    (v) => st.set('h24', v == 0),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> editTask(
  BuildContext ctx, {
  Task? t,
  String? date,
  String? list,
}) => showModalBottomSheet<void>(
  context: ctx,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) =>
      TaskEditor(t: t, date: date ?? dkey(DateTime.now()), list: list),
);

class TaskEditor extends StatefulWidget {
  final Task? t;
  final String date;
  final String? list;
  const TaskEditor({super.key, this.t, required this.date, this.list});
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final title = TextEditingController(text: widget.t?.title ?? '');
  late final note = TextEditingController(text: widget.t?.note ?? '');
  late String date = widget.t?.date ?? widget.date;
  late String? time = widget.t?.time;
  late int prio = widget.t?.prio ?? 0;
  late final List<TextEditingController> sc = [
    for (final s in widget.t?.steps ?? <Step>[])
      TextEditingController(text: s.t),
  ];
  late final List<bool> sd = [for (final s in widget.t?.steps ?? <Step>[]) s.d];

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    for (final x in sc) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(date),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => date = dkey(d));
  }

  Future<void> pickTime() async {
    final p = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (p != null)
      setState(
        () => time =
            '${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')}',
      );
  }

  Future<void> save() async {
    final ti = title.text.trim();
    if (ti.isEmpty) return toast(context, 'Введите название');
    final steps = [
      for (var k = 0; k < sc.length; k++)
        if (sc[k].text.trim().isNotEmpty) {'t': sc[k].text.trim(), 'd': sd[k]},
    ];
    final data = <String, dynamic>{
      'title': ti,
      'note': note.text.trim(),
      'date': date,
      'time': time,
      'prio': prio,
      'steps': steps,
      'done': steps.isNotEmpty
          ? steps.every((s) => s['d'] == true)
          : (widget.t?.done ?? false),
    };
    if (widget.t == null) {
      await addTask(ti, date, widget.list, data);
    } else {
      await tasksC.doc(widget.t!.id).update(data);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = cc(context);
    final d = DateTime.parse(date);
    Widget chip(IconData i, String s, VoidCallback f, {VoidCallback? clear}) =>
        Expanded(
          child: GestureDetector(
            onTap: f,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(i, size: 18, color: c.txt),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: ts(c.txt, 14))),
                  if (clear != null)
                    GestureDetector(
                      onTap: clear,
                      child: Icon(Icons.close, size: 16, color: c.txt),
                    ),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: c.bot,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.t == null ? 'Новая задача' : 'Редактировать',
                style: ts(c.txt, 20, FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Fld(
                title,
                'Название',
                label: 'Название',
                txt: c.txt,
                fill: c.card,
              ),
              const SizedBox(height: 10),
              Fld(note, 'Заметка', label: 'Заметка', txt: c.txt, fill: c.card),
              const SizedBox(height: 12),
              Row(
                children: [
                  chip(
                    Icons.calendar_today_outlined,
                    '${d.day} ${mons[d.month - 1]}',
                    pickDate,
                  ),
                  const SizedBox(width: 10),
                  chip(
                    Icons.schedule,
                    time ?? 'Время',
                    pickTime,
                    clear: time == null
                        ? null
                        : () => setState(() => time = null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Seg(
                const ['обычный', 'важный', 'срочный'],
                prio,
                (v) => setState(() => prio = v),
              ),
              const SizedBox(height: 14),
              Text(
                'Шаги — выполняйте постепенно',
                style: ts(c.txt, 15, FontWeight.w700),
              ),
              for (var k = 0; k < sc.length; k++)
                Padding(
                  key: ObjectKey(sc[k]),
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            sd[k] ? Icons.check_circle : Icons.circle_outlined,
                            color: c.btn,
                          ),
                          onPressed: () => setState(() => sd[k] = !sd[k]),
                        ),
                        Expanded(
                          child: TextField(
                            controller: sc[k],
                            autofocus: sc[k].text.isEmpty,
                            style: ts(c.txt, 15),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Шаг',
                              hintStyle: ts(
                                c.txt.withOpacity(.5),
                                15,
                                FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 18, color: c.txt),
                          onPressed: () => setState(() {
                            sc.removeAt(k);
                            sd.removeAt(k);
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: () => setState(() {
                  sc.add(TextEditingController());
                  sd.add(false);
                }),
                icon: Icon(Icons.add, color: c.acc),
                label: Text('Добавить шаг', style: ts(c.acc, 14)),
              ),
              const SizedBox(height: 6),
              Btn('Сохранить', save, bg: c.btn, fg: Colors.white),
              if (widget.t != null)
                Center(
                  child: TextButton(
                    onPressed: () {
                      tasksC.doc(widget.t!.id).delete();
                      Navigator.pop(context);
                    },
                    child: Text('Удалить задачу', style: ts(c.acc, 14)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
