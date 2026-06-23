import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_flutter_app/presentation/auth/welcome_screen.dart';
import 'package:my_flutter_app/presentation/customer_app/emi_calculator_screen.dart';
import 'package:my_flutter_app/presentation/customer_app/loan_selection_screen.dart';
import 'package:my_flutter_app/presentation/customer_app/my_loans_screen.dart';
import 'package:my_flutter_app/presentation/partner_app/referral_dashboard_screen.dart';
import 'package:my_flutter_app/presentation/b2b_network/banker_form_screen.dart';
import 'package:my_flutter_app/presentation/b2b_network/builder_broker_form_screen.dart';
import 'package:my_flutter_app/presentation/b2b_network/dsa_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF3F5F9,
      ), // Light background like in image
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png'),
        ),
        title: const Text(
          'Dhankund',
          style: TextStyle(
            color: Color(0xFF4A3AFF),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black87,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
        automaticallyImplyLeading: false, // Don't show back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome to Dhankund',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // Text Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose from the options below to get started with your financial journey',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Apply for a Loan Card
            _buildActionCard(
              context,
              title: 'Apply for a Loan',
              subtitle: 'Quick and easy loan application',
              icon: Icons.account_balance,
              color: const Color(0xFF4A3AFF), // Deep Blue/Purple
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoanSelectionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // My Loans Card
            _buildActionCard(
              context,
              title: 'My Loans',
              subtitle: 'Track your active loans and status',
              icon: Icons.assignment_turned_in,
              color: const Color(0xFF6C5CE7), // Purple/Indigo
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyLoansScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Refer a Friend Card
            _buildActionCard(
              context,
              title: 'Refer a Friend',
              subtitle: 'Earn rewards for referrals',
              icon: Icons.people,
              color: const Color(0xFF2E9C8E), // Teal/Green
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReferralDashboardScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // EMI Calculator Card
            _buildActionCard(
              context,
              title: 'EMI Calculator',
              subtitle: 'Calculate your monthly payments',
              icon: Icons.calculate,
              color: const Color(0xFF3ACCC3), // Cyan
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmiCalculatorScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Banker Registration Card
            _buildActionCard(
              context,
              title: 'Banker Registration',
              subtitle: 'Register for Banker portal',
              icon: Icons.admin_panel_settings,
              color: const Color(0xFFE17055), // Coral/Orange
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BankerFormScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Builder/Broker Registration Card
            _buildActionCard(
              context,
              title: 'Builder / Broker / Connector',
              subtitle: 'Register as a professional partner',
              icon: Icons.handshake_outlined,
              color: const Color(0xFF0984E3), // Bright Blue
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuilderBrokerFormScreen(role: 'Builder'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // DSA Registration Card
            _buildActionCard(
              context,
              title: 'DSA Registration',
              subtitle: 'Register as a Direct Selling Agent',
              icon: Icons.assignment_ind_outlined,
              color: const Color(0xFF27AE60), // Green
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DsaFormScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            // Need Help Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFC3C0F7), // Light Purple
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 48,
                    color: Color(0xFF4A3AFF),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Need Help?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Our customer support team is here to assist you with any questions about loans, referrals, or calculations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 2,
                    width: 100,
                    color: const Color(0xFF4A3AFF),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}

