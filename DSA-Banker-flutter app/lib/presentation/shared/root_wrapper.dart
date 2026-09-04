import 'package:flutter/material.dart';
import 'package:my_flutter_app/presentation/auth/auth_screen.dart';
import 'package:my_flutter_app/presentation/shared/new_home_screen.dart';
import 'package:my_flutter_app/presentation/b2b_network/profession_selection_screen.dart';
import 'package:my_flutter_app/presentation/auth/biometric_auth_wrapper.dart';

class RootWrapper extends StatelessWidget {
  const RootWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement Cloudflare Email OTP Auth check
    BiometricAuthWrapper.authenticatedThisSession = false;
    return const AuthScreen();
  }
}

class ProfileCheckWrapper extends StatelessWidget {
  const ProfileCheckWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement Cloudflare D1 check for profile completion
    return const AuthScreen();
  }
}
