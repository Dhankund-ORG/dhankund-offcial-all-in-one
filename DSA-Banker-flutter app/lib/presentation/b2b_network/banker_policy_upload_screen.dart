import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../services/cloudflare_r2_service.dart';

class BankerPolicyUploadScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;
  const BankerPolicyUploadScreen({super.key, this.initialProfile});

  @override
  State<BankerPolicyUploadScreen> createState() => _BankerPolicyUploadScreenState();
}

class _BankerPolicyUploadScreenState extends State<BankerPolicyUploadScreen> {
  final ApiService _api = ApiService();
  final CloudflareR2Service _r2Service = CloudflareR2Service();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingDoc = false;
  bool _isExistingPolicy = false;
  bool _isBankNameLocked = false;
  String? _existingPolicyId;
  String? _policyStatus;
  String? _rejectionReason;
  String? _onePagerDocUrl;
  String? _onePagerDocName;
  List<Map<String, dynamic>> _allMyPolicies = [];

  late final TextEditingController _bankNameController;
  late final TextEditingController _bankerNameController;
  late final TextEditingController _bankerMobileController;
  late final TextEditingController _officeAddressController;
  late final TextEditingController _l1NameController;
  late final TextEditingController _l1MobileController;
  late final TextEditingController _l2NameController;
  late final TextEditingController _l2MobileController;

  late final TextEditingController _minTicketController;
  late final TextEditingController _maxTicketController;
  late final TextEditingController _ltvRatioController;
  late final TextEditingController _minCibilController;
  late final TextEditingController _minIncomeController;
  late final TextEditingController _maxBouncesController;
  late final TextEditingController _geoRadiusController;
  late final TextEditingController _approvedPincodesController;
  late final TextEditingController _loginFeeController;
  late final TextEditingController _processingFeeController;
  late final TextEditingController _interestRateController;
  late final TextEditingController _tatDaysController;
  late final TextEditingController _specialFeaturesController;

  // Home Loan & Mortgage Loan Exclusive Controllers
  late final TextEditingController _ageLimitController;
  late final TextEditingController _repaymentTenureController;
  late final TextEditingController _foirNormsController;
  late final TextEditingController _existingObligationsController;
  late final TextEditingController _employmentStabilityController;
  late final TextEditingController _ltvOnPlotController;

  String _loanType = 'Home Loan';
  String _vertical = 'Prime';
  String _segment = 'DSA';
  String _mProfileAllowed = 'YES';

  // 13 Property & Collateral Funding Options (YES / NO)
  String _roadWindingProperty = 'YES';
  String _gramPanchayatProperty = 'YES';
  String _notaryToRegistry = 'YES';
  String _gramPanchayatPatta = 'YES';
  String _dronPatta = 'YES';
  String _highestTicketSizeNotary = 'YES';
  String _highTensionLine = 'NO';
  String _withoutDiversion = 'NO';
  String _onlyDiversion = 'YES';
  String _akvnProperty = 'YES';
  String _greenBeltProperty = 'NO';
  String _plotPurchase = 'YES';
  String _plotMortgage = 'YES';

  // Personal Loan Specific Policies
  String _isSalarySlipRequired = 'YES';
  String _residenceOwnershipType = 'Owned Only';

  // Business Loan Specific Policies
  String _businessOwnershipType = 'At least One Owned Required';
  String _isGstRequired = 'YES';
  String _isItrRequired = 'YES';
  String _isUdyamRequired = 'YES';
  String _isCurrentAccountRequired = 'YES';
  String _bankingsConsidered = '6';

  final List<String> _loanTypes = [
    'Personal Loan',
    'Business Loan',
    'Home Loan',
    'Mortgage Loan',
    'Car Loan',
    'Commercial Vehicle Loan',
    'CC/OD Limit',
  ];

  final List<String> _verticals = [
    'Prime',
    'Affordable',
    'Informal',
  ];

  final List<String> _segments = [
    'DSA',
    'Connector',
    'Direct',
  ];

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile ?? {};
    final bankName = (profile['company'] ?? profile['companyName'] ?? profile['bank_name'] ?? '').toString().trim();
    final bankerName = (profile['name'] ?? ApiClient.currentUserName ?? '').toString();
    final bankerMobile = (profile['mobile'] ?? ApiClient.currentUserMobile ?? '').toString();
    final officeAddr = (profile['officeAddress'] ?? profile['office_address'] ?? profile['companyAddress'] ?? '').toString();

