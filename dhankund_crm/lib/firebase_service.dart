import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ----------------------------------------------------
  // Overview Metrics
  // ----------------------------------------------------
  Future<Map<String, dynamic>> fetchOverviewMetrics() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final loansSnapshot = await _firestore.collection('loan_applications').get();
      final referralsSnapshot = await _firestore.collection('referrals').get();
      final dsaSnapshot = await _firestore.collection('dsa_registrations').where('status', isEqualTo: 'pending').get();
      final bankerSnapshot = await _firestore.collection('banker_registrations').where('status', isEqualTo: 'pending').get();
      final partnerSnapshot = await _firestore.collection('partner_registrations').where('status', isEqualTo: 'pending').get();

      int totalUsers = usersSnapshot.docs.length;
      int totalLoans = loansSnapshot.docs.length;
      int totalReferrals = referralsSnapshot.docs.length;
      int pendingApprovals = dsaSnapshot.docs.length + bankerSnapshot.docs.length + partnerSnapshot.docs.length;

      double disbursedCommission = 0;
      double pendingCommission = 0;

      for (var doc in referralsSnapshot.docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase() ?? '';
        if (status == 'earned') {
          disbursedCommission += 5000;
        } else if (status == 'approved') {
          pendingCommission += 5000;
        }
      }

      return {
        'totalUsers': totalUsers,
        'totalLoans': totalLoans,
        'totalReferrals': totalReferrals,
        'pendingApprovals': pendingApprovals,
        'disbursedCommission': disbursedCommission,
        'pendingCommission': pendingCommission,
      };
    } catch (e) {
      debugPrint("Error fetching overview metrics: $e");
      // Fallback/mock statistics if database is empty/not configured yet
      return {
        'totalUsers': 120,
        'totalLoans': 45,
        'totalReferrals': 78,
        'pendingApprovals': 8,
        'disbursedCommission': 150000.0,
        'pendingCommission': 45000.0,
      };
    }
  }

  // ----------------------------------------------------
  // Registrations Management
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchRegistrations(String roleType) async {
    try {
      String collectionName = '';
      if (roleType.toUpperCase() == 'DSA') {
        collectionName = 'dsa_registrations';
      } else if (roleType.toUpperCase() == 'BANKER') {
        collectionName = 'banker_registrations';
      } else {
        collectionName = 'partner_registrations';
      }

      final QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
          '_source_collection': collectionName,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching $roleType registrations: $e");
      return _getMockRegistrations(roleType);
    }
  }

  Future<void> updateRegistrationStatus({
    required String collection,
    required String docId,
    required String uid,
    required String status,
    required String role,
    required Map<String, dynamic> userDetails,
  }) async {
    final batch = _firestore.batch();

    // 1. Update Registration Table Status
    final regRef = _firestore.collection(collection).doc(docId);
    batch.update(regRef, {'status': status});

    // 2. If approved, sync profile to `users/[uid]` and set profileCompleted = true, role = role
    if (status.toLowerCase() == 'approved' && uid.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(uid);
      
      final Map<String, dynamic> updatedProfile = {
        'uid': uid,
        'role': role,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        ...userDetails,
      };
      
      // Remove any helper fields
      updatedProfile.remove('status');
      updatedProfile.remove('timestamp');
      updatedProfile.remove('id');
      updatedProfile.remove('_source_collection');

      batch.set(userRef, updatedProfile, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // ----------------------------------------------------
  // KYC & Bank Details Approvals
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchKycBankUsers() async {
    try {
      // Query users who have either KYC submitted or Bank details submitted, but not fully verified, or all users for administration
      final QuerySnapshot snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching KYC/Bank users: $e");
      return _getMockKycBankUsers();
    }
  }

  Future<void> updateKycVerification(String uid, bool completed) async {
    await _firestore.collection('users').doc(uid).update({
      'kycCompleted': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBankVerification(String uid, bool completed) async {
    await _firestore.collection('users').doc(uid).update({
      'bankDetailsCompleted': completed,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ----------------------------------------------------
  // Loan Applications Management
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchLoanApplications() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('loan_applications')
          .orderBy('submitted_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching loan applications: $e");
      return _getMockLoanApplications();
    }
  }

  Future<void> updateLoanStatus(String docId, String status) async {
    await _firestore.collection('loan_applications').doc(docId).update({
      'status': status,
    });
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
    try {
      await _firestore.collection('loan_applications').add({
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
        'submitted_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _getMockLoanApplications(); // Ensure initialized
      _cachedMockLoans!.insert(0, {
        'id': 'loan_mock_${DateTime.now().millisecondsSinceEpoch}',
        'loan_type': loanType,
        'full_name': fullName,
        'pan_number': panNumber,
        'aadhaar_number': aadhaarNumber,
        'mobile_number': mobileNumber,
        'email': email,
        'loan_amount': loanAmount,
        'salary': salary,
        'turnover': turnover,
        'status': status,
        'applicant_cibil': applicantCibil,
        'submitted_at': Timestamp.now(),
      });
    }
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
    try {
      await _firestore.collection('loan_applications').doc(docId).update({
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
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _getMockLoanApplications(); // Ensure initialized
      final idx = _cachedMockLoans!.indexWhere((app) => app['id'] == docId);
      if (idx != -1) {
        final existing = _cachedMockLoans![idx];
        _cachedMockLoans![idx] = {
          ...existing,
          'loan_type': loanType,
          'full_name': fullName,
          'pan_number': panNumber ?? existing['pan_number'],
          'aadhaar_number': aadhaarNumber ?? existing['aadhaar_number'],
          'mobile_number': mobileNumber,
          'email': email,
          'loan_amount': loanAmount,
          'salary': salary,
          'turnover': turnover,
          'status': status,
          'applicant_cibil': applicantCibil ?? existing['applicant_cibil'],
        };
      }
    }
  }

  // ----------------------------------------------------
  // Referrals & Wallet Management
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchReferrals() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('referrals')
          .orderBy('created_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching referrals: $e");
      return _getMockReferrals();
    }
  }

  Future<void> updateReferralStatus(String docId, String status) async {
    await _firestore.collection('referrals').doc(docId).update({
      'status': status,
    });
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
    await _firestore.collection('referrals').add({
      'referrer_id': referrerId,
      'friend_name': friendName,
      'friend_mobile': friendMobile,
      'friend_email': friendEmail,
      'relationship': relationship,
      'loan_type': loanType,
      'estimated_amount': estimatedAmount,
      'consent_given': consentGiven,
      'status': status,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // ----------------------------------------------------
  // Community Feed & Admin Announcements
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchAdminPosts() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('admin_posts')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching admin posts: $e");
      return _getMockAdminPosts();
    }
  }

  Future<void> createAdminPost(String title, String content, String imageUrl) async {
    await _firestore.collection('admin_posts').add({
      'uid': 'admin',
      'name': 'Admin',
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> fetchNewsFeed() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('news_feed')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching news feed: $e");
      return _getMockNewsFeed();
    }
  }

  Future<List<Map<String, dynamic>>> fetchStatuses() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('statuses')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching statuses: $e");
      return _getMockStatuses();
    }
  }

  // ----------------------------------------------------
  // Banker Credit Policies System
  // ----------------------------------------------------
  static List<Map<String, dynamic>>? _cachedBankPolicies;

  Future<List<Map<String, dynamic>>> fetchBankPolicies() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('bank_policies')
          .orderBy('updated_at', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching bank policies: $e");
      return _getMockBankPolicies();
    }
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
    final policyData = {
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
      'ticket_size': '$minTicketSize - $maxTicketSize',
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
      'updated_at': FieldValue.serverTimestamp(),
    };

    try {
      if (docId != null) {
        await _firestore.collection('bank_policies').doc(docId).update(policyData);
      } else {
        await _firestore.collection('bank_policies').add(policyData);
      }
    } catch (e) {
      _getMockBankPolicies();
      if (docId != null) {
        final idx = _cachedBankPolicies!.indexWhere((p) => p['id'] == docId);
        if (idx != -1) {
          _cachedBankPolicies![idx] = {
            ...policyData,
            'id': docId,
            'updated_at': Timestamp.now(),
          };
        }
      } else {
        _cachedBankPolicies!.insert(0, {
          ...policyData,
          'id': 'policy_mock_${DateTime.now().millisecondsSinceEpoch}',
          'updated_at': Timestamp.now(),
        });
      }
    }
  }

  // ----------------------------------------------------
  // Broadcast Messaging System
  // ----------------------------------------------------
  Future<List<Map<String, dynamic>>> fetchBroadcastHistory() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('broadcast_history')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }).toList();
    } catch (e) {
      debugPrint("Error fetching broadcast history: $e");
      return _getMockBroadcastHistory();
    }
  }

  Future<void> createBroadcast({
    required List<String> audiences,
    required bool sendWhatsapp,
    required bool sendEmail,
    required String subject,
    required String message,
    required int recipientCount,
  }) async {
    await _firestore.collection('broadcast_history').add({
      'audiences': audiences,
      'send_whatsapp': sendWhatsapp,
      'send_email': sendEmail,
      'subject': subject,
      'message': message,
      'recipient_count': recipientCount,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ----------------------------------------------------
  // Mock Data Fallbacks (for beautiful demo state when DB is empty/disconnected)
  // ----------------------------------------------------
  List<Map<String, dynamic>> _getMockRegistrations(String roleType) {
    final now = Timestamp.now();
    if (roleType.toUpperCase() == 'DSA') {
      return [
        {
          'id': 'dsa_mock_1',
          'uid': 'user_dsa_1',
          'name': 'Rajesh Kumar',
          'email': 'rajesh.dsa@gmail.com',
          'mobile': '+91 98765 43210',
          'gender': 'Male',
          'gumastaUrl': 'intellij.png',
          'company': 'Rajesh Finance Solutions',
          'address': '102, Gold Crest Plaza, Indore, MP',
          'currentExp': '4',
          'totalExp': '7',
          'segment': 'Finance',
          'profession': 'BUSINESS',
          'about': 'Experienced B2B direct sales partner specializing in business & personal loans.',
          'status': 'pending',
          'timestamp': now,
        },
        {
          'id': 'dsa_mock_2',
          'uid': 'user_dsa_2',
          'name': 'Priya Sharma',
          'email': 'priya.finance@yahoo.com',
          'mobile': '+91 87654 32109',
          'gender': 'Female',
          'gumastaUrl': 'intellij.png',
          'company': 'Priya & Associates',
          'address': 'A-4, Shanti Nagar, Bhopal, MP',
          'currentExp': '3',
          'totalExp': '5',
          'segment': 'Finance',
          'profession': 'JOB',
          'about': 'Referral associate focused on home loans.',
          'status': 'approved',
          'timestamp': now,
        }
      ];
    } else if (roleType.toUpperCase() == 'BANKER') {
      return [
        {
          'id': 'banker_mock_1',
          'uid': 'user_banker_1',
          'name': 'Amit Verma',
          'email': 'amit.verma@hdfcbank.com',
          'mobile': '+91 76543 21098',
          'gender': 'Male',
          'nomineeName': 'Sita Verma',
          'idCardUrl': 'intellij.png',
          'company': 'HDFC Bank',
          'status': 'pending',
          'timestamp': now,
        },
        {
          'id': 'banker_mock_2',
          'uid': 'user_banker_2',
          'name': 'Sanjay Gupta',
          'email': 'sanjay.gupta@icicibank.com',
          'mobile': '+91 90123 45678',
          'gender': 'Male',
          'nomineeName': 'Rita Gupta',
          'idCardUrl': 'intellij.png',
          'company': 'ICICI Bank',
          'status': 'approved',
          'timestamp': now,
        }
      ];
    } else {
      return [
        {
          'id': 'partner_mock_1',
          'uid': 'user_partner_1',
          'name': 'Vikram Rathore',
          'email': 'vikram.builders@outlook.com',
          'mobile': '+91 99988 77766',
          'gender': 'Male',
          'company': 'Rathore Infra Group',
          'officeAddress': 'Plot 45, Vijay Nagar, Indore, MP',
          'currentExp': '8',
          'totalExp': '12',
          'segment': 'Real Estate',
          'profession': 'BUSINESS',
          'about': 'Prominent property developer looking to offer financing services directly to clients.',
          'role': 'Builder',
          'status': 'pending',
          'timestamp': now,
        },
        {
          'id': 'partner_mock_2',
          'uid': 'user_partner_2',
          'name': 'Rohan Shah',
          'email': 'rohan@shahrealtors.com',
          'mobile': '+91 88877 66655',
          'gender': 'Male',
          'company': 'Shah Realtors',
          'officeAddress': 'Flat 202, Royal Palms, Mumbai',
          'currentExp': '5',
          'totalExp': '6',
          'segment': 'Real Estate',
          'profession': 'BUSINESS',
          'about': 'Property brokerage connecting customers to customized property loans.',
          'role': 'Broker',
          'status': 'approved',
          'timestamp': now,
        }
      ];
    }
  }

  List<Map<String, dynamic>> _getMockKycBankUsers() {
    return [
      {
        'id': 'user_dsa_1',
        'uid': 'user_dsa_1',
        'name': 'Rajesh Kumar',
        'email': 'rajesh.dsa@gmail.com',
        'mobile': '+91 98765 43210',
        'role': 'DSA',
        'profileCompleted': true,
        'kycCompleted': false,
        'kycPan': 'ABCDE1234F',
        'kycAadhaar': '1234 5678 9012',
        'kycDocUrl': 'intellij.png',
        'bankDetailsCompleted': false,
        'bankName': 'State Bank of India',
        'bankAccountHolder': 'Rajesh Kumar',
        'bankAccountNumber': '100023456789',
        'bankIfsc': 'SBIN0001234',
        'bankProofUrl': 'intellij.png',
      },
      {
        'id': 'user_banker_1',
        'uid': 'user_banker_1',
        'name': 'Amit Verma',
        'email': 'amit.verma@hdfcbank.com',
        'mobile': '+91 76543 21098',
        'role': 'Banker',
        'profileCompleted': true,
        'kycCompleted': true,
        'kycPan': 'FGHIJ5678K',
        'kycAadhaar': '9876 5432 1098',
        'kycDocUrl': 'intellij.png',
        'bankDetailsCompleted': true,
        'bankName': 'HDFC Bank Ltd',
        'bankAccountHolder': 'Amit Verma',
        'bankAccountNumber': '5010023456789',
        'bankIfsc': 'HDFC0000123',
        'bankProofUrl': 'intellij.png',
      }
    ];
  }

  static List<Map<String, dynamic>>? _cachedMockLoans;

  List<Map<String, dynamic>> _getMockLoanApplications() {
    if (_cachedMockLoans != null) return _cachedMockLoans!;
    final now = Timestamp.now();
    _cachedMockLoans = [
      {
        'id': 'loan_mock_1',
        'user_id': 'user_cust_1',
        'loan_type': 'Personal Loan',
        'full_name': 'Karan Malhotra',
        'mobile_number': '+91 95555 44444',
        'email': 'karan.malhotra@gmail.com',
        'loan_amount': '7,50,000',
        'salary': '65,000',
        'status': 'Pending Details',
        'applicant_cibil': 680,
        'submitted_at': now,
      },
      {
        'id': 'loan_mock_2',
        'user_id': 'user_cust_2',
        'loan_type': 'Business Loan',
        'full_name': 'Balaji Sweets & Caterers',
        'mobile_number': '+91 94444 33333',
        'email': 'balaji.sweets@outlook.com',
        'loan_amount': '25,00,000',
        'turnover': '1,20,00,000',
        'status': 'Disbursed',
        'applicant_cibil': 785,
        'login_company_name': 'HDFC Bank',
        'bank_executive_name': 'Ramesh Kumar',
        'submitted_at': now,
      },
      {
        'id': 'loan_mock_3',
        'user_id': 'user_cust_3',
        'loan_type': 'Home Loan',
        'full_name': 'Sunita Deshmukh',
        'mobile_number': '+91 93333 22222',
        'email': 'sunita.desh@gmail.com',
        'loan_amount': '45,00,000',
        'status': 'Rejected',
        'submitted_at': now,
      },
      {
        'id': 'loan_mock_4',
        'user_id': 'user_cust_4',
        'loan_type': 'Mortgage Loan',
        'full_name': 'Rajesh Gupta',
        'mobile_number': '+91 98888 77777',
        'email': 'rajesh.gupta@outlook.com',
        'loan_amount': '60,00,000',
        'status': 'Sanctioned',
        'login_company_name': 'ICICI Bank',
        'bank_executive_name': 'Suresh Sharma',
        'submitted_at': Timestamp.fromDate(now.toDate().subtract(const Duration(days: 2))),
      },
      {
        'id': 'loan_mock_5',
        'user_id': 'user_cust_5',
        'loan_type': 'Car Loan',
        'full_name': 'Aarav Sharma',
        'mobile_number': '+91 97777 66666',
        'email': 'aarav.sharma@gmail.com',
        'loan_amount': '12,00,000',
        'status': 'Login done',
        'login_company_name': 'SBI Bank',
        'bank_executive_name': 'Sanjay Gupta',
        'submitted_at': Timestamp.fromDate(now.toDate().subtract(const Duration(days: 5))),
      },
      {
        'id': 'loan_mock_6',
        'user_id': 'user_cust_6',
        'loan_type': 'Commercial Vehicle Loan',
        'full_name': 'Vikas Logistics Corp',
        'mobile_number': '+91 96666 55555',
        'email': 'vikas.logistics@gmail.com',
        'loan_amount': '35,00,000',
        'status': 'Pending Details',
        'submitted_at': Timestamp.fromDate(now.toDate().subtract(const Duration(days: 10))),
      }
    ];
    return _cachedMockLoans!;
  }

  List<Map<String, dynamic>> _getMockReferrals() {
    final now = Timestamp.now();
    return [
      {
        'id': 'ref_mock_1',
        'referrer_id': 'user_dsa_1',
        'friend_name': 'Vijay Rathod',
        'friend_mobile': '+91 91111 22222',
        'friend_email': 'vijay.rathod@gmail.com',
        'relationship': 'Friend',
        'loan_type': 'Business Loan',
        'estimated_amount': '15,00,000',
        'consent_given': true,
        'status': 'Earned',
        'created_at': now,
      },
      {
        'id': 'ref_mock_2',
        'referrer_id': 'user_dsa_1',
        'friend_name': 'Nikhil Deshmukh',
        'friend_mobile': '+91 92222 33333',
        'friend_email': 'nikhil.desh@gmail.com',
        'relationship': 'Relative',
        'loan_type': 'Personal Loan',
        'estimated_amount': '5,00,000',
        'consent_given': true,
        'status': 'Approved',
        'created_at': now,
      },
      {
        'id': 'ref_mock_3',
        'referrer_id': 'user_partner_1',
        'friend_name': 'Meera Sen',
        'friend_mobile': '+91 93333 44444',
        'friend_email': 'meera.sen@gmail.com',
        'relationship': 'Client',
        'loan_type': 'Home Loan',
        'estimated_amount': '35,00,000',
        'consent_given': true,
        'status': 'Invited',
        'created_at': now,
      }
    ];
  }

  List<Map<String, dynamic>> _getMockAdminPosts() {
    final now = Timestamp.now();
    return [
      {
        'id': 'post_mock_1',
        'uid': 'admin',
        'name': 'Admin',
        'title': 'Monsoon Loan Carnival Bonanza',
        'content': 'We are excited to launch the Monsoon Loan Carnival. Earn up to 2% extra referral payouts for all successful disbursements made between July 15 and September 15. Standard KYC terms apply.',
        'imageUrl': 'intellij.png',
        'timestamp': now,
      },
      {
        'id': 'post_mock_2',
        'uid': 'admin',
        'name': 'Admin',
        'title': 'New HDFC Banker Approvals Live',
        'content': 'All HDFC Home loan payouts have been processed. Direct directory sync is active. Bankers can now browse updated DSA contact cards to accelerate files.',
        'imageUrl': 'intellij.png',
        'timestamp': now,
      }
    ];
  }

  List<Map<String, dynamic>> _getMockNewsFeed() {
    final now = Timestamp.now();
    return [
      {
        'id': 'feed_mock_1',
        'uid': 'user_dsa_1',
        'name': 'Rajesh Kumar',
        'role': 'DSA',
        'company': 'Rajesh Finance Solutions',
        'profilePictureUrl': '',
        'mobile': '+91 98765 43210',
        'content': 'Successfully closed a ₹50 Lakh commercial loan for a client in under 4 days through HDFC Banker portals. Kudos to the Dhankund team for smooth networking!',
        'imageUrl': 'intellij.png',
        'likes': ['user_banker_1', 'user_partner_2'],
        'timestamp': now,
      }
    ];
  }

  List<Map<String, dynamic>> _getMockStatuses() {
    final now = Timestamp.now();
    return [
      {
        'id': 'status_mock_1',
        'uid': 'user_dsa_1',
        'name': 'Rajesh Kumar',
        'role': 'DSA',
        'company': 'Rajesh Finance Solutions',
        'mobile': '+91 98765 43210',
        'text': 'Processing 5 major loan files today! Looking for DSA collaborations in Indore.',
        'gradientIndex': 2,
        'mediaUrl': '',
        'mediaType': 'text',
        'profilePictureUrl': '',
        'timestamp': now,
      }
    ];
  }

  List<Map<String, dynamic>> _getMockBroadcastHistory() {
    final now = Timestamp.now();
    return [
      {
        'id': 'bc_mock_1',
        'audiences': ['DSAs', 'Bankers'],
        'send_whatsapp': true,
        'send_email': true,
        'subject': 'New Payout Slabs Activated!',
        'message': 'Dear Partners, we have updated our payout slabs for higher volumes. Check the portal for details.',
        'recipient_count': 150,
        'timestamp': now,
      },
      {
        'id': 'bc_mock_2',
        'audiences': ['Customers'],
        'send_whatsapp': true,
        'send_email': false,
        'subject': 'Monsoon Offer',
        'message': 'Avail processing fee waivers on all Home Loans this Monsoon season!',
        'recipient_count': 320,
        'timestamp': Timestamp.fromDate(now.toDate().subtract(const Duration(days: 2))),
      },
    ];
  }

  List<Map<String, dynamic>> _getMockBankPolicies() {
    if (_cachedBankPolicies != null) return _cachedBankPolicies!;
    final now = Timestamp.now();
    _cachedBankPolicies = [
      {
        'id': 'pol_1',
        'bank_name': 'HDFC Bank',
        'banker_name': 'Amit Verma',
        'banker_mobile': '+91 76543 21098',
        'office_address': 'Trade Tower, 4th Floor, Vijay Nagar, Indore (M.P.)',
        'l1_manager_name': 'Rakesh Mehra (Cluster Head)',
        'l1_manager_mobile': '+91 98221 00112',
        'l2_manager_name': 'Siddharth Rao (Zonal Head)',
        'l2_manager_mobile': '+91 99334 55667',
        'loan_type': 'Personal Loan',
        'product_type': 'Prime',
        'vertical': 'DSA',
        'min_cibil': 720,
        'min_income': '₹35,000 / mo',
        'min_ticket_size': '₹1,00,000',
        'max_ticket_size': '₹40,00,000',
        'ticket_size': '₹1 Lakh - ₹40 Lakh',
        'max_loan_amount': '₹40,00,000',
        'ltv_ratio': 'N/A (Unsecured)',
        'm_profile_allowed': 'YES',
        'max_allowed_bounces': 0,
        'geo_radius': '50 km surrounding city',
        'login_fee': 'Nil / Free Login Promo',
        'interest_rate': '10.25% - 13.50%',
        'processing_fee': '0.99% - 1.50%',
        'special_features': 'Instant 10-minute digital sanction for salaried professionals. Special discounts on Super-A category corporate lists.',
        'tat_days': '2 Days',
        'updated_at': now,
      },
      {
        'id': 'pol_2',
        'bank_name': 'HDFC Bank',
        'banker_name': 'Amit Verma',
        'banker_mobile': '+91 76543 21098',
        'office_address': 'Trade Tower, 4th Floor, Vijay Nagar, Indore (M.P.)',
        'l1_manager_name': 'Rakesh Mehra',
        'l1_manager_mobile': '+91 98221 00112',
        'l2_manager_name': 'Siddharth Rao',
        'l2_manager_mobile': '+91 99334 55667',
        'loan_type': 'Business Loan',
        'product_type': 'Prime',
        'vertical': 'Connector',
        'min_cibil': 700,
        'min_income': '₹50,00,000 / yr',
        'min_ticket_size': '₹5,00,000',
        'max_ticket_size': '₹75,00,000',
        'ticket_size': '₹5 Lakh - ₹75 Lakh',
        'max_loan_amount': '₹75,00,000',
        'ltv_ratio': 'N/A (Unsecured)',
        'm_profile_allowed': 'YES',
        'max_allowed_bounces': 1,
        'geo_radius': '60 km radius',
        'login_fee': '₹2,500 + GST',
        'interest_rate': '13.00% - 16.00%',
        'processing_fee': '1.50%',
        'special_features': 'No collateral required up to ₹50 Lakh. GST & Banking surrogate programs accepted.',
        'tat_days': '4 Days',
        'updated_at': now,
      },
      {
        'id': 'pol_3',
        'bank_name': 'HDFC Bank',
        'banker_name': 'Amit Verma',
        'banker_mobile': '+91 76543 21098',
        'office_address': 'Trade Tower, 4th Floor, Vijay Nagar, Indore (M.P.)',
        'l1_manager_name': 'Deepak Khurana',
        'l1_manager_mobile': '+91 97110 44332',
        'l2_manager_name': 'Siddharth Rao',
        'l2_manager_mobile': '+91 99334 55667',
        'loan_type': 'Home Loan',
        'product_type': 'Affordable',
        'vertical': 'Direct',
        'min_cibil': 700,
        'min_income': '₹30,000 / mo',
        'min_ticket_size': '₹10,00,000',
        'max_ticket_size': '₹5,00,00,000',
        'ticket_size': '₹10 Lakh - ₹5 Crore',
        'max_loan_amount': '₹5,00,00,000',
        'ltv_ratio': 'Up to 90% LTV',
        'm_profile_allowed': 'YES',
        'max_allowed_bounces': 1,
        'geo_radius': '75 km radius',
        'login_fee': '₹3,000 flat',
        'interest_rate': '8.40% - 9.15%',
        'processing_fee': '₹3,000 flat',
        'special_features': 'Up to 90% LTV funding with custom doorstep legal and technical evaluation.',
        'tat_days': '5 Days',
        'updated_at': now,
      },
      {
        'id': 'pol_4',
        'bank_name': 'ICICI Bank',
        'banker_name': 'Sanjay Gupta',
        'banker_mobile': '+91 90123 45678',
        'office_address': 'ICICI Financial Centre, AB Road, Indore (M.P.)',
        'l1_manager_name': 'Naveen Bajaj (Area Manager)',
        'l1_manager_mobile': '+91 98980 12345',
        'l2_manager_name': 'Vikramaditya (Regional Head)',
        'l2_manager_mobile': '+91 98111 22334',
        'loan_type': 'Personal Loan',
        'product_type': 'Affordable',
        'vertical': 'DSA',
        'min_cibil': 700,
        'min_income': '₹25,000 / mo',
        'min_ticket_size': '₹50,000',
        'max_ticket_size': '₹50,00,000',
        'ticket_size': '₹50,000 - ₹50 Lakh',
        'max_loan_amount': '₹50,00,000',
        'ltv_ratio': 'N/A (Unsecured)',
        'm_profile_allowed': 'YES',
        'max_allowed_bounces': 1,
        'geo_radius': '45 km radius',
        'login_fee': 'Nil',
        'interest_rate': '10.50% - 14.00%',
        'processing_fee': '1.25%',
        'special_features': 'High FOIR allowance up to 65%. Overdraft facility available along with term loan.',
        'tat_days': '2 Days',
        'updated_at': now,
      },
      {
        'id': 'pol_5',
        'bank_name': 'ICICI Bank',
        'banker_name': 'Sanjay Gupta',
        'banker_mobile': '+91 90123 45678',
        'office_address': 'ICICI Financial Centre, AB Road, Indore (M.P.)',
        'l1_manager_name': 'Naveen Bajaj',
        'l1_manager_mobile': '+91 98980 12345',
        'l2_manager_name': 'Vikramaditya',
        'l2_manager_mobile': '+91 98111 22334',
        'loan_type': 'Business Loan',
        'product_type': 'Informal',
        'vertical': 'Connector',
        'min_cibil': 680,
        'min_income': '₹30,00,000 / yr',
        'min_ticket_size': '₹10,00,000',
        'max_ticket_size': '₹1,00,00,000',
        'ticket_size': '₹10 Lakh - ₹1 Crore',
        'max_loan_amount': '₹1,00,00,000',
        'ltv_ratio': '75% on Industrial/Commercial',
        'm_profile_allowed': 'YES',
        'max_allowed_bounces': 1,
        'geo_radius': '50 km radius',
        'login_fee': '₹5,000',
        'interest_rate': '13.50% - 17.00%',
        'processing_fee': '1.75%',
        'special_features': 'Fast surrogate evaluation based on 12-month current account average quarterly balance.',
        'tat_days': '3 Days',
        'updated_at': now,
      },
      {
        'id': 'pol_6',
        'bank_name': 'State Bank of India (SBI)',
        'banker_name': 'Priya Nambiar',
        'banker_mobile': '+91 98231 44556',
        'office_address': 'SBI Main Administrative Building, M.G. Road, Indore',
        'l1_manager_name': 'Shyam Sundar (AGM)',
        'l1_manager_mobile': '+91 94250 88990',
        'l2_manager_name': 'K. S. Narayanan (DGM)',
        'l2_manager_mobile': '+91 94251 11223',
        'loan_type': 'Home Loan',
        'product_type': 'Prime',
        'vertical': 'Direct',
        'min_cibil': 750,
        'min_income': '₹25,000 / mo',
        'min_ticket_size': '₹5,00,000',
        'max_ticket_size': '₹10,00,00,000',
        'ticket_size': '₹5 Lakh - ₹10 Crore',
        'max_loan_amount': '₹10,00,00,000',
        'ltv_ratio': '85% - 90% LTV',
        'm_profile_allowed': 'YES',
        'max_allowed_bounces': 0,
        'geo_radius': '80 km city radius',
        'login_fee': 'Zero (Monsoon Campaign)',
        'interest_rate': '8.25% - 8.85%',
        'processing_fee': 'Zero (Monsoon Campaign)',
        'special_features': 'Lowest interest rates with daily reducing balance. Strict clean banking required with zero recent defaults.',
        'tat_days': '8 Days',
        'updated_at': now,
      },
      {
        'id': 'pol_7',
        'bank_name': 'Axis Bank',
        'banker_name': 'Rohit Deshmukh',
        'banker_mobile': '+91 91234 56789',
        'office_address': 'Axis House, Race Course Road, Indore',
        'l1_manager_name': 'Abhay Patil',
        'l1_manager_mobile': '+91 98990 44556',
        'l2_manager_name': 'Harish Iyer',
        'l2_manager_mobile': '+91 98770 12345',
        'loan_type': 'Personal Loan',
        'product_type': 'Affordable',
        'vertical': 'DSA',
        'min_cibil': 680,
        'min_income': '₹22,000 / mo',
        'min_ticket_size': '₹1,00,000',
        'max_ticket_size': '₹35,00,000',
        'ticket_size': '₹1 Lakh - ₹35 Lakh',
        'max_loan_amount': '₹35,00,00,000',
        'ltv_ratio': 'N/A (Unsecured)',
        'm_profile_allowed': 'NO',
        'max_allowed_bounces': 2,
        'geo_radius': '40 km radius',
        'login_fee': '₹1,000 + GST',
        'interest_rate': '11.00% - 15.50%',
        'processing_fee': '1.50%',
        'special_features': 'Flexible underwriting for Category-C companies and semi-urban branch profiles.',
        'tat_days': '3 Days',
        'updated_at': now,
      },
      {
        'id': 'pol_8',
        'bank_name': 'Kotak Mahindra Bank',
        'banker_name': 'Manish Joshi',
        'banker_mobile': '+91 98760 12345',
        'office_address': 'Kotak Infinity, Palasia Square, Indore',
        'l1_manager_name': 'Tushar Gandhi',
        'l1_manager_mobile': '+91 98200 99887',
        'l2_manager_name': 'Alok Singhania',
        'l2_manager_mobile': '+91 98201 11223',
        'loan_type': 'Home Loan',
        'product_type': 'Prime',
        'vertical': 'DSA',
        'min_cibil': 730,
        'min_income': '₹40,000 / mo',
        'min_ticket_size': '₹20,00,000',
        'max_ticket_size': '₹7,50,00,000',
        'ticket_size': '₹20 Lakh - ₹7.5 Crore',
        'max_loan_amount': '₹7,50,00,000',
        'ltv_ratio': '80% - 85% LTV',
        'm_profile_allowed': 'YES',
        'max_allowed_bounces': 0,
        'geo_radius': '60 km radius',
        'login_fee': '₹2,000',
        'interest_rate': '8.45% - 8.95%',
        'processing_fee': '0.50%',
        'special_features': 'Zero foreclosure charges on floating rates. Express doorstep legal documentation.',
        'tat_days': '4 Days',
        'updated_at': now,
      },
      {
        'id': 'pol_9',
        'bank_name': 'Bajaj Finserv',
        'banker_name': 'Ankit Saxena',
        'banker_mobile': '+91 97112 33445',
        'office_address': 'Bajaj Capital Hub, Scheme 54, Vijay Nagar, Indore',
        'l1_manager_name': 'Vikas Malhotra',
        'l1_manager_mobile': '+91 98110 55443',
        'l2_manager_name': 'Rajeev Sethi',
        'l2_manager_mobile': '+91 98111 66778',
        'loan_type': 'Business Loan',
        'product_type': 'Informal',
        'vertical': 'DSA',
        'min_cibil': 650,
        'min_income': '₹20,00,000 / yr',
        'min_ticket_size': '₹3,00,000',
        'max_ticket_size': '₹45,00,000',
        'ticket_size': '₹3 Lakh - ₹45 Lakh',
        'max_loan_amount': '₹45,00,000',
        'ltv_ratio': '70% LTV (Unregistered/Gram Panchayat)',
        'm_profile_allowed': 'YES',
        'max_allowed_bounces': 3,
        'geo_radius': '35 km radius',
        'login_fee': 'Nil / Deducted from disbursal',
        'interest_rate': '14.50% - 19.00%',
        'processing_fee': '2.00%',
        'special_features': 'High risk tolerance policy. Bounces accepted if justified with business cash flow.',
        'tat_days': '24 Hours',
        'updated_at': now,
      },
      {
        'id': 'pol_10',
        'bank_name': 'Bajaj Finserv',
        'banker_name': 'Ankit Saxena',
        'banker_mobile': '+91 97112 33445',
        'office_address': 'Bajaj Capital Hub, Scheme 54, Vijay Nagar, Indore',
        'l1_manager_name': 'Vikas Malhotra',
        'l1_manager_mobile': '+91 98110 55443',
        'l2_manager_name': 'Rajeev Sethi',
        'l2_manager_mobile': '+91 98111 66778',
        'loan_type': 'Personal Loan',
        'product_type': 'Informal',
        'vertical': 'Connector',
        'min_cibil': 660,
        'min_income': '₹20,000 / mo',
        'min_ticket_size': '₹1,00,000',
        'max_ticket_size': '₹25,00,000',
        'ticket_size': '₹1 Lakh - ₹25 Lakh',
        'max_loan_amount': '₹25,00,00,000',
        'ltv_ratio': 'N/A (Unsecured)',
        'm_profile_allowed': 'YES',
        'max_allowed_bounces': 2,
        'geo_radius': '35 km radius',
        'login_fee': 'Nil',
        'interest_rate': '12.50% - 17.50%',
        'processing_fee': '2.00%',
        'special_features': 'Flexi Hybrid Loan with interest-only EMI option for the initial 24 months.',
        'tat_days': '24 Hours',
        'updated_at': now,
      },
    ];
    return _cachedBankPolicies!;
  }
}
