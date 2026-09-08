import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudflareD1Service {
  late final String baseUrl;

  CloudflareD1Service() {
    baseUrl = (dotenv.env['CLOUDFLARE_API_BASE_URL'] ?? 'https://dhankund.com').trim();
  }

  Future<dynamic> _postDb(String action, Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/api/db');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': action, 'payload': payload}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return decoded['data'];
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('CloudflareD1Service Error [$action]: $e');
      rethrow;
    }
  }

  // ----------------------------------------------------
  // Overview Metrics
  // ----------------------------------------------------
  Future<Map<String, dynamic>> fetchOverviewMetrics() async {
    try {
      final res = await _postDb('fetchOverviewMetrics', {});
      return Map<String, dynamic>.from(res);
    } catch (e) {
      return {
        'totalUsers': 0, 'totalLoans': 0, 'totalReferrals': 0,
        'pendingApprovals': 0, 'disbursedCommission': 0, 'pendingCommission': 0,
      };
    }
  }

  // ----------------------------------------------------
  // Registrations Management
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchRegistrations(String roleType) async {
    try {
      final res = await _postDb('fetchRegistrations', {'roleType': roleType.toUpperCase()});
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  Future<void> updateRegistrationStatus({
    required String collection,
    required String docId,
    required String uid,
    required String status,
    required String role,
    required Map<String, dynamic> userDetails,
  }) async {
    await _postDb('updateRegistrationStatus', {
      'collection': collection, 'docId': docId, 'uid': uid, 'status': status, 'role': role, 'userDetails': userDetails
    });
  }

  // ----------------------------------------------------
  // KYC & Bank Details
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchKycBankUsers() async {
    try {
      final res = await _postDb('fetchKycBankUsers', {});
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  Future<void> updateKycVerification(String uid, bool completed) async {
    await _postDb('updateKycVerification', {'uid': uid, 'completed': completed});
  }

  Future<void> updateBankVerification(String uid, bool completed) async {
    await _postDb('updateBankVerification', {'uid': uid, 'completed': completed});
  }

  Future<void> deleteUserRecord({required String uid, String? collection, String? docId}) async {
    await _postDb('deleteUserRecord', {'uid': uid, 'collection': collection, 'docId': docId});
  }

  // ----------------------------------------------------
  // Loan Applications
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchLoanApplications() async {
    try {
      final res = await _postDb('fetchLoanApplications', {});
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  Future<void> updateLoanStatus(String docId, String status) async {
    await _postDb('updateLoanStatus', {'docId': docId, 'status': status});
  }

  Future<void> createLoanApplication({
    required String loanType, required String fullName, required String mobileNumber, required String email, required String loanAmount,
    String? salary, String? turnover, String? fatherName, String? motherName, String? maritalStatus, String? spouseName,
    String? occupation, String? personalEmail, String? officialEmail, String? currentAddress, String? officeAddress,
    String? ref1Name, String? ref1Mobile, String? ref1Address, String? ref2Name, String? ref2Mobile, String? ref2Address,
    Map<String, dynamic>? applicantDocuments, List<dynamic>? coApplicants, String status = 'Pending',
    String? loginCompanyName, String? bankExecutiveName, String? gender, int? applicantCibil, String? panNumber, String? aadhaarNumber,
  }) async {
    await _postDb('createLoanApplication', {
      'loanType': loanType, 'fullName': fullName, 'mobileNumber': mobileNumber, 'email': email, 'loanAmount': loanAmount,
      'salary': salary, 'turnover': turnover, 'status': status, 'applicantCibil': applicantCibil, 'panNumber': panNumber, 'aadhaarNumber': aadhaarNumber,
      'fatherName': fatherName, 'motherName': motherName, 'maritalStatus': maritalStatus, 'spouseName': spouseName, 'occupation': occupation,
      'personalEmail': personalEmail, 'officialEmail': officialEmail, 'currentAddress': currentAddress, 'officeAddress': officeAddress,
      'ref1Name': ref1Name, 'ref1Mobile': ref1Mobile, 'ref1Address': ref1Address, 'ref2Name': ref2Name, 'ref2Mobile': ref2Mobile, 'ref2Address': ref2Address,
      'applicantDocuments': applicantDocuments, 'coApplicants': coApplicants, 'loginCompanyName': loginCompanyName, 'bankExecutiveName': bankExecutiveName, 'gender': gender,
    });
  }

  Future<void> updateLoanApplication({
    required String docId, required String loanType, required String fullName, required String mobileNumber, required String email, required String loanAmount,
    String? salary, String? turnover, String? fatherName, String? motherName, String? maritalStatus, String? spouseName,
    String? occupation, String? personalEmail, String? officialEmail, String? currentAddress, String? officeAddress,
    String? ref1Name, String? ref1Mobile, String? ref1Address, String? ref2Name, String? ref2Mobile, String? ref2Address,
    Map<String, dynamic>? applicantDocuments, List<dynamic>? coApplicants, required String status,
    String? loginCompanyName, String? bankExecutiveName, String? gender, int? applicantCibil, String? panNumber, String? aadhaarNumber,
  }) async {
    await _postDb('updateLoanApplication', {
      'docId': docId, 'loanType': loanType, 'fullName': fullName, 'mobileNumber': mobileNumber, 'email': email, 'loanAmount': loanAmount,
      'salary': salary, 'turnover': turnover, 'status': status, 'applicantCibil': applicantCibil, 'panNumber': panNumber, 'aadhaarNumber': aadhaarNumber,
      'fatherName': fatherName, 'motherName': motherName, 'maritalStatus': maritalStatus, 'spouseName': spouseName, 'occupation': occupation,
      'personalEmail': personalEmail, 'officialEmail': officialEmail, 'currentAddress': currentAddress, 'officeAddress': officeAddress,
      'ref1Name': ref1Name, 'ref1Mobile': ref1Mobile, 'ref1Address': ref1Address, 'ref2Name': ref2Name, 'ref2Mobile': ref2Mobile, 'ref2Address': ref2Address,
      'applicantDocuments': applicantDocuments, 'coApplicants': coApplicants, 'loginCompanyName': loginCompanyName, 'bankExecutiveName': bankExecutiveName, 'gender': gender,
    });
  }

  // ----------------------------------------------------
  // Referrals
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchReferrals() async {
    try {
      final res = await _postDb('fetchReferrals', {});
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  Future<void> updateReferralStatus(String docId, String status) async {
    await _postDb('updateReferralStatus', {'docId': docId, 'status': status});
  }

  Future<void> createReferral({
    required String referrerId, required String friendName, required String friendMobile, required String friendEmail,
    required String relationship, required String loanType, required String estimatedAmount, required bool consentGiven, String status = 'Invited',
  }) async {
    await _postDb('createReferral', {
      'referrerId': referrerId, 'friendName': friendName, 'friendMobile': friendMobile, 'friendEmail': friendEmail,
      'relationship': relationship, 'loanType': loanType, 'estimatedAmount': estimatedAmount, 'consentGiven': consentGiven, 'status': status,
    });
  }

  // ----------------------------------------------------
  // Community Feed & Admin Announcements
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchAdminPosts() async {
    try {
      final res = await _postDb('fetchAdminPosts', {});
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  Future<void> createAdminPost(String title, String content, String imageUrl) async {
    await _postDb('createAdminPost', {'title': title, 'content': content, 'imageUrl': imageUrl});
  }

  Future<List<Map<String, dynamic>>> fetchNewsFeed() async {
    try {
      final res = await _postDb('fetchNewsFeed', {});
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  Future<List<Map<String, dynamic>>> fetchStatuses() async {
    try {
      final res = await _postDb('fetchStatuses', {});
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  // ----------------------------------------------------
  // Banker Credit Policies System
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchBankPolicies() async {
    try {
      final res = await _postDb('fetchBankPolicies', {});
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  Future<void> saveBankPolicy({
    String? docId, required String bankName, required String bankerName, required String bankerMobile,
    String? officeAddress, String? l1ManagerName, String? l1ManagerMobile, String? l2ManagerName, String? l2ManagerMobile,
    required String loanType, required String productType, required String vertical, required int minCibil, required String minIncome,
    required String minTicketSize, required String maxTicketSize, String? ltvRatio, required String mProfileAllowed, required int maxAllowedBounces,
    required String geoRadius, required String loginFee, required String interestRate, required String processingFee, required String specialFeatures, required String tatDays,
  }) async {
    await _postDb('saveBankPolicy', {
      'docId': docId, 'bankName': bankName, 'bankerName': bankerName, 'bankerMobile': bankerMobile,
      'officeAddress': officeAddress, 'l1ManagerName': l1ManagerName, 'l1ManagerMobile': l1ManagerMobile, 'l2ManagerName': l2ManagerName, 'l2ManagerMobile': l2ManagerMobile,
      'loanType': loanType, 'productType': productType, 'vertical': vertical, 'minCibil': minCibil, 'minIncome': minIncome,
      'minTicketSize': minTicketSize, 'maxTicketSize': maxTicketSize, 'ltvRatio': ltvRatio, 'mProfileAllowed': mProfileAllowed, 'maxAllowedBounces': maxAllowedBounces,
      'geoRadius': geoRadius, 'loginFee': loginFee, 'interestRate': interestRate, 'processingFee': processingFee, 'specialFeatures': specialFeatures, 'tatDays': tatDays,
    });
  }

  // ----------------------------------------------------
  // Broadcast Messaging System
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchBroadcastHistory() async {
    try {
      final res = await _postDb('fetchBroadcastHistory', {});
      return List<Map<String, dynamic>>.from(res);
    } catch (e) { return []; }
  }

  Future<void> createBroadcast({
    required List<String> audiences, required bool sendWhatsapp, required bool sendEmail,
    required String subject, required String message, required int recipientCount,
  }) async {
    await _postDb('createBroadcast', {
      'audiences': audiences, 'sendWhatsapp': sendWhatsapp, 'sendEmail': sendEmail, 'subject': subject, 'message': message, 'recipientCount': recipientCount
    });
  }
}