    _isBankNameLocked = bankName.isNotEmpty && bankName != 'Partner Bank' && bankName != 'Not provided';
    _bankNameController = TextEditingController(text: _isBankNameLocked ? bankName : '');
    _bankerNameController = TextEditingController(text: bankerName);
    _bankerMobileController = TextEditingController(text: bankerMobile);
    _officeAddressController = TextEditingController(text: officeAddr);
    _l1NameController = TextEditingController(text: (profile['managerName'] ?? profile['manager_name'] ?? '').toString());
    _l1MobileController = TextEditingController(text: (profile['managerMobile'] ?? profile['manager_mobile'] ?? '').toString());
    _l2NameController = TextEditingController(text: (profile['areaManagerName'] ?? profile['area_manager_name'] ?? '').toString());
    _l2MobileController = TextEditingController(text: (profile['areaManagerMobile'] ?? profile['area_manager_mobile'] ?? '').toString());

    _minTicketController = TextEditingController(text: '₹1,00,000');
    _maxTicketController = TextEditingController(text: '₹50,00,000');
    _ltvRatioController = TextEditingController(text: 'Up to 90% LTV');
    _minCibilController = TextEditingController(text: '700');
    _minIncomeController = TextEditingController(text: '₹25,000 / mo');
    _maxBouncesController = TextEditingController(text: '0');
    _geoRadiusController = TextEditingController(text: '50 km radius');
    _approvedPincodesController = TextEditingController();
    _loginFeeController = TextEditingController(text: 'Nil');
    _processingFeeController = TextEditingController(text: '1.00%');
    _interestRateController = TextEditingController(text: '10.50% - 13.50%');
    _tatDaysController = TextEditingController(text: '3 Days');
    _specialFeaturesController = TextEditingController();

    _ageLimitController = TextEditingController(text: '21 - 65 Years');
    _repaymentTenureController = TextEditingController(text: 'Up to 30 Years (HL) / 20 Years (LAP)');
    _foirNormsController = TextEditingController(text: '1L-7L: 60% | 7L-10L: 65% | 10L-12L: 70% | >=12L: 75%');
    _existingObligationsController = TextEditingController(text: 'Deducted from net income (>6 months EMI balance counted)');
    _employmentStabilityController = TextEditingController(text: 'Min 2 yrs total experience / 1 yr current company');
    _ltvOnPlotController = TextEditingController(text: '1L-30L: 90% | 30L-75L: 80% | >=75L: 70%');

