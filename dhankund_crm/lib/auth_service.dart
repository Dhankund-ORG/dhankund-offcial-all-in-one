import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> login(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(credential.user!.uid).get();
        
        if (userDoc.exists) {
          Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
          String? role = data?['role'];
          
          if (role == 'admin' || role == 'staff') {
            return null; 
          } else {
            await logout();
            return 'Unauthorized access. Only admin or staff can login.';
          }
        } else {
          await logout();
          return 'User record not found. Unauthorized.';
        }
      }
      return 'Login failed.';
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'An unknown error occurred.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
