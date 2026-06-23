import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/presentation/shared/file_upload_widget.dart';

class MyEarningsScreen extends StatefulWidget {
  const MyEarningsScreen({super.key});

  @override
  State<MyEarningsScreen> createState() => _MyEarningsScreenState();
}

class _MyEarningsScreenState extends State<MyEarningsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // KYC controllers
  final _panController = TextEditingController();
  final _aadhaarController = TextEditingController();

  // Bank controllers
  final _holderNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _ifscController = TextEditingController();

  @override
  void dispose() {
    _panController.dispose();
    _aadhaarController.dispose();
    _holderNameController.dispose();
    _bankNameController.dispose();
    _accountNoController.dispose();
    _ifscController.dispose();
    super.dispose();
  }

  void _showKYCBottomSheet(BuildContext context, Map<String, dynamic> userData) {
    _panController.text = userData['kycPan'] ?? '';
    _aadhaarController.text = userData['kycAadhaar'] ?? '';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? localKycDocUrl = userData['kycDocUrl'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'KYC Authentication',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please fill out your identity credentials for verification.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    const Text('PAN Card Number *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _panController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Enter 10-digit PAN (e.g. ABCDE1234F)',
                        prefixIcon: const Icon(Icons.credit_card_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'PAN number is required';
                        if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(val.trim().toUpperCase())) {
                          return 'Invalid PAN Card Number format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Aadhaar Card Number *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _aadhaarController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter 12-digit Aadhaar Card Number',
                        prefixIcon: const Icon(Icons.fingerprint),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Aadhaar number is required';
                        if (!RegExp(r'^[0-9]{12}$').hasMatch(val.trim())) {
                          return 'Invalid Aadhaar (must be exactly 12 digits)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (localKycDocUrl != null && localKycDocUrl!.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Document uploaded previously',
                              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    FileUploadWidget(
                      label: 'Upload KYC Document (Aadhaar / PAN) *',
                      storagePath: 'kyc_documents',
                      onUploadComplete: (url) {
                        setModalState(() {
                          localKycDocUrl = url;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                if (localKycDocUrl == null || localKycDocUrl!.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please upload your KYC document (Aadhaar / PAN) to submit.'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => isSaving = true);
                                try {
                                  if (user != null) {
                                    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                                      'kycCompleted': true,
                                      'kycPan': _panController.text.trim().toUpperCase(),
                                      'kycAadhaar': _aadhaarController.text.trim(),
                                      'kycDocUrl': localKycDocUrl,
                                    });
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('KYC Submitted & Approved successfully!')),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error updating KYC: $e')),
                                  );
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A3AFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Verify & Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

  void _showBankDetailsBottomSheet(BuildContext context, Map<String, dynamic> userData) {
    _holderNameController.text = userData['bankAccountHolder'] ?? userData['name'] ?? '';
    _bankNameController.text = userData['bankName'] ?? '';
    _accountNoController.text = userData['bankAccountNumber'] ?? '';
    _ifscController.text = userData['bankIfsc'] ?? '';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? localBankProofUrl = userData['bankProofUrl'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Bank Account Details',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Provide your bank details to enable direct commission transfers.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    const Text('Account Holder Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _holderNameController,
                      decoration: InputDecoration(
                        hintText: 'Enter name as in passbook',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Bank Name *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: InputDecoration(
                        hintText: 'e.g. State Bank of India',
                        prefixIcon: const Icon(Icons.account_balance),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Bank name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Account Number *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accountNoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter account number',
                        prefixIcon: const Icon(Icons.numbers),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Account number is required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('IFSC Code *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ifscController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Enter 11-digit IFSC (e.g. SBIN0001234)',
                        prefixIcon: const Icon(Icons.code),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'IFSC code is required';
                        if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(val.trim().toUpperCase())) {
                          return 'Invalid IFSC Code format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (localBankProofUrl != null && localBankProofUrl!.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bank proof uploaded previously',
                              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    FileUploadWidget(
                      label: 'Upload Bank Proof (Optional) - Passbook / Cheque',
                      storagePath: 'bank_proofs',
                      onUploadComplete: (url) {
                        setModalState(() {
                          localBankProofUrl = url;
                        });
                      },
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSaving = true);
                                try {
                                  if (user != null) {
                                    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                                      'bankDetailsCompleted': true,
                                      'bankName': _bankNameController.text.trim(),
                                      'bankAccountHolder': _holderNameController.text.trim(),
                                      'bankAccountNumber': _accountNoController.text.trim(),
                                      'bankIfsc': _ifscController.text.trim().toUpperCase(),
                                      'bankProofUrl': localBankProofUrl ?? '',
                                    });
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Bank Details linked successfully!')),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error linking bank: $e')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A3AFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Link Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view earnings.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final kycCompleted = userData['kycCompleted'] ?? false;
          final bankDetailsCompleted = userData['bankDetailsCompleted'] ?? false;
          final tasksCompleted = kycCompleted && bankDetailsCompleted;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('referrals')
                .where('referrer_id', isEqualTo: user!.uid)
                .snapshots(),
            builder: (context, referralSnapshot) {
              int totalEarnings = 0;
              int pendingEarnings = 0;
              List<Map<String, dynamic>> payoutList = [];

              if (referralSnapshot.hasData) {
                for (var doc in referralSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'Invited';
                  
                  // Simple logic: commissions are ₹5000 per success, pending if approved
                  if (status == 'Earned') {
                    totalEarnings += 5000;
                    payoutList.add({
                      'name': data['friend_name'] ?? 'Friend',
                      'loan_type': data['loan_type'] ?? 'Loan',
                      'amount': '₹5,000',
                      'status': 'Disbursed',
                      'color': Colors.green,
                      'timestamp': data['created_at'],
                    });
                  } else if (status == 'Approved') {
                    pendingEarnings += 5000;
                    payoutList.add({
                      'name': data['friend_name'] ?? 'Friend',
                      'loan_type': data['loan_type'] ?? 'Loan',
                      'amount': '₹5,000',
                      'status': 'Processing',
                      'color': Colors.orange,
                      'timestamp': data['created_at'],
                    });
                  }
                }
              }

              return SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      const Text(
                        'My Earnings',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1D1F)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage your profile setup and monitor referral payouts.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),

                      // Wallet Balance Gradient Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4A3AFF), Color(0xFF6C5DD3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4A3AFF).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL EARNINGS',
                              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹$totalEarnings',
                              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Received Amount', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('₹$totalEarnings', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Pending Payouts', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('₹$pendingEarnings', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Task 1: KYC Authentication Section
                      _buildTaskCard(
                        title: '1. KYC Authentication',
                        subtitle: kycCompleted 
                            ? 'PAN: ${userData['kycPan']} • Aadhaar verified${userData['kycDocUrl'] != null && userData['kycDocUrl'].toString().isNotEmpty ? ' • Document uploaded' : ''}'
                            : 'Complete identity verification to unlock commissions.',
                        icon: Icons.verified_user_outlined,
                        isDone: kycCompleted,
                        onTap: () => _showKYCBottomSheet(context, userData),
                      ),
                      const SizedBox(height: 16),

                      // Task 2: Add Bank Details Section
                      _buildTaskCard(
                        title: '2. Add Bank Account Details',
                        subtitle: bankDetailsCompleted 
                            ? '${userData['bankName']} • A/C ****${userData['bankAccountNumber'].toString().substring(userData['bankAccountNumber'].toString().length > 4 ? userData['bankAccountNumber'].toString().length - 4 : 0)}${userData['bankProofUrl'] != null && userData['bankProofUrl'].toString().isNotEmpty ? ' • Bank proof uploaded' : ''}'
                            : 'Provide banking details for direct payouts.',
                        icon: Icons.account_balance_outlined,
                        isDone: bankDetailsCompleted,
                        onTap: () => _showBankDetailsBottomSheet(context, userData),
                      ),
                      const SizedBox(height: 32),

                      // Earnings Display / Locked Earnings list
                      const Text(
                        'REFERRAL LEDGER',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                      ),
                      const SizedBox(height: 16),

                      if (!tasksCompleted) ...[
                        // Locked State UI
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.lock_outline, color: Colors.orange, size: 36),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Ledger Inactive',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please complete KYC authentication and add your Bank Account details above to activate your payout logs.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Unlocked Earnings Ledger
                        payoutList.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                alignment: Alignment.center,
                                child: Text(
                                  'No referral commission payouts generated yet.',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: payoutList.length,
                                itemBuilder: (context, index) {
                                  final payout = payoutList[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: payout['color'].withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.wallet, color: payout['color'], size: 22),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Referral Bonus - ${payout['name']}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                payout['loan_type'],
                                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              payout['amount'],
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1D1F)),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: payout['color'].withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                payout['status'],
                                                style: TextStyle(color: payout['color'], fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDone ? const Color(0xFF27AE60).withOpacity(0.2) : Colors.grey.shade200,
            width: isDone ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFF27AE60).withOpacity(0.1) : const Color(0xFF4A3AFF).withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isDone ? const Color(0xFF27AE60) : const Color(0xFF4A3AFF),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1D1F)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFF27AE60).withOpacity(0.1) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDone) ...[
                    const Icon(Icons.check, size: 14, color: Color(0xFF27AE60)),
                    const SizedBox(width: 4),
                    const Text(
                      'Approved',
                      style: TextStyle(color: Color(0xFF27AE60), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ] else ...[
                    const Text(
                      'Setup',
                      style: TextStyle(color: Color(0xFF4A3AFF), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, size: 14, color: Color(0xFF4A3AFF)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
