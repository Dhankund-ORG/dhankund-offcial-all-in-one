import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
  void initState() {
    super.initState();
    _loadReferrals();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadReferrals());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadReferrals() async {
    try {
      final list = await _api.fetchMyReferrals();
      if (mounted) {
        setState(() {
          _referrals = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  String _formatDateTime(dynamic createdAt) {
    if (createdAt == null || createdAt.toString().isEmpty) return 'Date N/A';
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$min';
    } catch (_) {
      return createdAt.toString();
    }
  }

  String _getTatStatus(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt.toString());
      final diff = DateTime.now().difference(dt);
      if (diff.inHours < 24) {
        return 'TAT: ${diff.inHours}h elapsed (Within SLA)';
      } else {
        return 'TAT: ${diff.inDays}d ${diff.inHours % 24}h elapsed';
      }
    } catch (_) {
      return '';
    }
  }

  Future<void> _openDocument(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open document URL')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening document: $e')));
      }
    }
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
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.black87), onPressed: _logout)],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4A3AFF),
        onRefresh: _loadReferrals,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A3AFF)))
            : ListView(
                padding: const EdgeInsets.all(20.0),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _buildStatCard('Total Referrals', total, const Color(0xFF4A3AFF)),
                      _buildStatCard('Invited / In Review', invited, Colors.orange),
                      _buildStatCard('Approved', approved, Colors.blue),
                      _buildStatCard('Earned / Disbursed', earned, const Color(0xFF27AE60)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Referred Leads & TAT Tracker',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A3AFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$total Leads',
                          style: const TextStyle(color: Color(0xFF4A3AFF), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_referrals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No referrals yet. Refer a friend to get started and earn unlimited payouts!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._referrals.map((r) => _buildReferralCard(r)),
                  const SizedBox(height: 80),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferFriendFormScreen()));
          _loadReferrals();
        },
        backgroundColor: const Color(0xFF4A3AFF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Refer a Lead', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count.toString(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildReferralCard(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'Invited').toString();
    String leadId = (r['lead_id'] ?? r['leadId'] ?? r['leadID'] ?? '').toString();
    final createdAt = r['created_at'];
    if (leadId.isEmpty || leadId == 'null' || leadId == 'Pending ID') {
      final rawId = (r['id'] ?? '').toString();
      final dt = DateTime.tryParse(createdAt?.toString() ?? '') ?? DateTime.now();
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = dt.year.toString().substring(2);
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final hashSeq = (rawId.hashCode.abs() % 900000 + 100000).toString();
      leadId = '$dd$mm$yy$hh$min$hashSeq';
    }
    final docUrl = (r['document_url'] ?? '').toString();
    final tatText = _getTatStatus(createdAt);
    final isWithinSla = tatText.contains('Within SLA');

    Color statusColor;
    if (status.toLowerCase() == 'earned') {
      statusColor = const Color(0xFF27AE60);
    } else if (status.toLowerCase() == 'approved') {
      statusColor = Colors.blue;
    } else {
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Lead ID Chip & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A3AFF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4A3AFF).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag, size: 15, color: Color(0xFF4A3AFF)),
                      const SizedBox(width: 4),
                      Text(
                        'LEAD ID: ',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                      ),
                      Flexible(
                        child: Text(
                          leadId,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A3AFF),
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: leadId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lead ID $leadId copied!'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Icon(Icons.copy, size: 14, color: Color(0xFF4A3AFF)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Friend details
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A3AFF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Color(0xFF4A3AFF), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r['friend_name'] ?? 'Friend',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((r['relationship'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r['relationship'],
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r['friend_mobile'] ?? '',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    if ((r['friend_email'] ?? '').toString().isNotEmpty)
                      Text(
                        r['friend_email'],
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Loan type and Estimated Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    r['loan_type'] ?? 'Loan',
                    style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if ((r['estimated_amount'] ?? '').toString().isNotEmpty)
                Text(
                  '₹${r['estimated_amount']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF27AE60)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Date & Time + TAT Breach Protection Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_filled, size: 15, color: Colors.indigo),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Referred: ${_formatDateTime(createdAt)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      if (tatText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          tatText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isWithinSla ? const Color(0xFF27AE60) : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (docUrl.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () => _openDocument(docUrl),
                    icon: const Icon(Icons.attachment, size: 13, color: Colors.white),
                    label: const Text('Doc', style: TextStyle(fontSize: 11, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A3AFF),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
