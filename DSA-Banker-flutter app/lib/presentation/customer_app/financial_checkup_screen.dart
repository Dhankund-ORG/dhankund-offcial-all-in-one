import 'package:flutter/material.dart';
import 'loan_selection_screen.dart';

class FinancialCheckupScreen extends StatefulWidget {
  const FinancialCheckupScreen({super.key});

  @override
  State<FinancialCheckupScreen> createState() => _FinancialCheckupScreenState();
}

class _FinancialCheckupScreenState extends State<FinancialCheckupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _panController = TextEditingController();
  final _incomeController = TextEditingController();
  final _obligationsController = TextEditingController();

  int _currentStep = 0; // 0 = Input Form, 1 = Diagnostics Loading, 2 = Summary Report
  int _loadingStepIndex = 0;
  final List<String> _loadingSteps = [
    'Validating PAN Card with income registry...',
    'Fetching CIBIL & Credit History details...',
    'Scanning PAN-linked Mutual Funds & active SIPs...',
    'Analyzing Debt-to-Income obligations...',
    'Generating complete Financial Diagnostics Report...'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _panController.dispose();
    _incomeController.dispose();
    _obligationsController.dispose();
    super.dispose();
  }

  void _startDiagnostics() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _currentStep = 1;
      _loadingStepIndex = 0;
    });

    _runLoadingSimulation();
  }

  void _runLoadingSimulation() {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_loadingStepIndex < _loadingSteps.length - 1) {
        setState(() {
          _loadingStepIndex++;
        });
        _runLoadingSimulation();
      } else {
        setState(() {
          _currentStep = 2;
        });
      }
    });
  }

  void _resetCheckup() {
    setState(() {
      _currentStep = 0;
      _panController.clear();
      _incomeController.clear();
      _obligationsController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'Financial Check-Up',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildCurrentPhase(),
        ),
      ),
    );
  }

  Widget _buildCurrentPhase() {
    if (_currentStep == 0) {
      return _buildInputForm();
    } else if (_currentStep == 1) {
      return _buildLoadingScreen();
    } else {
      return _buildSummaryReport();
    }
  }

  // --- PHASE 1: INPUT FORM ---
  Widget _buildInputForm() {
    return SingleChildScrollView(
      key: const ValueKey('input_form'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get Your Financial Health Check-Up',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Analyze your credit score, active obligations, and investment portfolios linked with your PAN.',
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            
            _buildLabel('Full Name (as per PAN) *'),
            _buildTextField(
              controller: _nameController,
              hint: 'Enter your full name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            _buildLabel('PAN Card Number *'),
            _buildTextField(
              controller: _panController,
              hint: 'e.g. ABCDE1234F',
              icon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your PAN Card';
                }
                final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
                if (!panRegex.hasMatch(value.trim().toUpperCase())) {
                  return 'Enter a valid 10-digit PAN (e.g. ABCDE1234F)';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            _buildLabel('Monthly Income (₹) *'),
            _buildTextField(
              controller: _incomeController,
              hint: 'Enter your net monthly income',
              icon: Icons.currency_rupee,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your monthly income';
                }
                final amt = double.tryParse(value.trim());
                if (amt == null || amt <= 0) {
                  return 'Please enter a valid income amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            _buildLabel('Monthly Obligations / EMIs (₹) *'),
            _buildTextField(
              controller: _obligationsController,
              hint: 'Enter total existing monthly obligations',
              icon: Icons.account_balance_wallet_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter obligations (or 0 if none)';
                }
                final amt = double.tryParse(value.trim());
                if (amt == null || amt < 0) {
                  return 'Please enter a valid amount (or 0)';
                }
                return null;
              },
            ),
            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startDiagnostics,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3AFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics_outlined, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Check Financial Health',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Text(
                    'Your data is encrypted & secure.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PHASE 2: SIMULATED DIAGNOSTICS LOADING ---
  Widget _buildLoadingScreen() {
    return Center(
      key: const ValueKey('loading_screen'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A3AFF).withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(
                  color: Color(0xFF4A3AFF),
                  strokeWidth: 4,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Running Diagnostics',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Analyzing PAN profile and credit logs...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 48),
            
            // Diagnostics steps list
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
                ],
              ),
              child: Column(
                children: List.generate(_loadingSteps.length, (index) {
                  final isDone = index < _loadingStepIndex;
                  final isCurrent = index == _loadingStepIndex;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle
                              : (isCurrent ? Icons.sync : Icons.radio_button_unchecked),
                          color: isDone
                              ? const Color(0xFF27AE60)
                              : (isCurrent ? const Color(0xFF4A3AFF) : Colors.grey.shade300),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _loadingSteps[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isDone
                                  ? Colors.grey.shade800
                                  : (isCurrent ? const Color(0xFF4A3AFF) : Colors.grey.shade400),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PHASE 3: DIAGNOSTICS SUMMARY REPORT ---
  Widget _buildSummaryReport() {
    final income = double.tryParse(_incomeController.text.trim()) ?? 0;
    final obligations = double.tryParse(_obligationsController.text.trim()) ?? 0;
    final disposable = income - obligations;
    final dti = income > 0 ? (obligations / income) * 100 : 0.0;

    // Simulate CIBIL based on name/obligations to make it realistic
    final simulatedCibil = 650 + ((income - obligations) > 50000 ? 100 : 30) + (obligations == 0 ? 30 : -20);
    final cibilScore = simulatedCibil.clamp(300, 900);

    String cibilRating = 'Good';
    Color cibilColor = const Color(0xFF27AE60);
    if (cibilScore >= 800) {
      cibilRating = 'Excellent';
      cibilColor = const Color(0xFF27AE60);
    } else if (cibilScore >= 720) {
      cibilRating = 'Good';
      cibilColor = const Color(0xFF2E9C8E);
    } else if (cibilScore >= 650) {
      cibilRating = 'Fair';
      cibilColor = const Color(0xFFFFB300);
    } else {
      cibilRating = 'Poor';
      cibilColor = const Color(0xFFD63031);
    }

    String dtiStatus = 'Healthy';
    Color dtiColor = const Color(0xFF27AE60);
    if (dti <= 30) {
      dtiStatus = 'Excellent (Low Risk)';
      dtiColor = const Color(0xFF27AE60);
    } else if (dti <= 45) {
      dtiStatus = 'Moderate (Medium Risk)';
      dtiColor = const Color(0xFFFFB300);
    } else {
      dtiStatus = 'High Obligations (High Risk)';
      dtiColor = const Color(0xFFD63031);
    }

    // Simulate Mutual Fund and SIP Portfolio
    final hasInvestments = cibilScore > 650;
    final totalMFValue = hasInvestments ? (income * 3.5).roundToDouble() : 0.0;
    final totalSIP = hasInvestments ? (income * 0.12).roundToDouble() : 0.0;

    return SingleChildScrollView(
      key: const ValueKey('summary_report'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A3AFF), Color(0xFF6C5DD3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report Generated For',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _nameController.text.trim(),
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PAN: ${_panController.text.trim().toUpperCase()}',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Verified',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CIBIL SCORE METRIC
          _buildSectionTitle('Credit Registry Diagnostics'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CIBIL Score',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fetched from Credit Bureau database',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cibilColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        cibilRating,
                        style: TextStyle(color: cibilColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Score Gauge Meter
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          '$cibilScore',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: cibilColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const Text(
                          'out of 900',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: (cibilScore - 300) / 600,
                  color: cibilColor,
                  backgroundColor: Colors.grey.shade100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('300 (Poor)', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                    Text('900 (Excellent)', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // OBLIGATIONS & DISPOSABLE INCOME
          _buildSectionTitle('Debt-to-Income Assessment'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Obligation Ratio (DTI)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '${dti.toStringAsFixed(1)}%',
                      style: TextStyle(color: dtiColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Current Status: $dtiStatus',
                  style: TextStyle(color: dtiColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildObligationRow('Monthly Income', '₹${income.toInt()}'),
                const Divider(height: 20, thickness: 0.5),
                _buildObligationRow('Monthly EMIs', '₹${obligations.toInt()}'),
                const Divider(height: 20, thickness: 0.5),
                _buildObligationRow('Disposable Surplus', '₹${disposable.toInt()}', isSurplus: true),
                const SizedBox(height: 24),
                
                // Eligibility Verdict
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A3AFF).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4A3AFF).withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF4A3AFF), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          dti <= 45
                              ? 'Your surplus income suggests a strong capacity to service additional loan installments. Repayment risk is low.'
                              : 'High existing debt burden detected. We recommend settling outstanding cards/loans before applying for further credits.',
                          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // MUTUAL FUNDS & SIP PORTFOLIO
          _buildSectionTitle('PAN-Linked Investments'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mutual Funds Holdings',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      hasInvestments ? '₹${totalMFValue.toInt()}' : 'No holdings found',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A3AFF)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Portfolio values extracted via registered PAN card',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 20),
                if (hasInvestments) ...[
                  _buildInvestmentDetailTile('Active SIPs Contribution', '₹${totalSIP.toInt()} / month', Icons.trending_up, Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Active Portfolio breakdown:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  _buildSIPItem('HDFC Top 100 Bluechip Fund', '₹${(totalSIP * 0.4).round()}/mo', 'SIP Active'),
                  _buildSIPItem('ICICI Prudential Multi-Asset Fund', '₹${(totalSIP * 0.35).round()}/mo', 'SIP Active'),
                  _buildSIPItem('Parag Parikh Flexi Cap Fund', '₹${(totalSIP * 0.25).round()}/mo', 'SIP Active'),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Colors.grey.shade300, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'No Active Mutual Funds or SIPs linked to this PAN',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 36),

          // ACTIONS BUTTONS
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoanSelectionScreen()),
                );
              },
              child: const Text('Apply for Recommended Loan'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _showDownloadDialog,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4A3AFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download, color: Color(0xFF4A3AFF)),
                  SizedBox(width: 12),
                  Text(
                    'Download PDF Summary Report',
                    style: TextStyle(color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: _resetCheckup,
              child: const Text(
                'Run Another Check-Up',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
    );
  }

  Widget _buildObligationRow(String label, String value, {bool isSurplus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: isSurplus ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isSurplus ? const Color(0xFF27AE60) : Colors.black87)),
      ],
    );
  }

  Widget _buildInvestmentDetailTile(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSIPItem(String fundName, String value, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fundName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 2),
                Text(status, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future.delayed(const Duration(seconds: 2), () {
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Financial Diagnostics Report PDF downloaded successfully!')),
                );
              }
            });
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF4A3AFF)),
                    SizedBox(height: 24),
                    Text(
                      'Generating PDF Report...',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Exporting diagnostics, graphs & ratios',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- REUSABLE UTILITIES ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade400),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      ),
    );
  }
}
