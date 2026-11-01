import 'dart:math';
import 'package:flutter/material.dart';

enum CalculatorMode {
  calculateEmi,
  calculateLoanAmount,
  calculateTenure,
  calculateRoi,
}

class AmortizationRow {
  final int period;
  final double openingBalance;
  final double emi;
  final double principal;
  final double interest;
  final double closingBalance;

  AmortizationRow({
    required this.period,
    required this.openingBalance,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.closingBalance,
  });
}

class YearlyAmortizationRow {
  final int year;
  final double openingBalance;
  final double totalEmi;
  final double principal;
  final double interest;
  final double closingBalance;

  YearlyAmortizationRow({
    required this.year,
    required this.openingBalance,
    required this.totalEmi,
    required this.principal,
    required this.interest,
    required this.closingBalance,
  });
}

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  CalculatorMode _activeMode = CalculatorMode.calculateEmi;

  // Controllers for editable inputs
  final _amountController = TextEditingController(text: '2500000');
  final _rateController = TextEditingController(text: '8.5');
  final _tenureController = TextEditingController(text: '20');
  final _emiController = TextEditingController(text: '21696');

  // Input values
  double _amount = 2500000;
  double _rate = 8.5;
  double _tenureYears = 20;
  double _targetEmi = 21696;
  bool _isTenureInYears = true;

  // Output values
  double _calculatedEmi = 0;
  double _calculatedLoanAmount = 0;
  double _calculatedTenureMonths = 0;
  double _calculatedRate = 0;
  double _totalInterest = 0;
  double _totalPayment = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    _emiController.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _errorMessage = null;

      double months = _isTenureInYears ? (_tenureYears * 12) : _tenureYears;
      if (months <= 0) months = 1;

      switch (_activeMode) {
        case CalculatorMode.calculateEmi:
          if (_amount > 0 && _rate > 0 && months > 0) {
            double monthlyRate = _rate / 12 / 100;
            double factor = pow(1 + monthlyRate, months).toDouble();
            _calculatedEmi = (_amount * monthlyRate * factor) / (factor - 1);
            _totalPayment = _calculatedEmi * months;
            _totalInterest = _totalPayment - _amount;
          } else {
            _calculatedEmi = 0;
            _totalPayment = 0;
            _totalInterest = 0;
          }
          break;

        case CalculatorMode.calculateLoanAmount:
          if (_targetEmi > 0 && _rate > 0 && months > 0) {
            double monthlyRate = _rate / 12 / 100;
            double factor = pow(1 + monthlyRate, months).toDouble();
            _calculatedLoanAmount = (_targetEmi * (factor - 1)) / (monthlyRate * factor);
            _totalPayment = _targetEmi * months;
            _totalInterest = _totalPayment - _calculatedLoanAmount;
          } else {
            _calculatedLoanAmount = 0;
            _totalPayment = 0;
            _totalInterest = 0;
          }
          break;

        case CalculatorMode.calculateTenure:
          if (_amount > 0 && _targetEmi > 0 && _rate > 0) {
            double monthlyRate = _rate / 12 / 100;
            if (_targetEmi <= _amount * monthlyRate) {
              _errorMessage = 'EMI must be greater than monthly interest (₹${(_amount * monthlyRate).round()})';
              _calculatedTenureMonths = 0;
              _totalPayment = 0;
              _totalInterest = 0;
            } else {
              double n = log(_targetEmi / (_targetEmi - _amount * monthlyRate)) / log(1 + monthlyRate);
              _calculatedTenureMonths = n;
              _totalPayment = _targetEmi * n;
              _totalInterest = _totalPayment - _amount;
            }
          } else {
            _calculatedTenureMonths = 0;
            _totalPayment = 0;
            _totalInterest = 0;
          }
          break;

        case CalculatorMode.calculateRoi:
          if (_amount > 0 && _targetEmi > 0 && months > 0) {
            if (_targetEmi * months <= _amount) {
              _errorMessage = 'Total EMI paid must exceed loan principal.';
              _calculatedRate = 0;
              _totalPayment = 0;
              _totalInterest = 0;
            } else {
              // Binary search to find monthly rate
              double low = 0.0001; // ~0.12% per year
              double high = 0.10;  // 120% per year
              for (int i = 0; i < 35; i++) {
                double mid = (low + high) / 2;
                double factor = pow(1 + mid, months).toDouble();
                double emiEstimate = (_amount * mid * factor) / (factor - 1);
                if (emiEstimate > _targetEmi) {
                  high = mid;
                } else {
                  low = mid;
                }
              }
              _calculatedRate = (low + high) / 2 * 12 * 100;
              _totalPayment = _targetEmi * months;
              _totalInterest = _totalPayment - _amount;
            }
          } else {
            _calculatedRate = 0;
            _totalPayment = 0;
            _totalInterest = 0;
          }
          break;
      }
    });
  }

  String _formatCurrency(double val) {
    if (val.isNaN || val.isInfinite || val <= 0) return '₹ 0';
    final rounded = val.round();
    if (rounded < 1000) return '₹ $rounded';
    String numStr = rounded.toString();
    String lastThree = numStr.substring(numStr.length - 3);
    String otherNumbers = numStr.substring(0, numStr.length - 3);
    String formatted = '';
    while (otherNumbers.length > 2) {
      formatted = ',${otherNumbers.substring(otherNumbers.length - 2)}$formatted';
      otherNumbers = otherNumbers.substring(0, otherNumbers.length - 2);
    }
    formatted = otherNumbers + formatted + ',' + lastThree;
    return '₹ $formatted';
  }

  List<AmortizationRow> _generateMonthlySchedule() {
    double principal = (_activeMode == CalculatorMode.calculateLoanAmount) ? _calculatedLoanAmount : _amount;
    double rate = (_activeMode == CalculatorMode.calculateRoi) ? _calculatedRate : _rate;
    double emi = (_activeMode == CalculatorMode.calculateEmi) ? _calculatedEmi : _targetEmi;
    double totalMonths = (_activeMode == CalculatorMode.calculateTenure)
        ? _calculatedTenureMonths
        : (_isTenureInYears ? _tenureYears * 12 : _tenureYears);

    int count = totalMonths.ceil();
    if (principal <= 0 || rate <= 0 || emi <= 0 || count <= 0 || count > 480) return [];

    double monthlyRate = rate / 12 / 100;
    double balance = principal;
    List<AmortizationRow> rows = [];

    for (int m = 1; m <= count; m++) {
      double opening = balance;
      double interest = opening * monthlyRate;
      double principalPaid = emi - interest;
      if (principalPaid > balance || m == count) {
        principalPaid = balance;
        emi = principalPaid + interest;
        balance = 0;
      } else {
        balance -= principalPaid;
      }

      rows.add(AmortizationRow(
        period: m,
        openingBalance: opening,
        emi: emi,
        principal: principalPaid,
        interest: interest,
        closingBalance: max(0, balance),
      ));

      if (balance <= 0) break;
    }
    return rows;
  }

  List<YearlyAmortizationRow> _generateYearlySchedule(List<AmortizationRow> monthly) {
    List<YearlyAmortizationRow> yearly = [];
    if (monthly.isEmpty) return yearly;

    int currentYear = 1;
    double yearOpening = monthly.first.openingBalance;
    double yearEmi = 0;
    double yearPrincipal = 0;
    double yearInterest = 0;
    double yearClosing = 0;

    for (int i = 0; i < monthly.length; i++) {
      final row = monthly[i];
      yearEmi += row.emi;
      yearPrincipal += row.principal;
      yearInterest += row.interest;
      yearClosing = row.closingBalance;

      if ((i + 1) % 12 == 0 || i == monthly.length - 1) {
        yearly.add(YearlyAmortizationRow(
          year: currentYear,
          openingBalance: yearOpening,
          totalEmi: yearEmi,
          principal: yearPrincipal,
          interest: yearInterest,
          closingBalance: yearClosing,
        ));
        currentYear++;
        if (i + 1 < monthly.length) {
          yearOpening = monthly[i + 1].openingBalance;
        }
        yearEmi = 0;
        yearPrincipal = 0;
        yearInterest = 0;
      }
    }
    return yearly;
  }

  void _showRepaymentScheduleModal() {
    final monthlyRows = _generateMonthlySchedule();
    final yearlyRows = _generateYearlySchedule(monthlyRows);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DefaultTabController(
              length: 2,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Repayment Schedule',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              Text(
                                'Amortization breakdown over loan tenure',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const TabBar(
                      labelColor: Color(0xFF4A3AFF),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFF4A3AFF),
                      tabs: [
                        Tab(text: 'Yearly Summary'),
                        Tab(text: 'Monthly Breakdown'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Yearly Tab
                          _buildYearlyTable(yearlyRows),
                          // Monthly Tab
                          _buildMonthlyTable(monthlyRows),
                        ],
                      ),
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

  Widget _buildYearlyTable(List<YearlyAmortizationRow> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No repayment schedule available for these values.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F5F9)),
          columns: const [
            DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Opening Bal.', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Total EMI', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Principal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Interest', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Closing Bal.', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: rows.map((r) {
            return DataRow(cells: [
              DataCell(Text('Yr ${r.year}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF)))),
              DataCell(Text(_formatCurrency(r.openingBalance))),
              DataCell(Text(_formatCurrency(r.totalEmi))),
              DataCell(Text(_formatCurrency(r.principal), style: const TextStyle(color: Color(0xFF27AE60), fontWeight: FontWeight.w600))),
              DataCell(Text(_formatCurrency(r.interest), style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600))),
              DataCell(Text(_formatCurrency(r.closingBalance))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthlyTable(List<AmortizationRow> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No repayment schedule available for these values.'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF3F5F9)),
          columns: const [
            DataColumn(label: Text('Month', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Opening Bal.', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('EMI', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Principal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Interest', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Closing Bal.', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: rows.map((r) {
            return DataRow(cells: [
              DataCell(Text('Mo ${r.period}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A3AFF)))),
              DataCell(Text(_formatCurrency(r.openingBalance))),
              DataCell(Text(_formatCurrency(r.emi))),
              DataCell(Text(_formatCurrency(r.principal), style: const TextStyle(color: Color(0xFF27AE60)))),
              DataCell(Text(_formatCurrency(r.interest), style: const TextStyle(color: Colors.deepOrange))),
              DataCell(Text(_formatCurrency(r.closingBalance))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'Advanced EMI Calculator',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // Mode Selector
            _buildModeSelector(),
            const SizedBox(height: 20),

            // Main Result Card
            _buildResultCard(),
            const SizedBox(height: 20),

            // Inputs according to mode
            _buildInputs(),
            const SizedBox(height: 24),

            // View Repayment Schedule Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _showRepaymentScheduleModal,
                icon: const Icon(Icons.table_chart_outlined, color: Colors.white),
                label: const Text(
                  'View Repayment Schedule',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A3AFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildModeTab('EMI', CalculatorMode.calculateEmi, Icons.calculate_outlined),
          _buildModeTab('Amount', CalculatorMode.calculateLoanAmount, Icons.monetization_on_outlined),
          _buildModeTab('Tenure', CalculatorMode.calculateTenure, Icons.calendar_month_outlined),
          _buildModeTab('ROI %', CalculatorMode.calculateRoi, Icons.percent_outlined),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, CalculatorMode mode, IconData icon) {
    final isSelected = _activeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeMode = mode;
            _recalculate();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A3AFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    String title = 'Monthly EMI';
    String primaryValue = _formatCurrency(_calculatedEmi);
    String subtitle = 'Payable every month';

    if (_activeMode == CalculatorMode.calculateLoanAmount) {
      title = 'Eligible Loan Amount';
      primaryValue = _formatCurrency(_calculatedLoanAmount);
      subtitle = 'Maximum loan you can borrow';
    } else if (_activeMode == CalculatorMode.calculateTenure) {
      title = 'Loan Repayment Period';
      int totalM = _calculatedTenureMonths.round();
      int y = totalM ~/ 12;
      int m = totalM % 12;
      primaryValue = '$y Yrs ${m > 0 ? '$m Mos' : ''}';
      subtitle = 'Total $totalM monthly payments';
    } else if (_activeMode == CalculatorMode.calculateRoi) {
      title = 'Calculated Interest Rate';
      primaryValue = '${_calculatedRate.toStringAsFixed(2)} %';
      subtitle = 'Effective per annum ROI';
    }

    double principal = (_activeMode == CalculatorMode.calculateLoanAmount) ? _calculatedLoanAmount : _amount;
    double principalRatio = (_totalPayment > 0) ? (principal / _totalPayment) : 0.7;
    double interestRatio = (_totalPayment > 0) ? (_totalInterest / _totalPayment) : 0.3;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A3AFF), Color(0xFF3228B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4A3AFF).withOpacity(0.35), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? primaryValue,
            style: TextStyle(
              color: _errorMessage != null ? Colors.amberAccent : Colors.white,
              fontSize: _errorMessage != null ? 18 : 32,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
          const SizedBox(height: 20),

          // Visual Ratio Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Expanded(
                  flex: (principalRatio * 100).round().clamp(1, 100),
                  child: Container(height: 8, color: const Color(0xFF27AE60)),
                ),
                Expanded(
                  flex: (interestRatio * 100).round().clamp(1, 100),
                  child: Container(height: 8, color: Colors.amberAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Breakdown statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatSummary('Principal Amount', _formatCurrency(principal), const Color(0xFF27AE60)),
              _buildStatSummary('Total Interest', _formatCurrency(_totalInterest), Colors.amberAccent),
              _buildStatSummary('Total Payment', _formatCurrency(_totalPayment), Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatSummary(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInputs() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Loan Amount Field & Slider (if not in calculateLoanAmount mode)
          if (_activeMode != CalculatorMode.calculateLoanAmount) ...[
            _buildEditableSliderField(
              title: 'Loan Amount (₹)',
              controller: _amountController,
              value: _amount,
              min: 50000,
              max: 100000000, // 10 Crore
              onChanged: (val) {
                _amount = val;
                _amountController.text = val.round().toString();
                _recalculate();
              },
              onTextChanged: (text) {
                final parsed = double.tryParse(text) ?? _amount;
                _amount = parsed.clamp(50000, 100000000);
                _recalculate();
              },
              presets: [
                {'label': '₹5 Lakh', 'value': 500000.0},
                {'label': '₹15 Lakh', 'value': 1500000.0},
                {'label': '₹25 Lakh', 'value': 2500000.0},
                {'label': '₹50 Lakh', 'value': 5000000.0},
                {'label': '₹1 Crore', 'value': 10000000.0},
              ],
            ),
            const Divider(height: 28),
          ],

          // Target EMI Field & Slider (if in calculateLoanAmount, calculateTenure, or calculateRoi mode)
          if (_activeMode != CalculatorMode.calculateEmi) ...[
            _buildEditableSliderField(
              title: 'Monthly EMI (₹)',
              controller: _emiController,
              value: _targetEmi,
              min: 2000,
              max: 1000000,
              onChanged: (val) {
                _targetEmi = val;
                _emiController.text = val.round().toString();
                _recalculate();
              },
              onTextChanged: (text) {
                final parsed = double.tryParse(text) ?? _targetEmi;
                _targetEmi = parsed.clamp(2000, 1000000);
                _recalculate();
              },
              presets: [
                {'label': '₹10,000', 'value': 10000.0},
                {'label': '₹25,000', 'value': 25000.0},
                {'label': '₹50,000', 'value': 50000.0},
                {'label': '₹1 Lakh', 'value': 100000.0},
              ],
            ),
            const Divider(height: 28),
          ],

          // Interest Rate Field & Slider (if not in calculateRoi mode)
          if (_activeMode != CalculatorMode.calculateRoi) ...[
            _buildEditableSliderField(
              title: 'Interest Rate (% P.A.)',
              controller: _rateController,
              value: _rate,
              min: 1.0,
              max: 30.0,
              onChanged: (val) {
                _rate = val;
                _rateController.text = val.toStringAsFixed(1);
                _recalculate();
              },
              onTextChanged: (text) {
                final parsed = double.tryParse(text) ?? _rate;
                _rate = parsed.clamp(1.0, 30.0);
                _recalculate();
              },
              presets: [
                {'label': '8.5 %', 'value': 8.5},
                {'label': '9.5 %', 'value': 9.5},
                {'label': '10.5 %', 'value': 10.5},
                {'label': '12.0 %', 'value': 12.0},
                {'label': '14.0 %', 'value': 14.0},
              ],
            ),
            const Divider(height: 28),
          ],

          // Tenure Field & Slider (if not in calculateTenure mode)
          if (_activeMode != CalculatorMode.calculateTenure) ...[
            _buildTenureField(),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableSliderField({
    required String title,
    required TextEditingController controller,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
    required Function(String) onTextChanged,
    required List<Map<String, dynamic>> presets,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
            Container(
              width: 140,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4A3AFF)),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 10)),
                onChanged: onTextChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF4A3AFF),
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: const Color(0xFF4A3AFF),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((p) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(p['label'] as String, style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFFF3F5F9),
                  side: BorderSide(color: Colors.grey.shade300),
                  onPressed: () => onChanged(p['value'] as double),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTenureField() {
    double min = _isTenureInYears ? 1 : 6;
    double max = _isTenureInYears ? 30 : 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Tenure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildUnitToggle('Yr', _isTenureInYears, () {
                        setState(() {
                          _isTenureInYears = true;
                          _tenureController.text = _tenureYears.round().toString();
                          _recalculate();
                        });
                      }),
                      _buildUnitToggle('Mo', !_isTenureInYears, () {
                        setState(() {
                          _isTenureInYears = false;
                          _tenureController.text = (_tenureYears * 12).round().toString();
                          _recalculate();
                        });
                      }),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              width: 100,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: _tenureController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF4A3AFF)),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.only(bottom: 10)),
                onChanged: (text) {
                  final parsed = double.tryParse(text) ?? _tenureYears;
                  if (_isTenureInYears) {
                    _tenureYears = parsed.clamp(1, 30);
                  } else {
                    _tenureYears = (parsed / 12).clamp(0.5, 30);
                  }
                  _recalculate();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF4A3AFF),
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: const Color(0xFF4A3AFF),
            trackHeight: 4,
          ),
          child: Slider(
            value: (_isTenureInYears ? _tenureYears : (_tenureYears * 12)).clamp(min, max),
            min: min,
            max: max,
            onChanged: (val) {
              if (_isTenureInYears) {
                _tenureYears = val;
                _tenureController.text = val.round().toString();
              } else {
                _tenureYears = val / 12;
                _tenureController.text = val.round().toString();
              }
              _recalculate();
            },
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [1, 3, 5, 10, 15, 20, 25, 30].map((y) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text('$y Yr', style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFFF3F5F9),
                  side: BorderSide(color: Colors.grey.shade300),
                  onPressed: () {
                    _tenureYears = y.toDouble();
                    _tenureController.text = _isTenureInYears ? y.toString() : (y * 12).toString();
                    _recalculate();
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUnitToggle(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A3AFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
