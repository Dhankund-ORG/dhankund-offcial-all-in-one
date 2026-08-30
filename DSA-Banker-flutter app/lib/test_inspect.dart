import 'package:local_auth/local_auth.dart';

void main() async {
  final auth = LocalAuthentication();
  await auth.authenticate(
    localizedReason: 'Test',
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  );
}