    _loadExistingPolicy();
  }

  void _populateFromPolicyMap(Map<String, dynamic> existing) {
    _isExistingPolicy = true;
    _existingPolicyId = (existing['status'] == 'pending_approval' || existing['status'] == 'rejected')
        ? existing['id']?.toString()
        : null;
    _policyStatus = existing['status']?.toString();
    _rejectionReason = existing['rejection_reason']?.toString();

    if ((existing['bank_name'] ?? '').toString().trim().isNotEmpty &&
        existing['bank_name'].toString().trim() != 'Partner Bank') {
      _bankNameController.text = existing['bank_name'].toString().trim();
      _isBankNameLocked = true;
    }
    _bankerNameController.text = existing['banker_name'] ?? _bankerNameController.text;
    _bankerMobileController.text = existing['banker_mobile'] ?? _bankerMobileController.text;
    _officeAddressController.text = existing['office_address'] ?? _officeAddressController.text;
    _l1NameController.text = existing['l1_manager_name'] ?? _l1NameController.text;
    _l1MobileController.text = existing['l1_manager_mobile'] ?? _l1MobileController.text;
    _l2NameController.text = existing['l2_manager_name'] ?? _l2NameController.text;
    _l2MobileController.text = existing['l2_manager_mobile'] ?? _l2MobileController.text;

    if (_loanTypes.contains(existing['loan_type'])) _loanType = existing['loan_type'];
    if (_verticals.contains(existing['vertical'])) {
      _vertical = existing['vertical'];
    } else if (_verticals.contains(existing['product_type'])) {
      _vertical = existing['product_type'];
    }
    if (_segments.contains(existing['segment'])) _segment = existing['segment'];
    _mProfileAllowed = (existing['m_profile_allowed'] ?? 'YES').toString().toUpperCase() == 'NO' ? 'NO' : 'YES';

    _minTicketController.text = existing['min_ticket_size'] ?? '₹1,00,000';
    _maxTicketController.text = existing['max_ticket_size'] ?? (existing['max_loan_amount'] ?? '₹50,00,000');
    _ltvRatioController.text = existing['ltv_ratio'] ?? 'Up to 90% LTV';
    _minCibilController.text = (existing['min_cibil'] ?? '700').toString();
    _minIncomeController.text = existing['min_income'] ?? '₹25,000 / mo';
    _maxBouncesController.text = (existing['max_allowed_bounces'] ?? '0').toString();
    _geoRadiusController.text = existing['geo_radius'] ?? '50 km radius';
    _approvedPincodesController.text = existing['approved_pincodes'] ?? '';
    _loginFeeController.text = existing['login_fee'] ?? 'Nil';
    _processingFeeController.text = existing['processing_fee'] ?? '1.00%';
    _interestRateController.text = existing['interest_rate'] ?? '10.50% - 13.50%';
    _tatDaysController.text = existing['tat_days'] ?? '3 Days';
    _specialFeaturesController.text = existing['special_features'] ?? '';

    _ageLimitController.text = existing['age_limit'] ?? '21 - 65 Years';
    _repaymentTenureController.text = existing['repayment_tenure'] ?? 'Up to 30 Years (HL) / 20 Years (LAP)';
    _foirNormsController.text = existing['foir_norms'] ?? '1L-7L: 60% | 7L-10L: 65% | 10L-12L: 70% | >=12L: 75%';
    _existingObligationsController.text = existing['existing_obligations'] ?? 'Deducted from net income (>6 months EMI balance counted)';
    _employmentStabilityController.text = existing['employment_stability'] ?? 'Min 2 yrs total experience / 1 yr current company';
    _ltvOnPlotController.text = existing['ltv_on_plot'] ?? '1L-30L: 90% | 30L-75L: 80% | >=75L: 70%';

    _roadWindingProperty = existing['road_winding_property_funding'] ?? 'YES';
    _gramPanchayatProperty = existing['gram_panchayat_property_funding'] ?? 'YES';
    _notaryToRegistry = existing['notary_to_registry_funding'] ?? 'YES';
    _gramPanchayatPatta = existing['gram_panchayat_patta_funding'] ?? 'YES';
    _dronPatta = existing['dron_patta_funding'] ?? 'YES';
    _highestTicketSizeNotary = existing['highest_ticket_size_notary'] ?? 'YES';
    _highTensionLine = existing['high_tension_line_funding'] ?? 'NO';
    _withoutDiversion = existing['without_diversion_property_funding'] ?? 'NO';
    _onlyDiversion = existing['only_diversion_property_funding'] ?? 'YES';
    _akvnProperty = existing['akvn_property_funding'] ?? 'YES';
    _greenBeltProperty = existing['green_belt_property_funding'] ?? 'NO';
    _plotPurchase = existing['plot_purchase'] ?? 'YES';
    _plotMortgage = existing['plot_mortgage'] ?? 'YES';

    _isSalarySlipRequired = existing['is_salary_slip_required'] ?? 'YES';
    _residenceOwnershipType = existing['residence_ownership_type'] ?? 'Owned Only';

    _businessOwnershipType = existing['business_ownership_type'] ?? 'At least One Owned Required';
    _isGstRequired = existing['is_gst_required'] ?? 'YES';
    _isItrRequired = existing['is_itr_required'] ?? 'YES';
    _isUdyamRequired = existing['is_udyam_required'] ?? 'YES';
    _isCurrentAccountRequired = existing['is_current_account_required'] ?? 'YES';
    _bankingsConsidered = existing['bankings_considered'] ?? '6';

    _onePagerDocUrl = existing['one_pager_policy_url']?.toString();
    if (_onePagerDocUrl != null && _onePagerDocUrl!.isNotEmpty) {
      _onePagerDocName = _onePagerDocUrl!.split('/').last;
    } else {
      _onePagerDocName = null;
    }
  }

  void _onLoanTypeOrVerticalChanged(String newLoanType, String newVertical) {
    setState(() {
      _loanType = newLoanType;
      _vertical = newVertical;
      Map<String, dynamic>? match;
      for (final p in _allMyPolicies) {
        final lt = (p['loan_type'] ?? '').toString();
        final vt = (p['vertical'] ?? p['product_type'] ?? 'Prime').toString();
        if (lt.toLowerCase() == newLoanType.toLowerCase() && vt.toLowerCase() == newVertical.toLowerCase()) {
          match = p;
          break;
        }
      }
      if (match != null) {
        _populateFromPolicyMap(match);
      } else {
        _isExistingPolicy = false;
        _existingPolicyId = null;
        _policyStatus = null;
        _rejectionReason = null;
      }
    });
  }

  Future<void> _loadExistingPolicy() async {
    setState(() => _isLoading = true);
    try {
      final bundle = await _api.fetchMyBankPolicyBundle();
      final bankerInfo = (bundle['banker_info'] is Map)
          ? (bundle['banker_info'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final existing = (bundle['policy'] is Map)
          ? (bundle['policy'] as Map).cast<String, dynamic>()
          : null;
      if (bundle['policies'] is List) {
        _allMyPolicies = (bundle['policies'] as List)
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }

      if (bankerInfo.isNotEmpty) {
        final bName = (bankerInfo['bank_name'] ?? '').toString().trim();
        if (bName.isNotEmpty && bName != 'Partner Bank' && bName != 'Not provided') {
          _bankNameController.text = bName;
          _isBankNameLocked = true;
        }
        if (_bankerNameController.text.isEmpty && (bankerInfo['banker_name'] ?? '').toString().isNotEmpty) {
          _bankerNameController.text = bankerInfo['banker_name'].toString();
        }
        if (_bankerMobileController.text.isEmpty && (bankerInfo['banker_mobile'] ?? '').toString().isNotEmpty) {
          _bankerMobileController.text = bankerInfo['banker_mobile'].toString();
        }
        if (_officeAddressController.text.isEmpty && (bankerInfo['office_address'] ?? '').toString().isNotEmpty) {
          _officeAddressController.text = bankerInfo['office_address'].toString();
        }
        if (_l1NameController.text.isEmpty && (bankerInfo['l1_manager_name'] ?? '').toString().isNotEmpty) {
          _l1NameController.text = bankerInfo['l1_manager_name'].toString();
        }
        if (_l1MobileController.text.isEmpty && (bankerInfo['l1_manager_mobile'] ?? '').toString().isNotEmpty) {
          _l1MobileController.text = bankerInfo['l1_manager_mobile'].toString();
        }
        if (_l2NameController.text.isEmpty && (bankerInfo['l2_manager_name'] ?? '').toString().isNotEmpty) {
          _l2NameController.text = bankerInfo['l2_manager_name'].toString();
        }
        if (_l2MobileController.text.isEmpty && (bankerInfo['l2_manager_mobile'] ?? '').toString().isNotEmpty) {
          _l2MobileController.text = bankerInfo['l2_manager_mobile'].toString();
        }
      }

      if (existing != null && mounted) {
        _populateFromPolicyMap(existing);
      }
    } catch (e) {
      debugPrint('Error loading existing policy: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickExcelPincodes() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;
        if (bytes == null && !kIsWeb && file.path != null) {
          bytes = await io.File(file.path!).readAsBytes();
        }
        if (bytes != null) {
          final matches = await _api.parsePincodesFromFile(bytes);
          if (matches.isNotEmpty) {
            final current = _approvedPincodesController.text.trim();
            final existingPins = current.isNotEmpty
                ? current.split(RegExp(r'[\s,]+')).where((p) => p.isNotEmpty).toSet()
                : <String>{};
            existingPins.addAll(matches);
            setState(() {
              _approvedPincodesController.text = existingPins.join(', ');
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Extracted ${matches.length} approved pincodes from file!'),
                  backgroundColor: const Color(0xFF27AE60),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No 6-digit pin codes found in file.'), backgroundColor: Colors.orange),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadOnePagerPolicy() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes = file.bytes;
        if (bytes == null && !kIsWeb && file.path != null) {
          bytes = await io.File(file.path!).readAsBytes();
        }
        if (bytes != null) {
          setState(() => _isUploadingDoc = true);
          final ext = file.extension ?? 'pdf';
          final url = await _r2Service.uploadFile(bytes: bytes, folderPath: 'bank_policies', extension: ext);
          if (url != null) {
            setState(() {
              _onePagerDocUrl = url;
              _onePagerDocName = file.name;
              _isUploadingDoc = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('One Pager Policy uploaded successfully!'),
                  backgroundColor: Color(0xFF27AE60),
                ),
              );
            }
          } else {
            setState(() => _isUploadingDoc = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Document upload failed. Please try again.'), backgroundColor: Colors.red),
              );
            }
          }
        }
      }
    } catch (e) {
      setState(() => _isUploadingDoc = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitPolicy() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final isHomeOrMortgage = (_loanType == 'Home Loan' || _loanType == 'Mortgage Loan');
    final isPersonalLoan = (_loanType == 'Personal Loan');
    final isBusinessLoan = (_loanType == 'Business Loan');
    final isUnsecured = (isPersonalLoan || isBusinessLoan);

    try {
      final body = <String, dynamic>{
        if (_existingPolicyId != null) 'id': _existingPolicyId,
        'bank_name': _bankNameController.text.trim(),
        'banker_name': _bankerNameController.text.trim(),
        'banker_mobile': _bankerMobileController.text.trim(),
        'office_address': _officeAddressController.text.trim(),
        'l1_manager_name': _l1NameController.text.trim(),
        'l1_manager_mobile': _l1MobileController.text.trim(),
        'l2_manager_name': _l2NameController.text.trim(),
        'l2_manager_mobile': _l2MobileController.text.trim(),
        'loan_type': _loanType,
        'product_type': _vertical,
        'vertical': _vertical,
        'segment': _segment,
        'm_profile_allowed': _mProfileAllowed,
        'min_cibil': int.tryParse(_minCibilController.text.trim()) ?? 700,
        'min_income': _minIncomeController.text.trim(),
        'max_allowed_bounces': int.tryParse(_maxBouncesController.text.trim()) ?? 0,
        'min_ticket_size': _minTicketController.text.trim(),
        'max_ticket_size': _maxTicketController.text.trim(),
        'ltv_ratio': isUnsecured ? null : _ltvRatioController.text.trim(),
        'ltv_on_plot': isHomeOrMortgage ? _ltvOnPlotController.text.trim() : null,
        'geo_radius': _geoRadiusController.text.trim(),
        'approved_pincodes': _approvedPincodesController.text.trim(),
        'login_fee': _loginFeeController.text.trim(),
        'processing_fee': _processingFeeController.text.trim(),
        'interest_rate': _interestRateController.text.trim(),
        'tat_days': _tatDaysController.text.trim(),
        'special_features': _specialFeaturesController.text.trim(),
        'one_pager_policy_url': _onePagerDocUrl,
        'age_limit': isHomeOrMortgage ? _ageLimitController.text.trim() : null,
        'repayment_tenure': isHomeOrMortgage ? _repaymentTenureController.text.trim() : null,
        'foir_norms': isHomeOrMortgage ? _foirNormsController.text.trim() : null,
        'existing_obligations': isHomeOrMortgage ? _existingObligationsController.text.trim() : null,
        'employment_stability': isHomeOrMortgage ? _employmentStabilityController.text.trim() : null,
        'road_winding_property_funding': isHomeOrMortgage ? _roadWindingProperty : null,
        'gram_panchayat_property_funding': isHomeOrMortgage ? _gramPanchayatProperty : null,
        'notary_to_registry_funding': isHomeOrMortgage ? _notaryToRegistry : null,
        'gram_panchayat_patta_funding': isHomeOrMortgage ? _gramPanchayatPatta : null,
        'dron_patta_funding': isHomeOrMortgage ? _dronPatta : null,
        'highest_ticket_size_notary': isHomeOrMortgage ? _highestTicketSizeNotary : null,
        'high_tension_line_funding': isHomeOrMortgage ? _highTensionLine : null,
        'without_diversion_property_funding': isHomeOrMortgage ? _withoutDiversion : null,
        'only_diversion_property_funding': isHomeOrMortgage ? _onlyDiversion : null,
        'akvn_property_funding': isHomeOrMortgage ? _akvnProperty : null,
        'green_belt_property_funding': isHomeOrMortgage ? _greenBeltProperty : null,
        'plot_purchase': isHomeOrMortgage ? _plotPurchase : null,
        'plot_mortgage': isHomeOrMortgage ? _plotMortgage : null,
        'is_salary_slip_required': isPersonalLoan ? _isSalarySlipRequired : null,
        'residence_ownership_type': isPersonalLoan ? _residenceOwnershipType : null,
        'business_ownership_type': isBusinessLoan ? _businessOwnershipType : null,
        'is_gst_required': isBusinessLoan ? _isGstRequired : null,
        'is_itr_required': isBusinessLoan ? _isItrRequired : null,
        'is_udyam_required': isBusinessLoan ? _isUdyamRequired : null,
        'is_current_account_required': isBusinessLoan ? _isCurrentAccountRequired : null,
        'bankings_considered': isBusinessLoan ? _bankingsConsidered : null,
      };

      await _api.submitBankerPolicy(body);

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF27AE60)),
                const SizedBox(width: 10),
                Text(_isExistingPolicy ? 'Policy Updated' : 'Policy Submitted'),
              ],
            ),
            content: const Text(
              'Your Bank Policy has been submitted! It is now visible in CRM under "App Uploaded Policy" for review, modification (if required), and final approval by Dhankund Admin.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF093A7A)),
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildYesNoDropdown(String label, String value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value.toUpperCase() == 'NO' ? 'NO' : 'YES',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: const [
          DropdownMenuItem(value: 'YES', child: Text('YES - Allowed')),
          DropdownMenuItem(value: 'NO', child: Text('NO - Restricted')),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHomeOrMortgage = (_loanType == 'Home Loan' || _loanType == 'Mortgage Loan');
    final isPersonalLoan = (_loanType == 'Personal Loan');
    final isBusinessLoan = (_loanType == 'Business Loan');
    final isUnsecured = (isPersonalLoan || isBusinessLoan);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Update Bank Policy'),
        backgroundColor: const Color(0xFF093A7A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF093A7A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status / Info Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF093A7A).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF093A7A).withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_outlined, color: Color(0xFF093A7A), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isExistingPolicy
                                      ? 'Your One-Time Bank Policy is registered. You can update your bank policy details below.'
                                      : 'One-Time Bank Policy Upload (Only for Your Registered Bank)',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF093A7A)),
                                ),
                              ),
                            ],
                          ),
                          if (_policyStatus != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Current CRM Status: ${_policyStatus!.toUpperCase()}${(_rejectionReason != null && _rejectionReason!.isNotEmpty) ? " ($_rejectionReason)" : ""}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _policyStatus == 'approved'
                                    ? const Color(0xFF27AE60)
                                    : (_policyStatus == 'rejected' ? Colors.red : Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick selector for Banker's existing loan category policies
                    if (_allMyPolicies.isNotEmpty) ...[
                      const Text(
                        'YOUR BANK POLICIES BY LOAN CATEGORY (TAP TO EDIT / SWITCH)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _allMyPolicies.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final pol = _allMyPolicies[idx];
                            final lt = (pol['loan_type'] ?? 'Home Loan').toString();
                            final vt = (pol['vertical'] ?? pol['product_type'] ?? 'Prime').toString();
                            final st = (pol['status'] ?? 'approved').toString();
                            final isSelected = _loanType.toLowerCase() == lt.toLowerCase() && _vertical.toLowerCase() == vt.toLowerCase();
                            return ActionChip(
                              backgroundColor: isSelected ? const Color(0xFF093A7A) : Colors.white,
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF093A7A)
                                    : (st == 'approved' ? const Color(0xFF27AE60) : Colors.orange),
                              ),
                              avatar: Icon(
                                st == 'approved' ? Icons.check_circle : Icons.pending_actions,
                                size: 15,
                                color: isSelected ? Colors.white : (st == 'approved' ? const Color(0xFF27AE60) : Colors.orange),
                              ),
                              label: Text(
                                '$lt ($vt)',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : const Color(0xFF093A7A),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _populateFromPolicyMap(pol);
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // SECTION 1: BANK, PRODUCT & SOURCING VERTICAL
                    const Text(
                      '1. BANK, PRODUCT & SOURCING VERTICAL',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _bankNameController,
                      readOnly: _isBankNameLocked,
                      decoration: InputDecoration(
                        labelText: _isBankNameLocked ? 'Bank / NBFC Name (Locked to Your Bank) *' : 'Bank / NBFC Name *',
                        hintText: 'e.g. HDFC Bank, ICICI Bank, SBI, Axis Bank',
                        prefixIcon: Icon(
                          _isBankNameLocked ? Icons.lock_outline : Icons.account_balance_outlined,
                          color: const Color(0xFF093A7A),
                          size: 18,
                        ),
                        filled: _isBankNameLocked,
                        fillColor: _isBankNameLocked ? const Color(0xFFEFF3F8) : null,
                        helperText: 'Bankers can upload & update policies for their own bank (Reviewed & Merged in CRM)',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _loanType,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Loan Category *'),
                      items: _loanTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => _onLoanTypeOrVerticalChanged(val ?? 'Home Loan', _vertical),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _vertical,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Vertical *'),
                            items: _verticals.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) => _onLoanTypeOrVerticalChanged(_loanType, val ?? 'Prime'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _segment,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Segment *'),
                            items: _segments.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) => setState(() => _segment = val ?? 'DSA'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 2: OFFICER, OFFICE ADDRESS & ESCALATION HIERARCHY (L1 / L2)
                    const Text(
                      '2. OFFICER, OFFICE ADDRESS & ESCALATION HIERARCHY (L1 / L2)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bankerNameController,
                            decoration: const InputDecoration(labelText: 'Primary Bank Officer Name *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _bankerMobileController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Primary Officer Mobile *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _officeAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Office Address / Branch Location',
                        prefixIcon: Icon(Icons.business_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _l1NameController,
                            decoration: const InputDecoration(labelText: 'L1 Manager Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _l1MobileController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'L1 Manager Mobile'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _l2NameController,
                            decoration: const InputDecoration(labelText: 'L2 Manager Name'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _l2MobileController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'L2 Manager Mobile'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 3: UNDERWRITING CRITERIA, GEO LOCATION, PINCODES & ONE PAGER
                    const Text(
                      '3. UNDERWRITING CRITERIA, GEO LOCATION & PINCODES',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minTicketController,
                            decoration: const InputDecoration(labelText: 'Min Ticket Size *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _maxTicketController,
                            decoration: const InputDecoration(labelText: 'Max Ticket Size *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!isUnsecured) ...[
                      TextFormField(
                        controller: _ltvRatioController,
                        decoration: const InputDecoration(labelText: 'LTV (Loan to Value Ratio) *'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      value: _mProfileAllowed,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'M Profile Funding *'),
                      items: const [
                        DropdownMenuItem(value: 'YES', child: Text('YES - M Profile Funded')),
                        DropdownMenuItem(value: 'NO', child: Text('NO - M Profile Restricted')),
                      ],
                      onChanged: (val) => setState(() => _mProfileAllowed = val ?? 'YES'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minCibilController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Min CIBIL *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _minIncomeController,
                            decoration: const InputDecoration(labelText: 'Min Income / Turnover *'),
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
                            controller: _maxBouncesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Max Bounces (BT) *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _geoRadiusController,
                            decoration: const InputDecoration(labelText: 'Geo Location Radius *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Approved Locations Pin code (Manually + Excel Upload)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _approvedPincodesController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Approved Locations Pin code',
                                  hintText: 'e.g. 452001, 452010 (Manual or Excel Upload)',
                                  prefixIcon: Icon(Icons.pin_drop_outlined, color: Color(0xFF093A7A)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _pickExcelPincodes,
                              icon: const Icon(Icons.file_upload_outlined, size: 16),
                              label: const Text('Excel/CSV'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF093A7A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter approved location pin codes manually or upload an Excel (.xlsx, .xls) / CSV file.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Document Upload: "Upload One Pager Policy"
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF093A7A).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.description_outlined, color: Color(0xFF093A7A), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Upload One Pager Policy',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF093A7A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Upload official bank one-pager circular / policy document (PDF, Image, Docx)',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                          if (_onePagerDocUrl != null && _onePagerDocUrl!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF27AE60), size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _onePagerDocName ?? 'One Pager Policy Uploaded',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF27AE60)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _isUploadingDoc ? null : _uploadOnePagerPolicy,
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('Update Document', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ] else ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isUploadingDoc ? null : _uploadOnePagerPolicy,
                                icon: _isUploadingDoc
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.upload_file, size: 18),
                                label: Text(_isUploadingDoc ? 'Uploading Document...' : 'Upload One Pager Policy'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF093A7A),
                                  side: const BorderSide(color: Color(0xFF093A7A)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _interestRateController,
                            decoration: const InputDecoration(labelText: 'Interest Rate (ROI) *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tatDaysController,
                            decoration: const InputDecoration(labelText: 'Approval TAT'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _loginFeeController,
                            decoration: const InputDecoration(labelText: 'Bank Login Fee *'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _processingFeeController,
                            decoration: const InputDecoration(labelText: 'Processing Fee'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specialFeaturesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Special Guidelines / Key Underwriting Highlights',
                      ),
                    ),

                    // SECTION 4: CATEGORY-SPECIFIC EXCLUSIVE POLICIES
                    if (isHomeOrMortgage) ...[
                      const SizedBox(height: 20),
                      const Text(
                        '4. HOME & MORTGAGE LOAN EXCLUSIVE POLICIES',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageLimitController,
                              decoration: const InputDecoration(labelText: 'Age Limit'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _repaymentTenureController,
                              decoration: const InputDecoration(labelText: 'Repayment Tenure'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _foirNormsController,
                        decoration: const InputDecoration(labelText: 'Income Ratio (FOIR)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _existingObligationsController,
                        decoration: const InputDecoration(labelText: 'Existing Obligations'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _employmentStabilityController,
                        decoration: const InputDecoration(labelText: 'Employment Stability'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ltvOnPlotController,
                        decoration: const InputDecoration(labelText: 'LTV on Plot'),
                      ),
                      const SizedBox(height: 14),
                      _buildYesNoDropdown('Road winding property funding', _roadWindingProperty, (v) => setState(() => _roadWindingProperty = v ?? 'YES')),
                      _buildYesNoDropdown('Gram panchayat property funding', _gramPanchayatProperty, (v) => setState(() => _gramPanchayatProperty = v ?? 'YES')),
                      _buildYesNoDropdown('Notary to registry funding', _notaryToRegistry, (v) => setState(() => _notaryToRegistry = v ?? 'YES')),
                      _buildYesNoDropdown('Gram panchayat patta funding', _gramPanchayatPatta, (v) => setState(() => _gramPanchayatPatta = v ?? 'YES')),
                      _buildYesNoDropdown('Dron patta funding', _dronPatta, (v) => setState(() => _dronPatta = v ?? 'YES')),
                      _buildYesNoDropdown('Highest ticket size for notary property', _highestTicketSizeNotary, (v) => setState(() => _highestTicketSizeNotary = v ?? 'YES')),
                      _buildYesNoDropdown('Property under HIGH tension line funding', _highTensionLine, (v) => setState(() => _highTensionLine = v ?? 'NO')),
                      _buildYesNoDropdown('Without diversion property funding', _withoutDiversion, (v) => setState(() => _withoutDiversion = v ?? 'NO')),
                      _buildYesNoDropdown('Only diversion property funding', _onlyDiversion, (v) => setState(() => _onlyDiversion = v ?? 'YES')),
                      _buildYesNoDropdown('AKVN Property funding', _akvnProperty, (v) => setState(() => _akvnProperty = v ?? 'YES')),
                      _buildYesNoDropdown('Green belt property funding', _greenBeltProperty, (v) => setState(() => _greenBeltProperty = v ?? 'NO')),
                      _buildYesNoDropdown('Plot purchase', _plotPurchase, (v) => setState(() => _plotPurchase = v ?? 'YES')),
                      _buildYesNoDropdown('Plot mortgage', _plotMortgage, (v) => setState(() => _plotMortgage = v ?? 'YES')),
                    ],

                    if (isPersonalLoan) ...[
                      const SizedBox(height: 20),
                      const Text(
                        '4. PERSONAL LOAN EXCLUSIVE POLICIES',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      _buildYesNoDropdown('Is Salary Slip Required?', _isSalarySlipRequired, (v) => setState(() => _isSalarySlipRequired = v ?? 'YES')),
                      DropdownButtonFormField<String>(
                        value: _residenceOwnershipType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Customer Residence Status *'),
                        items: const [
                          DropdownMenuItem(value: 'Owned Only', child: Text('Owned Only Required')),
                          DropdownMenuItem(value: 'Rented Allowed', child: Text('Rented Allowed')),
                        ],
                        onChanged: (v) => setState(() => _residenceOwnershipType = v ?? 'Owned Only'),
                      ),
                    ],

                    if (isBusinessLoan) ...[
                      const SizedBox(height: 20),
                      const Text(
                        '4. BUSINESS LOAN EXCLUSIVE POLICIES',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF093A7A), letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _businessOwnershipType,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Residence / Business Ownership *'),
                        items: const [
                          DropdownMenuItem(value: 'At least One Owned Required', child: Text('At least One Owned Required')),
                          DropdownMenuItem(value: 'Both Rented Allowed', child: Text('Both Rented Allowed')),
                        ],
                        onChanged: (v) => setState(() => _businessOwnershipType = v ?? 'At least One Owned Required'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _bankingsConsidered,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Bankings Considered (Months) *'),
                        items: const [
                          DropdownMenuItem(value: '1', child: Text('1 Month Banking')),
                          DropdownMenuItem(value: '2', child: Text('2 Months Banking')),
                          DropdownMenuItem(value: '3', child: Text('3 Months Banking')),
                          DropdownMenuItem(value: '4', child: Text('4 Months Banking')),
                          DropdownMenuItem(value: '5', child: Text('5 Months Banking')),
                          DropdownMenuItem(value: '6', child: Text('6 Months Banking')),
                          DropdownMenuItem(value: '6+', child: Text('6+ Months Banking')),
                        ],
                        onChanged: (v) => setState(() => _bankingsConsidered = v ?? '6'),
                      ),
                      const SizedBox(height: 12),
                      _buildYesNoDropdown('IS GST REQUIRED?', _isGstRequired, (v) => setState(() => _isGstRequired = v ?? 'YES')),
                      _buildYesNoDropdown('IS ITR REQUIRED?', _isItrRequired, (v) => setState(() => _isItrRequired = v ?? 'YES')),
                      _buildYesNoDropdown('IS UDYAM REQUIRED?', _isUdyamRequired, (v) => setState(() => _isUdyamRequired = v ?? 'YES')),
                      _buildYesNoDropdown('CURRENT A/C REQUIRED?', _isCurrentAccountRequired, (v) => setState(() => _isCurrentAccountRequired = v ?? 'YES')),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _submitPolicy,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(_isExistingPolicy ? Icons.update : Icons.policy_outlined),
                        label: Text(
                          _isExistingPolicy ? 'Update Bank Policy' : 'Submit Bank Policy for CRM Approval',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF093A7A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
