import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/api_service.dart';
import 'package:my_flutter_app/presentation/auth/auth_screen.dart';
import 'package:my_flutter_app/presentation/shared/new_home_screen.dart';
import 'package:my_flutter_app/presentation/b2b_network/profession_selection_screen.dart';
import 'package:my_flutter_app/presentation/auth/biometric_auth_wrapper.dart';

class RootWrapper extends StatelessWidget {
  const RootWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = ApiClient.token != null && ApiClient.token!.isNotEmpty;
    if (!loggedIn) {
      BiometricAuthWrapper.authenticatedThisSession = false;
      return const AuthScreen();
    }
    return const ProfileCheckWrapper();
  }
}

class ProfileCheckWrapper extends StatelessWidget {
  const ProfileCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BiometricAuthWrapper(
      child: FutureBuilder<bool>(
        future: _isProfileCompleted(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.data == true) {
            return const NewHomeScreen();
          }
          return const ProfessionSelectionScreen();
        },
      ),
    );
  }

  Future<bool> _isProfileCompleted() async {
    try {
      final profile = await ApiService().fetchMyProfile();
      return profile['profileCompleted'] == true;
    } catch (_) {
      return false;
    }
  }
}
