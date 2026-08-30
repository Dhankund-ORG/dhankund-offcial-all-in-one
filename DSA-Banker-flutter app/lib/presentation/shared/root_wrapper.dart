import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/presentation/auth/auth_screen.dart';
import 'package:my_flutter_app/presentation/shared/new_home_screen.dart';
import 'package:my_flutter_app/presentation/b2b_network/profession_selection_screen.dart';
import 'package:my_flutter_app/presentation/auth/biometric_auth_wrapper.dart';

class RootWrapper extends StatelessWidget {
  const RootWrapper({super.key});

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

        if (snapshot.hasData) {
          return const ProfileCheckWrapper();
        }

        // When user is not logged in, reset the session authentication flag
        BiometricAuthWrapper.authenticatedThisSession = false;
        return const AuthScreen();
      },
    );
  }
}

class ProfileCheckWrapper extends StatelessWidget {
  const ProfileCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const AuthScreen();

    return BiometricAuthWrapper(
      child: FutureBuilder<bool>(
        future: _isProfileCompleted(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data == true) {
            return const NewHomeScreen();
          }

          return const ProfessionSelectionScreen();
        },
      ),
    );
  }

  Future<bool> _isProfileCompleted(String uid) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['profileCompleted'] == true) return true;
      }

      List<String> collections = ['banker_registrations', 'dsa_registrations', 'partner_registrations'];
      for (var coll in collections) {
        final uidQuery = await FirebaseFirestore.instance.collection(coll).where('uid', isEqualTo: uid).limit(1).get();
        if (uidQuery.docs.isNotEmpty) return true;

        if (email != null) {
          final emailQuery = await FirebaseFirestore.instance.collection(coll).where('email', isEqualTo: email).limit(1).get();
          if (emailQuery.docs.isNotEmpty) return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

