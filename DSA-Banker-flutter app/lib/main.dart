import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_flutter_app/presentation/shared/root_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "config.env");
  
  String? jsonStr;
  try {
    if (kIsWeb) {
      jsonStr = dotenv.env['DSA_FIREBASE_WEB'];
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      jsonStr = dotenv.env['DSA_FIREBASE_ANDROID'];
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      jsonStr = dotenv.env['DSA_FIREBASE_IOS'];
    }

    if (jsonStr != null && jsonStr.isNotEmpty) {
      Map<String, dynamic> config = {};
      try {
        config = jsonDecode(jsonStr);
      } catch (e) {
        // Fallback for JS object formats or unquoted keys/values
        final RegExp keyRegex = RegExp(r'([a-zA-Z0-9_]+)\s*:\s*["\u0027]?([^,"\u0027}\s]+)["\u0027]?');
        for (final match in keyRegex.allMatches(jsonStr)) {
          config[match.group(1)!] = match.group(2);
        }
      }

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
      await Firebase.initializeApp(); // Fallback to native config if present
    }
  } catch (e, stack) {
    debugPrint("Firebase initialization failed: $e\n$stack");
    runApp(MaterialApp(home: Scaffold(body: Center(child: SelectableText("Firebase Init Error:\n$e\n$jsonStr")))));
    return;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dhankund Loan Services',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A3AFF),
          primary: const Color(0xFF4A3AFF),
          secondary: const Color(0xFF6C5DD3),
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF1A1D1F),
          error: const Color(0xFFD63031),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F5F9),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF1A1D1F)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1D1F),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A3AFF),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F9FB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: const TextStyle(
            color: Color(0xFF8896A6),
            fontSize: 14,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF5F6D7E),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE6E8EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4A3AFF), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD63031), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD63031), width: 1.5),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE6E8EC), width: 1),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF4A3AFF),
          unselectedItemColor: Color(0xFF8896A6),
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFF4A3AFF),
          unselectedLabelColor: Color(0xFF8896A6),
          indicatorColor: Color(0xFF4A3AFF),
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      home: const RootWrapper(),
    );
  }
}
