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

class ApiClient {
  static String baseUrl = '';
  static String? token;
  static String? currentUserId;
  static String? currentUserRole;

  static void init() {
    var url = (dotenv.env['API_BASE_URL'] ?? dotenv.env['CLOUDFLARE_API_BASE_URL'] ?? '').trim();
    if (url.isEmpty) {
      url = Uri.base.origin;
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    baseUrl = url;
  }

  static Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('crm_session_token');
      currentUserId = prefs.getString('crm_session_uid');
      currentUserRole = prefs.getString('crm_session_role');
    } catch (_) {}
  }

  static Future<void> saveSession(String t, String uid, String role) async {
    token = t;
    currentUserId = uid;
    currentUserRole = role;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('crm_session_token', t);
      await prefs.setString('crm_session_uid', uid);
      await prefs.setString('crm_session_role', role);
    } catch (_) {}
  }

  static Future<void> clearSession() async {
    token = null;
    currentUserId = null;
    currentUserRole = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('crm_session_token');
      await prefs.remove('crm_session_uid');
      await prefs.remove('crm_session_role');
    } catch (_) {}
  }

  static Map<String, String> headers() {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer ' + token!,
    };
  }

  static dynamic _decode(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = response.body;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    final message = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Request failed (' + response.statusCode.toString() + ')';
    throw ApiException(message);
  }

  static Future<dynamic> _request(String method, String path, {Object? body}) async {
    final uri = Uri.parse(baseUrl + path);
    final h = headers();
    http.Response response;
    if (method == 'GET') {
      response = await http.get(uri, headers: h);
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: h, body: body == null ? null : jsonEncode(body));
    } else if (method == 'POST') {
      response = await http.post(uri, headers: h, body: body == null ? null : jsonEncode(body));
    } else if (method == 'PUT') {
      response = await http.put(uri, headers: h, body: body == null ? null : jsonEncode(body));
    } else {
      response = await http.patch(uri, headers: h, body: body == null ? null : jsonEncode(body));
    }
    return _decode(response);
  }

  static Future<dynamic> get(String path) => _request('GET', path);
  static Future<dynamic> post(String path, Map<String, dynamic> body) => _request('POST', path, body: body);
  static Future<dynamic> put(String path, Map<String, dynamic> body) => _request('PUT', path, body: body);
  static Future<dynamic> patch(String path, Map<String, dynamic> body) => _request('PATCH', path, body: body);
  static Future<dynamic> delete(String path, {Map<String, dynamic>? body}) => _request('DELETE', path, body: body);
}

