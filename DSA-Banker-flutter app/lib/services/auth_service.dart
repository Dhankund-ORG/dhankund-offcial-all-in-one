import '../services/api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  /// Returns null on success, error message on failure.
  Future<String?> signup(String email, String password, String role, String name) async {
    try {
      await _api.signup(email: email, password: password, role: role, name: name);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Sign up failed. Please try again.';
    }
  }

  /// Returns null on success, error message on failure.
  Future<String?> login(String email, String password) async {
    try {
      await _api.login(email: email, password: password);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Login failed. Please try again.';
    }
  }

  Future<void> logout() async {
    await _api.logout();
  }

  bool get isLoggedIn => ApiClient.token != null && ApiClient.token!.isNotEmpty;

  Future<String?> forgotPassword(String email) async {
    try {
      await _api.forgotPassword(email);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to send OTP. Please try again.';
    }
  }

  Future<Map<String, dynamic>?> verifyOtp(String email, String otp) async {
    try {
      return await _api.verifyOtp(email, otp);
    } on ApiException catch (e) {
      return {'error': e.message};
    } catch (_) {
      return {'error': 'OTP verification failed.'};
    }
  }

  Future<String?> resetPassword(String resetToken, String newPassword) async {
    try {
      await _api.resetPassword(resetToken, newPassword);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Password reset failed. Please try again.';
    }
  }
}
