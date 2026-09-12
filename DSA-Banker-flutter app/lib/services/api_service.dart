import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// Returns a message that is safe to show to end users.
/// Server-side validation messages (ApiException) are shown as-is; any other
/// error (network, timeout, unexpected exception) is hidden behind a generic message.
String friendlyErrorMessage(Object error) {
  if (error is ApiException) {
    final m = error.message.trim();
    if (m.isNotEmpty) return m;
  }
  return 'Something went wrong. Please try again.';
}

class ApiClient {
  static String baseUrl = '';
  static String? token;
  static String? currentUserId;
  static String? currentUserEmail;
  static String? currentUserRole;
  static String? currentUserName;

  static void init() {
    var url = (dotenv.env['API_BASE_URL'] ?? dotenv.env['CLOUDFLARE_API_BASE_URL'] ?? '').trim();
    if (url.isEmpty) { url = 'https://api.dhankund.com'; }
    if (url.endsWith('/')) { url = url.substring(0, url.length - 1); }
    baseUrl = url;
  }

  static Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('dsa_session_token');
      currentUserId = prefs.getString('dsa_session_uid');
      currentUserEmail = prefs.getString('dsa_session_email');
      currentUserRole = prefs.getString('dsa_session_role');
      currentUserName = prefs.getString('dsa_session_name');
    } catch (_) {}
  }

  static Future<void> saveSession(String t, String uid, String email, String role, String name) async {
    token = t; currentUserId = uid; currentUserEmail = email; currentUserRole = role; currentUserName = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dsa_session_token', t);
      await prefs.setString('dsa_session_uid', uid);
      await prefs.setString('dsa_session_email', email);
      await prefs.setString('dsa_session_role', role);
      await prefs.setString('dsa_session_name', name);
    } catch (_) {}
  }

  static Future<void> clearSession() async {
    token = null; currentUserId = null; currentUserEmail = null; currentUserRole = null; currentUserName = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('dsa_session_token');
      await prefs.remove('dsa_session_uid');
      await prefs.remove('dsa_session_email');
      await prefs.remove('dsa_session_role');
      await prefs.remove('dsa_session_name');
    } catch (_) {}
  }

  static Map<String, String> headers() {
    return { 'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer ' + token! };
  }

  static dynamic _decode(http.Response response) {
    dynamic data;
    try { data = jsonDecode(response.body); } catch (_) { data = response.body; }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final message = (data is Map && data['error'] != null) ? data['error'].toString() : 'Request failed (' + response.statusCode.toString() + ')';
    throw ApiException(message);
  }

  static Future<dynamic> _request(String method, String path, {Object? body}) async {
    final uri = Uri.parse(baseUrl + path);
    final h = headers();
    http.Response response;
    if (method == 'GET') { response = await http.get(uri, headers: h); }
    else if (method == 'DELETE') { response = await http.delete(uri, headers: h, body: body == null ? null : jsonEncode(body)); }
    else if (method == 'POST') { response = await http.post(uri, headers: h, body: body == null ? null : jsonEncode(body)); }
    else if (method == 'PUT') { response = await http.put(uri, headers: h, body: body == null ? null : jsonEncode(body)); }
    else { response = await http.patch(uri, headers: h, body: body == null ? null : jsonEncode(body)); }
    return _decode(response);
  }

  static Future<dynamic> get(String path) => _request('GET', path);
  static Future<dynamic> post(String path, Map<String, dynamic> body) => _request('POST', path, body: body);
  static Future<dynamic> put(String path, Map<String, dynamic> body) => _request('PUT', path, body: body);
  static Future<dynamic> patch(String path, Map<String, dynamic> body) => _request('PATCH', path, body: body);
  static Future<dynamic> delete(String path) => _request('DELETE', path);
}

List<Map<String, dynamic>> _asList(dynamic data) {
  if (data is List) return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  return [];
}

