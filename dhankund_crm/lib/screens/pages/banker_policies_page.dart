import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../api_service.dart';

class BankerPoliciesPage extends StatefulWidget {
  const BankerPoliciesPage({super.key});

  @override
  State<BankerPoliciesPage> createState() => _BankerPoliciesPageState();
}

class _BankerPoliciesPageState extends State<BankerPoliciesPage> {
  final ApiService _firestoreService = ApiService();
  List<Map<String, dynamic>> _policies = [];
  bool _isLoading = true;
  String _selectedLoanType = 'All';
  String _selectedProductType = 'All';
  String _selectedVertical = 'All';
  String _searchQuery = '';

  final List<String> _loanTypeFilters = [
    'All',
    'Personal Loan',
    'Business Loan',
    'Home Loan',
    'Mortgage Loan',
  ];

  final List<String> _productTypeFilters = [
    'All',
    'Prime',
    'Affordable',
    'Informal',
  ];

  final List<String> _verticalFilters = [
    'All',
    'DSA',
    'Connector',
    'Direct',
  ];

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    setState(() => _isLoading = true);
    final data = await _firestoreService.fetchBankPolicies();
    if (mounted) {
      setState(() {
        _policies = data;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPolicies {
    return _policies.where((p) {
      final matchesType = _selectedLoanType == 'All' || p['loan_type'] == _selectedLoanType;
      final matchesProduct = _selectedProductType == 'All' || p['product_type'] == _selectedProductType;
      final matchesVertical = _selectedVertical == 'All' || p['vertical'] == _selectedVertical;
      final matchesSearch = _searchQuery.isEmpty ||
          (p['bank_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (p['banker_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (p['office_address']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (p['l1_manager_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (p['l2_manager_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (p['special_features']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesType && matchesProduct && matchesVertical && matchesSearch;
    }).toList();
  }

  void _showPolicyDialog({Map<String, dynamic>? existingPolicy}) {
    final isEdit = existingPolicy != null;
    final formKey = GlobalKey<FormState>();

    final bankNameController = TextEditingController(text: existingPolicy?['bank_name'] ?? '');
    final bankerNameController = TextEditingController(text: existingPolicy?['banker_name'] ?? '');
    final bankerMobileController = TextEditingController(text: existingPolicy?['banker_mobile'] ?? '');
    final officeAddressController = TextEditingController(text: existingPolicy?['office_address'] ?? '');
    
    // L1 & L2 Managers
    final l1NameController = TextEditingController(text: existingPolicy?['l1_manager_name'] ?? '');
    final l1MobileController = TextEditingController(text: existingPolicy?['l1_manager_mobile'] ?? '');
    final l2NameController = TextEditingController(text: existingPolicy?['l2_manager_name'] ?? '');
    final l2MobileController = TextEditingController(text: existingPolicy?['l2_manager_mobile'] ?? '');

    // Underwriting & Parameters
    final minCibilController = TextEditingController(text: (existingPolicy?['min_cibil'] ?? 700).toString());
    final minIncomeController = TextEditingController(text: existingPolicy?['min_income'] ?? '₹25,000 / mo');
    final minTicketSizeController = TextEditingController(text: existingPolicy?['min_ticket_size'] ?? '₹1,00,000');
    final maxTicketSizeController = TextEditingController(text: existingPolicy?['max_ticket_size'] ?? (existingPolicy?['max_loan_amount'] ?? '₹50,00,000'));
    final ltvRatioController = TextEditingController(text: existingPolicy?['ltv_ratio'] ?? 'Up to 90% LTV');
    final maxBouncesController = TextEditingController(text: (existingPolicy?['max_allowed_bounces'] ?? 0).toString());
    final geoRadiusController = TextEditingController(text: existingPolicy?['geo_radius'] ?? '50 km radius');
    final loginFeeController = TextEditingController(text: existingPolicy?['login_fee'] ?? 'Nil');
    final interestRateController = TextEditingController(text: existingPolicy?['interest_rate'] ?? '10.50% - 13.50%');
    final processingFeeController = TextEditingController(text: existingPolicy?['processing_fee'] ?? '1.00%');
    final tatController = TextEditingController(text: existingPolicy?['tat_days'] ?? '3 Days');
    final specialFeaturesController = TextEditingController(text: existingPolicy?['special_features'] ?? '');

    String loanType = existingPolicy?['loan_type'] ?? 'Personal Loan';
    String vertical = existingPolicy?['vertical'] ?? existingPolicy?['product_type'] ?? 'Prime';
    if (!['Prime', 'Affordable', 'Informal'].contains(vertical)) {
      vertical = 'Prime';
    }
    String productType = vertical;
    String segment = existingPolicy?['segment'] ?? (['DSA', 'Connector', 'Direct'].contains(existingPolicy?['vertical']) ? existingPolicy!['vertical'] : 'DSA');
    String mProfileAllowed = existingPolicy?['m_profile_allowed'] ?? 'YES';

    // Home Loan & Mortgage Loan Exclusive Controllers
    final ageLimitController = TextEditingController(text: existingPolicy?['age_limit'] ?? '21 - 65 Years');
    final foirNormsController = TextEditingController(
      text: existingPolicy?['foir_norms'] ?? '1L-7L: 60% | 7L-10L: 65% | 10L-12L: 70% | >=12L: 75%',
    );
    final existingObligationsController = TextEditingController(
      text: existingPolicy?['existing_obligations'] ?? 'Deducted from net income (>6 months EMI balance counted)',
    );
    final employmentStabilityController = TextEditingController(
      text: existingPolicy?['employment_stability'] ?? 'Min 2 yrs total experience / 1 yr current company',
    );
    final ltvOnPlotController = TextEditingController(
      text: existingPolicy?['ltv_on_plot'] ?? '1L-30L: 90% | 30L-75L: 80% | >=75L: 70%',
    );
    final repaymentTenureController = TextEditingController(
      text: existingPolicy?['repayment_tenure'] ?? 'Up to 30 Years (HL) / 20 Years (LAP)',
    );

    // 13 Property & Collateral Funding Options (YES / NO)
    String roadWindingProperty = existingPolicy?['road_winding_property_funding'] ?? 'YES';
    String gramPanchayatProperty = existingPolicy?['gram_panchayat_property_funding'] ?? 'YES';
    String notaryToRegistry = existingPolicy?['notary_to_registry_funding'] ?? 'YES';
    String gramPanchayatPatta = existingPolicy?['gram_panchayat_patta_funding'] ?? 'YES';
    String dronPatta = existingPolicy?['dron_patta_funding'] ?? 'YES';
    String highestTicketSizeNotary = existingPolicy?['highest_ticket_size_notary'] ?? 'YES';
    String highTensionLine = existingPolicy?['high_tension_line_funding'] ?? 'NO';
    String withoutDiversion = existingPolicy?['without_diversion_property_funding'] ?? 'NO';
    String onlyDiversion = existingPolicy?['only_diversion_property_funding'] ?? 'YES';
    String akvnProperty = existingPolicy?['akvn_property_funding'] ?? 'YES';
    String greenBeltProperty = existingPolicy?['green_belt_property_funding'] ?? 'NO';
    String plotPurchase = existingPolicy?['plot_purchase'] ?? 'YES';
    String plotMortgage = existingPolicy?['plot_mortgage'] ?? 'YES';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isHomeOrMortgage = (loanType == 'Home Loan' || loanType == 'Mortgage Loan');

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
                    isEdit ? 'Edit Bank Credit Policy' : 'Add New Bank Policy',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
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
                        // SECTION 1: Bank, Product & Vertical Category
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
                                decoration: const InputDecoration(labelText: 'Bank / NBFC Name *', hintText: 'e.g. HDFC Bank, ICICI Bank'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
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
                                items: [
                                  'Personal Loan',
                                  'Business Loan',
                                  'Home Loan',
                                  'Mortgage Loan',
                                  'Car Loan',
                                  'Commercial Vehicle Loan',
                                  'CC/OD Limit',
                                ].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      loanType = val;
                                      if ((val == 'Home Loan' || val == 'Mortgage Loan') && (ltvRatioController.text == 'Up to 90% LTV' || ltvRatioController.text.isEmpty)) {
                                        ltvRatioController.text = '1L-30L: 90% | 30L-75L: 80% | >=75L: 70%';
                                      }
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
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: vertical,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(
                                  labelText: 'Vertical *',
                                  helperText: 'Prime / Affordable / Informal',
                                  helperStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Prime', child: Text('Prime (Standard Tier-1)')),
                                  DropdownMenuItem(value: 'Affordable', child: Text('Affordable (Sub-Prime / Low Ticket)')),
                                  DropdownMenuItem(value: 'Informal', child: Text('Informal (Cash / Surrogate Segment)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      vertical = val;
                                      productType = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: segment,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(
                                  labelText: 'Segment *',
                                  helperText: 'DSA / Connector / Direct',
                                  helperStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'DSA', child: Text('DSA Channel')),
                                  DropdownMenuItem(value: 'Connector', child: Text('Connector Network')),
                                  DropdownMenuItem(value: 'Direct', child: Text('Direct / Branch Walk-in')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => segment = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // SECTION 2: Officer & Management Escalation Hierarchy (L1 / L2) & Office Address
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
                                decoration: const InputDecoration(labelText: 'Primary Bank Officer Name *', hintText: 'e.g. Amit Verma (SM/Sales)'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: bankerMobileController,
                                decoration: const InputDecoration(labelText: 'Primary Officer Mobile *', hintText: '+91 98765 43210'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: officeAddressController,
                          decoration: const InputDecoration(
                            labelText: 'Bank Office Address / Branch Location',
                            hintText: 'e.g. 4th Floor, Trade Tower, AB Road, Vijay Nagar, Indore (M.P.)',
                            prefixIcon: Icon(Icons.business_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: l1NameController,
                                decoration: const InputDecoration(labelText: 'L1 Manager Name (Team Lead / Cluster Head)', hintText: 'e.g. Rakesh Mehra'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: l1MobileController,
                                decoration: const InputDecoration(labelText: 'L1 Manager Mobile Number', hintText: '+91 98221 00112'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: l2NameController,
                                decoration: const InputDecoration(labelText: 'L2 Manager Name (Area / Zonal Head)', hintText: 'e.g. Siddharth Rao'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: l2MobileController,
                                decoration: const InputDecoration(labelText: 'L2 Manager Mobile Number', hintText: '+91 99334 55667'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // SECTION 3: Underwriting & Operational Eligibility (Min/Max Ticket, LTV, M Profile)
                        const Text(
                          '3. UNDERWRITING CRITERIA, TICKET SIZE, LTV & M PROFILE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: minTicketSizeController,
                                decoration: const InputDecoration(labelText: 'Min. Loan Ticket Size *', hintText: 'e.g. ₹1,00,000'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: maxTicketSizeController,
                                decoration: const InputDecoration(labelText: 'Max. Loan Ticket Size *', hintText: 'e.g. ₹50,00,000'),
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
                                controller: ltvRatioController,
                                decoration: const InputDecoration(
                                  labelText: 'LTV (Loan to Value Ratio) *',
                                  hintText: 'e.g. Up to 90% LTV / N/A (Unsecured)',
                                  helperText: 'For Property / LAP / Home Loans',
                                  helperStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
  isExpanded: true,
                                value: mProfileAllowed,
                                dropdownColor: AppTheme.obsidianMedium,
                                decoration: const InputDecoration(
                                  labelText: 'M Profile Funding *',
                                  helperText: 'Muslim / Minority community loan policy',
                                  helperStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'YES', child: Text('YES - M Profile Funded')),
                                  DropdownMenuItem(value: 'NO', child: Text('NO - M Profile Restricted')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDialogState(() => mProfileAllowed = val);
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
                                controller: minCibilController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Minimum CIBIL Cutoff *', hintText: 'e.g. 700'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: minIncomeController,
                                decoration: const InputDecoration(labelText: 'Min Income / Turnover *', hintText: '₹25,000 / mo or ₹30 Lakh / yr'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: maxBouncesController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Max Allowed Bounces *', hintText: '0, 1 or 2'),
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
                                controller: geoRadiusController,
                                decoration: const InputDecoration(labelText: 'Geo Location (Surrounding Coverage) *', hintText: 'e.g. Up to 50 km from city'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: loginFeeController,
                                decoration: const InputDecoration(labelText: 'Bank Login Fee *', hintText: 'e.g. ₹2,500 + GST or Nil'),
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
                                controller: interestRateController,
                                decoration: const InputDecoration(labelText: 'Interest Rate Range', hintText: 'e.g. 10.25% - 13.50%'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: tatController,
                                decoration: const InputDecoration(labelText: 'Approval TAT', hintText: 'e.g. 2 Days'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: processingFeeController,
                          decoration: const InputDecoration(labelText: 'Processing Fee Policy', hintText: 'e.g. 0.99% flat or ₹3,000 promo'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: specialFeaturesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Special Guidelines / Key Underwriting Highlights',
                            alignLabelWithHint: true,
                            hintText: 'e.g. Immediate digital sanction for Super-A companies, no property verification for loans < ₹30L, banking surrogate program active.',
                          ),
                        ),

                        // SECTION 4: HOME & MORTGAGE LOAN EXCLUSIVE POLICIES (क्रेडिट एवं प्रॉपर्टी नियम)
                        if (isHomeOrMortgage) ...[
                          const SizedBox(height: 24),
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
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.royalGold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Age Limit & Repayment Tenure
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: ageLimitController,
                                        decoration: const InputDecoration(
                                          labelText: 'Age Limit (आयु सीमा) *',
                                          hintText: 'e.g. 21 - 65 Years',
                                          helperText: 'Applicant age limit at loan maturity',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: repaymentTenureController,
                                        decoration: const InputDecoration(
                                          labelText: 'Repayment Tenure (पुनर्भुगतान अवधि) *',
                                          hintText: 'e.g. Up to 30 Years (HL) / 20 Years (LAP)',
                                          helperText: 'Max allowable loan tenure',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Income ratio (FOIR)
                                TextFormField(
                                  controller: foirNormsController,
                                  decoration: const InputDecoration(
                                    labelText: 'Income Ratio (FOIR) *',
                                    hintText: '1L-7L: 60% | 7L-10L: 65% | 10L-12L: 70% | >=12L: 75%',
                                    helperText: 'Norms: 1L-7L = 60%, 7L-10L = 65%, 10L-12L = 70%, 12L & above = 75%',
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Existing Obligations & Employment Stability
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: existingObligationsController,
                                        decoration: const InputDecoration(
                                          labelText: 'Existing Obligations (मौजूदा देनदारियां) *',
                                          hintText: 'e.g. Deducted from net income (>6 months EMI)',
                                          helperText: 'Obligation treatment in FOIR calculation',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: employmentStabilityController,
                                        decoration: const InputDecoration(
                                          labelText: 'Employment Stability Requirement *',
                                          hintText: 'e.g. Min 2 yrs total / 1 yr current company',
                                          helperText: 'Job or business vintage requirement',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // LTV on Plot
                                TextFormField(
                                  controller: ltvOnPlotController,
                                  decoration: const InputDecoration(
                                    labelText: 'LTV on Plot (प्लॉट पर LTV अनुपात) *',
                                    hintText: '1L-30L: 90%/80%/70% | 30L-75L: 90%/80%/70% | >=75L: 90%/80%/70%',
                                    helperText: '1L-30L = 90%/80%/70% LTV, 30L-75L = 90%/80%/70% LTV, 75L+ = 90%/80%/70% LTV',
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // 13 Property Funding Options (Yes/No)
                                const Text(
                                  'PROPERTY & COLLATERAL FUNDING PERMISSIONS (संपत्ति एवं पट्टा फंडिंग नियम)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Road winding property funding',
                                        hindiLabel: 'रोड वाइंडिंग संपत्ति फंडिंग',
                                        value: roadWindingProperty,
                                        onChanged: (v) => setDialogState(() => roadWindingProperty = v ?? 'YES'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Gram panchayat property funding',
                                        hindiLabel: 'ग्राम पंचायत संपत्ति फंडिंग',
                                        value: gramPanchayatProperty,
                                        onChanged: (v) => setDialogState(() => gramPanchayatProperty = v ?? 'YES'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Notry to registry funding',
                                        hindiLabel: 'नोटरी से रजिस्ट्री फंडिंग',
                                        value: notaryToRegistry,
                                        onChanged: (v) => setDialogState(() => notaryToRegistry = v ?? 'YES'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Gram panchayat patta funding',
                                        hindiLabel: 'ग्राम पंचायत पट्टा फंडिंग',
                                        value: gramPanchayatPatta,
                                        onChanged: (v) => setDialogState(() => gramPanchayatPatta = v ?? 'YES'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Dron patta funding',
                                        hindiLabel: 'ड्रोन पट्टा फंडिंग',
                                        value: dronPatta,
                                        onChanged: (v) => setDialogState(() => dronPatta = v ?? 'YES'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Highest ticket size for notry property',
                                        hindiLabel: 'नोटरी प्रॉपर्टी अधिकतम टिकट साइज',
                                        value: highestTicketSizeNotary,
                                        onChanged: (v) => setDialogState(() => highestTicketSizeNotary = v ?? 'YES'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Property under HIGH tension line funding',
                                        hindiLabel: 'हाई टेंशन लाइन के नीचे संपत्ति फंडिंग',
                                        value: highTensionLine,
                                        onChanged: (v) => setDialogState(() => highTensionLine = v ?? 'NO'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Without diversion property funding',
                                        hindiLabel: 'बिना डायवर्जन संपत्ति फंडिंग',
                                        value: withoutDiversion,
                                        onChanged: (v) => setDialogState(() => withoutDiversion = v ?? 'NO'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Only diversion property funding',
                                        hindiLabel: 'केवल डायवर्जन संपत्ति फंडिंग',
                                        value: onlyDiversion,
                                        onChanged: (v) => setDialogState(() => onlyDiversion = v ?? 'YES'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'AKVN Property funding',
                                        hindiLabel: 'AKVN संपत्ति फंडिंग',
                                        value: akvnProperty,
                                        onChanged: (v) => setDialogState(() => akvnProperty = v ?? 'YES'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Green belt property funding',
                                        hindiLabel: 'ग्रीन बेल्ट संपत्ति फंडिंग',
                                        value: greenBeltProperty,
                                        onChanged: (v) => setDialogState(() => greenBeltProperty = v ?? 'NO'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Plot purchase',
                                        hindiLabel: 'प्लॉट खरीद फंडिंग',
                                        value: plotPurchase,
                                        onChanged: (v) => setDialogState(() => plotPurchase = v ?? 'YES'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPropertyYesNoField(
                                        label: 'Plot mortgage',
                                        hindiLabel: 'प्लॉट बंधक / मॉर्टगेज',
                                        value: plotMortgage,
                                        onChanged: (v) => setDialogState(() => plotMortgage = v ?? 'YES'),
                                      ),
                                    ),
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
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(context).pop();

                    await _firestoreService.saveBankPolicy(
                      docId: existingPolicy?['id'],
                      bankName: bankNameController.text.trim(),
                      bankerName: bankerNameController.text.trim(),
                      bankerMobile: bankerMobileController.text.trim(),
                      officeAddress: officeAddressController.text.trim().isNotEmpty ? officeAddressController.text.trim() : null,
                      l1ManagerName: l1NameController.text.trim().isNotEmpty ? l1NameController.text.trim() : null,
                      l1ManagerMobile: l1MobileController.text.trim().isNotEmpty ? l1MobileController.text.trim() : null,
                      l2ManagerName: l2NameController.text.trim().isNotEmpty ? l2NameController.text.trim() : null,
                      l2ManagerMobile: l2MobileController.text.trim().isNotEmpty ? l2MobileController.text.trim() : null,
                      loanType: loanType,
                      productType: productType,
                      vertical: vertical,
                      segment: segment,
                      minCibil: int.tryParse(minCibilController.text.trim()) ?? 700,
                      minIncome: minIncomeController.text.trim(),
                      minTicketSize: minTicketSizeController.text.trim(),
                      maxTicketSize: maxTicketSizeController.text.trim(),
                      ltvRatio: ltvRatioController.text.trim().isNotEmpty ? ltvRatioController.text.trim() : null,
                      ltvOnPlot: isHomeOrMortgage && ltvOnPlotController.text.trim().isNotEmpty ? ltvOnPlotController.text.trim() : null,
                      mProfileAllowed: mProfileAllowed,
                      maxAllowedBounces: int.tryParse(maxBouncesController.text.trim()) ?? 0,
                      geoRadius: geoRadiusController.text.trim(),
                      loginFee: loginFeeController.text.trim(),
                      interestRate: interestRateController.text.trim(),
                      processingFee: processingFeeController.text.trim(),
                      specialFeatures: specialFeaturesController.text.trim(),
                      tatDays: tatController.text.trim(),
                      ageLimit: isHomeOrMortgage && ageLimitController.text.trim().isNotEmpty ? ageLimitController.text.trim() : null,
                      foirNorms: isHomeOrMortgage && foirNormsController.text.trim().isNotEmpty ? foirNormsController.text.trim() : null,
                      existingObligations: isHomeOrMortgage && existingObligationsController.text.trim().isNotEmpty ? existingObligationsController.text.trim() : null,
                      employmentStability: isHomeOrMortgage && employmentStabilityController.text.trim().isNotEmpty ? employmentStabilityController.text.trim() : null,
                      repaymentTenure: isHomeOrMortgage && repaymentTenureController.text.trim().isNotEmpty ? repaymentTenureController.text.trim() : null,
                      roadWindingPropertyFunding: isHomeOrMortgage ? roadWindingProperty : null,
                      gramPanchayatPropertyFunding: isHomeOrMortgage ? gramPanchayatProperty : null,
                      notaryToRegistryFunding: isHomeOrMortgage ? notaryToRegistry : null,
                      gramPanchayatPattaFunding: isHomeOrMortgage ? gramPanchayatPatta : null,
                      dronPattaFunding: isHomeOrMortgage ? dronPatta : null,
                      highestTicketSizeNotary: isHomeOrMortgage ? highestTicketSizeNotary : null,
                      highTensionLineFunding: isHomeOrMortgage ? highTensionLine : null,
                      withoutDiversionPropertyFunding: isHomeOrMortgage ? withoutDiversion : null,
                      onlyDiversionPropertyFunding: isHomeOrMortgage ? onlyDiversion : null,
                      akvnPropertyFunding: isHomeOrMortgage ? akvnProperty : null,
                      greenBeltPropertyFunding: isHomeOrMortgage ? greenBeltProperty : null,
                      plotPurchase: isHomeOrMortgage ? plotPurchase : null,
                      plotMortgage: isHomeOrMortgage ? plotMortgage : null,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isEdit ? 'Bank policy updated successfully!' : 'Bank policy created successfully!'),
                          backgroundColor: AppTheme.emeraldGreen,
                        ),
                      );
                    }

                    _loadPolicies();
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Create Policy'),
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.policy_outlined, color: AppTheme.royalGold, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Banker Credit Policies Hub',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Live lending criteria, LTV norms, M-Profile eligibility, Min/Max ticket sizes & manager hierarchy from partner banks.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showPolicyDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Bank Policy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.royalGold,
                      foregroundColor: AppTheme.obsidianDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _loadPolicies,
                    icon: const Icon(Icons.refresh, color: AppTheme.royalGold),
                    tooltip: 'Refresh Policies',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Overview Statistics Row
          Row(
            children: [
              _buildMetricCard(
                icon: Icons.account_balance,
                title: 'Partner Banks Active',
                value: '7 Banks',
                subtitle: 'HDFC, ICICI, SBI, Axis + more',
                color: AppTheme.royalGold,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                icon: Icons.pie_chart_outline,
                title: 'Max Property LTV',
                value: 'Up to 90% LTV',
                subtitle: 'Home & LAP credit lines',
                color: AppTheme.emeraldGreen,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                icon: Icons.people_outline,
                title: 'M-Profile Coverage',
                value: '9 / 10 Policies',
                subtitle: 'Minority segment acceptance',
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 16),
              _buildMetricCard(
                icon: Icons.currency_rupee,
                title: 'Ticket Sizes Supported',
                value: '₹50K to ₹10 Cr',
                subtitle: 'Micro to Super-HNI loans',
                color: Colors.purpleAccent,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filter and Search Bar
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by Bank, Officer, Office Address, L1/L2 Manager, or keywords...',
                          prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.obsidianMedium,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white10)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Loan Category Chips
                  const Text('Category: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 6,
                    children: _loanTypeFilters.map((type) {
                      final isSelected = _selectedLoanType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: AppTheme.royalGold,
                        backgroundColor: AppTheme.obsidianMedium,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.obsidianDark : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedLoanType = type);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 16),

                  // Product Type Chips
                  const Text('Product: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 6,
                    children: _productTypeFilters.map((pType) {
                      final isSelected = _selectedProductType == pType;
                      return ChoiceChip(
                        label: Text(pType),
                        selected: isSelected,
                        selectedColor: Colors.blueAccent,
                        backgroundColor: AppTheme.obsidianMedium,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedProductType = pType);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(width: 16),

                  // Vertical Chips
                  const Text('Vertical: ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 6,
                    children: _verticalFilters.map((v) {
                      final isSelected = _selectedVertical == v;
                      return ChoiceChip(
                        label: Text(v),
                        selected: isSelected,
                        selectedColor: Colors.purpleAccent,
                        backgroundColor: AppTheme.obsidianMedium,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedVertical = v);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Policies Cards Grid / List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
                : _filteredPolicies.isEmpty
                    ? const Center(child: Text('No bank policies match your filters.', style: TextStyle(color: AppTheme.textSecondary)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.25,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _filteredPolicies.length,
                        itemBuilder: (context, index) {
                          final policy = _filteredPolicies[index];
                          return _buildPolicyCard(policy);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.glassDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyCard(Map<String, dynamic> policy) {
    final minCibil = policy['min_cibil'] ?? 700;
    final maxBounces = policy['max_allowed_bounces'] ?? 0;
    final productType = policy['product_type'] ?? 'Prime';
    final vertical = policy['vertical'] ?? 'DSA';
    final segment = policy['segment'];
    final mProfile = policy['m_profile_allowed'] ?? 'YES';
    final ltv = policy['ltv_ratio'] ?? 'N/A';
    final minTicket = policy['min_ticket_size'] ?? '₹1 Lakh';
    final maxTicket = policy['max_ticket_size'] ?? (policy['max_loan_amount'] ?? '₹50 Lakh');
    final isHomeOrLap = policy['loan_type'] == 'Home Loan' || policy['loan_type'] == 'Mortgage Loan';

    final Color productBadgeColor = productType == 'Prime'
        ? AppTheme.royalGold
        : (productType == 'Affordable' ? Colors.blueAccent : Colors.purpleAccent);

    final Color mProfileColor = mProfile == 'YES' ? AppTheme.emeraldGreen : AppTheme.rubyRed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianMedium,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Bank Name, Product & Vertical & M-Profile Tags, Edit Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.royalGold.withOpacity(0.15),
                    child: Text(
                      (policy['bank_name']?.toString() ?? 'B').substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            policy['bank_name'] ?? 'Bank',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          // Loan Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.royalGold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.royalGold.withOpacity(0.3)),
                            ),
                            child: Text(
                              policy['loan_type'] ?? 'Loan',
                              style: const TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Product Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: productBadgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              productType.toUpperCase(),
                              style: TextStyle(color: productBadgeColor, fontWeight: FontWeight.bold, fontSize: 9),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Vertical Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'VERTICAL: $vertical',
                              style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 9),
                            ),
                          ),
                          if (segment != null && segment.toString().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SEGMENT: $segment',
                                style: const TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 9),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          // M-Profile Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: mProfileColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: mProfileColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              'M-PROFILE: $mProfile',
                              style: TextStyle(color: mProfileColor, fontWeight: FontWeight.bold, fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                onPressed: () => _showPolicyDialog(existingPolicy: policy),
                tooltip: 'Edit Policy',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),

          // Officer Hierarchy Row (Officer + Office Address + L1 + L2)
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_pin, size: 14, color: AppTheme.royalGold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Officer: ${policy['banker_name']} (${policy['banker_mobile']})',
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (policy['office_address'] != null && policy['office_address'].toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Address: ${policy['office_address']}',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (policy['l1_manager_name'] != null && policy['l1_manager_name'].toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'L1 Manager: ${policy['l1_manager_name']} ${policy['l1_manager_mobile'] != null ? '(${policy['l1_manager_mobile']})' : ''}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (policy['l2_manager_name'] != null && policy['l2_manager_name'].toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'L2 Manager: ${policy['l2_manager_name']} ${policy['l2_manager_mobile'] != null ? '(${policy['l2_manager_mobile']})' : ''}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Criteria Badges Grid
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _buildCriterionBadge('Min: $minTicket', Colors.cyanAccent),
              _buildCriterionBadge('Max: $maxTicket', Colors.cyanAccent),
              _buildCriterionBadge('LTV: $ltv', Colors.orangeAccent),
              _buildCriterionBadge('Min CIBIL: $minCibil', minCibil >= 720 ? Colors.orange : AppTheme.emeraldGreen),
              _buildCriterionBadge('Income: ${policy['min_income']}', AppTheme.royalGold),
              _buildCriterionBadge('Bounces: $maxBounces Max', maxBounces == 0 ? Colors.redAccent : Colors.teal),
              _buildCriterionBadge('Geo: ${policy['geo_radius'] ?? 'City limits'}', Colors.blueAccent),
              _buildCriterionBadge('Login Fee: ${policy['login_fee'] ?? 'Nil'}', Colors.purpleAccent),
              _buildCriterionBadge('ROI: ${policy['interest_rate']}', Colors.amber),
              _buildCriterionBadge('TAT: ${policy['tat_days']}', Colors.lightGreenAccent),
              if (policy['repayment_tenure'] != null && policy['repayment_tenure'].toString().isNotEmpty)
                _buildCriterionBadge('Tenure: ${policy['repayment_tenure']}', Colors.lightBlueAccent),
              if (policy['age_limit'] != null && policy['age_limit'].toString().isNotEmpty)
                _buildCriterionBadge('Age: ${policy['age_limit']}', Colors.pinkAccent),
              if (policy['ltv_on_plot'] != null && policy['ltv_on_plot'].toString().isNotEmpty)
                _buildCriterionBadge('Plot LTV: ${policy['ltv_on_plot']}', Colors.deepOrangeAccent),
              if (policy['foir_norms'] != null && policy['foir_norms'].toString().isNotEmpty)
                _buildCriterionBadge('FOIR Norms Active', Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 6),

          if (isHomeOrLap) ...[
            InkWell(
              onTap: () => _showPropertyNormsDialog(policy),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.royalGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.royalGold.withOpacity(0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_work_outlined, size: 13, color: AppTheme.royalGold),
                    SizedBox(width: 6),
                    Text(
                      'View HL/LAP Underwriting & 13 Property Norms',
                      style: TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 9, color: AppTheme.royalGold),
                  ],
                ),
              ),
            ),
          ],

          // Guidelines snippet
          Expanded(
            child: Text(
              policy['special_features'] ?? 'Standard underwriting guidelines apply.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10.5, height: 1.25),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriterionBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
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

  void _showPropertyNormsDialog(Map<String, dynamic> policy) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.obsidianMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.royalGold.withOpacity(0.25)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.home_work_outlined, color: AppTheme.royalGold, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '${policy['bank_name']} - ${policy['loan_type']} Criteria',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 740,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Underwriting Slabs Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UNDERWRITING & RATIO NORMS',
                          style: TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 10),
                        _buildDetailRow('Age Limit (आयु सीमा):', policy['age_limit'] ?? '21 - 65 Years'),
                        _buildDetailRow('Repayment Tenure (अवधि):', policy['repayment_tenure'] ?? 'Up to 30 Years'),
                        _buildDetailRow('Income Ratio (FOIR):', policy['foir_norms'] ?? '1L-7L: 60% | 7L-10L: 65% | 10L-12L: 70% | >=12L: 75%'),
                        _buildDetailRow('Existing Obligations:', policy['existing_obligations'] ?? 'Deducted from net income'),
                        _buildDetailRow('Employment Stability:', policy['employment_stability'] ?? 'Min 2 yrs total / 1 yr current'),
                        _buildDetailRow('LTV Ratio:', policy['ltv_ratio'] ?? '1L-30L: 90% | 30L-75L: 80% | >=75L: 70%'),
                        _buildDetailRow('LTV on Plot (प्लॉट LTV):', policy['ltv_on_plot'] ?? '1L-30L: 90%/80%/70% | 30L-75L: 90%/80%/70% | >=75L: 90%/80%/70%'),
                        _buildDetailRow('Vertical / Segment:', '${policy['vertical'] ?? 'Prime'} | ${policy['segment'] ?? 'DSA'}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'PROPERTY & COLLATERAL FUNDING PERMISSIONS (13 NORMS)',
                    style: TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildPropertyStatusChip('Road Winding Property', policy['road_winding_property_funding']),
                      _buildPropertyStatusChip('Gram Panchayat Property', policy['gram_panchayat_property_funding']),
                      _buildPropertyStatusChip('Notary to Registry', policy['notary_to_registry_funding']),
                      _buildPropertyStatusChip('Gram Panchayat Patta', policy['gram_panchayat_patta_funding']),
                      _buildPropertyStatusChip('Dron Patta Funding', policy['dron_patta_funding']),
                      _buildPropertyStatusChip('Highest Ticket Notary', policy['highest_ticket_size_notary']),
                      _buildPropertyStatusChip('High Tension Line', policy['high_tension_line_funding']),
                      _buildPropertyStatusChip('Without Diversion', policy['without_diversion_property_funding']),
                      _buildPropertyStatusChip('Only Diversion', policy['only_diversion_property_funding']),
                      _buildPropertyStatusChip('AKVN Property Funding', policy['akvn_property_funding']),
                      _buildPropertyStatusChip('Green Belt Property', policy['green_belt_property_funding']),
                      _buildPropertyStatusChip('Plot Purchase Funding', policy['plot_purchase']),
                      _buildPropertyStatusChip('Plot Mortgage Funding', policy['plot_mortgage']),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _buildPropertyStatusChip(String label, dynamic val) {
    final isYes = (val?.toString().toUpperCase() ?? 'NO') == 'YES';
    return Container(
      width: 225,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
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
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
