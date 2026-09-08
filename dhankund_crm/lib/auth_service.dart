import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Mock User class to replace firebase_auth User
class User {
  final String uid;
  final String email;
  User({required this.uid, required this.email});
}

class AuthService {
  late final String baseUrl;
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    baseUrl = (dotenv.env['CLOUDFLARE_API_BASE_URL'] ?? 'https://dhankund.com').trim();
  }

  // Simple reactive state for auth
  final ValueNotifier<User?> _userNotifier = ValueNotifier<User?>(null);
  
  Stream<User?> get authStateChanges async* {
    yield _userNotifier.value;
    // In a real app, listen to a stream controller or shared preferences
  }

  User? get currentUser => _userNotifier.value;

  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'signIn', 'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          final u = User(uid: decoded['user']['uid'], email: decoded['user']['email']);
          _userNotifier.value = u;
          return u;
        }
      }
      return null;
    } catch (e) {
      debugPrint("Auth error: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    _userNotifier.value = null;
  }
}