List<Map<String, dynamic>> _asList(dynamic data) {
  if (data is List) {
    return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
  return [];
}

class ApiService {
  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    final data = await ApiClient.post('/api/v1/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
    final t = data['token'] as String? ?? '';
    final user = (data['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    await ApiClient.saveSession(t, user['id']?.toString() ?? '', user['role']?.toString() ?? '');
    return user;
  }

  Future<void> logout() async {
    try {
      await ApiClient.post('/api/v1/auth/logout', const {});
    } catch (_) {}
    await ApiClient.clearSession();
  }

  Future<Map<String, dynamic>?> me() async {
    final data = await ApiClient.get('/api/v1/auth/me');
    if (data is Map) return data.cast<String, dynamic>();
    return null;
  }

  Future<void> verifyPassword(String password) async {
    await ApiClient.post('/api/v1/auth/verify-password', {'password': password});
  }

  Future<Map<String, dynamic>> fetchOverviewMetrics() async {
    final data = await ApiClient.get('/api/v1/overview');
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> fetchRegistrations(String roleType) async {
    final data = await ApiClient.get('/api/v1/registrations?role=' + roleType);
    return _asList(data);
  }

  Future<void> updateRegistrationStatus({
    required String collection,
    required String docId,
    required String uid,
    required String status,
    required String role,
    required Map<String, dynamic> userDetails,
  }) async {
    await ApiClient.patch('/api/v1/registrations/' + collection + '/' + docId, {
      'status': status,
      'uid': uid,
      'role': role,
      'userDetails': userDetails,
    });
  }

  Future<List<Map<String, dynamic>>> fetchKycBankUsers() async {
    final data = await ApiClient.get('/api/v1/kyc-bank-users');
    return _asList(data);
  }

  Future<void> updateKycVerification(String uid, bool completed) async {
    await ApiClient.patch('/api/v1/users/' + uid + '/kyc', {'completed': completed});
  }

  Future<void> updateBankVerification(String uid, bool completed) async {
    await ApiClient.patch('/api/v1/users/' + uid + '/bank', {'completed': completed});
  }

  Future<void> deleteUserRecord({required String uid, String? collection, String? docId}) async {
    await ApiClient.delete('/api/v1/users/' + uid, body: {
      if (collection != null) 'collection': collection,
      if (docId != null) 'docId': docId,
    });
  }

  Future<List<Map<String, dynamic>>> fetchLoanApplications() async {
    final data = await ApiClient.get('/api/v1/loans');
    return _asList(data);
  }

  Future<void> updateLoanStatus(String docId, String status) async {
    await ApiClient.patch('/api/v1/loans/' + docId + '/status', {'status': status});
  }

  Future<void> createLoanApplication({
    required String loanType,
    required String fullName,
    required String mobileNumber,
    required String email,
    required String loanAmount,
    String? salary,
    String? turnover,
    String? fatherName,
    String? motherName,
    String? maritalStatus,
    String? spouseName,
    String? occupation,
    String? personalEmail,
    String? officialEmail,
    String? currentAddress,
    String? officeAddress,
    String? ref1Name,
    String? ref1Mobile,
    String? ref1Address,
    String? ref2Name,
    String? ref2Mobile,
    String? ref2Address,
    Map<String, dynamic>? applicantDocuments,
    List<dynamic>? coApplicants,
    String status = 'Pending',
    String? loginCompanyName,
    String? bankExecutiveName,
    String? gender,
    int? applicantCibil,
    String? panNumber,
    String? aadhaarNumber,
  }) async {
    await ApiClient.post('/api/v1/loans', {
      'loan_type': loanType,
      'full_name': fullName,
      'pan_number': panNumber,
      'aadhaar_number': aadhaarNumber,
      'mobile_number': mobileNumber,
      'email': email,
      'loan_amount': loanAmount,
      'salary': salary,
      'turnover': turnover,
      'father_name': fatherName,
      'mother_name': motherName,
      'marital_status': maritalStatus,
      'spouse_name': spouseName,
      'occupation': occupation,
      'personal_email': personalEmail,
      'official_email': officialEmail,
      'current_address': currentAddress,
      'office_address': officeAddress,
      'ref1_name': ref1Name,
      'ref1_mobile': ref1Mobile,
      'ref1_address': ref1Address,
      'ref2_name': ref2Name,
      'ref2_mobile': ref2Mobile,
      'ref2_address': ref2Address,
      'applicant_documents': applicantDocuments,
      'co_applicants': coApplicants,
      'status': status,
      'login_company_name': loginCompanyName,
      'bank_executive_name': bankExecutiveName,
      'gender': gender,
      'applicant_cibil': applicantCibil,
    });
  }

  Future<void> updateLoanApplication({
    required String docId,
    required String loanType,
    required String fullName,
    required String mobileNumber,
    required String email,
    required String loanAmount,
    String? salary,
    String? turnover,
    String? fatherName,
    String? motherName,
    String? maritalStatus,
    String? spouseName,
    String? occupation,
    String? personalEmail,
    String? officialEmail,
    String? currentAddress,
    String? officeAddress,
    String? ref1Name,
    String? ref1Mobile,
    String? ref1Address,
    String? ref2Name,
    String? ref2Mobile,
    String? ref2Address,
    Map<String, dynamic>? applicantDocuments,
    List<dynamic>? coApplicants,
    required String status,
    String? loginCompanyName,
    String? bankExecutiveName,
    String? gender,
    int? applicantCibil,
    String? panNumber,
    String? aadhaarNumber,
  }) async {
    await ApiClient.put('/api/v1/loans/' + docId, {
      'loan_type': loanType,
      'full_name': fullName,
      'pan_number': panNumber,
      'aadhaar_number': aadhaarNumber,
      'mobile_number': mobileNumber,
      'email': email,
      'loan_amount': loanAmount,
      'salary': salary,
      'turnover': turnover,
      'father_name': fatherName,
      'mother_name': motherName,
      'marital_status': maritalStatus,
      'spouse_name': spouseName,
      'occupation': occupation,
      'personal_email': personalEmail,
      'official_email': officialEmail,
      'current_address': currentAddress,
      'office_address': officeAddress,
      'ref1_name': ref1Name,
      'ref1_mobile': ref1Mobile,
      'ref1_address': ref1Address,
      'ref2_name': ref2Name,
      'ref2_mobile': ref2Mobile,
      'ref2_address': ref2Address,
      'applicant_documents': applicantDocuments,
      'co_applicants': coApplicants,
      'status': status,
      'login_company_name': loginCompanyName,
      'bank_executive_name': bankExecutiveName,
      'gender': gender,
      'applicant_cibil': applicantCibil,
    });
  }

  Future<List<Map<String, dynamic>>> fetchReferrals() async {
    final data = await ApiClient.get('/api/v1/referrals');
    return _asList(data);
  }

  Future<void> updateReferralStatus(String docId, String status) async {
    await ApiClient.patch('/api/v1/referrals/' + docId + '/status', {'status': status});
  }

  Future<void> createReferral({
    required String referrerId,
    required String friendName,
    required String friendMobile,
    required String friendEmail,
    required String relationship,
    required String loanType,
    required String estimatedAmount,
    required bool consentGiven,
    String status = 'Invited',
  }) async {
    await ApiClient.post('/api/v1/referrals', {
      'referrer_id': referrerId,
      'friend_name': friendName,
      'friend_mobile': friendMobile,
      'friend_email': friendEmail,
      'relationship': relationship,
      'loan_type': loanType,
      'estimated_amount': estimatedAmount,
      'consent_given': consentGiven,
      'status': status,
    });
  }

  Future<List<Map<String, dynamic>>> fetchAdminPosts() async {
    final data = await ApiClient.get('/api/v1/admin-posts');
    return _asList(data);
  }

  Future<void> createAdminPost(String title, String content, String imageUrl) async {
    await ApiClient.post('/api/v1/admin-posts', {
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
    });
  }

  Future<List<Map<String, dynamic>>> fetchNewsFeed() async {
    final data = await ApiClient.get('/api/v1/news-feed');
    return _asList(data);
  }

  Future<List<Map<String, dynamic>>> fetchStatuses() async {
    final data = await ApiClient.get('/api/v1/statuses');
    return _asList(data);
  }

  Future<List<Map<String, dynamic>>> fetchBankPolicies() async {
    final data = await ApiClient.get('/api/v1/bank-policies');
    return _asList(data);
  }

  Future<void> saveBankPolicy({
    String? docId,
    required String bankName,
    required String bankerName,
    required String bankerMobile,
    String? officeAddress,
    String? l1ManagerName,
    String? l1ManagerMobile,
    String? l2ManagerName,
    String? l2ManagerMobile,
    required String loanType,
    required String productType,
    required String vertical,
    required int minCibil,
    required String minIncome,
    required String minTicketSize,
    required String maxTicketSize,
    String? ltvRatio,
    required String mProfileAllowed,
    required int maxAllowedBounces,
    required String geoRadius,
    required String loginFee,
    required String interestRate,
    required String processingFee,
    required String specialFeatures,
    required String tatDays,
  }) async {
    final body = {
      'bank_name': bankName,
      'banker_name': bankerName,
      'banker_mobile': bankerMobile,
      'office_address': officeAddress,
      'l1_manager_name': l1ManagerName,
      'l1_manager_mobile': l1ManagerMobile,
      'l2_manager_name': l2ManagerName,
      'l2_manager_mobile': l2ManagerMobile,
      'loan_type': loanType,
      'product_type': productType,
      'vertical': vertical,
      'min_cibil': minCibil,
      'min_income': minIncome,
      'min_ticket_size': minTicketSize,
      'max_ticket_size': maxTicketSize,
      'ticket_size': minTicketSize + ' - ' + maxTicketSize,
      'max_loan_amount': maxTicketSize,
      'ltv_ratio': ltvRatio,
      'm_profile_allowed': mProfileAllowed,
      'max_allowed_bounces': maxAllowedBounces,
      'geo_radius': geoRadius,
      'login_fee': loginFee,
      'interest_rate': interestRate,
      'processing_fee': processingFee,
      'special_features': specialFeatures,
      'tat_days': tatDays,
    };
    if (docId != null && docId.isNotEmpty) {
      await ApiClient.put('/api/v1/bank-policies/' + docId, body);
    } else {
      await ApiClient.post('/api/v1/bank-policies', body);
    }
  }

  Future<List<Map<String, dynamic>>> fetchBroadcastHistory() async {
    final data = await ApiClient.get('/api/v1/broadcasts');
    return _asList(data);
  }

  Future<void> createBroadcast({
    required List<String> audiences,
    required bool sendWhatsapp,
    required bool sendEmail,
    required String subject,
    required String message,
    required int recipientCount,
    bool sendPush = false,
  }) async {
    await ApiClient.post('/api/v1/broadcasts', {
      'audiences': audiences,
      'send_whatsapp': sendWhatsapp,
      'send_email': sendEmail,
      'send_push': sendPush,
      'subject': subject,
      'message': message,
      'recipient_count': recipientCount,
    });
  }
}
