import 'package:flutter/material.dart';
import 'package:my_flutter_app/presentation/customer_app/loan_application_screen.dart';

class LoanSelectionScreen extends StatelessWidget {
  const LoanSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          'Loan Application',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose Your Loan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select the type of loan that best fits your financial needs',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  _buildLoanTypeCard(
                    context,
                    title: 'Personal Loan',
                    subtitle:
                        'Quick funds for personal expenses, medical bills, or emergencies',
                    icon: Icons.person,
                    iconBgColor: const Color(0xFFE3F2FD), // Light Blue
                    iconColor: const Color(0xFF4A3AFF), // Deep Blue
                  ),
                  _buildLoanTypeCard(
                    context,
                    title: 'Business Loan',
                    subtitle:
                        'Expand your business operations and achieve growth goals',
                    icon: Icons.business,
                    iconBgColor: const Color(0xFFE8F5E9), // Light Green
                    iconColor: const Color(0xFF2E9C8E), // Teal
                  ),
                  _buildLoanTypeCard(
                    context,
                    title: 'Home Loan',
                    subtitle:
                        'Finance your dream home with competitive interest rates',
                    icon: Icons.home,
                    iconBgColor: const Color(0xFFFFF8E1), // Light Yellow
                    iconColor: const Color(0xFFFFB300), // Amber
                  ),
                  _buildLoanTypeCard(
                    context,
                    title: 'Mortgage Loan',
                    subtitle:
                        'Secure financing against your property for major investments',
                    icon: Icons.account_balance,
                    iconBgColor: const Color(0xFFFCE4EC), // Light Pink
                    iconColor: const Color(0xFFD81B60), // Pink
                  ),
                  _buildLoanTypeCard(
                    context,
                    title: 'CC/OD Limit',
                    subtitle:
                        'Credit card and overdraft facilities for flexible financing',
                    icon: Icons.credit_card,
                    iconBgColor: const Color(0xFFE1F5FE), // Light Cyan
                    iconColor: const Color(0xFF039BE5), // Light Blue
                  ),
                  _buildLoanTypeCard(
                    context,
                    title: 'Commercial Construction Loan',
                    subtitle:
                        'Fund your commercial construction and development projects',
                    icon: Icons.construction,
                    iconBgColor: const Color(0xFFFFEBEE), // Light Red
                    iconColor: const Color(0xFFE53935), // Red
                  ),
                ],
              ),
            ),
          ),
          // Help Banner
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFC3C0F7), // Light Purple
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A3AFF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need Help Choosing?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A3AFF),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Our loan experts are here to guide you through the application process',
                        style: TextStyle(color: Colors.black87, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTypeCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LoanApplicationScreen(loanTitle: title),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

