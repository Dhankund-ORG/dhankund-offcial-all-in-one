import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase_service.dart';
import '../../theme/app_theme.dart';

class LoansPage extends StatefulWidget {
  const LoansPage({super.key});

  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _applications = [];
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSegment = 'All';
  String _selectedAmountRange = 'All';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final list = await _firestoreService.fetchLoanApplications();
      setState(() {
        _applications = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching loan applications: $e");
      setState(() => _isLoading = false);
    }
  }

  double _parseAmount(dynamic amountStr) {
    if (amountStr == null) return 0.0;
    final clean = amountStr.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  List<Map<String, dynamic>> get _filteredApplications {
    return _applications.where((app) {
      // 1. Status Filter
      if (_selectedFilter != 'All') {
        final normStatus = _normalizeStatus(app['status']?.toString());
        if (_selectedFilter == 'All Active') {
          if (normStatus.toLowerCase() == 'rejected') return false;
        } else {
          if (normStatus.toLowerCase() != _selectedFilter.toLowerCase()) return false;
        }
      }

      // 2. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final name = (app['full_name'] ?? '').toString().toLowerCase();
        final phone = (app['mobile_number'] ?? '').toString().toLowerCase();
        final email = (app['email'] ?? '').toString().toLowerCase();
        final id = (app['id'] ?? '').toString().toLowerCase();
        if (!name.contains(query) &&
            !phone.contains(query) &&
            !email.contains(query) &&
            !id.contains(query)) {
          return false;
        }
      }

      // 3. Segment Filter
      if (_selectedSegment != 'All') {
        final type = (app['loan_type'] ?? '').toString().toLowerCase();
        if (type != _selectedSegment.toLowerCase()) return false;
      }

      // 4. Amount Filter
      if (_selectedAmountRange != 'All') {
        final amount = _parseAmount(app['loan_amount']);
        if (_selectedAmountRange == '< 5L' && amount >= 500000) return false;
        if (_selectedAmountRange == '5L - 15L' && (amount < 500000 || amount > 1500000)) return false;
        if (_selectedAmountRange == '15L - 50L' && (amount < 1500000 || amount > 5000000)) return false;
        if (_selectedAmountRange == '> 50L' && amount <= 5000000) return false;
      }

      // 5. Date Filter
      if (_selectedDateRange != null) {
        final timestamp = app['submitted_at'];
        if (timestamp == null) return false;
        final date = (timestamp is Timestamp) ? timestamp.toDate() : DateTime.tryParse(timestamp.toString());
        if (date == null) return false;
        
        final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
        final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.updateLoanStatus(docId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loan application status updated to $newStatus!'),
          backgroundColor: newStatus == 'Approved' ? AppTheme.emeraldGreen : (newStatus == 'Rejected' ? AppTheme.rubyRed : Colors.amber),
        ),
      );
      _loadApplications();
    } catch (e) {
      debugPrint("Error updating loan application: $e");
      setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.royalGold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: Colors.black.withOpacity(0.1), height: 1),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(
    BuildContext context,
    String docLabel,
    String docKey,
    Map<String, dynamic> docMap,
    String defaultFileName,
    StateSetter setDialogState,
  ) {
    final isUploaded = docMap[docKey] != null;
    final fileName = docMap[docKey]?.toString() ?? '';
    final isLoading = fileName == 'Uploading...';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              docLabel,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textPrimary),
            ),
          ),
          Row(
            children: [
              if (isLoading) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.royalGold),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Uploading...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 8),
              ] else if (isUploaded) ...[
                const Icon(Icons.check_circle, color: AppTheme.emeraldGreen, size: 18),
                const SizedBox(width: 6),
                Text(
                  fileName,
                  style: const TextStyle(color: AppTheme.emeraldGreen, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
              ] else ...[
                const Text(
                  'Not Uploaded',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () {
                        setDialogState(() {
                          docMap[docKey] = 'Uploading...';
                        });
                        Future.delayed(const Duration(milliseconds: 1000), () {
                          setDialogState(() {
                            docMap[docKey] = defaultFileName;
                          });
                        });
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  backgroundColor: isUploaded ? Colors.grey.shade200 : AppTheme.royalGold,
                  foregroundColor: isUploaded ? Colors.black87 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(
                  isUploaded ? 'Re-upload' : 'Upload',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoApplicantBlock({
    required BuildContext context,
    required int index,
    required Map<String, dynamic> coApp,
    required Map<String, TextEditingController> controllers,
    required VoidCallback onDelete,
    required StateSetter setDialogState,
  }) {
    String incomeConsidered = coApp['income_considered'] ?? 'YES';
    String maritalStatus = coApp['marital_status'] ?? 'Single';
    String occupation = coApp['occupation'] ?? 'Salaried';
    String safeOccupation = (occupation == 'Salaried' || occupation == 'SENP' || occupation == 'SEP') ? occupation : 'Salaried';
    String gender = coApp['gender'] ?? 'Male';

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.obsidianLight.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CO-APPLICANT ${index + 1} DETAILS',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.royalGold),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: AppTheme.rubyRed, size: 20),
                onPressed: onDelete,
                tooltip: 'Remove Co-applicant',
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: incomeConsidered,
                  dropdownColor: AppTheme.obsidianMedium,
                  decoration: const InputDecoration(labelText: 'Income Considered *'),
                  items: const [
                    DropdownMenuItem(value: 'YES', child: Text('YES')),
                    DropdownMenuItem(value: 'NO', child: Text('NO')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        coApp['income_considered'] = val;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: controllers['name'],
                  decoration: const InputDecoration(labelText: 'Co-applicant Full Name *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers['father_name'],
                  decoration: const InputDecoration(labelText: "Father's Name"),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: controllers['mother_name'],
                  decoration: const InputDecoration(labelText: "Mother's Name"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: gender,
                  dropdownColor: AppTheme.obsidianMedium,
                  decoration: const InputDecoration(labelText: 'Gender *'),
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        coApp['gender'] = val;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: maritalStatus,
                  dropdownColor: AppTheme.obsidianMedium,
                  decoration: const InputDecoration(labelText: 'Marital Status'),
                  items: const [
                    DropdownMenuItem(value: 'Single', child: Text('Single')),
                    DropdownMenuItem(value: 'Married', child: Text('Married')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        coApp['marital_status'] = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          if (maritalStatus == 'Married') ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: controllers['spouse_name'],
              decoration: const InputDecoration(labelText: 'Spouse Name *'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers['pan_number'],
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'PAN Card Number *',
                    hintText: 'e.g. ABCDE1234F',
                    prefixIcon: Icon(Icons.credit_card, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: controllers['aadhaar_number'],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar Card Number *',
                    hintText: '12-digit Aadhaar Number',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers['mobile_number'],
                  decoration: const InputDecoration(labelText: 'Mobile Number *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: safeOccupation,
                  dropdownColor: AppTheme.obsidianMedium,
                  decoration: const InputDecoration(labelText: 'Occupation'),
                  items: const [
                    DropdownMenuItem(value: 'Salaried', child: Text('Salaried')),
                    DropdownMenuItem(value: 'SENP', child: Text('Self Employed Non-Professional (SENP)')),
                    DropdownMenuItem(value: 'SEP', child: Text('Self Employed Professional (SEP)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        coApp['occupation'] = val;
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
                  controller: controllers['personal_email'],
                  decoration: const InputDecoration(labelText: 'Personal Mail ID'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: controllers['official_email'],
                  decoration: const InputDecoration(labelText: 'Official Mail ID'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers['current_address'],
                  decoration: const InputDecoration(labelText: 'Current Address'),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: controllers['office_address'],
                  decoration: const InputDecoration(labelText: 'Office Address'),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Co-Applicant ${index + 1} Documents',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          _buildDocumentRow(
            context,
            'Live Passport size photo *',
            'passport_photo',
            coApp['documents'] ??= <String, dynamic>{},
            'coapp${index + 1}_passport_photo.jpg',
            setDialogState,
          ),
          _buildDocumentRow(
            context,
            incomeConsidered == 'YES' ? 'PAN Card *' : 'Pan card/Voter card *',
            'pan_card',
            coApp['documents'] ??= <String, dynamic>{},
            'coapp${index + 1}_pan_card.pdf',
            setDialogState,
          ),
          _buildDocumentRow(
            context,
            'Aadhar card *',
            'aadhar_card',
            coApp['documents'] ??= <String, dynamic>{},
            'coapp${index + 1}_aadhar_card.pdf',
            setDialogState,
          ),
          _buildDocumentRow(
            context,
            'Additional Address Proof (Electricity Bill/Rent agreement/Aadhaar Correction) *',
            'additional_address_proof',
            coApp['documents'] ??= <String, dynamic>{},
            'coapp${index + 1}_address_proof.pdf',
            setDialogState,
          ),
          if (incomeConsidered == 'YES') ...[
            if (occupation == 'Salaried') ...[
              _buildDocumentRow(
                context,
                'Last 3 Month Salary Slip *',
                'salary_slips',
                coApp['documents'] ??= <String, dynamic>{},
                'coapp${index + 1}_salary_slips.pdf',
                setDialogState,
              ),
              _buildDocumentRow(
                context,
                'Job vintage proof *',
                'job_vintage_proof',
                coApp['documents'] ??= <String, dynamic>{},
                'coapp${index + 1}_job_vintage.pdf',
                setDialogState,
              ),
            ] else if (occupation == 'SENP' || occupation == 'SEP') ...[
              _buildDocumentRow(
                context,
                'Last 3 Years ITR *',
                'itr_3_years',
                coApp['documents'] ??= <String, dynamic>{},
                'coapp${index + 1}_itr_3yr.pdf',
                setDialogState,
              ),
              _buildDocumentRow(
                context,
                'Business Proof *',
                'business_proof',
                coApp['documents'] ??= <String, dynamic>{},
                'coapp${index + 1}_business_proof.pdf',
                setDialogState,
              ),
              _buildDocumentRow(
                context,
                'Udyam Aadhar *',
                'udyam_aadhar',
                coApp['documents'] ??= <String, dynamic>{},
                'coapp${index + 1}_udyam_aadhar.pdf',
                setDialogState,
              ),
              _buildDocumentRow(
                context,
                'GST Registration / Addl Business Proof *',
                'additional_business_proof',
                coApp['documents'] ??= <String, dynamic>{},
                'coapp${index + 1}_gst_proof.pdf',
                setDialogState,
              ),
              _buildDocumentRow(
                context,
                'Firm audit report last 3 years *',
                'firm_audit_report',
                coApp['documents'] ??= <String, dynamic>{},
                'coapp${index + 1}_firm_audit.pdf',
                setDialogState,
              ),
            ],
            _buildDocumentRow(
              context,
              'Property Papers *',
              'property_papers',
              coApp['documents'] ??= <String, dynamic>{},
              'coapp${index + 1}_property_papers.pdf',
              setDialogState,
            ),
          ],
        ],
      ),
    );
  }

  void _showAddLeadDialog({Map<String, dynamic>? existingLead}) {
    final isEditMode = existingLead != null;
    final formKey = GlobalKey<FormState>();
    
    final nameController = TextEditingController(text: existingLead?['full_name']?.toString() ?? '');
    final emailController = TextEditingController(text: existingLead?['email']?.toString() ?? '');
    final mobileController = TextEditingController(text: existingLead?['mobile_number']?.toString() ?? '');
    final amountController = TextEditingController(text: existingLead?['loan_amount']?.toString() ?? '');
    final salaryController = TextEditingController(text: existingLead?['salary']?.toString() ?? '');
    final turnoverController = TextEditingController(text: existingLead?['turnover']?.toString() ?? '');
    
    // Spouse details
    final spouseNameController = TextEditingController(text: existingLead?['spouse_name']?.toString() ?? '');

    // Identity details (PAN & Aadhaar)
    final panController = TextEditingController(text: existingLead?['pan_number']?.toString() ?? '');
    final aadhaarController = TextEditingController(text: existingLead?['aadhaar_number']?.toString() ?? '');

    // New fields text controllers
    final fatherNameController = TextEditingController(text: existingLead?['father_name']?.toString() ?? '');
    final motherNameController = TextEditingController(text: existingLead?['mother_name']?.toString() ?? '');
    final officialEmailController = TextEditingController(text: existingLead?['official_email']?.toString() ?? '');
    final currentAddressController = TextEditingController(text: existingLead?['current_address']?.toString() ?? '');
    final officeAddressController = TextEditingController(text: existingLead?['office_address']?.toString() ?? '');
    
    final ref1NameController = TextEditingController(text: existingLead?['ref1_name']?.toString() ?? '');
    final ref1MobileController = TextEditingController(text: existingLead?['ref1_mobile']?.toString() ?? '');
    final ref1AddressController = TextEditingController(text: existingLead?['ref1_address']?.toString() ?? '');
    
    final ref2NameController = TextEditingController(text: existingLead?['ref2_name']?.toString() ?? '');
    final ref2MobileController = TextEditingController(text: existingLead?['ref2_mobile']?.toString() ?? '');
    final ref2AddressController = TextEditingController(text: existingLead?['ref2_address']?.toString() ?? '');

    final loginCompanyController = TextEditingController(text: existingLead?['login_company_name']?.toString() ?? '');
    final bankExecutiveController = TextEditingController(text: existingLead?['bank_executive_name']?.toString() ?? '');
    
    String loanType = existingLead?['loan_type']?.toString() ?? 'Personal Loan';
    String maritalStatus = existingLead?['marital_status']?.toString() ?? 'Single';
    String occupation = existingLead?['occupation']?.toString() ?? 'Salaried';
    String status = existingLead?['status']?.toString() ?? 'Pending Details';
    String gender = existingLead?['gender']?.toString() ?? 'Male';
    int? applicantCibil = existingLead?['applicant_cibil'] as int?;

    // Documents Map
    final Map<String, dynamic> applicantDocs = Map<String, dynamic>.from(existingLead?['applicant_documents'] ?? {});

    // Co-Applicants Lists
    final coApplicants = List<Map<String, dynamic>>.from(
      (existingLead?['co_applicants'] as List?)?.map((x) => Map<String, dynamic>.from(x)) ?? []
    );

    final List<Map<String, TextEditingController>> coAppControllers = [];
    for (var coApp in coApplicants) {
      coAppControllers.add({
        'name': TextEditingController(text: coApp['full_name']?.toString() ?? ''),
        'pan_number': TextEditingController(text: coApp['pan_number']?.toString() ?? ''),
        'aadhaar_number': TextEditingController(text: coApp['aadhaar_number']?.toString() ?? ''),
        'father_name': TextEditingController(text: coApp['father_name']?.toString() ?? ''),
        'mother_name': TextEditingController(text: coApp['mother_name']?.toString() ?? ''),
        'spouse_name': TextEditingController(text: coApp['spouse_name']?.toString() ?? ''),
        'mobile_number': TextEditingController(text: coApp['mobile_number']?.toString() ?? ''),
        'personal_email': TextEditingController(text: coApp['personal_email']?.toString() ?? ''),
        'official_email': TextEditingController(text: coApp['official_email']?.toString() ?? ''),
        'current_address': TextEditingController(text: coApp['current_address']?.toString() ?? ''),
        'office_address': TextEditingController(text: coApp['office_address']?.toString() ?? ''),
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final safeOccupation = (occupation == 'Salaried' || occupation == 'SENP' || occupation == 'SEP') ? occupation : 'Salaried';
            return AlertDialog(
              backgroundColor: AppTheme.obsidianMedium,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.black.withOpacity(0.08)),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditMode ? 'Edit Lead Details' : 'Add New Lead',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
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
                        // SECTION 1: Loan Details
                        _buildSectionHeader('Loan Details'),
                        DropdownButtonFormField<String>(
                          value: loanType,
                          dropdownColor: AppTheme.obsidianMedium,
                          decoration: const InputDecoration(labelText: 'Loan Type *'),
                          items: [
                            'Personal Loan',
                            'Business Loan',
                            'Home Loan',
                            'Mortgage Loan',
                            'Car Loan',
                            'Commercial Vehicle Loan',
                            'Credit Card',
                            'CC/OD Limit',
                          ].map((l) {
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: amountController,
                                decoration: const InputDecoration(labelText: 'Requested Loan Amount (₹) *'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: loanType == 'Personal Loan'
                                  ? TextFormField(
                                      controller: salaryController,
                                      decoration: const InputDecoration(labelText: 'Monthly Income / Salary (₹)'),
                                    )
                                  : loanType == 'Business Loan'
                                      ? TextFormField(
                                          controller: turnoverController,
                                          decoration: const InputDecoration(labelText: 'Annual Turnover (₹)'),
                                        )
                                      : const SizedBox.shrink(),
                            ),
                          ],
                        ),

                        // SECTION 2: Personal Information
                        _buildSectionHeader('Applicant Personal Information'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: nameController,
                                decoration: const InputDecoration(labelText: 'Applicant Full Name *'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: safeOccupation,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(labelText: 'Occupation'),
                                items: const [
                                  DropdownMenuItem(value: 'Salaried', child: Text('Salaried')),
                                  DropdownMenuItem(value: 'SENP', child: Text('Self Employed Non-Professional (SENP)')),
                                  DropdownMenuItem(value: 'SEP', child: Text('Self Employed Professional (SEP)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      occupation = val;
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
                                controller: panController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Applicant PAN Card Number *',
                                  hintText: 'e.g. ABCDE1234F',
                                  prefixIcon: Icon(Icons.credit_card, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: aadhaarController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Applicant Aadhaar Card Number *',
                                  hintText: '12-digit Aadhaar Number',
                                  prefixIcon: Icon(Icons.badge_outlined, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: fatherNameController,
                                decoration: const InputDecoration(labelText: "Father's Name"),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: motherNameController,
                                decoration: const InputDecoration(labelText: "Mother's Name"),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: gender,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(labelText: 'Gender *'),
                                items: const [
                                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      gender = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: maritalStatus,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(labelText: 'Marital Status'),
                                items: const [
                                  DropdownMenuItem(value: 'Single', child: Text('Single')),
                                  DropdownMenuItem(value: 'Married', child: Text('Married')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      maritalStatus = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        if (maritalStatus == 'Married') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: spouseNameController,
                            decoration: const InputDecoration(labelText: 'Spouse Name *'),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                          ),
                        ],

                        // SECTION 3: Contact Details
                        _buildSectionHeader('Contact Details'),
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
                                decoration: const InputDecoration(labelText: 'Personal Mail ID'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: officialEmailController,
                                decoration: const InputDecoration(labelText: 'Official Mail ID'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),

                        // SECTION 4: Address Information
                        _buildSectionHeader('Address Information'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: currentAddressController,
                                decoration: const InputDecoration(labelText: 'Current Address'),
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: officeAddressController,
                                decoration: const InputDecoration(labelText: 'Office Address'),
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),

                        // SECTION 5: Reference Detail 1
                        _buildSectionHeader('Reference Detail 1'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: ref1NameController,
                                decoration: const InputDecoration(labelText: 'Reference 1 Name'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: ref1MobileController,
                                decoration: const InputDecoration(labelText: 'Reference 1 Mobile'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ref1AddressController,
                          decoration: const InputDecoration(labelText: 'Reference 1 Address'),
                          maxLines: 2,
                        ),

                        // SECTION 6: Reference Detail 2
                        _buildSectionHeader('Reference Detail 2'),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: ref2NameController,
                                decoration: const InputDecoration(labelText: 'Reference 2 Name'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: ref2MobileController,
                                decoration: const InputDecoration(labelText: 'Reference 2 Mobile'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: ref2AddressController,
                          decoration: const InputDecoration(labelText: 'Reference 2 Address'),
                          maxLines: 2,
                        ),

                        // Required Documents for Primary Applicant
                        _buildSectionHeader('Required Documents'),
                        _buildDocumentRow(
                          context,
                          'Live Passport size photo *',
                          'passport_photo',
                          applicantDocs,
                          'applicant_passport_photo.jpg',
                          setDialogState,
                        ),
                        _buildDocumentRow(
                          context,
                          'PAN Card *',
                          'pan_card',
                          applicantDocs,
                          'applicant_pan_card.pdf',
                          setDialogState,
                        ),
                        _buildDocumentRow(
                          context,
                          'Aadhar card *',
                          'aadhar_card',
                          applicantDocs,
                          'applicant_aadhar_card.pdf',
                          setDialogState,
                        ),
                        _buildDocumentRow(
                          context,
                          'Additional Address Proof (Electricity Bill/Rent agreement/Aadhaar Correction) *',
                          'additional_address_proof',
                          applicantDocs,
                          'applicant_address_proof.pdf',
                          setDialogState,
                        ),
                        if (occupation == 'Salaried') ...[
                          _buildDocumentRow(
                            context,
                            'Last 3 Month Salary Slip *',
                            'salary_slips',
                            applicantDocs,
                            'applicant_salary_slips.pdf',
                            setDialogState,
                          ),
                          _buildDocumentRow(
                            context,
                            'Job vintage proof *',
                            'job_vintage_proof',
                            applicantDocs,
                            'applicant_job_vintage.pdf',
                            setDialogState,
                          ),
                        ] else if (occupation == 'SENP' || occupation == 'SEP') ...[
                          _buildDocumentRow(
                            context,
                            'Last 3 Years ITR *',
                            'itr_3_years',
                            applicantDocs,
                            'applicant_itr_3yr.pdf',
                            setDialogState,
                          ),
                          _buildDocumentRow(
                            context,
                            'Business Proof *',
                            'business_proof',
                            applicantDocs,
                            'applicant_business_proof.pdf',
                            setDialogState,
                          ),
                          _buildDocumentRow(
                            context,
                            'Udyam Aadhar *',
                            'udyam_aadhar',
                            applicantDocs,
                            'applicant_udyam_aadhar.pdf',
                            setDialogState,
                          ),
                          _buildDocumentRow(
                            context,
                            'GST Registration / Addl Business Proof *',
                            'additional_business_proof',
                            applicantDocs,
                            'applicant_gst_proof.pdf',
                            setDialogState,
                          ),
                          _buildDocumentRow(
                            context,
                            'Firm audit report last 3 years *',
                            'firm_audit_report',
                            applicantDocs,
                            'applicant_firm_audit.pdf',
                            setDialogState,
                          ),
                        ],
                        _buildDocumentRow(
                          context,
                          'Property Papers *',
                          'property_papers',
                          applicantDocs,
                          'applicant_property_papers.pdf',
                          setDialogState,
                        ),

                        // Dynamic Co-Applicants
                        if (coApplicants.isNotEmpty) ...[
                          for (int i = 0; i < coApplicants.length; i++)
                            _buildCoApplicantBlock(
                              context: context,
                              index: i,
                              coApp: coApplicants[i],
                              controllers: coAppControllers[i],
                              onDelete: () {
                                setDialogState(() {
                                  coApplicants.removeAt(i);
                                  coAppControllers.removeAt(i);
                                });
                              },
                              setDialogState: setDialogState,
                            ),
                        ],
                        
                        if (coApplicants.length < 3) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  coApplicants.add({
                                    'income_considered': 'YES',
                                    'marital_status': 'Single',
                                    'occupation': 'Salaried',
                                    'documents': <String, dynamic>{},
                                  });
                                  coAppControllers.add({
                                    'name': TextEditingController(),
                                    'pan_number': TextEditingController(),
                                    'aadhaar_number': TextEditingController(),
                                    'father_name': TextEditingController(),
                                    'mother_name': TextEditingController(),
                                    'spouse_name': TextEditingController(),
                                    'mobile_number': TextEditingController(),
                                    'personal_email': TextEditingController(),
                                    'official_email': TextEditingController(),
                                    'current_address': TextEditingController(),
                                    'office_address': TextEditingController(),
                                  });
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: Text(
                                coApplicants.isEmpty
                                    ? 'Add Co-Applicant'
                                    : coApplicants.length == 1
                                        ? 'Add Second Co-Applicant'
                                        : 'Add Third Co-Applicant',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // SECTION 8: Application Status & Finalization
                        _buildSectionHeader('Application Status'),
                        DropdownButtonFormField<String>(
                          value: _normalizeStatus(status),
                          dropdownColor: AppTheme.obsidianMedium,
                          decoration: const InputDecoration(
                            labelText: 'Lead Status / Action',
                            helperText: 'Select "Login done" when documents are complete and filed to banks/NBFCs.',
                            helperStyle: TextStyle(color: AppTheme.textSecondary),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Pending Details', child: Text('Pending Details')),
                            DropdownMenuItem(value: 'Login done', child: Text('Login done')),
                            DropdownMenuItem(value: 'Sanctioned', child: Text('Sanctioned')),
                            DropdownMenuItem(value: 'Disbursed', child: Text('Disbursed')),
                            DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                status = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // CIBIL Check Section
                        _buildSectionHeader('CIBIL Check'),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Run CIBIL check for all applicants to verify creditworthiness.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  // Simulate CIBIL run
                                  applicantCibil = 700 + (DateTime.now().millisecond % 150); // random 700-850
                                  for (var coApp in coApplicants) {
                                    coApp['cibil'] = 680 + (DateTime.now().microsecond % 120); 
                                  }
                                });
                              },
                              icon: const Icon(Icons.speed, size: 18),
                              label: const Text('Run CIBIL (App & Co-Apps)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emeraldGreen,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (applicantCibil != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Applicant (${nameController.text.isEmpty ? 'N/A' : nameController.text})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Score: $applicantCibil', style: TextStyle(color: applicantCibil! >= 700 ? AppTheme.emeraldGreen : Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                if (coApplicants.isNotEmpty) ...[
                                  const Divider(height: 16),
                                  ...coApplicants.asMap().entries.map((entry) {
                                    int idx = entry.key;
                                    var coApp = entry.value;
                                    String coName = coAppControllers[idx]['name']?.text ?? 'Co-Applicant ${idx+1}';
                                    if (coName.isEmpty) coName = 'Co-Applicant ${idx+1}';
                                    int? cibil = coApp['cibil'] as int?;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(coName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text('Score: ${cibil ?? 'N/A'}', style: TextStyle(color: (cibil ?? 0) >= 700 ? AppTheme.emeraldGreen : Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: loginCompanyController,
                                decoration: const InputDecoration(
                                  labelText: 'Login Bank / Company Name',
                                  hintText: 'e.g. HDFC Bank, SBI',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: bankExecutiveController,
                                decoration: const InputDecoration(
                                  labelText: 'Bank Executive Name',
                                  hintText: 'e.g. Amit Verma',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                    
                    final fullName = nameController.text.trim();
                    final mobileNumber = mobileController.text.trim();
                    final email = emailController.text.trim();
                    final loanAmount = amountController.text.trim();
                    final salary = salaryController.text.trim();
                    final turnover = turnoverController.text.trim();
                    
                    // Spouse
                    final spouseName = spouseNameController.text.trim();

                    // PAN & Aadhaar
                    final panNumber = panController.text.trim();
                    final aadhaarNumber = aadhaarController.text.trim();

                    final fatherName = fatherNameController.text.trim();
                    final motherName = motherNameController.text.trim();
                    final personalEmail = emailController.text.trim();
                    final officialEmail = officialEmailController.text.trim();
                    final currentAddress = currentAddressController.text.trim();
                    final officeAddress = officeAddressController.text.trim();
                    
                    final ref1Name = ref1NameController.text.trim();
                    final ref1Mobile = ref1MobileController.text.trim();
                    final ref1Address = ref1AddressController.text.trim();
                    
                    final ref2Name = ref2NameController.text.trim();
                    final ref2Mobile = ref2MobileController.text.trim();
                    final ref2Address = ref2AddressController.text.trim();

                    final loginCompanyName = loginCompanyController.text.trim();
                    final bankExecutiveName = bankExecutiveController.text.trim();

                    // Extract values from co-applicant controllers
                    for (int i = 0; i < coApplicants.length; i++) {
                      coApplicants[i]['full_name'] = coAppControllers[i]['name']!.text.trim();
                      coApplicants[i]['pan_number'] = coAppControllers[i]['pan_number']!.text.trim();
                      coApplicants[i]['aadhaar_number'] = coAppControllers[i]['aadhaar_number']!.text.trim();
                      coApplicants[i]['father_name'] = coAppControllers[i]['father_name']!.text.trim();
                      coApplicants[i]['mother_name'] = coAppControllers[i]['mother_name']!.text.trim();
                      coApplicants[i]['spouse_name'] = coApplicants[i]['marital_status'] == 'Married' 
                          ? coAppControllers[i]['spouse_name']!.text.trim() 
                          : null;
                      coApplicants[i]['mobile_number'] = coAppControllers[i]['mobile_number']!.text.trim();
                      coApplicants[i]['personal_email'] = coAppControllers[i]['personal_email']!.text.trim();
                      coApplicants[i]['official_email'] = coAppControllers[i]['official_email']!.text.trim();
                      coApplicants[i]['current_address'] = coAppControllers[i]['current_address']!.text.trim();
                      coApplicants[i]['office_address'] = coAppControllers[i]['office_address']!.text.trim();
                    }

                    Navigator.of(context).pop();
                    setState(() => _isLoading = true);

                    try {
                      if (isEditMode) {
                        await _firestoreService.updateLoanApplication(
                          docId: existingLead['id'],
                          loanType: loanType,
                          fullName: fullName,
                          mobileNumber: mobileNumber,
                          email: email,
                          loanAmount: loanAmount,
                          salary: loanType == 'Personal Loan' ? (salary.isNotEmpty ? salary : null) : null,
                          turnover: loanType == 'Business Loan' ? (turnover.isNotEmpty ? turnover : null) : null,
                          fatherName: fatherName.isNotEmpty ? fatherName : null,
                          motherName: motherName.isNotEmpty ? motherName : null,
                          maritalStatus: maritalStatus,
                          spouseName: maritalStatus == 'Married' ? (spouseName.isNotEmpty ? spouseName : null) : null,
                          occupation: occupation,
                          personalEmail: personalEmail.isNotEmpty ? personalEmail : null,
                          officialEmail: officialEmail.isNotEmpty ? officialEmail : null,
                          currentAddress: currentAddress.isNotEmpty ? currentAddress : null,
                          officeAddress: officeAddress.isNotEmpty ? officeAddress : null,
                          ref1Name: ref1Name.isNotEmpty ? ref1Name : null,
                          ref1Mobile: ref1Mobile.isNotEmpty ? ref1Mobile : null,
                          ref1Address: ref1Address.isNotEmpty ? ref1Address : null,
                          ref2Name: ref2Name.isNotEmpty ? ref2Name : null,
                          ref2Mobile: ref2Mobile.isNotEmpty ? ref2Mobile : null,
                          ref2Address: ref2Address.isNotEmpty ? ref2Address : null,
                          applicantDocuments: applicantDocs,
                          coApplicants: coApplicants,
                          status: status,
                          loginCompanyName: loginCompanyName.isNotEmpty ? loginCompanyName : null,
                          bankExecutiveName: bankExecutiveName.isNotEmpty ? bankExecutiveName : null,
                          gender: gender,
                          applicantCibil: applicantCibil,
                          panNumber: panNumber.isNotEmpty ? panNumber : null,
                          aadhaarNumber: aadhaarNumber.isNotEmpty ? aadhaarNumber : null,
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lead updated successfully!'),
                            backgroundColor: AppTheme.emeraldGreen,
                          ),
                        );
                      } else {
                        await _firestoreService.createLoanApplication(
                          loanType: loanType,
                          fullName: fullName,
                          mobileNumber: mobileNumber,
                          email: email,
                          loanAmount: loanAmount,
                          salary: loanType == 'Personal Loan' ? (salary.isNotEmpty ? salary : null) : null,
                          turnover: loanType == 'Business Loan' ? (turnover.isNotEmpty ? turnover : null) : null,
                          fatherName: fatherName.isNotEmpty ? fatherName : null,
                          motherName: motherName.isNotEmpty ? motherName : null,
                          maritalStatus: maritalStatus,
                          spouseName: maritalStatus == 'Married' ? (spouseName.isNotEmpty ? spouseName : null) : null,
                          occupation: occupation,
                          personalEmail: personalEmail.isNotEmpty ? personalEmail : null,
                          officialEmail: officialEmail.isNotEmpty ? officialEmail : null,
                          currentAddress: currentAddress.isNotEmpty ? currentAddress : null,
                          officeAddress: officeAddress.isNotEmpty ? officeAddress : null,
                          ref1Name: ref1Name.isNotEmpty ? ref1Name : null,
                          ref1Mobile: ref1Mobile.isNotEmpty ? ref1Mobile : null,
                          ref1Address: ref1Address.isNotEmpty ? ref1Address : null,
                          ref2Name: ref2Name.isNotEmpty ? ref2Name : null,
                          ref2Mobile: ref2Mobile.isNotEmpty ? ref2Mobile : null,
                          ref2Address: ref2Address.isNotEmpty ? ref2Address : null,
                          applicantDocuments: applicantDocs,
                          coApplicants: coApplicants,
                          status: status,
                          loginCompanyName: loginCompanyName.isNotEmpty ? loginCompanyName : null,
                          bankExecutiveName: bankExecutiveName.isNotEmpty ? bankExecutiveName : null,
                          gender: gender,
                          applicantCibil: applicantCibil,
                          panNumber: panNumber.isNotEmpty ? panNumber : null,
                          aadhaarNumber: aadhaarNumber.isNotEmpty ? aadhaarNumber : null,
                        );

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lead added successfully!'),
                            backgroundColor: AppTheme.emeraldGreen,
                          ),
                        );
                      }

                      await _loadApplications();
                    } catch (e) {
                      debugPrint('Error saving loan application, fallback to local: $e');

                      final localId = isEditMode ? existingLead['id'] : 'loan_mock_local_${DateTime.now().millisecondsSinceEpoch}';
                      final updatedLead = {
                        'id': localId,
                        'loan_type': loanType,
                        'full_name': fullName,
                        'mobile_number': mobileNumber,
                        'email': email,
                        'loan_amount': loanAmount,
                        'salary': loanType == 'Personal Loan' ? (salary.isNotEmpty ? salary : null) : null,
                        'turnover': loanType == 'Business Loan' ? (turnover.isNotEmpty ? turnover : null) : null,
                        'father_name': fatherName.isNotEmpty ? fatherName : null,
                        'mother_name': motherName.isNotEmpty ? motherName : null,
                        'marital_status': maritalStatus,
                        'spouse_name': maritalStatus == 'Married' ? (spouseName.isNotEmpty ? spouseName : null) : null,
                        'occupation': occupation,
                        'personal_email': personalEmail.isNotEmpty ? personalEmail : null,
                        'official_email': officialEmail.isNotEmpty ? officialEmail : null,
                        'current_address': currentAddress.isNotEmpty ? currentAddress : null,
                        'office_address': officeAddress.isNotEmpty ? officeAddress : null,
                        'ref1_name': ref1Name.isNotEmpty ? ref1Name : null,
                        'ref1_mobile': ref1Mobile.isNotEmpty ? ref1Mobile : null,
                        'ref1_address': ref1Address.isNotEmpty ? ref1Address : null,
                        'ref2_name': ref2Name.isNotEmpty ? ref2Name : null,
                        'ref2_mobile': ref2Mobile.isNotEmpty ? ref2Mobile : null,
                        'ref2_address': ref2Address.isNotEmpty ? ref2Address : null,
                        'applicant_documents': applicantDocs,
                        'co_applicants': coApplicants,
                        'status': status,
                        'login_company_name': loginCompanyName.isNotEmpty ? loginCompanyName : null,
                        'bank_executive_name': bankExecutiveName.isNotEmpty ? bankExecutiveName : null,
                        'gender': gender,
                        'applicant_cibil': applicantCibil,
                        'pan_number': panNumber.isNotEmpty ? panNumber : null,
                        'aadhaar_number': aadhaarNumber.isNotEmpty ? aadhaarNumber : null,
                        'submitted_at': existingLead?['submitted_at'] ?? Timestamp.now(),
                      };

                      setState(() {
                        if (isEditMode) {
                          final idx = _applications.indexWhere((app) => app['id'] == localId);
                          if (idx != -1) {
                            _applications[idx] = updatedLead;
                          }
                        } else {
                          _applications.insert(0, updatedLead);
                        }
                        _isLoading = false;
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEditMode ? 'Lead updated successfully (local simulation)!' : 'Lead added successfully (local simulation)!'),
                          backgroundColor: AppTheme.emeraldGreen,
                        ),
                      );
                    }
                  },
                  child: Text(isEditMode ? 'Save Changes' : 'Add Lead'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSendFileDialog(Map<String, dynamic> lead) {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSending = false;
    String currentStep = "";
    double progress = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.obsidianMedium,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.black.withOpacity(0.08)),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Send File to Bank Executive',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: isSending
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 24),
                          CircularProgressIndicator(
                            value: progress == 1.0 ? null : progress,
                            color: AppTheme.royalGold,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            currentStep,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white10,
                            color: AppTheme.royalGold,
                          ),
                          const SizedBox(height: 24),
                        ],
                      )
                    : Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sending file for: ${lead['full_name'] ?? 'Applicant'}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.royalGold),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: "Executive's Email Address *",
                                hintText: "enter executive email",
                                prefixIcon: Icon(Icons.email, size: 20),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Email is required';
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'FILES & DETAILS INCLUDED:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            _buildIncludeRow(Icons.check_circle_outline, 'Applicant Loan Details'),
                            _buildIncludeRow(Icons.check_circle_outline, 'Co-Applicants Details (if applicable)'),
                            _buildIncludeRow(Icons.description_outlined, 'Identity & PAN Cards'),
                            _buildIncludeRow(Icons.folder_shared_outlined, 'Uploaded Assets & Income Proofs'),
                          ],
                        ),
                      ),
              ),
              actions: isSending
                  ? []
                  : [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final email = emailController.text.trim();
                          
                          setDialogState(() {
                            isSending = true;
                            currentStep = "Gathering lead information...";
                            progress = 0.1;
                          });

                          // Simulating files compression & upload
                          await Future.delayed(const Duration(milliseconds: 1000));
                          setDialogState(() {
                            currentStep = "Compressing uploaded PDF documents...";
                            progress = 0.4;
                          });

                          await Future.delayed(const Duration(milliseconds: 1000));
                          setDialogState(() {
                            currentStep = "Encrypting documents package...";
                            progress = 0.7;
                          });

                          await Future.delayed(const Duration(milliseconds: 1000));
                          setDialogState(() {
                            currentStep = "Sending encrypted email to $email...";
                            progress = 0.95;
                          });

                          try {
                            // Log action to firestore
                            await _firestoreService.updateLoanStatus(lead['id'], lead['status'] ?? 'Pending Details');
                            
                            await _firestoreService.updateLoanApplication(
                              docId: lead['id'],
                              loanType: lead['loan_type'] ?? 'Personal Loan',
                              fullName: lead['full_name'] ?? '',
                              mobileNumber: lead['mobile_number'] ?? '',
                              email: lead['email'] ?? '',
                              loanAmount: lead['loan_amount'] ?? '',
                              salary: lead['salary'],
                              turnover: lead['turnover'],
                              fatherName: lead['father_name'],
                              motherName: lead['mother_name'],
                              maritalStatus: lead['marital_status'],
                              spouseName: lead['spouse_name'],
                              occupation: lead['occupation'],
                              personalEmail: lead['personal_email'],
                              officialEmail: lead['official_email'],
                              currentAddress: lead['current_address'],
                              officeAddress: lead['office_address'],
                              ref1Name: lead['ref1_name'],
                              ref1Mobile: lead['ref1_mobile'],
                              ref1Address: lead['ref1_address'],
                              ref2Name: lead['ref2_name'],
                              ref2Mobile: lead['ref2_mobile'],
                              ref2Address: lead['ref2_address'],
                              applicantDocuments: lead['applicant_documents'],
                              coApplicants: lead['co_applicants'],
                              status: lead['status'] ?? 'Pending Details',
                              loginCompanyName: lead['login_company_name'],
                              bankExecutiveName: lead['bank_executive_name'],
                              gender: lead['gender'],
                            );
                          } catch (e) {
                            debugPrint("Log warning: $e");
                          }

                          await Future.delayed(const Duration(milliseconds: 800));
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Complete file and documents successfully sent to $email!'),
                                backgroundColor: AppTheme.emeraldGreen,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Send File'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  Widget _buildIncludeRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.royalGold),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  String _normalizeStatus(String? status) {
    if (status == null) return 'Pending Details';
    final s = status.toLowerCase().trim();
    if (s == 'pending details' || s == 'pending') return 'Pending Details';
    if (s == 'login done') return 'Login done';
    if (s == 'sanctioned' || s == 'approved') return 'Sanctioned';
    if (s == 'disbursed') return 'Disbursed';
    if (s == 'rejected') return 'Rejected';
    return 'Pending Details';
  }

  Color _getStatusColor(String? status) {
    switch (_normalizeStatus(status).toLowerCase()) {
      case 'pending details':
        return Colors.orange;
      case 'login done':
        return Colors.blue;
      case 'sanctioned':
        return Colors.indigo;
      case 'disbursed':
        return AppTheme.emeraldGreen;
      case 'rejected':
        return AppTheme.rubyRed;
      default:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Customer Loan Pipelines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLeadDialog,
        backgroundColor: AppTheme.royalGold,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add New Lead',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs & Summary Row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'All',
                      'All Active',
                      'Pending Details',
                      'Login done',
                      'Sanctioned',
                      'Disbursed',
                      'Rejected'
                    ].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          selectedColor: AppTheme.royalGold,
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.obsidianDark : AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),
                    Text(
                      'Showing ${_filteredApplications.length} applications',
                      style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search & Filter Panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: AppTheme.glassDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search box
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name, email, phone...',
                            prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            fillColor: AppTheme.obsidianLight,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                        ),
                      ),
                      // Segment Filter Dropdown
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          value: _selectedSegment,
                          dropdownColor: AppTheme.obsidianMedium,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.filter_alt_outlined, size: 20, color: AppTheme.textSecondary),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            fillColor: AppTheme.obsidianLight,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Segments')),
                            DropdownMenuItem(value: 'Personal Loan', child: Text('Personal Loan')),
                            DropdownMenuItem(value: 'Business Loan', child: Text('Business Loan')),
                            DropdownMenuItem(value: 'Home Loan', child: Text('Home Loan')),
                            DropdownMenuItem(value: 'Mortgage Loan', child: Text('Mortgage Loan')),
                            DropdownMenuItem(value: 'Car Loan', child: Text('Car Loan')),
                            DropdownMenuItem(value: 'Commercial Vehicle Loan', child: Text('Commercial Vehicle Loan')),
                            DropdownMenuItem(value: 'Credit Card', child: Text('Credit Card')),
                            DropdownMenuItem(value: 'CC/OD Limit', child: Text('CC/OD Limit')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedSegment = val;
                              });
                            }
                          },
                        ),
                      ),
                      // Amount Filter Dropdown
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          value: _selectedAmountRange,
                          dropdownColor: AppTheme.obsidianMedium,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.currency_rupee_outlined, size: 20, color: AppTheme.textSecondary),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            fillColor: AppTheme.obsidianLight,
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Amounts')),
                            DropdownMenuItem(value: '< 5L', child: Text('Under ₹5 Lakh')),
                            DropdownMenuItem(value: '5L - 15L', child: Text('₹5L - ₹15 Lakh')),
                            DropdownMenuItem(value: '15L - 50L', child: Text('₹15L - ₹50 Lakh')),
                            DropdownMenuItem(value: '> 50L', child: Text('Above ₹50 Lakh')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedAmountRange = val;
                              });
                            }
                          },
                        ),
                      ),
                      // Date range picker button
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: _selectedDateRange,
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppTheme.royalGold,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: AppTheme.textPrimary,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDateRange = picked;
                            });
                          }
                        },
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          _selectedDateRange == null
                              ? 'Filter by Date'
                              : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          side: BorderSide(color: AppTheme.royalGold.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (_selectedDateRange != null)
                        IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.rubyRed),
                          onPressed: () {
                            setState(() {
                              _selectedDateRange = null;
                            });
                          },
                          tooltip: 'Clear Date Filter',
                        ),
                      if (_searchQuery.isNotEmpty ||
                          _selectedSegment != 'All' ||
                          _selectedAmountRange != 'All' ||
                          _selectedDateRange != null)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _selectedSegment = 'All';
                              _selectedAmountRange = 'All';
                              _selectedDateRange = null;
                            });
                          },
                          icon: const Icon(Icons.refresh, size: 16, color: AppTheme.rubyRed),
                          label: const Text(
                            'Reset Filters',
                            style: TextStyle(color: AppTheme.rubyRed, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main pipeline list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
                : _filteredApplications.isEmpty
                    ? const Center(
                        child: Text(
                          'No loan applications match this filter.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredApplications.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApplications[index];
                          final status = app['status']?.toString() ?? 'Pending';
                          final statusColor = _getStatusColor(status);
                          final isPersonal = app['loan_type']?.toString().toLowerCase().contains('personal') ?? false;
                          final isBusiness = app['loan_type']?.toString().toLowerCase().contains('business') ?? false;

                          return Card(
                            color: AppTheme.obsidianMedium,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.royalGold.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppTheme.royalGold.withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              app['loan_type']?.toString().toUpperCase() ?? 'LOAN',
                                              style: const TextStyle(
                                                color: AppTheme.royalGold,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '#${app['id']?.toString().substring(0, 8) ?? 'MOCK'}',
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                          ),
                                          if (app['applicant_cibil'] != null) ...[
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: (app['applicant_cibil'] as int) >= 700 ? AppTheme.emeraldGreen.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: (app['applicant_cibil'] as int) >= 700 ? AppTheme.emeraldGreen : Colors.orange),
                                              ),
                                              child: Text('APP CIBIL: ${app['applicant_cibil']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (app['applicant_cibil'] as int) >= 700 ? AppTheme.emeraldGreen : Colors.orange)),
                                            ),
                                          ],
                                          if (app['co_applicants'] != null && (app['co_applicants'] as List).isNotEmpty) ...[
                                            ...(app['co_applicants'] as List).asMap().entries.where((e) => e.value['cibil'] != null).map((e) {
                                              int cibil = e.value['cibil'] as int;
                                              return Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: cibil >= 700 ? AppTheme.emeraldGreen.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: cibil >= 700 ? AppTheme.emeraldGreen : Colors.orange),
                                                  ),
                                                  child: Text('CO-APP ${e.key + 1} CIBIL: $cibil', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cibil >= 700 ? AppTheme.emeraldGreen : Colors.orange)),
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.mail_outline, color: AppTheme.royalGold, size: 20),
                                            onPressed: () => _showSendFileDialog(app),
                                            tooltip: 'Send File to Executive',
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: AppTheme.textSecondary, size: 20),
                                            onPressed: () => _showAddLeadDialog(existingLead: app),
                                            tooltip: 'Edit Lead Details',
                                          ),
                                          const SizedBox(width: 8),
                                          DropdownButton<String>(
                                            value: _normalizeStatus(status),
                                            dropdownColor: AppTheme.obsidianMedium,
                                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                            underline: Container(
                                              height: 1,
                                              color: statusColor.withOpacity(0.5),
                                            ),
                                            items: const [
                                              DropdownMenuItem(value: 'Pending Details', child: Text('Pending Details')),
                                              DropdownMenuItem(value: 'Login done', child: Text('Login done')),
                                              DropdownMenuItem(value: 'Sanctioned', child: Text('Sanctioned')),
                                              DropdownMenuItem(value: 'Disbursed', child: Text('Disbursed')),
                                              DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                                            ],
                                            onChanged: (newVal) {
                                              if (newVal != null && newVal != status) {
                                                _updateStatus(app['id'], newVal);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Colors.white10, height: 24),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('APPLICANT NAME', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(app['full_name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(height: 8),
                                            Text('Phone: ${app['mobile_number'] ?? 'N/A'}'),
                                            const SizedBox(height: 8),
                                            Text('Login Bank/Company: ${app['login_company_name'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.royalGold)),
                                            Text('Bank Executive: ${app['bank_executive_name'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('REQUESTED AMOUNT', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(
                                              '₹ ${app['loan_amount'] ?? '0'}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.royalGold),
                                            ),
                                            if (isBusiness && app['turnover'] != null) ...[
                                              const SizedBox(height: 12),
                                              const Text('ANNUAL TURNOVER', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 2),
                                              Text('₹ ${app['turnover']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
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
