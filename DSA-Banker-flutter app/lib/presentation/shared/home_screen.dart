import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/auth_service.dart';
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
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png'),
        ),
        title: const Text('Dhankund', style: TextStyle(color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.black87), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Welcome to Dhankund', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.orange.shade300), borderRadius: BorderRadius.circular(4), color: Colors.grey.shade100),
              child: const Text('Choose from the options below to get started with your financial journey', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 24),
            _buildActionCard(context, title: 'Apply for a Loan', subtitle: 'Quick and easy loan application', icon: Icons.account_balance, color: const Color(0xFF4A3AFF), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoanSelectionScreen()))),
            const SizedBox(height: 16),
            _buildActionCard(context, title: 'My Loans', subtitle: 'Track your active loans and status', icon: Icons.assignment_turned_in, color: const Color(0xFF6C5E7), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyLoansScreen()))),
            const SizedBox(height: 16),
            _buildActionCard(context, title: 'Refer a Friend', subtitle: 'Earn rewards for referrals', icon: Icons.people, color: const Color(0xFF2E9C8E), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferralDashboardScreen()))),
            const SizedBox(height: 16),
            _buildActionCard(context, title: 'EMI Calculator', subtitle: 'Calculate your monthly payments', icon: Icons.calculate, color: const Color(0xFF3ACCC3), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmiCalculatorScreen()))),
            const SizedBox(height: 16),
            _buildActionCard(context, title: 'Banker Registration', subtitle: 'Register for Banker portal', icon: Icons.admin_panel_settings, color: const Color(0xFFE17055), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BankerFormScreen()))),
            const SizedBox(height: 16),
            _buildActionCard(context, title: 'Builder / Broker / Connector', subtitle: 'Register as a professional partner', icon: Icons.handshake_outlined, color: const Color(0xFF0984E3), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BuilderBrokerFormScreen(role: 'Builder')))),
            const SizedBox(height: 16),
            _buildActionCard(context, title: 'DSA Registration', subtitle: 'Register as a Direct Selling Agent', icon: Icons.assignment_ind_outlined, color: const Color(0xFF27AE60), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DsaFormScreen()))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600]))])),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }
}
