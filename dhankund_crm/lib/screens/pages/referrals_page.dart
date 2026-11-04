import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class ReferralsPage extends StatefulWidget {
  final VoidCallback? onNavigateToLoanPipeline;
  const ReferralsPage({super.key, this.onNavigateToLoanPipeline});

  @override
  State<ReferralsPage> createState() => _ReferralsPageState();
}

class _ReferralsPageState extends State<ReferralsPage> {
  final ApiService _firestoreService = ApiService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _referrals = [];
  List<Map<String, dynamic>> _users = [];

  double _totalDisbursed = 0;
  double _totalProcessing = 0;
  int _earnedCount = 0;
  int _approvedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    setState(() => _isLoading = true);
    try {
      final refs = await _firestoreService.fetchReferrals();
      final users = await _firestoreService.fetchKycBankUsers(); // Get users for name lookup

      double disbursed = 0;
      double processing = 0;
      int earned = 0;
      int approved = 0;

      for (var ref in refs) {
        final status = ref['status']?.toString().toLowerCase() ?? '';
        if (status == 'earned') {
          disbursed += 5000;
          earned++;
        } else if (status == 'approved') {
          processing += 5000;
          approved++;
        }
      }

      setState(() {
        _referrals = refs;
        _users = users;
        _totalDisbursed = disbursed;
        _totalProcessing = processing;
        _earnedCount = earned;
        _approvedCount = approved;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading referral ledger: $e");
      setState(() => _isLoading = false);
    }
  }

  String _getReferrerName(String? referrerId) {
    if (referrerId == null || referrerId.isEmpty) return 'Guest Referrer';
    if (referrerId.toLowerCase() == 'website') return 'Website Lead (Contact Us)';
    final user = _users.firstWhere((u) => u['uid'] == referrerId, orElse: () => {});
    if (user.isNotEmpty) {
      return '${user['name']} (${user['role'] ?? 'DSA'})';
    }
    return referrerId.substring(0, referrerId.length > 8 ? 8 : referrerId.length);
  }

  Future<void> _updateStatus(String docId, String status) async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.updateReferralStatus(docId, status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Referral payout status marked as $status!'),
          backgroundColor: status == 'Earned' ? AppTheme.emeraldGreen : (status == 'Approved' ? Colors.amber : AppTheme.textSecondary),
        ),
      );
      _loadReferralData();
    } catch (e) {
      debugPrint("Error updating referral status: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showConvertToLoanDialog(Map<String, dynamic> ref) {
    final nameController = TextEditingController(text: ref['friend_name'] ?? '');
    final mobileController = TextEditingController(text: ref['friend_mobile'] ?? '');
    final emailController = TextEditingController(text: ref['friend_email'] ?? '');
    final officialEmailController = TextEditingController();
    final panController = TextEditingController();
    final aadhaarController = TextEditingController();
    final fatherNameController = TextEditingController();
    final motherNameController = TextEditingController();
    final spouseNameController = TextEditingController();
    final currentAddressController = TextEditingController();
    final officeAddressController = TextEditingController();
    final ref1NameController = TextEditingController();
    final ref1MobileController = TextEditingController();
    final ref1AddressController = TextEditingController();
    final ref2NameController = TextEditingController();
    final ref2MobileController = TextEditingController();
    final ref2AddressController = TextEditingController();
    final loginCompanyController = TextEditingController();
    final bankExecutiveController = TextEditingController();

    const loanTypesList = [
      'Personal Loan',
      'Business Loan',
      'Home Loan',
      'Mortgage Loan',
      'Car Loan',
      'Commercial Vehicle Loan',
      'Credit Card',
      'CC/OD Limit',
    ];
    String selectedLoanType = loanTypesList.contains(ref['loan_type'])
        ? ref['loan_type']
        : 'Personal Loan';
    String occupation = 'Salaried';
    String gender = 'Male';
    String maritalStatus = 'Single';

    final amountController = TextEditingController(
      text: (ref['estimated_amount'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty
          ? (ref['estimated_amount'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '')
          : '500000',
    );
    final salaryController = TextEditingController(text: '50000');
    final turnoverController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.obsidianMedium,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.transform, color: AppTheme.royalGold),
                  SizedBox(width: 10),
                  Text(
                    'Convert Lead to Loan Pipeline (Complete Details)',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
              ),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. LOAN REQUIREMENT & INCOME DETAILS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedLoanType,
                            dropdownColor: AppTheme.obsidianMedium,
                            decoration: const InputDecoration(labelText: 'Loan Type *'),
                            items: loanTypesList.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                            onChanged: (val) => setDialogState(() => selectedLoanType = val ?? 'Personal Loan'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: amountController,
                            decoration: const InputDecoration(labelText: 'Requested Loan Amount (₹) *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: occupation,
                            dropdownColor: AppTheme.obsidianMedium,
                            decoration: const InputDecoration(labelText: 'Occupation *'),
                            items: const [
                              DropdownMenuItem(value: 'Salaried', child: Text('Salaried')),
                              DropdownMenuItem(value: 'SENP', child: Text('Self Employed Non-Professional (SENP)')),
                              DropdownMenuItem(value: 'SEP', child: Text('Self Employed Professional (SEP)')),
                            ],
                            onChanged: (val) => setDialogState(() => occupation = val ?? 'Salaried'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: selectedLoanType == 'Business Loan'
                              ? TextFormField(
                                  controller: turnoverController,
                                  decoration: const InputDecoration(labelText: 'Annual Turnover (₹)'),
                                )
                              : TextFormField(
                                  controller: salaryController,
                                  decoration: const InputDecoration(labelText: 'Monthly Income / Salary (₹)'),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '2. APPLICANT PERSONAL & KYC INFORMATION',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(labelText: 'Applicant Full Name *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: mobileController,
                            decoration: const InputDecoration(labelText: 'Mobile Number *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: panController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'PAN Card Number', hintText: 'ABCDE1234F'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: aadhaarController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Aadhaar Card Number', hintText: '12-digit Aadhaar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: fatherNameController,
                            decoration: const InputDecoration(labelText: "Father's Name"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: motherNameController,
                            decoration: const InputDecoration(labelText: "Mother's Name"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: gender,
                            dropdownColor: AppTheme.obsidianMedium,
                            decoration: const InputDecoration(labelText: 'Gender'),
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                            ],
                            onChanged: (val) => setDialogState(() => gender = val ?? 'Male'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: maritalStatus,
                            dropdownColor: AppTheme.obsidianMedium,
                            decoration: const InputDecoration(labelText: 'Marital Status'),
                            items: const [
                              DropdownMenuItem(value: 'Single', child: Text('Single')),
                              DropdownMenuItem(value: 'Married', child: Text('Married')),
                            ],
                            onChanged: (val) => setDialogState(() => maritalStatus = val ?? 'Single'),
                          ),
                        ),
                      ],
                    ),
                    if (maritalStatus == 'Married') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: spouseNameController,
                        decoration: const InputDecoration(labelText: 'Spouse Name'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(labelText: 'Personal Email Address'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: officialEmailController,
                            decoration: const InputDecoration(labelText: 'Official Email Address'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '3. ADDRESS, REFERENCES & BANK LOGIN DETAILS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: currentAddressController,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Current Residence Address'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: officeAddressController,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Office / Business Address'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ref1NameController,
                            decoration: const InputDecoration(labelText: 'Reference 1 Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: ref1MobileController,
                            decoration: const InputDecoration(labelText: 'Reference 1 Mobile'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: ref1AddressController,
                            decoration: const InputDecoration(labelText: 'Reference 1 Address'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ref2NameController,
                            decoration: const InputDecoration(labelText: 'Reference 2 Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: ref2MobileController,
                            decoration: const InputDecoration(labelText: 'Reference 2 Mobile'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: ref2AddressController,
                            decoration: const InputDecoration(labelText: 'Reference 2 Address'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: loginCompanyController,
                            decoration: const InputDecoration(labelText: 'Login Bank / NBFC Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: bankExecutiveController,
                            decoration: const InputDecoration(labelText: 'Bank Executive Name'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _firestoreService.convertReferralToLoan(ref['id'].toString(), {
                    'full_name': nameController.text.trim(),
                    'mobile_number': mobileController.text.trim(),
                    'email': emailController.text.trim(),
                    'personal_email': emailController.text.trim(),
                    'official_email': officialEmailController.text.trim(),
                    'loan_type': selectedLoanType,
                    'loan_amount': amountController.text.trim(),
                    'salary': salaryController.text.trim(),
                    'turnover': turnoverController.text.trim(),
                    'occupation': occupation,
                    'gender': gender,
                    'marital_status': maritalStatus,
                    'spouse_name': spouseNameController.text.trim(),
                    'pan_number': panController.text.trim(),
                    'aadhaar_number': aadhaarController.text.trim(),
                    'father_name': fatherNameController.text.trim(),
                    'mother_name': motherNameController.text.trim(),
                    'current_address': currentAddressController.text.trim(),
                    'office_address': officeAddressController.text.trim(),
                    'ref1_name': ref1NameController.text.trim(),
                    'ref1_mobile': ref1MobileController.text.trim(),
                    'ref1_address': ref1AddressController.text.trim(),
                    'ref2_name': ref2NameController.text.trim(),
                    'ref2_mobile': ref2MobileController.text.trim(),
                    'ref2_address': ref2AddressController.text.trim(),
                    'login_company_name': loginCompanyController.text.trim(),
                    'bank_executive_name': bankExecutiveController.text.trim(),
                  });
                  await _loadReferralData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Lead converted to Loan Pipeline with complete details!'),
                        backgroundColor: AppTheme.emeraldGreen,
                        action: widget.onNavigateToLoanPipeline != null
                            ? SnackBarAction(
                                label: 'Open Loan Pipeline',
                                textColor: Colors.white,
                                onPressed: () => widget.onNavigateToLoanPipeline!(),
                              )
                            : null,
                      ),
                    );
                    if (widget.onNavigateToLoanPipeline != null) {
                      widget.onNavigateToLoanPipeline!();
                    }
                  }
                } catch (e) {
                  setState(() => _isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Conversion error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check_circle_outline, size: 16),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
              label: const Text('Save & Move to Loan Pipeline'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'earned':
        return AppTheme.emeraldGreen;
      case 'approved':
        return Colors.amber;
      case 'invited':
      default:
        return AppTheme.textSecondary;
    }
  }

  void _showAddLeadDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final emailController = TextEditingController();
    final amountController = TextEditingController();
    
    String referrerId = 'admin';
    String relationship = 'Friend';
    String loanType = 'Personal Loan';
    String initialStatus = 'Invited';
    bool consentGiven = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Dropdown items for Referrers
            final List<DropdownMenuItem<String>> referrerItems = [
              const DropdownMenuItem(value: 'admin', child: Text('Admin Referral (Attributed to Admin)')),
              ..._users.map((u) {
                final name = u['name'] ?? 'Unknown User';
                final role = u['role'] ?? 'DSA';
                final uid = u['uid'] ?? '';
                return DropdownMenuItem(
                  value: uid,
                  child: Text('$name ($role)'),
                );
              }),
            ];

            return AlertDialog(
              backgroundColor: AppTheme.obsidianMedium,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Lead / Referral',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Referrer (To attribute slab-based commission payouts)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.goldAccent),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
  isExpanded: true,
                          value: referrerId,
                          dropdownColor: AppTheme.obsidianMedium,
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                          items: referrerItems,
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                referrerId = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Lead Candidate Full Name *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: mobileController,
                                decoration: const InputDecoration(labelText: 'Mobile Number *'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: emailController,
                                decoration: const InputDecoration(labelText: 'Email Address'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
  isExpanded: true,
                                value: relationship,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(labelText: 'Relationship'),
                                items: ['Friend', 'Relative', 'Client', 'Professional', 'Colleague', 'Other'].map((r) {
                                  return DropdownMenuItem(value: r, child: Text(r));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      relationship = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
  isExpanded: true,
                                value: loanType,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(labelText: 'Target Loan Type'),
                                items: ['Personal Loan', 'Business Loan', 'Home Loan', 'Car Loan', 'Gold Loan', 'Project Loan'].map((l) {
                                  return DropdownMenuItem(value: l, child: Text(l));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      loanType = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: amountController,
                                decoration: const InputDecoration(labelText: 'Estimated Amount (₹)'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
  isExpanded: true,
                                value: initialStatus,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(labelText: 'Initial Payout Status'),
                                items: ['Invited', 'Approved', 'Earned'].map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      initialStatus = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        CheckboxListTile(
                          title: const Text(
                            'Consent of candidate received to register and process loan application',
                            style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          ),
                          value: consentGiven,
                          activeColor: AppTheme.royalGold,
                          checkColor: AppTheme.obsidianDark,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                consentGiven = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    
                    Navigator.of(context).pop();
                    setState(() => _isLoading = true);
                    
                    try {
                      await _firestoreService.createReferral(
                        referrerId: referrerId,
                        friendName: nameController.text.trim(),
                        friendMobile: mobileController.text.trim(),
                        friendEmail: emailController.text.trim(),
                        relationship: relationship,
                        loanType: loanType,
                        estimatedAmount: amountController.text.trim(),
                        consentGiven: consentGiven,
                        status: initialStatus,
                      );
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lead referral registered successfully!'),
                          backgroundColor: AppTheme.emeraldGreen,
                        ),
                      );
                      
                      _loadReferralData();
                    } catch (e) {
                      debugPrint('Error saving lead: $e');
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to save lead referral details.'),
                          backgroundColor: AppTheme.rubyRed,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Lead'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Partner Referral & Commission Ledger'),
        actions: [
          ElevatedButton.icon(
            onPressed: _showAddLeadDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Lead'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalGold,
              foregroundColor: AppTheme.obsidianDark,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReferralData,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Wallet Ledger Overview
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: 16.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DISBURSED COMMISSION', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('₹', style: TextStyle(fontSize: 20, color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Text(
                              _totalDisbursed.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Paid out to $_earnedCount referrals', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassCard(
                    padding: 16.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PROCESSING COMMISSION', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('₹', style: TextStyle(fontSize: 20, color: Colors.amber, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Text(
                              _totalProcessing.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Under processing for $_approvedCount referrals', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassCard(
                    padding: 16.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('COMMISSION STRUCTURE RULE', style: TextStyle(fontSize: 10, color: AppTheme.royalGold, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'Variable Payout Slab',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.royalGold),
                        ),
                        const SizedBox(height: 4),
                        const Text('Earned (Disbursed) & Approved (Processing)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Referrals List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
                : _referrals.isEmpty
                    ? const Center(child: Text('No referral submissions found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _referrals.length,
                        itemBuilder: (context, index) {
                          final ref = _referrals[index];
                          final status = ref['status']?.toString() ?? 'Invited';
                          final statusColor = _getStatusColor(status);
                          final referrerName = _getReferrerName(ref['referrer_id']);
                          
                          // Wallet reward amount based on loan amount slab
                          double loanAmount = double.tryParse(ref['estimated_amount']?.toString() ?? '0') ?? 0;
                          double calculatePayout(double amount) {
                            if (amount >= 10000001) return amount * 0.0050; // 0.50%
                            if (amount >= 5000001) return amount * 0.0045; // 0.45%
                            if (amount >= 2000001) return amount * 0.0040; // 0.40%
                            if (amount >= 1000001) return amount * 0.0035; // 0.35%
                            if (amount >= 1) return amount * 0.0030; // 0.30%
                            return 0;
                          }
                          double calculatedReward = calculatePayout(loanAmount);
                          
                          double payoutReward = 0;
                          String payoutState = 'No Payout';
                          if (status.toLowerCase() == 'earned') {
                            payoutReward = calculatedReward;
                            payoutState = 'Disbursed';
                          } else if (status.toLowerCase() == 'approved') {
                            payoutReward = calculatedReward;
                            payoutState = 'Processing';
                          }

                          return Card(
                            color: AppTheme.obsidianMedium,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              ref['friend_name'] ?? 'Friend Name',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                            ),
                                            const SizedBox(width: 8),
                                            if (ref['relationship'] == 'Website Contact Form' || ref['loan_type'] == 'Website Lead' || ref['referrer_id'] == 'website') ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.emeraldGreen.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: AppTheme.emeraldGreen.withOpacity(0.5)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.language, size: 12, color: AppTheme.emeraldGreen),
                                                    SizedBox(width: 4),
                                                    Text('Website Lead', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                ref['relationship'] ?? 'Relationship',
                                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if ((ref['lead_id'] ?? '').toString().isNotEmpty) ...[
                                          Text(
                                            'Lead ID: ${ref['lead_id']}',
                                            style: const TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        if ((ref['created_at'] ?? '').toString().isNotEmpty) ...[
                                          Text(
                                            'Referred: ${ref['created_at'].toString().replaceFirst('T', ' ').split('.').first}',
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text('Candidate: ${ref['friend_email'] ?? 'N/A'} | ${ref['friend_mobile'] ?? 'N/A'}'),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Referrer: $referrerName',
                                          style: const TextStyle(color: AppTheme.goldAccent, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('LOAN TARGET', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 2),
                                        Text(ref['loan_type'] ?? 'Personal Loan', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text('Est. ₹${ref['estimated_amount'] ?? '0'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          payoutReward > 0 ? '+₹ ${payoutReward.toStringAsFixed(0)}' : '₹ 0',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: payoutReward > 0 ? AppTheme.emeraldGreen : AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(payoutState, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: status.toLowerCase() == 'converted to pipeline' ? null : () => _showConvertToLoanDialog(ref),
                                    icon: const Icon(Icons.trending_up, size: 14),
                                    label: Text(status.toLowerCase() == 'converted to pipeline' ? 'In Pipeline' : 'Convert Lead to Loan Pipeline', style: const TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: status.toLowerCase() == 'converted to pipeline' ? Colors.grey.shade700 : AppTheme.royalGold,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  DropdownButton<String>(
                                    value: ['invited', 'approved', 'earned', 'converted to pipeline'].contains(status.toLowerCase()) ? status : 'Invited',
                                    dropdownColor: AppTheme.obsidianMedium,
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                    underline: Container(),
                                    items: const [
                                      DropdownMenuItem(value: 'Invited', child: Text('Invited')),
                                      DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                                      DropdownMenuItem(value: 'Earned', child: Text('Earned')),
                                      DropdownMenuItem(value: 'Converted to Pipeline', child: Text('Converted to Pipeline')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null && val != status) {
                                        _updateStatus(ref['id'], val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
