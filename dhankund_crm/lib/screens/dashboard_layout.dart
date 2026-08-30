import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pages/overview_page.dart';
import 'pages/registrations_page.dart';
import 'pages/kyc_bank_page.dart';
import 'pages/loans_page.dart';
import 'pages/referrals_page.dart';
import 'pages/community_page.dart';
import 'pages/broadcast_page.dart';
import 'pages/leads_report_page.dart';
import 'pages/banker_policies_page.dart';

class DashboardLayout extends StatefulWidget {
  const DashboardLayout({super.key});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  int _activeTabIndex = 0;

  final List<String> _tabsTitles = [
    'Overview Metrics',
    'B2B Registrations',
    'KYC & Bank Accounts',
    'Loan Pipelines',
    'Payouts & Referrals',
    'Community Network',
    'Broadcast',
    'Leads Report',
    'Banker Policies',
  ];

  final List<IconData> _tabsIcons = [
    Icons.dashboard_outlined,
    Icons.how_to_reg_outlined,
    Icons.verified_user_outlined,
    Icons.assignment_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.forum_outlined,
    Icons.campaign_outlined,
    Icons.analytics_outlined,
    Icons.policy_outlined,
  ];

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      OverviewPage(onNavigateToTab: (index) {
        setState(() {
          _activeTabIndex = index;
        });
      }),
      const RegistrationsPage(),
      const KycBankPage(),
      const LoansPage(),
      const ReferralsPage(),
      const CommunityPage(),
      const BroadcastPage(),
      const LeadsReportPage(),
      const BankerPoliciesPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.backgroundGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: MediaQuery.of(context).size.width <= 1000 ? _buildSidebar(isDrawer: true) : null,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sidebar for Larger Screens
              if (MediaQuery.of(context).size.width > 1000)
                SizedBox(
                  width: 280,
                  child: _buildSidebar(isDrawer: false),
                ),

              // Main content region
              Expanded(
                child: Column(
                  children: [
                    // Top App Header bar
                    _buildHeader(),

                    // Current page panel
                    Expanded(
                      child: IndexedStack(
                        index: _activeTabIndex,
                        children: _pages,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar({required bool isDrawer}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.obsidianMedium,
        border: const Border(
          right: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo & Title Section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.royalGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.royalGold.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: AppTheme.royalGold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DHANKUND',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'CRM CONTROL CENTER',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.royalGold,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 16),

          // Sidebar Tab items
          Expanded(
            child: ListView.builder(
              itemCount: _tabsTitles.length,
              itemBuilder: (context, index) {
                final isSelected = _activeTabIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeTabIndex = index;
                      });
                      if (isDrawer) {
                        Navigator.of(context).pop(); // Close drawer on mobile selection
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: isSelected
                          ? BoxDecoration(
                              color: AppTheme.royalGold.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.royalGold.withOpacity(0.2),
                                width: 1.0,
                              ),
                            )
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            _tabsIcons[index],
                            color: isSelected ? AppTheme.royalGold : AppTheme.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _tabsTitles[index],
                            style: TextStyle(
                              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Admin profile card at bottom of sidebar
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.royalGold.withOpacity(0.1),
                  child: const Text('AD', style: TextStyle(color: AppTheme.royalGold, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Super Administrator',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'admin@dhankund.com',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: const BoxDecoration(
        color: AppTheme.obsidianMedium,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (MediaQuery.of(context).size.width <= 1000)
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu, color: AppTheme.royalGold),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                _tabsTitles[_activeTabIndex],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          // Clock & Status badges
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: AppTheme.royalGold, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'SECURE CHANNEL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'July 28, 2026',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
