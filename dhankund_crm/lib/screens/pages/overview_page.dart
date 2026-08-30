import 'package:flutter/material.dart';
import '../../firebase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/custom_chart.dart';

class OverviewPage extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const OverviewPage({super.key, required this.onNavigateToTab});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  Map<String, dynamic> _metrics = {};
  List<Map<String, dynamic>> _recentDsa = [];
  List<Map<String, dynamic>> _recentBankers = [];

  @override
  void initState() {
    super.initState();
    _loadOverviewData();
  }

  Future<void> _loadOverviewData() async {
    setState(() => _isLoading = true);
    try {
      final metrics = await _firestoreService.fetchOverviewMetrics();
      final dsaList = await _firestoreService.fetchRegistrations('DSA');
      final bankerList = await _firestoreService.fetchRegistrations('Banker');

      setState(() {
        _metrics = metrics;
        _recentDsa = dsaList.where((e) => e['status'] == 'pending').take(3).toList();
        _recentBankers = bankerList.where((e) => e['status'] == 'pending').take(3).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading overview details: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.royalGold),
      );
    }

    final double disbursedVal = _metrics['disbursedCommission'] ?? 0.0;
    final double pendingVal = _metrics['pendingCommission'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _loadOverviewData,
      color: AppTheme.royalGold,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time stats and partner registrations tracker.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _loadOverviewData,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh Data'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stat Cards Grid
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                  children: [
                    StatCard(
                      title: 'TOTAL REGISTERED USERS',
                      value: '${_metrics['totalUsers']}',
                      subtitle: 'Active B2B Directory users',
                      icon: Icons.people,
                      iconColor: AppTheme.royalGold,
                      trendText: '+12%',
                    ),
                    StatCard(
                      title: 'PENDING REGISTRATIONS',
                      value: '${_metrics['pendingApprovals']}',
                      subtitle: 'Requires immediate review',
                      icon: Icons.pending_actions,
                      iconColor: Colors.amber,
                      trendText: 'New',
                      isTrendingUp: true,
                    ),
                    StatCard(
                      title: 'LOAN APPLICATIONS',
                      value: '${_metrics['totalLoans']}',
                      subtitle: 'Personal, Business & Home loans',
                      icon: Icons.monetization_on,
                      iconColor: AppTheme.emeraldGreen,
                      trendText: '+8%',
                    ),
                    StatCard(
                      title: 'TOTAL DISBURSED PAYOUT',
                      value: '₹${disbursedVal.toStringAsFixed(0)}',
                      subtitle: '₹${pendingVal.toStringAsFixed(0)} Processing',
                      icon: Icons.account_balance_wallet,
                      iconColor: Colors.lightBlueAccent,
                      trendText: 'Wallet',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Chart & Action Row
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 950) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildChartContainer(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: _buildQuickActionsPanel(),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildChartContainer(),
                      const SizedBox(height: 24),
                      _buildQuickActionsPanel(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer() {
    return GlassCard(
      padding: 24.0,
      child: SizedBox(
        height: 350,
        child: CustomChart(
          title: 'Partner Referral Earnings Growth (₹)',
          data: const [30000, 45000, 60000, 95000, 110000, 150000],
          labels: const ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'],
        ),
      ),
    );
  }

  Widget _buildQuickActionsPanel() {
    return GlassCard(
      padding: 20.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Action Alerts',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.royalGold,
                ),
          ),
          const SizedBox(height: 16),
          if (_recentDsa.isEmpty && _recentBankers.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Text(
                  'All caught up! No pending registrations.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ] else ...[
            ..._recentDsa.map((dsa) => _buildAlertItem(
                  context: context,
                  title: 'New DSA Register Request',
                  subtitle: '${dsa['name']} (${dsa['company'] ?? 'Individual'})',
                  icon: Icons.person_add,
                  onTap: () => widget.onNavigateToTab(1), // Navigates to registrations
                )),
            ..._recentBankers.map((banker) => _buildAlertItem(
                  context: context,
                  title: 'New Banker Register Request',
                  subtitle: '${banker['name']} (${banker['company']})',
                  icon: Icons.business,
                  onTap: () => widget.onNavigateToTab(1), // Navigates to registrations
                )),
          ],
          const Divider(color: Colors.white10, height: 24),
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppTheme.royalGold.withOpacity(0.1),
                child: const Icon(Icons.verified_user, color: AppTheme.royalGold),
              ),
              title: const Text('Verify KYC Submissions'),
              subtitle: const Text('Check identity card uploads'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              onTap: () => widget.onNavigateToTab(2), // Navigates to KYC
            ),
          ),
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppTheme.emeraldGreen.withOpacity(0.1),
                child: const Icon(Icons.account_balance, color: AppTheme.emeraldGreen),
              ),
              title: const Text('Manage Loan Lead Pipelines'),
              subtitle: const Text('View and update loan states'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
              onTap: () => widget.onNavigateToTab(3), // Navigates to Loans
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppTheme.obsidianMedium,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.amber.withOpacity(0.25)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(icon, color: Colors.amber),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textSecondary),
          onTap: onTap,
        ),
      ),
    );
  }
}