class ApiService {
  Future<Map<String, dynamic>> signup({required String email, required String password, required String role, String name = ''}) async {
    final data = await ApiClient.post('/api/v1/auth/signup', {'email': email, 'password': password, 'role': role, 'name': name}) as Map<String, dynamic>;
    final t = data['token'] as String? ?? '';
    final user = (data['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    await ApiClient.saveSession(t, user['id']?.toString() ?? '', user['email']?.toString() ?? '', user['role']?.toString() ?? '', user['name']?.toString() ?? '');
    return user;
  }

  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final data = await ApiClient.post('/api/v1/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
    final t = data['token'] as String? ?? '';
    final user = (data['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    await ApiClient.saveSession(t, user['id']?.toString() ?? '', user['email']?.toString() ?? '', user['role']?.toString() ?? '', user['name']?.toString() ?? '');
    return user;
  }

  Future<void> logout() async { try { await ApiClient.post('/api/v1/auth/logout', const {}); } catch (_) {} await ApiClient.clearSession(); }
  Future<Map<String, dynamic>?> me() async { final data = await ApiClient.get('/api/v1/auth/me'); if (data is Map) return data.cast<String, dynamic>(); return null; }

  Future<Map<String, dynamic>> fetchMyProfile() async { final data = await ApiClient.get('/api/v1/me/profile'); return (data as Map).cast<String, dynamic>(); }
  Future<void> updateProfile(Map<String, dynamic> patch) async { await ApiClient.put('/api/v1/me/profile', patch); }
  Future<void> submitKyc({required String pan, required String aadhaar, String docUrl = ''}) async { await ApiClient.post('/api/v1/me/kyc', {'pan': pan, 'aadhaar': aadhaar, 'docUrl': docUrl}); }
  Future<void> submitBank({required String holderName, required String bankName, required String accountNumber, required String ifsc, String proofUrl = ''}) async { await ApiClient.post('/api/v1/me/bank', {'holderName': holderName, 'bankName': bankName, 'accountNumber': accountNumber, 'ifsc': ifsc, 'proofUrl': proofUrl}); }

  Future<void> submitRegistration({required String role, required Map<String, dynamic> details}) async { await ApiClient.post('/api/v1/registrations', {'role': role, 'details': details}); }

  Future<List<Map<String, dynamic>>> fetchMyLoans() async { final data = await ApiClient.get('/api/v1/me/loans'); return _asList(data); }
  Future<void> createLoan(Map<String, dynamic> body) async { await ApiClient.post('/api/v1/loans', body); }

  Future<List<Map<String, dynamic>>> fetchMyReferrals() async { final data = await ApiClient.get('/api/v1/me/referrals'); return _asList(data); }
  Future<void> createReferral({required String friendName, required String friendMobile, String? friendEmail, required String relationship, required String loanType, required String estimatedAmount, required bool consentGiven, String status = 'Invited'}) async {
    await ApiClient.post('/api/v1/referrals', {'friend_name': friendName, 'friend_mobile': friendMobile, 'friend_email': friendEmail, 'relationship': relationship, 'loan_type': loanType, 'estimated_amount': estimatedAmount, 'consent_given': consentGiven, 'status': status});
  }

  Future<List<Map<String, dynamic>>> fetchNewsFeed() async { final data = await ApiClient.get('/api/v1/news-feed'); return _asList(data); }
  Future<void> createNewsFeedPost({required String content, String? imageUrl}) async { await ApiClient.post('/api/v1/news-feed', {'content': content, 'imageUrl': imageUrl}); }
  Future<void> deleteNewsFeedPost(String id) async { await ApiClient.delete('/api/v1/news-feed/' + id); }
  Future<void> toggleNewsFeedLike(String id) async { await ApiClient.patch('/api/v1/news-feed/' + id + '/like', {}); }

  Future<List<Map<String, dynamic>>> fetchStatuses() async { final data = await ApiClient.get('/api/v1/statuses'); return _asList(data); }
  Future<void> createStatus({required String text, int gradientIndex = 0, String? mediaUrl, String mediaType = 'text'}) async { await ApiClient.post('/api/v1/statuses', {'text': text, 'gradientIndex': gradientIndex, 'mediaUrl': mediaUrl, 'mediaType': mediaType}); }
  Future<void> deleteStatus(String id) async { await ApiClient.delete('/api/v1/statuses/' + id); }

  Future<List<Map<String, dynamic>>> fetchAdminPosts() async { final data = await ApiClient.get('/api/v1/admin-posts'); return _asList(data); }
  Future<void> createAdminPost({required String title, required String content, String? imageUrl}) async { await ApiClient.post('/api/v1/admin-posts', {'title': title, 'content': content, 'imageUrl': imageUrl}); }
  Future<void> deleteAdminPost(String id) async { await ApiClient.delete('/api/v1/admin-posts/' + id); }

  Future<List<Map<String, dynamic>>> fetchDirectory(String role) async { final data = await ApiClient.get('/api/v1/directory?role=' + role); return _asList(data); }
  Future<List<Map<String, dynamic>>> fetchBankPolicies() async { final data = await ApiClient.get('/api/v1/bank-policies'); return _asList(data); }

  Future<void> registerDevice(String token, {String? platform}) async { await ApiClient.post('/api/v1/devices', {'token': token, 'platform': platform}); }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    return (await ApiClient.post('/api/v1/auth/forgot-password', {'email': email}) as Map<String, dynamic>).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    return (await ApiClient.post('/api/v1/auth/verify-otp', {'email': email, 'otp': otp}) as Map<String, dynamic>).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> resetPassword(String resetToken, String newPassword) async {
    return (await ApiClient.post('/api/v1/auth/reset-password', {'reset_token': resetToken, 'new_password': newPassword}) as Map<String, dynamic>).cast<String, dynamic>();
  }
}
