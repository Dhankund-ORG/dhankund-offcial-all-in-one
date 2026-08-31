import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Initialize Firebase using JSON config from environment
  try {
    String? jsonStr;
    if (kIsWeb) {
      jsonStr = dotenv.env['CRM_FIREBASE_WEB'];
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      jsonStr = dotenv.env['CRM_FIREBASE_ANDROID'];
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      jsonStr = dotenv.env['CRM_FIREBASE_IOS'];
    }

    if (jsonStr != null && jsonStr.isNotEmpty) {
      final config = jsonDecode(jsonStr);
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: config['apiKey'] ?? "",
          authDomain: config['authDomain'] ?? "",
          databaseURL: config['databaseURL'] ?? "",
          projectId: config['projectId'] ?? "",
          storageBucket: config['storageBucket'] ?? "",
          messagingSenderId: config['messagingSenderId'] ?? "",
          appId: config['appId'] ?? "",
          measurementId: config['measurementId'] ?? "",
        ),
      );
    } else {
      debugPrint("Warning: No Firebase JSON configuration found for this platform.");
    }
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
                Map<String, dynamic>? data = roleSnapshot.data!.data() as Map<String, dynamic>?;
                String? role = data?['role'];
                if (role == 'admin' || role == 'staff') {
                  return const DashboardLayout();
                }
              }
              
              // If unauthorized or error, sign out
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            },
          );
        }
        
        return const LoginScreen();
      },
    );
  }
}
