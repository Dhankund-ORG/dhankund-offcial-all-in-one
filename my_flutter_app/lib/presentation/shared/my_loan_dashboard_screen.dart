import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';
import 'package:my_flutter_app/presentation/customer_app/personal_loan_form_screen.dart';
import 'package:my_flutter_app/presentation/customer_app/business_loan_form_screen.dart';
import 'package:my_flutter_app/presentation/customer_app/general_loan_form_screen.dart';
import 'package:my_flutter_app/presentation/customer_app/financial_checkup_screen.dart';
import 'package:my_flutter_app/presentation/shared/help_support_screen.dart';

class MyLoanDashboardScreen extends StatefulWidget {
  const MyLoanDashboardScreen({super.key});

  @override
  State<MyLoanDashboardScreen> createState() => _MyLoanDashboardScreenState();
}

class _MyLoanDashboardScreenState extends State<MyLoanDashboardScreen> {
  String _userName = '';
  final PageController _adController = PageController();
  int _currentAdIndex = 0;
  Timer? _adTimer;

  final List<Map<String, dynamic>> _loanCategories = [
    {'title': 'Personal Loan', 'icon': Icons.person, 'color': Color(0xFF4A3AFF)},
    {'title': 'Business Loan', 'icon': Icons.business_center, 'color': Color(0xFF27AE60)},
    {'title': 'Home Loan', 'icon': Icons.home, 'color': Color(0xFF0984E3)},
    {'title': 'Mortgage Loan', 'icon': Icons.real_estate_agent, 'color': Color(0xFFE17055)},
    {'title': 'Credit Card', 'icon': Icons.credit_card, 'color': Color(0xFFFDCB6E)},
    {'title': 'Commercial Vehicle', 'icon': Icons.local_shipping, 'color': Color(0xFF6C5CE7)},
    {'title': 'Car Loan', 'icon': Icons.directions_car, 'color': Color(0xFF00CEC9)},
    {'title': 'Loan Transfer', 'icon': Icons.currency_exchange, 'color': Color(0xFFD63031)},
  ];

  final List<Map<String, dynamic>> _insuranceCategories = [
    {'title': 'Health Insurance', 'icon': Icons.health_and_safety, 'color': Color(0xFFE84393)},
    {'title': 'General Insurance', 'icon': Icons.shield, 'color': Color(0xFF27AE60)},
    {'title': 'Vehicle Insurance', 'icon': Icons.directions_car, 'color': Color(0xFF0984E3)},
    {'title': 'Loan Cover', 'icon': Icons.umbrella, 'color': Color(0xFFE17055)},
  ];

