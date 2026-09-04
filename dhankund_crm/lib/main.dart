import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_layout.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the AWS credentials from the config.env file
  try {
    await dotenv.load(fileName: "config.env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dhankund CRM Control Center',
      theme: AppTheme.themeData,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement Cloudflare Email OTP authentication logic
    // Returning LoginScreen temporarily
    return const LoginScreen();
  }
}
