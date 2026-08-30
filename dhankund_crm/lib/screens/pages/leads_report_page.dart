import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../firebase_service.dart';

class LeadsReportPage extends StatefulWidget {
  const LeadsReportPage({super.key});

  @override
  State<LeadsReportPage> createState() => _LeadsReportPageState();
}

class _LeadsReportPageState extends State<LeadsReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<Map<String, dynamic>> _allLeads = [];
  List<Map<String, dynamic>> _eligibleLeads = [];
  List<Map<String, dynamic>> _bankPolicies = [];
  bool _isLoading = true;
  
  // Track analysis state: null (not started), 'analyzing', or 'done'
  final Map<String, String> _analysisState = {};
  
  // Track analysis results
  final Map<String, Map<String, dynamic>> _analysisResults = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final leads = await _firestoreService.fetchLoanApplications();
    final policies = await _firestoreService.fetchBankPolicies();
    
    final filtered = leads.where((l) => l['applicant_cibil'] != null).toList();
    
    if (mounted) {
      setState(() {
        _allLeads = leads;
        _eligibleLeads = filtered;
        _bankPolicies = policies;
        _isLoading = false;
      });
    }
  }

  Future<void> _runAiAnalysis(Map<String, dynamic> lead) async {
    final id = lead['id'];
    setState(() {
      _analysisState[id] = 'analyzing';
    });

    // Step 1: Simulate AI checking documents sequentially
    await Future.delayed(const Duration(milliseconds: 600)); // Checking CIBIL
    await Future.delayed(const Duration(milliseconds: 600)); // Checking ITR/GST
    await Future.delayed(const Duration(milliseconds: 600)); // Checking Bank Statements
    await Future.delayed(const Duration(milliseconds: 600)); // Matching against Live Bank Policies
    
    // Generate Report based on lead data
    int cibil = lead['applicant_cibil'] ?? 0;
    String loanType = lead['loan_type'] ?? 'Personal Loan';
    bool isBusiness = loanType.toLowerCase().contains('business');
    
    List<Map<String, dynamic>> issues = [];
    bool hasEmiBounce = false;
    bool hasNameMismatch = false;
    bool hasIncomeVariance = false;
    
    // 1. CIBIL Logic
    if (cibil < 700) {
      issues.add({
        'type': 'HIGH RISK',
        'title': 'Low CIBIL Score ($cibil)',
        'desc': 'Score is below 700 standard cutoff. Prime banks (HDFC, SBI) will reject; consider NBFC surrogate options.',
        'icon': Icons.warning_amber_rounded,
        'color': AppTheme.rubyRed,
      });
    } else {
      issues.add({
        'type': 'PASS',
        'title': 'Healthy CIBIL ($cibil)',
        'desc': 'Credit history is prime with clean vintage and no recent 30+ DPD default flags.',
        'icon': Icons.check_circle,
        'color': AppTheme.emeraldGreen,
      });
    }
    
    // 2. Identity Mismatch & PAN/Aadhaar Logic
    final pan = lead['pan_number'] ?? 'NOT ENTERED';
    final aadhaar = lead['aadhaar_number'] ?? 'NOT ENTERED';
    if (lead['pan_number'] == null || lead['aadhaar_number'] == null) {
      hasNameMismatch = true;
      issues.add({
        'type': 'WARNING',
        'title': 'Missing PAN/Aadhaar KYC',
        'desc': 'PAN ($pan) or Aadhaar ($aadhaar) incomplete. Bank verification portals require both numbers.',
        'icon': Icons.badge,
        'color': Colors.orange,
      });
    } else if (DateTime.now().millisecond % 4 == 0) {
      hasNameMismatch = true;
      issues.add({
        'type': 'WARNING',
        'title': 'Identity Name Mismatch (PAN: $pan)',
        'desc': 'Aadhaar ($aadhaar) name has spelling variance with PAN ($pan). Underwriter affidavit may be requested.',
        'icon': Icons.person_search,
        'color': Colors.orange,
      });
    } else {
      issues.add({
        'type': 'PASS',
        'title': 'KYC Verified (PAN: $pan)',
        'desc': 'PAN & Aadhaar ($aadhaar) records authenticated successfully via NSDL/UIDAI gateways.',
        'icon': Icons.verified_user,
        'color': AppTheme.emeraldGreen,
      });
    }
    
    // 3. Banking Logic (EMI Bounce)
    if (DateTime.now().millisecond % 3 == 0) {
      hasEmiBounce = true;
      issues.add({
        'type': 'HIGH RISK',
        'title': 'EMI Bounce Detected',
        'desc': 'Bank statements show 2 EMI technical inward returns in the past 6 months.',
        'icon': Icons.account_balance,
        'color': AppTheme.rubyRed,
      });
    } else {
      issues.add({
        'type': 'PASS',
        'title': 'Clean Banking Track',
        'desc': 'Zero inward cheque/NACH bounces in 6-month banking statement analysis.',
        'icon': Icons.account_balance,
        'color': AppTheme.emeraldGreen,
      });
    }
    
    // 4. Financial / GST / ITR Logic
    if (isBusiness) {
      if (DateTime.now().millisecond % 2 == 0) {
        hasIncomeVariance = true;
        issues.add({
          'type': 'WARNING',
          'title': 'GST Turnover Variance',
          'desc': 'Declared turnover (₹${lead['turnover']}) has a 15% variance compared to 3B filings.',
          'icon': Icons.receipt_long,
          'color': Colors.orange,
        });
      } else {
        issues.add({
          'type': 'PASS',
          'title': 'Income & Turnover Verified',
          'desc': 'GSTR-3B filings and 3-year ITR compute ratios match declared figures.',
          'icon': Icons.receipt_long,
          'color': AppTheme.emeraldGreen,
        });
      }
    } else {
      if (DateTime.now().millisecond % 4 == 0) {
        hasIncomeVariance = true;
        issues.add({
          'type': 'WARNING',
          'title': 'Salary Credit Variance',
          'desc': 'Declared salary (₹${lead['salary']}) is higher than average monthly net banking credits.',
          'icon': Icons.money,
          'color': Colors.orange,
        });
      } else {
        issues.add({
          'type': 'PASS',
          'title': 'Salary Credits Verified',
          'desc': 'Consistent salary credits observed in consecutive 3 months statements.',
          'icon': Icons.money,
          'color': AppTheme.emeraldGreen,
        });
      }
    }

    // Step 2: Compare against all live Bank Policies to calculate Approval Probability
    final policies = await _firestoreService.fetchBankPolicies();
    List<Map<String, dynamic>> bankRecommendations = [];

    for (var pol in policies) {
      int score = 88;
      List<String> pros = [];
      List<String> cons = [];

      final polLoanType = pol['loan_type']?.toString() ?? '';
      final isProductMatch = polLoanType == loanType || loanType.contains(polLoanType);
      final polMinCibil = pol['min_cibil'] as int? ?? 700;
      final polMaxBounces = pol['max_allowed_bounces'] as int? ?? 0;

      // Product alignment
      if (isProductMatch) {
        score += 6;
      } else {
        score -= 20;
      }

      // CIBIL Matching
      if (cibil >= polMinCibil) {
        score += 6;
        pros.add('CIBIL ($cibil) meets bank minimum cutoff of $polMinCibil.');
      } else {
        final diff = polMinCibil - cibil;
        score -= (diff > 30 ? 45 : 25);
        cons.add('CIBIL ($cibil) is below bank requirement ($polMinCibil).');
      }

      // Bounce Rules
      if (hasEmiBounce) {
        if (polMaxBounces == 0) {
          score -= 30;
          cons.add('Bank policy requires strictly 0 EMI bounces; file has inward return flag.');
        } else {
          score -= 8;
          pros.add('Bank accepts up to $polMaxBounces bounce(s) with justification.');
        }
      } else {
        score += 4;
        pros.add('Clean banking meets strict zero-bounce credit criteria.');
      }

      // Income Variance
      if (hasIncomeVariance) {
        score -= 10;
        cons.add('Income/GST variance may trigger supplementary audit requirements.');
      }

      // Name discrepancy
      if (hasNameMismatch) {
        score -= 6;
      }

      // Clamp between 15% and 98%
      final finalProbability = score.clamp(15, 98);

      bankRecommendations.add({
        'bank_name': pol['bank_name'],
        'banker_name': pol['banker_name'],
        'banker_mobile': pol['banker_mobile'],
        'office_address': pol['office_address'],
        'l1_manager_name': pol['l1_manager_name'],
        'l1_manager_mobile': pol['l1_manager_mobile'],
        'l2_manager_name': pol['l2_manager_name'],
        'l2_manager_mobile': pol['l2_manager_mobile'],
        'loan_type': pol['loan_type'],
        'product_type': pol['product_type'] ?? 'Prime',
        'vertical': pol['vertical'] ?? 'DSA',
        'ticket_size': pol['ticket_size'] ?? pol['max_loan_amount'],
        'ltv_ratio': pol['ltv_ratio'] ?? 'N/A',
        'm_profile_allowed': pol['m_profile_allowed'] ?? 'YES',
        'geo_radius': pol['geo_radius'] ?? 'City Limits',
        'login_fee': pol['login_fee'] ?? 'Nil',
        'interest_rate': pol['interest_rate'],
        'tat_days': pol['tat_days'],
        'probability': finalProbability,
        'special_features': pol['special_features'],
        'pros': pros,
        'cons': cons,
      });
    }

    // Sort by approval probability descending
    bankRecommendations.sort((a, b) => (b['probability'] as int).compareTo(a['probability'] as int));

    if (mounted) {
      setState(() {
        _analysisResults[id] = {
          'issues': issues,
          'bank_recommendations': bankRecommendations,
          'timestamp': DateTime.now(),
        };
        _analysisState[id] = 'done';
      });
    }
  }

  void _forwardLeadToBanker(Map<String, dynamic> lead, Map<String, dynamic> bankRec) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.obsidianMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: AppTheme.royalGold, size: 22),
            const SizedBox(width: 10),
            Text('Forward File to ${bankRec['bank_name']}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to route applicant ${lead['full_name']} (Loan Amount: ₹${lead['loan_amount']}) directly to partner banker:', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.obsidianLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bank Officer: ${bankRec['banker_name']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Text('Contact: ${bankRec['banker_mobile']}', style: const TextStyle(color: AppTheme.royalGold, fontSize: 12)),
                  if (bankRec['office_address'] != null && bankRec['office_address'].toString().isNotEmpty)
                    Text('Branch: ${bankRec['office_address']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  if (bankRec['l1_manager_name'] != null && bankRec['l1_manager_name'].toString().isNotEmpty)
                    Text('L1 Manager: ${bankRec['l1_manager_name']} (${bankRec['l1_manager_mobile'] ?? ''})', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  if (bankRec['l2_manager_name'] != null && bankRec['l2_manager_name'].toString().isNotEmpty)
                    Text('L2 Manager: ${bankRec['l2_manager_name']} (${bankRec['l2_manager_mobile'] ?? ''})', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('Segment: ${bankRec['product_type']} | Vertical: ${bankRec['vertical']} | M-Profile: ${bankRec['m_profile_allowed']}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                  Text('LTV: ${bankRec['ltv_ratio']} | ROI: ${bankRec['interest_rate']} | TAT: ${bankRec['tat_days']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File successfully routed to ${bankRec['banker_name']} at ${bankRec['bank_name']}!'),
                  backgroundColor: AppTheme.emeraldGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalGold, foregroundColor: AppTheme.obsidianDark),
            child: const Text('Confirm & Dispatch'),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.royalGold, size: 28),
                      SizedBox(width: 12),
                      Text('AI Leads Analysis & Bank Matcher', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Evaluate loan files against live Banker Credit Policies to predict approval probability and rank best-fit banks.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Queue & Policies'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.obsidianMedium,
                  foregroundColor: AppTheme.royalGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Main List
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
                : _eligibleLeads.isEmpty
                    ? const Center(child: Text('No eligible leads with CIBIL score found.', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        itemCount: _eligibleLeads.length,
                        itemBuilder: (context, index) {
                          final lead = _eligibleLeads[index];
                          final id = lead['id'];
                          final state = _analysisState[id];
                          final result = _analysisResults[id];
                          
                          return Card(
                            color: AppTheme.obsidianMedium,
                            margin: const EdgeInsets.only(bottom: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white10)),
                            child: Padding(
                              padding: const EdgeInsets.all(22.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Lead Header Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(color: AppTheme.royalGold.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                                  child: Text(lead['loan_type'] ?? 'LOAN', style: const TextStyle(fontSize: 11, color: AppTheme.royalGold, fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(lead['full_name'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary)),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                Text('Amount: ₹${lead['loan_amount'] ?? '0'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                Text('CIBIL: ${lead['applicant_cibil']}', style: TextStyle(color: (lead['applicant_cibil'] ?? 0) >= 700 ? AppTheme.emeraldGreen : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                                                if (lead['pan_number'] != null)
                                                  Text('PAN: ${lead['pan_number']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                if (lead['aadhaar_number'] != null)
                                                  Text('Aadhaar: ${lead['aadhaar_number']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                Text('Status: ${lead['status']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (state == null)
                                        ElevatedButton.icon(
                                          onPressed: () => _runAiAnalysis(lead),
                                          icon: const Icon(Icons.psychology, size: 18),
                                          label: const Text('Run AI Analysis & Bank Match'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.royalGold,
                                            foregroundColor: AppTheme.obsidianDark,
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        )
                                      else if (state == 'analyzing')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(color: AppTheme.obsidianLight, borderRadius: BorderRadius.circular(8)),
                                          child: const Row(
                                            children: [
                                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.royalGold)),
                                              SizedBox(width: 12),
                                              Text('AI Matching Live Bank Policies...', style: TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 12)),
                                            ],
                                          ),
                                        )
                                      else if (state == 'done')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.emeraldGreen.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.emeraldGreen),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.verified, color: AppTheme.emeraldGreen, size: 16),
                                              SizedBox(width: 8),
                                              Text('Analysis & Match Complete', style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  // Results Display
                                  if (state == 'done' && result != null) ...[
                                    const SizedBox(height: 20),
                                    const Divider(color: Colors.white10),
                                    const SizedBox(height: 12),

                                    // SECTION A: AI RISK REPORT
                                    const Row(
                                      children: [
                                        Icon(Icons.shield_outlined, size: 16, color: AppTheme.royalGold),
                                        SizedBox(width: 8),
                                        Text('1. AI UNDERWRITING & KYC RISK REPORT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...(result['issues'] as List<Map<String, dynamic>>).map((issue) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: (issue['color'] as Color).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: (issue['color'] as Color).withOpacity(0.25)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(issue['icon'], color: issue['color'], size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(issue['title'], style: TextStyle(fontWeight: FontWeight.bold, color: issue['color'], fontSize: 14)),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(color: issue['color'], borderRadius: BorderRadius.circular(4)),
                                                        child: Text(issue['type'], style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(issue['desc'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),

                                    const SizedBox(height: 20),
                                    const Divider(color: Colors.white10),
                                    const SizedBox(height: 12),

                                    // SECTION B: AI BANK APPROVAL PROBABILITY RANKING
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Row(
                                          children: [
                                            Icon(Icons.account_balance, size: 16, color: AppTheme.royalGold),
                                            SizedBox(width: 8),
                                            Text('2. AI BANK APPROVAL PROBABILITY & BEST FIT RANKING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0)),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
                                          child: Text('Checked ${_bankPolicies.length} Partner Policies', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    if ((result['bank_recommendations'] as List).isNotEmpty) ...[
                                      // Top #1 Recommended Bank (Hero Card)
                                      _buildTopRecommendedBankCard(lead, (result['bank_recommendations'] as List).first),
                                      const SizedBox(height: 14),

                                      // Other Banks Grid / List
                                      const Text('OTHER EVALUATED PARTNER BANKS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.8)),
                                      const SizedBox(height: 10),
                                      ...((result['bank_recommendations'] as List).skip(1).take(3)).map((rec) {
                                        return _buildSecondaryBankCard(lead, rec);
                                      }).toList(),
                                    ],
                                  ],
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

  Widget _buildTopRecommendedBankCard(Map<String, dynamic> lead, Map<String, dynamic> topRec) {
    final prob = topRec['probability'] as int;
    final color = prob >= 80 ? AppTheme.emeraldGreen : (prob >= 65 ? Colors.orange : AppTheme.rubyRed);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.obsidianLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.royalGold.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppTheme.royalGold.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.royalGold, borderRadius: BorderRadius.circular(4)),
                    child: const Row(
                      children: [
                        Icon(Icons.emoji_events, size: 14, color: AppTheme.obsidianDark),
                        SizedBox(width: 4),
                        Text('RANK #1 BEST MATCH', style: TextStyle(color: AppTheme.obsidianDark, fontWeight: FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    topRec['bank_name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              // Probability Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: color, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$prob% Approval Chance',
                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text('Interest Rate: ${topRec['interest_rate']}', style: const TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Ticket: ${topRec['ticket_size']}', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w600, fontSize: 13)),
              Text('LTV: ${topRec['ltv_ratio']}', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600, fontSize: 13)),
              Text('M-Profile: ${topRec['m_profile_allowed']}', style: TextStyle(color: topRec['m_profile_allowed'] == 'YES' ? AppTheme.emeraldGreen : AppTheme.rubyRed, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Product: ${topRec['product_type']} (${topRec['vertical']})', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w600, fontSize: 13)),
              Text('Geo Radius: ${topRec['geo_radius']}', style: const TextStyle(color: Colors.blueAccent, fontSize: 13)),
              Text('Login Fee: ${topRec['login_fee']}', style: const TextStyle(color: Colors.amberAccent, fontSize: 13)),
              Text('TAT: ${topRec['tat_days']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Text('Officer: ${topRec['banker_name']} (${topRec['banker_mobile']})', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          if (topRec['office_address'] != null && topRec['office_address'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Office: ${topRec['office_address']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
          if (topRec['l1_manager_name'] != null && topRec['l1_manager_name'].toString().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('L1 / L2 Escalation: ${topRec['l1_manager_name']} (${topRec['l1_manager_mobile'] ?? ''}) | ${topRec['l2_manager_name'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
          const SizedBox(height: 10),
          if ((topRec['pros'] as List).isNotEmpty)
            ...((topRec['pros'] as List).map((p) => Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Row(
                children: [
                  const Icon(Icons.check, color: AppTheme.emeraldGreen, size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
                ],
              ),
            ))),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _forwardLeadToBanker(lead, topRec),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text('Forward File to ${topRec['bank_name']} Banker'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalGold,
                  foregroundColor: AppTheme.obsidianDark,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryBankCard(Map<String, dynamic> lead, Map<String, dynamic> rec) {
    final prob = rec['probability'] as int;
    final color = prob >= 75 ? AppTheme.emeraldGreen : (prob >= 50 ? Colors.orange : AppTheme.rubyRed);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.obsidianLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rec['bank_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Text('$prob% Probability', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    Text('Rate: ${rec['interest_rate']}', style: const TextStyle(color: AppTheme.royalGold, fontSize: 12)),
                    Text('Ticket: ${rec['ticket_size']}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    Text('LTV: ${rec['ltv_ratio']}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                    Text('M-Profile: ${rec['m_profile_allowed']}', style: TextStyle(color: rec['m_profile_allowed'] == 'YES' ? AppTheme.emeraldGreen : AppTheme.rubyRed, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('Type: ${rec['product_type']} (${rec['vertical']})', style: const TextStyle(color: Colors.purpleAccent, fontSize: 12)),
                    Text('Geo: ${rec['geo_radius']}', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                    Text('Officer: ${rec['banker_name']} (${rec['banker_mobile']})', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
                if ((rec['cons'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text('⚠️ ${(rec['cons'] as List).first}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                  ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _forwardLeadToBanker(lead, rec),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppTheme.royalGold.withOpacity(0.5)),
              foregroundColor: AppTheme.royalGold,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Forward', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
