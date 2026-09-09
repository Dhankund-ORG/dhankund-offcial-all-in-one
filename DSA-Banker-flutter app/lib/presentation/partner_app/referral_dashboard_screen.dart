import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/api_service.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/presentation/auth/welcome_screen.dart';
import 'package:my_flutter_app/presentation/partner_app/refer_friend_form_screen.dart';

class ReferralDashboardScreen extends StatefulWidget {
  const ReferralDashboardScreen({super.key});
  @override
  State<ReferralDashboardScreen> createState() => _ReferralDashboardScreenState();
}

class _ReferralDashboardScreenState extends State<ReferralDashboardScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _referrals = [];
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() { super.initState(); _loadReferrals(); _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadReferrals()); }
  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  Future<void> _loadReferrals() async {
    try {
      final list = await _api.fetchMyReferrals();
      if (mounted) setState(() { _referrals = list; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final total = _referrals.length;
    final invited = _referrals.where((r) => (r['status'] ?? 'Invited').toLowerCase() == 'invited').length;
    final approved = _referrals.where((r) => (r['status'] ?? '').toLowerCase() == 'approved').length;
    final earned = _referrals.where((r) => (r['status'] ?? '').toLowerCase() == 'earned').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text('My Referrals', style: TextStyle(color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.black87), onPressed: _logout)],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4A3AFF),
        onRefresh: _loadReferrals,
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A3AFF)))
          : ListView(padding: const EdgeInsets.all(20.0), children: [
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.6, children: [
              _buildStatCard('Total', total, const Color(0xFF4A3AFF)),
              _buildStatCard('Invited', invited, Colors.orange),
              _buildStatCard('Approved', approved, Colors.blue),
              _buildStatCard('Earned', earned, const Color(0xFF27AE60)),
            ]),
            const SizedBox(height: 24),
            if (_referrals.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No referrals yet. Refer a friend to get started!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))))
            else
              ..._referrals.map((r) => _buildReferralCard(r)),
            const SizedBox(height: 80),
          ]),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferFriendFormScreen())), backgroundColor: const Color(0xFF4A3AFF), icon: const Icon(Icons.add, color: Colors.white), label: const Text('Refer a Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(count.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 4), Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))]));
  }

  Widget _buildReferralCard(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'Invited').toString();
    Color statusColor;
    if (status.toLowerCase() == 'earned') statusColor = const Color(0xFF27AE60);
    else if (status.toLowerCase() == 'approved') statusColor = Colors.blue;
    else statusColor = Colors.orange;
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF4A3AFF).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person, color: Color(0xFF4A3AFF))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r['friend_name'] ?? 'Friend', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(r['friend_mobile'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13))]))]),
      const SizedBox(height: 12), const Divider(),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(r['loan_type'] ?? 'Loan', style: TextStyle(color: Colors.grey[600], fontSize: 13)), if ((r['estimated_amount'] ?? '').toString().isNotEmpty) Text('₹${r['estimated_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold))),
    ]));
  }
}
