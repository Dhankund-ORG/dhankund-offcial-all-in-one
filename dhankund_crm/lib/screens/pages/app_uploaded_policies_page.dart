import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../api_service.dart';

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
            content: Text('Bank policy approved and aligned with active CRM policies!'),
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
    final bankNameController = TextEditingController(text: policy['bank_name'] ?? '');
    final bankerNameController = TextEditingController(text: policy['banker_name'] ?? '');
    final bankerMobileController = TextEditingController(text: policy['banker_mobile'] ?? '');
    final officeAddressController = TextEditingController(text: policy['office_address'] ?? '');
    final l1NameController = TextEditingController(text: policy['l1_manager_name'] ?? '');
    final l1MobileController = TextEditingController(text: policy['l1_manager_mobile'] ?? '');
    final l2NameController = TextEditingController(text: policy['l2_manager_name'] ?? '');
    final l2MobileController = TextEditingController(text: policy['l2_manager_mobile'] ?? '');
    final minTicketController = TextEditingController(text: policy['min_ticket_size'] ?? '₹1,00,000');
    final maxTicketController = TextEditingController(text: policy['max_ticket_size'] ?? '₹50,00,000');
    final roiController = TextEditingController(text: policy['interest_rate'] ?? '');
    final ltvController = TextEditingController(text: policy['ltv_ratio'] ?? '');
    final geoController = TextEditingController(text: policy['geo_radius'] ?? '');
    final pincodesController = TextEditingController(text: policy['approved_pincodes'] ?? '');
    final minCibilController = TextEditingController(text: (policy['min_cibil'] ?? 700).toString());
    final minIncomeController = TextEditingController(text: policy['min_income'] ?? '₹25,000 / mo');
    final maxBouncesController = TextEditingController(text: (policy['max_allowed_bounces'] ?? 0).toString());
    final loginFeeController = TextEditingController(text: policy['login_fee'] ?? 'Nil');
    final processingFeeController = TextEditingController(text: policy['processing_fee'] ?? '1.00%');
    final tatController = TextEditingController(text: policy['tat_days'] ?? '3 Days');
    final specialFeaturesController = TextEditingController(text: policy['special_features'] ?? '');

    String loanType = ['Personal Loan', 'Business Loan', 'Home Loan', 'Mortgage Loan', 'Car Loan', 'Commercial Vehicle Loan', 'CC/OD Limit']
            .contains(policy['loan_type'])
        ? policy['loan_type']
        : 'Home Loan';
    String vertical = ['Prime', 'Affordable', 'Informal'].contains(policy['vertical'])
        ? policy['vertical']
        : 'Prime';
    String segment = ['DSA', 'Connector', 'Direct'].contains(policy['segment'])
        ? policy['segment']
        : 'DSA';
    String mProfileAllowed = (policy['m_profile_allowed'] ?? 'YES').toString().toUpperCase() == 'NO' ? 'NO' : 'YES';

    Future<void> pickExcelPincodes() async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['xlsx', 'xls', 'csv', 'txt'],
          withData: true,
        );
        if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
          final matches = await _api.parsePincodesFromFile(result.files.first.bytes!);
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
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.obsidianMedium,
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: AppTheme.royalGold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review & Modify App Uploaded Policy - ${policy['bank_name']}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 680,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: bankNameController,
                          decoration: const InputDecoration(labelText: 'Bank Name *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: vertical,
                          dropdownColor: AppTheme.obsidianMedium,
                          decoration: const InputDecoration(labelText: 'Vertical *'),
                          items: const [
                            DropdownMenuItem(value: 'Prime', child: Text('Prime')),
                            DropdownMenuItem(value: 'Affordable', child: Text('Affordable')),
                            DropdownMenuItem(value: 'Informal', child: Text('Informal')),
                          ],
                          onChanged: (v) => setDialogState(() => vertical = v ?? vertical),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: segment,
                          dropdownColor: AppTheme.obsidianMedium,
                          decoration: const InputDecoration(labelText: 'Segment *'),
                          items: const [
                            DropdownMenuItem(value: 'DSA', child: Text('DSA')),
                            DropdownMenuItem(value: 'Connector', child: Text('Connector')),
                            DropdownMenuItem(value: 'Direct', child: Text('Direct')),
                          ],
                          onChanged: (v) => setDialogState(() => segment = v ?? segment),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: bankerNameController,
                          decoration: const InputDecoration(labelText: 'Bank Officer Name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: bankerMobileController,
                          decoration: const InputDecoration(labelText: 'Bank Officer Mobile'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: officeAddressController,
                    decoration: const InputDecoration(labelText: 'Office / Branch Address'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: l1NameController,
                          decoration: const InputDecoration(labelText: 'L1 Manager Name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: l1MobileController,
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
                          controller: l2NameController,
                          decoration: const InputDecoration(labelText: 'L2 Manager Name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: l2MobileController,
                          decoration: const InputDecoration(labelText: 'L2 Manager Mobile'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: minTicketController,
                          decoration: const InputDecoration(labelText: 'Min Ticket Size'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: maxTicketController,
                          decoration: const InputDecoration(labelText: 'Max Ticket Size'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: roiController,
                          decoration: const InputDecoration(labelText: 'ROI / Interest Rate *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: ltvController,
                          decoration: const InputDecoration(labelText: 'LTV Ratio'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: minCibilController,
                          decoration: const InputDecoration(labelText: 'Min CIBIL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: minIncomeController,
                          decoration: const InputDecoration(labelText: 'Min Income / Turnover'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: maxBouncesController,
                          decoration: const InputDecoration(labelText: 'Max Bounces'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: geoController,
                          decoration: const InputDecoration(labelText: 'Geo Location Radius'),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                              label: const Text('Excel'),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: loginFeeController,
                          decoration: const InputDecoration(labelText: 'Bank Login Fee'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: processingFeeController,
                          decoration: const InputDecoration(labelText: 'Processing Fee'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: tatController,
                          decoration: const InputDecoration(labelText: 'TAT Days'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: specialFeaturesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Special Features / Guidelines'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
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
                updates['ltv_ratio'] = ltvController.text.trim();
                updates['min_cibil'] = int.tryParse(minCibilController.text.trim()) ?? 700;
                updates['min_income'] = minIncomeController.text.trim();
                updates['max_allowed_bounces'] = int.tryParse(maxBouncesController.text.trim()) ?? 0;
                updates['geo_radius'] = geoController.text.trim();
                updates['approved_pincodes'] = pincodesController.text.trim();
                updates['login_fee'] = loginFeeController.text.trim();
                updates['processing_fee'] = processingFeeController.text.trim();
                updates['tat_days'] = tatController.text.trim();
                updates['special_features'] = specialFeaturesController.text.trim();
                _approvePolicy(policy, updates);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
              child: const Text('Save & Approve Policy'),
            ),
          ],
        ),
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
                    'Banker policies submitted via mobile app requiring review and verification before alignment with active policies.',
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
                              'All banker submitted policies are approved and aligned.',
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
                          final loanType = p['loan_type'] ?? 'General Loan';
                          final roi = p['interest_rate'] ?? 'N/A';
                          final geo = p['geo_radius'] ?? 'N/A';
                          final pincodes = p['approved_pincodes'] ?? '';
                          final onePagerUrl = p['one_pager_policy_url'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            color: AppTheme.obsidianMedium,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppTheme.royalGold.withOpacity(0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                            Text(
                                              bankName,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Uploaded by: $bankerName ($bankerMobile)',
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                            ),
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
                                              'PENDING APPROVAL',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24, color: Colors.white10),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      _buildBadge('Loan Type: $loanType', Colors.blueAccent),
                                      _buildBadge('ROI: $roi', Colors.amber),
                                      _buildBadge('Geo Radius: $geo', Colors.cyanAccent),
                                      if (p['min_cibil'] != null)
                                        _buildBadge('Min CIBIL: ${p['min_cibil']}', AppTheme.emeraldGreen),
                                      if (p['ltv_ratio'] != null && p['ltv_ratio'].toString().isNotEmpty)
                                        _buildBadge('LTV: ${p['ltv_ratio']}', Colors.purpleAccent),
                                      if (pincodes.toString().isNotEmpty)
                                        _buildBadge('📍 Pincodes: $pincodes', Colors.indigoAccent),
                                    ],
                                  ),
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
                                            'One Pager Policy Document Attached',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                                          ),
                                          const Spacer(),
                                          Text(
                                            onePagerUrl.toString().split('/').last,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.royalGold),
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
                                        label: const Text('Modify & Review'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.royalGold,
                                          side: const BorderSide(color: AppTheme.royalGold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ElevatedButton.icon(
                                        onPressed: () => _approvePolicy(p),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('Approve & Align Policy'),
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

