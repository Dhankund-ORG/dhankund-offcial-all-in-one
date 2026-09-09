import '../api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

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
}