  final List<Map<String, String>> _advertisements = [
    {
      'title': 'Business Loan',
      'subtitle': 'Aapke business ka game changer!',
      'color': '0xFF4A3AFF',
    },
    {
      'title': 'Home Loan at 8.5%',
      'subtitle': 'Apne sapno ka ghar banayein hakikat.',
      'color': '0xFF27AE60',
    },
    {
      'title': 'Instant Personal Loan',
      'subtitle': 'Zero documentation, Instant approval!',
      'color': '0xFFE17055',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _startAdTimer();
  }

  @override
  void dispose() {
    _adTimer?.cancel();
    _adController.dispose();
    super.dispose();
  }

  void _startAdTimer() {
    _adTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_adController.hasClients) {
        _currentAdIndex = (_currentAdIndex + 1) % _advertisements.length;
        _adController.animateToPage(
          _currentAdIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userName = doc.data()?['name'] ?? 'User';
          // Extract first name
          if (_userName.contains(' ')) {
            _userName = _userName.split(' ')[0];
          }
        });
      }
    }
  }

  void _showComingSoon(String service) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$service application coming soon!')),
    );
  }

  void _openEmiCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const EmiCalculatorBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildUtilityBanner(),
          const SizedBox(height: 24),
          _buildSectionTitle('Apply For Loan'),
          _buildLoanGrid(),
          const SizedBox(height: 24),
          _buildSectionTitle('Apply For Insurance'),
          _buildInsuranceGrid(),
          const SizedBox(height: 24),
          _buildSectionTitle('Recent Applications'),
          _buildApplicationsList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Hi, ',
                style: TextStyle(fontSize: 24, color: Colors.black87),
              ),
              Text(
                _userName.isNotEmpty ? _userName : 'Guest',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A3AFF),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HelpSupportScreen(userName: _userName),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A3AFF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent, color: Color(0xFF4A3AFF)),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _adController,
              itemCount: _advertisements.length,
              onPageChanged: (index) => setState(() => _currentAdIndex = index),
              itemBuilder: (context, index) {
                final ad = _advertisements[index];
                final color = Color(int.parse(ad['color']!));
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: NetworkImage('https://www.transparenttextures.com/patterns/cubes.png'),
                      opacity: 0.1,
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ad['title']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ad['subtitle']!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _advertisements.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentAdIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentAdIndex == index ? const Color(0xFF4A3AFF) : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUtilityBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _openEmiCalculator,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A3AFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF4A3AFF).withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.calculate, color: Color(0xFF4A3AFF)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'EMI Calculator',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showComingSoon('Credit Score'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.speed, color: Color(0xFF27AE60)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Credit Score',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27AE60)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FinancialCheckupScreen(),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5DD3), Color(0xFF4A3AFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A3AFF).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MY FINANCIAL CHECK-UP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Analyze CIBIL & mutual funds using PAN & income details',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildLoanGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.7,
      ),
      itemCount: _loanCategories.length,
      itemBuilder: (context, index) {
        final category = _loanCategories[index];
        return GestureDetector(
          onTap: () {
            if (category['title'] == 'Personal Loan') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PersonalLoanFormScreen(),
                ),
              );
            } else if (category['title'] == 'Business Loan') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BusinessLoanFormScreen(),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GeneralLoanFormScreen(
                    loanTitle: category['title'],
                  ),
                ),
              );
            }
          },
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: category['color'].withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  category['icon'],
                  color: category['color'],
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                category['title'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsuranceGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 24,
        childAspectRatio: 0.7,
      ),
      itemCount: _insuranceCategories.length,
      itemBuilder: (context, index) {
        final category = _insuranceCategories[index];
        return GestureDetector(
          onTap: () => _showComingSoon(category['title']),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: category['color'].withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  category['icon'],
                  color: category['color'],
                  size: 28,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                category['title'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApplicationsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No recent loan applications',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Apply for a loan above to track its status here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// EMI Calculator Bottom Sheet
class EmiCalculatorBottomSheet extends StatefulWidget {
  const EmiCalculatorBottomSheet({super.key});

  @override
  State<EmiCalculatorBottomSheet> createState() => _EmiCalculatorBottomSheetState();
}

class _EmiCalculatorBottomSheetState extends State<EmiCalculatorBottomSheet> {
  double _principal = 100000;
  double _rate = 10.5;
  double _tenureYears = 5;

  double get _emi {
    double p = _principal;
    double r = _rate / (12 * 100); // Monthly interest rate
    double n = _tenureYears * 12; // Total months
    
    if (r == 0) return p / n;
    
    double emi = (p * r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    return emi;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EMI Calculator',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Principal Amount
          _buildSliderRow(
            'Loan Amount (₹)', 
            _principal, 
            10000, 
            5000000, 
            (val) => setState(() => _principal = val),
            '₹${_principal.toInt()}',
          ),
          
          // Interest Rate
          _buildSliderRow(
            'Interest Rate (p.a)', 
            _rate, 
            5.0, 
            20.0, 
            (val) => setState(() => _rate = val),
            '${_rate.toStringAsFixed(1)}%',
          ),
          
          // Tenure
          _buildSliderRow(
            'Tenure (Years)', 
            _tenureYears, 
            1, 
            30, 
            (val) => setState(() => _tenureYears = val),
            '${_tenureYears.toInt()} Yr',
          ),
          
          const SizedBox(height: 32),
          
          // Result Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A3AFF), Color(0xFF6C5DD3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Your Monthly EMI',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${_emi.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Principal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('₹${_principal.toInt()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Total Interest', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('₹${(_emi * _tenureYears * 12 - _principal).toInt()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String title, double value, double min, double max, ValueChanged<double> onChanged, String displayValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(displayValue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A3AFF))),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF4A3AFF),
          inactiveColor: const Color(0xFF4A3AFF).withOpacity(0.1),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
