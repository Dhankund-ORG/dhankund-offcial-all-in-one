import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_service.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_layout.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'config.env');
  ApiClient.init();
  await ApiClient.loadSession();
  runApp(const DhankundCrmApp());
}

class DhankundCrmApp extends StatelessWidget {
  const DhankundCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dhankund CRM Control Center',
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Map<String, dynamic>?> _session;

  @override
  void initState() {
    super.initState();
    _session = _resolveSession();
  }

  Future<Map<String, dynamic>?> _resolveSession() async {
    final token = ApiClient.token;
    if (token == null || token.isEmpty) return null;
    try {
      final user = await ApiService().me();
      if (user != null) {
        final role = (user['role'] ?? '').toString();
        if (role == 'admin' || role == 'staff') return user;
      }
      await ApiClient.clearSession();
    } catch (_) {
      await ApiClient.clearSession();
    }
    return null;
  }

  void _onLoggedIn() {
    setState(() {
      _session = _resolveSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data != null) {
          return const DashboardLayout();
        }
        return LoginScreen(onLogin: _onLoggedIn);
      },
    );
  }
}
