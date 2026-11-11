import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../api_service.dart';
import '../../cloudflare_r2_service.dart';

class AppUploadedPoliciesPage extends StatefulWidget {
  const AppUploadedPoliciesPage({super.key});

  @override
  State<AppUploadedPoliciesPage> createState() => _AppUploadedPoliciesPageState();
}

class _AppUploadedPoliciesPageState extends State<AppUploadedPoliciesPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _pendingPolicies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingPolicies();
  }

  Future<void> _loadPendingPolicies() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.fetchAppUploadedPolicies();
      if (mounted) {
        setState(() {
          _pendingPolicies = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading app policies: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approvePolicy(Map<String, dynamic> policy, [Map<String, dynamic>? modified]) async {
    setState(() => _isLoading = true);
    try {
      await _api.approveBankPolicy(policy['id'].toString(), modified);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank policy approved and merged with CRM Banker Policies!'),
            backgroundColor: AppTheme.emeraldGreen,
          ),
        );
        _loadPendingPolicies();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectPolicy(Map<String, dynamic> policy) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidianMedium,
        title: const Text('Reject Bank Policy', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject policy from ${policy['bank_name']}?', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason for Rejection *', hintText: 'e.g. Incomplete pincodes or incorrect ROI'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rubyRed, foregroundColor: Colors.white),
            child: const Text('Reject Policy'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _api.rejectBankPolicy(policy['id'].toString(), reasonController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Policy rejected and banker notified.'), backgroundColor: Colors.orange),
          );
          _loadPendingPolicies();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rejection error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showModifyDialog(Map<String, dynamic> policy) {
    final formKey = GlobalKey<FormState>();

    final bankNameController = TextEditingController(text: policy['bank_name'] ?? '');
    final bankerNameController = TextEditingController(text: policy['banker_name'] ?? '');
    final bankerMobileController = TextEditingController(text: policy['banker_mobile'] ?? '');
    final officeAddressController = TextEditingController(text: policy['office_address'] ?? '');
    final l1NameController = TextEditingController(text: policy['l1_manager_name'] ?? '');
    final l1MobileController = TextEditingController(text: policy['l1_manager_mobile'] ?? '');
    final l2NameController = TextEditingController(text: policy['l2_manager_name'] ?? '');
    final l2MobileController = TextEditingController(text: policy['l2_manager_mobile'] ?? '');
    final minTicketController = TextEditingController(text: policy['min_ticket_size'] ?? '₹1,00,000');
    final maxTicketController = TextEditingController(text: policy['max_ticket_size'] ?? (policy['max_loan_amount'] ?? '₹50,00,000'));
    final roiController = TextEditingController(text: policy['interest_rate'] ?? '10.50% - 13.50%');
    final ltvController = TextEditingController(text: policy['ltv_ratio'] ?? 'Up to 90% LTV');
    final geoController = TextEditingController(text: policy['geo_radius'] ?? '50 km radius');
    final pincodesController = TextEditingController(text: policy['approved_pincodes'] ?? '');
    final minCibilController = TextEditingController(text: (policy['min_cibil'] ?? 700).toString());
    final minIncomeController = TextEditingController(text: policy['min_income'] ?? '₹25,000 / mo');
    final maxBouncesController = TextEditingController(text: (policy['max_allowed_bounces'] ?? 0).toString());
    final loginFeeController = TextEditingController(text: policy['login_fee'] ?? 'Nil');
    final processingFeeController = TextEditingController(text: policy['processing_fee'] ?? '1.00%');
    final tatController = TextEditingController(text: policy['tat_days'] ?? '3 Days');
    final specialFeaturesController = TextEditingController(text: policy['special_features'] ?? '');

    // Home Loan & Mortgage Loan Exclusive Controllers
    final ageLimitController = TextEditingController(text: policy['age_limit'] ?? '21 - 65 Years');
    final foirNormsController = TextEditingController(
      text: policy['foir_norms'] ?? '1L-7L: 60% | 7L-10L: 65% | 10L-12L: 70% | >=12L: 75%',
    );
    final existingObligationsController = TextEditingController(
      text: policy['existing_obligations'] ?? 'Deducted from net income (>6 months EMI balance counted)',
    );
    final employmentStabilityController = TextEditingController(
      text: policy['employment_stability'] ?? 'Min 2 yrs total experience / 1 yr current company',
    );
    final ltvOnPlotController = TextEditingController(
      text: policy['ltv_on_plot'] ?? '1L-30L: 90% | 30L-75L: 80% | >=75L: 70%',
    );
    final repaymentTenureController = TextEditingController(
      text: policy['repayment_tenure'] ?? 'Up to 30 Years (HL) / 20 Years (LAP)',
    );

    String loanType = ['Personal Loan', 'Business Loan', 'Home Loan', 'Mortgage Loan', 'Car Loan', 'Commercial Vehicle Loan', 'CC/OD Limit']
            .contains(policy['loan_type'])
        ? policy['loan_type']
        : 'Home Loan';
    String vertical = ['Prime', 'Affordable', 'Informal'].contains(policy['vertical'])
        ? policy['vertical']
        : (['Prime', 'Affordable', 'Informal'].contains(policy['product_type']) ? policy['product_type'] : 'Prime');
    String segment = ['DSA', 'Connector', 'Direct'].contains(policy['segment'])
        ? policy['segment']
        : 'DSA';
    String mProfileAllowed = (policy['m_profile_allowed'] ?? 'YES').toString().toUpperCase() == 'NO' ? 'NO' : 'YES';
    String? onePagerPolicyUrl = policy['one_pager_policy_url']?.toString();
    bool isUploadingOnePager = false;

    // 13 Property & Collateral Funding Options (YES / NO)
    String roadWindingProperty = policy['road_winding_property_funding'] ?? 'YES';
    String gramPanchayatProperty = policy['gram_panchayat_property_funding'] ?? 'YES';
    String notaryToRegistry = policy['notary_to_registry_funding'] ?? 'YES';
    String gramPanchayatPatta = policy['gram_panchayat_patta_funding'] ?? 'YES';
    String dronPatta = policy['dron_patta_funding'] ?? 'YES';
    String highestTicketSizeNotary = policy['highest_ticket_size_notary'] ?? 'YES';
    String highTensionLine = policy['high_tension_line_funding'] ?? 'NO';
    String withoutDiversion = policy['without_diversion_property_funding'] ?? 'NO';
    String onlyDiversion = policy['only_diversion_property_funding'] ?? 'YES';
    String akvnProperty = policy['akvn_property_funding'] ?? 'YES';
    String greenBeltProperty = policy['green_belt_property_funding'] ?? 'NO';
    String plotPurchase = policy['plot_purchase'] ?? 'YES';
    String plotMortgage = policy['plot_mortgage'] ?? 'YES';

    // Personal Loan Specific Policies
    String isSalarySlipRequired = (policy['is_salary_slip_required'] ?? 'YES').toString().toUpperCase().startsWith('NO') ? 'NO' : 'YES';
    String residenceOwnershipType = ['Owned Only', 'Rented Allowed'].contains(policy['residence_ownership_type'])
        ? policy['residence_ownership_type']
        : 'Owned Only';

    // Business Loan Specific Policies
    String businessOwnershipType = ['At least One Owned Required', 'Both Rented Allowed'].contains(policy['business_ownership_type'])
        ? policy['business_ownership_type']
        : 'At least One Owned Required';
    String isGstRequired = (policy['is_gst_required'] ?? 'YES').toString().toUpperCase() == 'NO' ? 'NO' : 'YES';
    String isItrRequired = (policy['is_itr_required'] ?? 'YES').toString().toUpperCase() == 'NO' ? 'NO' : 'YES';
    String isUdyamRequired = (policy['is_udyam_required'] ?? 'YES').toString().toUpperCase() == 'NO' ? 'NO' : 'YES';
    String isCurrentAccountRequired = (policy['is_current_account_required'] ?? 'YES').toString().toUpperCase() == 'NO' ? 'NO' : 'YES';
    String bankingsConsidered = ['1', '2', '3', '4', '5', '6', '6+'].contains(policy['bankings_considered']?.toString())
        ? policy['bankings_considered'].toString()
        : '6';

    Future<void> pickExcelPincodes() async {
      try {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
        );
        if (file != null) {
          final bytes = await file.readAsBytes();
          final matches = await _api.parsePincodesFromFile(bytes);
          if (matches.isNotEmpty) {
            final current = pincodesController.text.trim();
            final existingPins = current.isNotEmpty
                ? current.split(RegExp(r'[\s,]+')).where((p) => p.isNotEmpty).toSet()
                : <String>{};
            existingPins.addAll(matches);
            pincodesController.text = existingPins.join(', ');
          }
        }
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isHomeOrMortgage = (loanType == 'Home Loan' || loanType == 'Mortgage Loan');
          final isPersonalLoan = (loanType == 'Personal Loan');
          final isBusinessLoan = (loanType == 'Business Loan');
          final isUnsecured = (isPersonalLoan || isBusinessLoan);

          return AlertDialog(
            backgroundColor: AppTheme.obsidianMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.royalGold.withOpacity(0.25)),
            ),
            title: Row(
              children: [
                const Icon(Icons.edit_note, color: AppTheme.royalGold, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review, Modify & Merge App Policy - ${policy['bank_name']}',
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: SizedBox(
              width: 780,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1
                      const Text(
                        '1. BANK, PRODUCT & SOURCING VERTICAL',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: bankNameController,
                              decoration: const InputDecoration(labelText: 'Bank / NBFC Name *'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: loanType,
                              dropdownColor: AppTheme.obsidianMedium,
                              decoration: const InputDecoration(labelText: 'Loan Category *'),
                              items: const [
                                DropdownMenuItem(value: 'Personal Loan', child: Text('Personal Loan')),
                                DropdownMenuItem(value: 'Business Loan', child: Text('Business Loan')),
                                DropdownMenuItem(value: 'Home Loan', child: Text('Home Loan')),
                                DropdownMenuItem(value: 'Mortgage Loan', child: Text('Mortgage Loan')),
                                DropdownMenuItem(value: 'Car Loan', child: Text('Car Loan')),
                                DropdownMenuItem(value: 'Commercial Vehicle Loan', child: Text('Commercial Vehicle Loan')),
                                DropdownMenuItem(value: 'CC/OD Limit', child: Text('CC/OD Limit')),
                              ],
                              onChanged: (v) => setDialogState(() => loanType = v ?? loanType),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: vertical,
                              dropdownColor: AppTheme.obsidianMedium,
                              decoration: const InputDecoration(labelText: 'Vertical *'),
                              items: const [
                                DropdownMenuItem(value: 'Prime', child: Text('Prime (Standard Tier-1)')),
                                DropdownMenuItem(value: 'Affordable', child: Text('Affordable (Sub-Prime / Low Ticket)')),
                                DropdownMenuItem(value: 'Informal', child: Text('Informal (Cash / Surrogate Segment)')),
                              ],
                              onChanged: (v) => setDialogState(() => vertical = v ?? vertical),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: segment,
                              dropdownColor: AppTheme.obsidianMedium,
                              decoration: const InputDecoration(labelText: 'Segment *'),
                              items: const [
                                DropdownMenuItem(value: 'DSA', child: Text('DSA Channel')),
                                DropdownMenuItem(value: 'Connector', child: Text('Connector Network')),
                                DropdownMenuItem(value: 'Direct', child: Text('Direct / Branch Walk-in')),
                              ],
                              onChanged: (v) => setDialogState(() => segment = v ?? segment),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 2
                      const Text(
                        '2. OFFICER, OFFICE ADDRESS & ESCALATION HIERARCHY (L1 / L2)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: bankerNameController,
                              decoration: const InputDecoration(labelText: 'Primary Bank Officer Name *'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: bankerMobileController,
                              decoration: const InputDecoration(labelText: 'Primary Officer Mobile *'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: officeAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Office Address / Branch Location',
                          prefixIcon: Icon(Icons.business_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: l1NameController,
                              decoration: const InputDecoration(labelText: 'L1 Manager Name'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: l1MobileController,
                              decoration: const InputDecoration(labelText: 'L1 Manager Mobile'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: l2NameController,
                              decoration: const InputDecoration(labelText: 'L2 Manager Name'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: l2MobileController,
                              decoration: const InputDecoration(labelText: 'L2 Manager Mobile'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 3
                      const Text(
                        '3. UNDERWRITING CRITERIA, TICKET SIZE, LTV & M PROFILE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minTicketController,
                              decoration: const InputDecoration(labelText: 'Min. Loan Ticket Size *'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: maxTicketController,
                              decoration: const InputDecoration(labelText: 'Max. Loan Ticket Size *'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (!isUnsecured) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: ltvController,
                                decoration: const InputDecoration(labelText: 'LTV (Loan to Value Ratio) *'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: mProfileAllowed,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(labelText: 'M Profile Funding *'),
                                items: const [
                                  DropdownMenuItem(value: 'YES', child: Text('YES - M Profile Funded')),
                                  DropdownMenuItem(value: 'NO', child: Text('NO - M Profile Restricted')),
                                ],
                                onChanged: (v) => setDialogState(() => mProfileAllowed = v ?? 'YES'),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: mProfileAllowed,
                          dropdownColor: AppTheme.obsidianMedium,
                          decoration: const InputDecoration(labelText: 'M Profile Funding *'),
                          items: const [
                            DropdownMenuItem(value: 'YES', child: Text('YES - M Profile Funded')),
                            DropdownMenuItem(value: 'NO', child: Text('NO - M Profile Restricted')),
                          ],
                          onChanged: (v) => setDialogState(() => mProfileAllowed = v ?? 'YES'),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minCibilController,
                              decoration: const InputDecoration(labelText: 'Minimum CIBIL Cutoff *'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: minIncomeController,
                              decoration: const InputDecoration(labelText: 'Min Income / Turnover *'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: maxBouncesController,
                              decoration: const InputDecoration(labelText: 'Max Allowed Bounces (BT) *'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: geoController,
                              decoration: const InputDecoration(labelText: 'Geo Location Radius *'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: pincodesController,
                                    maxLines: 1,
                                    decoration: const InputDecoration(labelText: 'Approved Locations Pin code'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: pickExcelPincodes,
                                  icon: const Icon(Icons.upload_file, size: 15),
                                  label: const Text('Excel / CSV'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.royalGold,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: loginFeeController,
                              decoration: const InputDecoration(labelText: 'Bank Login Fee *'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: processingFeeController,
                              decoration: const InputDecoration(labelText: 'Processing Fee Policy'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: roiController,
                              decoration: const InputDecoration(labelText: 'Interest Rate Range (ROI) *'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: tatController,
                              decoration: const InputDecoration(labelText: 'Approval TAT'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.royalGold.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.royalGold.withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.description_outlined, color: AppTheme.royalGold, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Upload One Pager Policy',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                  ),
                                  Text(
                                    (onePagerPolicyUrl != null && onePagerPolicyUrl!.isNotEmpty)
                                        ? 'Attached: ${onePagerPolicyUrl!.split('/').last}'
                                        : 'Attach official 1-pager policy circular / matrix (PDF, Image, Doc)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (onePagerPolicyUrl != null && onePagerPolicyUrl!.isNotEmpty)
                                          ? AppTheme.emeraldGreen
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: isUploadingOnePager
                                  ? null
                                  : () async {
                                      final file = await FilePicker.pickFile(
                                        type: FileType.custom,
                                        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx'],
                                      );
                                      if (file != null) {
                                        setDialogState(() => isUploadingOnePager = true);
                                        final bytes = await file.readAsBytes();
                                        final url = await CloudflareR2Service().uploadDocument(
                                          'one_pager_${DateTime.now().millisecondsSinceEpoch}_${file.name}',
                                          bytes,
                                        );
                                        setDialogState(() {
                                          isUploadingOnePager = false;
                                          if (url != null) onePagerPolicyUrl = url;
                                        });
                                      }
                                    },
                              icon: isUploadingOnePager
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.cloud_upload_outlined, size: 16),
                              label: Text(
                                isUploadingOnePager
                                    ? 'Uploading...'
                                    : ((onePagerPolicyUrl != null && onePagerPolicyUrl!.isNotEmpty)
                                        ? 'Replace One Pager Policy'
                                        : 'Upload One Pager Policy'),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.royalGold,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: specialFeaturesController,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Special Guidelines / Key Underwriting Highlights'),
                      ),

                      // SECTION 4: HOME & MORTGAGE LOAN EXCLUSIVE POLICIES
                      if (isHomeOrMortgage) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.royalGold.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.royalGold.withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.home_work_outlined, color: AppTheme.royalGold, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '4. HOME & MORTGAGE LOAN EXCLUSIVE POLICIES (अंडरराइटिंग एवं प्रॉपर्टी मानदंड)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: ageLimitController,
                                      decoration: const InputDecoration(labelText: 'Age Limit (आयु सीमा) *'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: repaymentTenureController,
                                      decoration: const InputDecoration(labelText: 'Repayment Tenure (अधिकतम अवधि) *'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: foirNormsController,
                                decoration: const InputDecoration(labelText: 'Income Ratio / FOIR Slabs *'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: existingObligationsController,
                                      decoration: const InputDecoration(labelText: 'Existing Obligations Policy *'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: employmentStabilityController,
                                      decoration: const InputDecoration(labelText: 'Employment Stability Requirement *'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: ltvOnPlotController,
                                decoration: const InputDecoration(labelText: 'LTV on Plot (प्लॉट पर LTV अनुपात) *'),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'PROPERTY & COLLATERAL FUNDING PERMISSIONS (13 NORMS)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _buildPropertyYesNoField(label: 'Road winding property funding', hindiLabel: 'रोड वाइंडिंग संपत्ति फंडिंग', value: roadWindingProperty, onChanged: (v) => setDialogState(() => roadWindingProperty = v ?? 'YES'))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildPropertyYesNoField(label: 'Gram panchayat property funding', hindiLabel: 'ग्राम पंचायत संपत्ति फंडिंग', value: gramPanchayatProperty, onChanged: (v) => setDialogState(() => gramPanchayatProperty = v ?? 'YES'))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _buildPropertyYesNoField(label: 'Notary to registry funding', hindiLabel: 'नोटरी से रजिस्ट्री फंडिंग', value: notaryToRegistry, onChanged: (v) => setDialogState(() => notaryToRegistry = v ?? 'YES'))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildPropertyYesNoField(label: 'Gram panchayat patta funding', hindiLabel: 'ग्राम पंचायत पट्टा फंडिंग', value: gramPanchayatPatta, onChanged: (v) => setDialogState(() => gramPanchayatPatta = v ?? 'YES'))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _buildPropertyYesNoField(label: 'Dron patta funding', hindiLabel: 'ड्रोन पट्टा फंडिंग', value: dronPatta, onChanged: (v) => setDialogState(() => dronPatta = v ?? 'YES'))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildPropertyYesNoField(label: 'Highest ticket size for notary property', hindiLabel: 'नोटरी प्रॉपर्टी अधिकतम टिकट साइज', value: highestTicketSizeNotary, onChanged: (v) => setDialogState(() => highestTicketSizeNotary = v ?? 'YES'))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _buildPropertyYesNoField(label: 'Property under HIGH tension line funding', hindiLabel: 'हाई टेंशन लाइन के नीचे संपत्ति फंडिंग', value: highTensionLine, onChanged: (v) => setDialogState(() => highTensionLine = v ?? 'NO'))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildPropertyYesNoField(label: 'Without diversion property funding', hindiLabel: 'बिना डायवर्जन संपत्ति फंडिंग', value: withoutDiversion, onChanged: (v) => setDialogState(() => withoutDiversion = v ?? 'NO'))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _buildPropertyYesNoField(label: 'Only diversion property funding', hindiLabel: 'केवल डायवर्जन संपत्ति फंडिंग', value: onlyDiversion, onChanged: (v) => setDialogState(() => onlyDiversion = v ?? 'YES'))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildPropertyYesNoField(label: 'AKVN Property funding', hindiLabel: 'AKVN संपत्ति फंडिंग', value: akvnProperty, onChanged: (v) => setDialogState(() => akvnProperty = v ?? 'YES'))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _buildPropertyYesNoField(label: 'Green belt property funding', hindiLabel: 'ग्रीन बेल्ट संपत्ति फंडिंग', value: greenBeltProperty, onChanged: (v) => setDialogState(() => greenBeltProperty = v ?? 'NO'))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildPropertyYesNoField(label: 'Plot purchase', hindiLabel: 'प्लॉट खरीद फंडिंग', value: plotPurchase, onChanged: (v) => setDialogState(() => plotPurchase = v ?? 'YES'))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildPropertyYesNoField(label: 'Plot mortgage', hindiLabel: 'प्लॉट बंधक / मॉर्टगेज', value: plotMortgage, onChanged: (v) => setDialogState(() => plotMortgage = v ?? 'YES'))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // SECTION 4: PERSONAL LOAN EXCLUSIVE POLICIES
                      if (isPersonalLoan) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.person_pin_outlined, color: Colors.blueAccent, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '4. PERSONAL LOAN EXCLUSIVE POLICIES (पर्सनल लोन अंडरराइटिंग मानदंड)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: isSalarySlipRequired,
                                      dropdownColor: AppTheme.obsidianMedium,
                                      decoration: const InputDecoration(labelText: 'Is Salary Slip Required? *'),
                                      items: const [
                                        DropdownMenuItem(value: 'YES', child: Text('YES - Salary Slip Mandatory (अनिवार्य)')),
                                        DropdownMenuItem(value: 'NO', child: Text('NO - Banking / Surrogate Program Allowed')),
                                      ],
                                      onChanged: (v) => setDialogState(() => isSalarySlipRequired = v ?? 'YES'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: residenceOwnershipType,
                                      dropdownColor: AppTheme.obsidianMedium,
                                      decoration: const InputDecoration(labelText: 'Customer Residence Status *'),
                                      items: const [
                                        DropdownMenuItem(value: 'Owned Only', child: Text('Owned Only Required (केवल खुद का मकान)')),
                                        DropdownMenuItem(value: 'Rented Allowed', child: Text('Rented Allowed (किरायेदार भी मान्य)')),
                                      ],
                                      onChanged: (v) => setDialogState(() => residenceOwnershipType = v ?? 'Owned Only'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // SECTION 4: BUSINESS LOAN EXCLUSIVE POLICIES
                      if (isBusinessLoan) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreen.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.storefront_outlined, color: AppTheme.emeraldGreen, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '4. BUSINESS LOAN EXCLUSIVE POLICIES (बिजनेस लोन अंडरराइटिंग एवं बैंकिंग मानदंड)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen, letterSpacing: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: businessOwnershipType,
                                      dropdownColor: AppTheme.obsidianMedium,
                                      decoration: const InputDecoration(labelText: 'Residence / Business Ownership *'),
                                      items: const [
                                        DropdownMenuItem(value: 'At least One Owned Required', child: Text('At least One Owned Required (Residence or Office)')),
                                        DropdownMenuItem(value: 'Both Rented Allowed', child: Text('Both Rented Allowed')),
                                      ],
                                      onChanged: (v) => setDialogState(() => businessOwnershipType = v ?? 'At least One Owned Required'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: bankingsConsidered,
                                      dropdownColor: AppTheme.obsidianMedium,
                                      decoration: const InputDecoration(labelText: 'Bankings Considered *'),
                                      items: const [
                                        DropdownMenuItem(value: '1', child: Text('1 Month Banking')),
                                        DropdownMenuItem(value: '2', child: Text('2 Months Banking')),
                                        DropdownMenuItem(value: '3', child: Text('3 Months Banking')),
                                        DropdownMenuItem(value: '4', child: Text('4 Months Banking')),
                                        DropdownMenuItem(value: '5', child: Text('5 Months Banking')),
                                        DropdownMenuItem(value: '6', child: Text('6 Months Banking')),
                                        DropdownMenuItem(value: '6+', child: Text('6+ Months Banking')),
                                      ],
                                      onChanged: (v) => setDialogState(() => bankingsConsidered = v ?? '6'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildPropertyYesNoField(label: 'IS GST REQUIRED? *', hindiLabel: 'GST रजिस्ट्रेशन अनिवार्य', value: isGstRequired, onChanged: (v) => setDialogState(() => isGstRequired = v ?? 'YES'))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildPropertyYesNoField(label: 'IS ITR REQUIRED? *', hindiLabel: 'ITR रिटर्न अनिवार्य', value: isItrRequired, onChanged: (v) => setDialogState(() => isItrRequired = v ?? 'YES'))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: _buildPropertyYesNoField(label: 'IS UDYAM REQUIRED? *', hindiLabel: 'उद्यम आधार अनिवार्य', value: isUdyamRequired, onChanged: (v) => setDialogState(() => isUdyamRequired = v ?? 'YES'))),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildPropertyYesNoField(label: 'CURRENT A/C REQUIRED? *', hindiLabel: 'करंट अकाउंट अनिवार्य', value: isCurrentAccountRequired, onChanged: (v) => setDialogState(() => isCurrentAccountRequired = v ?? 'YES'))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  final updates = Map<String, dynamic>.from(policy);
                  updates['bank_name'] = bankNameController.text.trim();
                  updates['loan_type'] = loanType;
                  updates['vertical'] = vertical;
                  updates['product_type'] = vertical;
                  updates['segment'] = segment;
                  updates['m_profile_allowed'] = mProfileAllowed;
                  updates['banker_name'] = bankerNameController.text.trim();
                  updates['banker_mobile'] = bankerMobileController.text.trim();
                  updates['office_address'] = officeAddressController.text.trim();
                  updates['l1_manager_name'] = l1NameController.text.trim();
                  updates['l1_manager_mobile'] = l1MobileController.text.trim();
                  updates['l2_manager_name'] = l2NameController.text.trim();
                  updates['l2_manager_mobile'] = l2MobileController.text.trim();
                  updates['min_ticket_size'] = minTicketController.text.trim();
                  updates['max_ticket_size'] = maxTicketController.text.trim();
                  updates['interest_rate'] = roiController.text.trim();
                  updates['ltv_ratio'] = isUnsecured ? null : ltvController.text.trim();
                  updates['ltv_on_plot'] = isHomeOrMortgage ? ltvOnPlotController.text.trim() : null;
                  updates['min_cibil'] = int.tryParse(minCibilController.text.trim()) ?? 700;
                  updates['min_income'] = minIncomeController.text.trim();
                  updates['max_allowed_bounces'] = int.tryParse(maxBouncesController.text.trim()) ?? 0;
                  updates['geo_radius'] = geoController.text.trim();
                  updates['approved_pincodes'] = pincodesController.text.trim();
                  updates['login_fee'] = loginFeeController.text.trim();
                  updates['processing_fee'] = processingFeeController.text.trim();
                  updates['tat_days'] = tatController.text.trim();
                  updates['special_features'] = specialFeaturesController.text.trim();
                  updates['one_pager_policy_url'] = onePagerPolicyUrl;

                  updates['age_limit'] = isHomeOrMortgage ? ageLimitController.text.trim() : null;
                  updates['repayment_tenure'] = isHomeOrMortgage ? repaymentTenureController.text.trim() : null;
                  updates['foir_norms'] = isHomeOrMortgage ? foirNormsController.text.trim() : null;
                  updates['existing_obligations'] = isHomeOrMortgage ? existingObligationsController.text.trim() : null;
                  updates['employment_stability'] = isHomeOrMortgage ? employmentStabilityController.text.trim() : null;
                  updates['road_winding_property_funding'] = isHomeOrMortgage ? roadWindingProperty : null;
                  updates['gram_panchayat_property_funding'] = isHomeOrMortgage ? gramPanchayatProperty : null;
                  updates['notary_to_registry_funding'] = isHomeOrMortgage ? notaryToRegistry : null;
                  updates['gram_panchayat_patta_funding'] = isHomeOrMortgage ? gramPanchayatPatta : null;
                  updates['dron_patta_funding'] = isHomeOrMortgage ? dronPatta : null;
                  updates['highest_ticket_size_notary'] = isHomeOrMortgage ? highestTicketSizeNotary : null;
                  updates['high_tension_line_funding'] = isHomeOrMortgage ? highTensionLine : null;
                  updates['without_diversion_property_funding'] = isHomeOrMortgage ? withoutDiversion : null;
                  updates['only_diversion_property_funding'] = isHomeOrMortgage ? onlyDiversion : null;
                  updates['akvn_property_funding'] = isHomeOrMortgage ? akvnProperty : null;
                  updates['green_belt_property_funding'] = isHomeOrMortgage ? greenBeltProperty : null;
                  updates['plot_purchase'] = isHomeOrMortgage ? plotPurchase : null;
                  updates['plot_mortgage'] = isHomeOrMortgage ? plotMortgage : null;

                  updates['is_salary_slip_required'] = isPersonalLoan ? isSalarySlipRequired : null;
                  updates['residence_ownership_type'] = isPersonalLoan ? residenceOwnershipType : null;

                  updates['business_ownership_type'] = isBusinessLoan ? businessOwnershipType : null;
                  updates['is_gst_required'] = isBusinessLoan ? isGstRequired : null;
                  updates['is_itr_required'] = isBusinessLoan ? isItrRequired : null;
                  updates['is_udyam_required'] = isBusinessLoan ? isUdyamRequired : null;
                  updates['is_current_account_required'] = isBusinessLoan ? isCurrentAccountRequired : null;
                  updates['bankings_considered'] = isBusinessLoan ? bankingsConsidered : null;

                  _approvePolicy(policy, updates);
                },
                icon: const Icon(Icons.merge_type, size: 18),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
                label: const Text('Save, Approve & Merge with Banker Policies'),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildPropertyYesNoField({
    required String label,
    required String hindiLabel,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    final isYes = value.toUpperCase() == 'YES';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  hindiLabel,
                  style: const TextStyle(fontSize: 9.5, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isYes ? AppTheme.emeraldGreen.withOpacity(0.15) : AppTheme.rubyRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isYes ? AppTheme.emeraldGreen.withOpacity(0.4) : AppTheme.rubyRed.withOpacity(0.4)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: isYes ? 'YES' : 'NO',
                dropdownColor: AppTheme.obsidianMedium,
                isDense: true,
                items: const [
                  DropdownMenuItem(
                    value: 'YES',
                    child: Text('YES', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  DropdownMenuItem(
                    value: 'NO',
                    child: Text('NO', style: TextStyle(color: AppTheme.rubyRed, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 175,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _buildPropertyStatusChip(String label, dynamic val) {
    final isYes = (val?.toString().toUpperCase() ?? 'NO') == 'YES';
    return Container(
      width: 215,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isYes ? AppTheme.emeraldGreen.withOpacity(0.08) : AppTheme.rubyRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isYes ? AppTheme.emeraldGreen.withOpacity(0.3) : AppTheme.rubyRed.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 10.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: isYes ? AppTheme.emeraldGreen.withOpacity(0.2) : AppTheme.rubyRed.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isYes ? 'YES' : 'NO',
              style: TextStyle(
                color: isYes ? AppTheme.emeraldGreen : AppTheme.rubyRed,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.approval_outlined, color: AppTheme.royalGold, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'App Uploaded Policies',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Banker policies submitted or updated via mobile app ("Update Bank Policy") for review, modification & direct merge into CRM Banker Policies.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadPendingPolicies,
                icon: const Icon(Icons.refresh, color: AppTheme.royalGold),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
                : _pendingPolicies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_outlined, size: 64, color: Colors.grey.shade600),
                            const SizedBox(height: 16),
                            const Text(
                              'कोई लंबित पॉलिसी नहीं है (No Pending App Policies)',
                              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'All banker submitted policies are approved and merged with CRM Banker Policies.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _pendingPolicies.length,
                        itemBuilder: (context, index) {
                          final p = _pendingPolicies[index];
                          final bankName = p['bank_name'] ?? 'Unknown Bank';
                          final bankerName = p['banker_name'] ?? p['uploaded_by_name'] ?? 'Banker';
                          final bankerMobile = p['banker_mobile'] ?? p['uploaded_by_mobile'] ?? 'N/A';
                          final officeAddress = p['office_address'] ?? '';
                          final l1Name = p['l1_manager_name'] ?? '';
                          final l1Mobile = p['l1_manager_mobile'] ?? '';
                          final l2Name = p['l2_manager_name'] ?? '';
                          final l2Mobile = p['l2_manager_mobile'] ?? '';
                          final loanType = p['loan_type'] ?? 'Home Loan';
                          final vertical = p['vertical'] ?? p['product_type'] ?? 'Prime';
                          final segment = p['segment'] ?? 'DSA';
                          final mProfile = p['m_profile_allowed'] ?? 'YES';
                          final minTicket = p['min_ticket_size'] ?? '₹1,00,000';
                          final maxTicket = p['max_ticket_size'] ?? (p['max_loan_amount'] ?? '₹50,00,000');
                          final roi = p['interest_rate'] ?? 'N/A';
                          final geo = p['geo_radius'] ?? 'N/A';
                          final pincodes = p['approved_pincodes'] ?? '';
                          final onePagerUrl = p['one_pager_policy_url'];
                          final isHomeOrLap = (loanType == 'Home Loan' || loanType == 'Mortgage Loan');
                          final isPersonal = (loanType == 'Personal Loan');
                          final isBusiness = (loanType == 'Business Loan');

                          return Card(
                            margin: const EdgeInsets.only(bottom: 18),
                            color: AppTheme.obsidianMedium,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: AppTheme.royalGold.withOpacity(0.35)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Row
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.royalGold.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.account_balance, color: AppTheme.royalGold, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  bankName,
                                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                                const SizedBox(width: 10),
                                                _buildBadge(loanType, AppTheme.royalGold),
                                                const SizedBox(width: 6),
                                                _buildBadge('VERTICAL: $vertical', Colors.tealAccent),
                                                const SizedBox(width: 6),
                                                _buildBadge('SEGMENT: $segment', Colors.indigoAccent),
                                                const SizedBox(width: 6),
                                                _buildBadge(
                                                  'M-PROFILE: $mProfile',
                                                  mProfile == 'YES' ? AppTheme.emeraldGreen : AppTheme.rubyRed,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Uploaded by Banker: $bankerName ($bankerMobile)${officeAddress.toString().isNotEmpty ? " • Branch: $officeAddress" : ""}',
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                            ),
                                            if (l1Name.toString().isNotEmpty || l2Name.toString().isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Hierarchy: ${l1Name.toString().isNotEmpty ? "L1 Manager: $l1Name ($l1Mobile)" : ""}${l1Name.toString().isNotEmpty && l2Name.toString().isNotEmpty ? " | " : ""}${l2Name.toString().isNotEmpty ? "L2 Manager: $l2Name ($l2Mobile)" : ""}',
                                                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.amber.withOpacity(0.5)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.hourglass_top, color: Colors.amber, size: 13),
                                            SizedBox(width: 4),
                                            Text(
                                              'PENDING CRM APPROVAL',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24, color: Colors.white10),

                                  // Core Underwriting Parameters
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: [
                                      _buildBadge('Ticket: $minTicket - $maxTicket', Colors.cyanAccent),
                                      _buildBadge('ROI: $roi', Colors.amber),
                                      if (!isPersonal && !isBusiness && p['ltv_ratio'] != null && p['ltv_ratio'].toString().isNotEmpty)
                                        _buildBadge('LTV: ${p['ltv_ratio']}', Colors.purpleAccent),
                                      _buildBadge('Min CIBIL: ${p['min_cibil'] ?? 700}', AppTheme.emeraldGreen),
                                      if (p['min_income'] != null && p['min_income'].toString().isNotEmpty)
                                        _buildBadge('Min Income: ${p['min_income']}', AppTheme.royalGold),
                                      _buildBadge('Max Bounces (BT): ${p['max_allowed_bounces'] ?? 0}', Colors.orangeAccent),
                                      _buildBadge('Geo Radius: $geo', Colors.blueAccent),
                                      _buildBadge('Login Fee: ${p['login_fee'] ?? 'Nil'}', Colors.pinkAccent),
                                      if (p['processing_fee'] != null && p['processing_fee'].toString().isNotEmpty)
                                        _buildBadge('PF: ${p['processing_fee']}', Colors.tealAccent),
                                      if (p['tat_days'] != null && p['tat_days'].toString().isNotEmpty)
                                        _buildBadge('TAT: ${p['tat_days']}', Colors.lightGreenAccent),
                                      if (pincodes.toString().isNotEmpty)
                                        _buildBadge('📍 Approved Pincodes: $pincodes', Colors.indigoAccent),
                                    ],
                                  ),

                                  // Category-Specific Full Details Box
                                  if (isHomeOrLap) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: AppTheme.royalGold.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.royalGold.withOpacity(0.2)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'HOME & MORTGAGE LOAN UNDERWRITING & 13 PROPERTY NORMS SUBMITTED BY BANKER:',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 0.5),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildDetailRow('Age Limit & Tenure:', '${p['age_limit'] ?? '21 - 65 Years'} | Tenure: ${p['repayment_tenure'] ?? 'Up to 30 Years'}'),
                                          _buildDetailRow('FOIR Norms:', p['foir_norms'] ?? 'Standard Slabs'),
                                          _buildDetailRow('Existing Obligations:', p['existing_obligations'] ?? 'Deducted from net income'),
                                          _buildDetailRow('Employment Stability:', p['employment_stability'] ?? 'Min 2 yrs total / 1 yr current'),
                                          _buildDetailRow('LTV on Plot:', p['ltv_on_plot'] ?? 'Standard Plot LTV'),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _buildPropertyStatusChip('Road Winding Property', p['road_winding_property_funding']),
                                              _buildPropertyStatusChip('Gram Panchayat Property', p['gram_panchayat_property_funding']),
                                              _buildPropertyStatusChip('Notary to Registry', p['notary_to_registry_funding']),
                                              _buildPropertyStatusChip('Gram Panchayat Patta', p['gram_panchayat_patta_funding']),
                                              _buildPropertyStatusChip('Dron Patta Funding', p['dron_patta_funding']),
                                              _buildPropertyStatusChip('Highest Ticket Notary', p['highest_ticket_size_notary']),
                                              _buildPropertyStatusChip('High Tension Line', p['high_tension_line_funding']),
                                              _buildPropertyStatusChip('Without Diversion', p['without_diversion_property_funding']),
                                              _buildPropertyStatusChip('Only Diversion', p['only_diversion_property_funding']),
                                              _buildPropertyStatusChip('AKVN Property Funding', p['akvn_property_funding']),
                                              _buildPropertyStatusChip('Green Belt Property', p['green_belt_property_funding']),
                                              _buildPropertyStatusChip('Plot Purchase Funding', p['plot_purchase']),
                                              _buildPropertyStatusChip('Plot Mortgage Funding', p['plot_mortgage']),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  if (isPersonal) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'PERSONAL LOAN EXCLUSIVE CRITERIA SUBMITTED BY BANKER:',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                          ),
                                          const SizedBox(height: 6),
                                          _buildDetailRow('Salary Slip Required:', p['is_salary_slip_required'] ?? 'YES'),
                                          _buildDetailRow('Residence Ownership:', p['residence_ownership_type'] ?? 'Owned Only'),
                                        ],
                                      ),
                                    ),
                                  ],

                                  if (isBusiness) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emeraldGreen.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.emeraldGreen.withValues(alpha: 0.25)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'BUSINESS LOAN EXCLUSIVE CRITERIA SUBMITTED BY BANKER:',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen),
                                          ),
                                          const SizedBox(height: 6),
                                          _buildDetailRow('Business / Residence Ownership:', p['business_ownership_type'] ?? 'At least One Owned Required'),
                                          _buildDetailRow('Bankings Considered:', '${p['bankings_considered'] ?? '6'} Months'),
                                          _buildDetailRow(
                                            'Mandatory Registrations:',
                                            'GST: ${p['is_gst_required'] ?? 'YES'} | ITR: ${p['is_itr_required'] ?? 'YES'} | Udyam: ${p['is_udyam_required'] ?? 'YES'} | Current A/C: ${p['is_current_account_required'] ?? 'YES'}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  if (p['special_features'] != null && p['special_features'].toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      'Special Guidelines: ${p['special_features']}',
                                      style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                                    ),
                                  ],

                                  if (onePagerUrl != null && onePagerUrl.toString().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.description_outlined, color: AppTheme.royalGold, size: 18),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'One Pager Policy Document Attached:',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: SelectableText(
                                              onePagerUrl.toString(),
                                              style: const TextStyle(fontSize: 11, color: AppTheme.royalGold),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy, size: 15, color: AppTheme.royalGold),
                                            tooltip: 'Copy Document Link',
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: onePagerUrl.toString()));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('One Pager document link copied!')),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _rejectPolicy(p),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: const Text('Reject'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.rubyRed,
                                          side: const BorderSide(color: AppTheme.rubyRed),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: () => _showModifyDialog(p),
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Modify & Review All Fields'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.royalGold,
                                          side: const BorderSide(color: AppTheme.royalGold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        onPressed: () => _approvePolicy(p),
                                        icon: const Icon(Icons.merge_type, size: 18),
                                        label: const Text('Approve & Merge with Banker Policies'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.emeraldGreen,
                                          foregroundColor: Colors.white,
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

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
