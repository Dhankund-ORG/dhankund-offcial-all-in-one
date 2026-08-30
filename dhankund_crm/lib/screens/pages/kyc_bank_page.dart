import 'package:flutter/material.dart';
import '../../firebase_service.dart';
import '../../cloudflare_r2_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class KycBankPage extends StatefulWidget {
  const KycBankPage({super.key});

  @override
  State<KycBankPage> createState() => _KycBankPageState();
}

class _KycBankPageState extends State<KycBankPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final CloudflareR2Service _r2Service = CloudflareR2Service();

  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _firestoreService.fetchKycBankUsers();
      setState(() {
        _users = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading KYC/Bank users: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _kycPendingUsers {
    return _users.where((u) {
      final matchesSearch = u['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      final kycCompleted = u['kycCompleted'] == true;
      final hasKycDetails = (u['kycPan'] != null && u['kycPan'].toString().isNotEmpty) ||
                            (u['kycAadhaar'] != null && u['kycAadhaar'].toString().isNotEmpty);
      return matchesSearch && !kycCompleted && hasKycDetails;
    }).toList();
  }

  List<Map<String, dynamic>> get _bankPendingUsers {
    return _users.where((u) {
      final matchesSearch = u['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      final bankCompleted = u['bankDetailsCompleted'] == true;
      final hasBankDetails = (u['bankAccountNumber'] != null && u['bankAccountNumber'].toString().isNotEmpty);
      return matchesSearch && !bankCompleted && hasBankDetails;
    }).toList();
  }

  List<Map<String, dynamic>> get _allVerifiedUsers {
    return _users.where((u) {
      final matchesSearch = u['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      final kycCompleted = u['kycCompleted'] == true;
      final bankCompleted = u['bankDetailsCompleted'] == true;
      return matchesSearch && kycCompleted && bankCompleted;
    }).toList();
  }

  Future<void> _toggleKycVerification(String uid, bool completed) async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.updateKycVerification(uid, completed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completed ? 'KYC successfully verified!' : 'KYC status reset to unverified'),
          backgroundColor: completed ? AppTheme.emeraldGreen : Colors.amber,
        ),
      );
      _loadUsers();
    } catch (e) {
      debugPrint("Error updating KYC: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBankVerification(String uid, bool completed) async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.updateBankVerification(uid, completed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completed ? 'Bank details successfully verified!' : 'Bank details reset to unverified'),
          backgroundColor: completed ? AppTheme.emeraldGreen : Colors.amber,
        ),
      );
      _loadUsers();
    } catch (e) {
      debugPrint("Error updating Bank details: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showDocumentPreview(String docKey, String docTitle) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.obsidianMedium,
          title: Text(docTitle, style: const TextStyle(color: AppTheme.textPrimary)),
          content: FutureBuilder<String?>(
            future: _r2Service.getBankerDocumentUrl(docKey),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.royalGold)),
                );
              }
              final url = snapshot.data;
              if (url == null) return const Text('Document URL fetch error.');
              
              final isImage = docKey.toLowerCase().endsWith('.png') || 
                              docKey.toLowerCase().endsWith('.jpg') || 
                              docKey.toLowerCase().endsWith('.jpeg');

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isImage)
                    Image.network(
                      url,
                      height: 250,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Text('Image preview is not available'),
                    )
                  else
                    const Icon(Icons.description, size: 64, color: AppTheme.royalGold),
                  const SizedBox(height: 16),
                  Text('Document key: $docKey', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      debugPrint('Presigned URL: $url');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Copied URL: $url')),
                      );
                    },
                    child: const Text('Copy Presigned URL'),
                  )
                ],
              );
            },
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('KYC & Bank Account gates'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.royalGold,
          labelColor: AppTheme.royalGold,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'KYC Verifications'),
            Tab(text: 'Bank Linkings'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search & Metrics Row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search user by name...',
                prefixIcon: Icon(Icons.search, color: AppTheme.royalGold),
              ),
            ),
          ),

          // Main View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: KYC Verification Gate
                      _buildKycTab(),

                      // TAB 2: Bank Linkage Verification Gate
                      _buildBankTab(),
                    ],
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildKycTab() {
    final list = _kycPendingUsers;
    final allVerified = _allVerifiedUsers;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'PENDING KYC VERIFICATION',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Card(
            color: Colors.white10,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No users with pending KYC details submitted.'),
            ),
          )
        else
          ...list.map((u) => _buildKycCard(u, false)),

        const SizedBox(height: 32),
        const Text(
          'FULLY VERIFIED PARTNERS (KYC & BANK CONNECTED)',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        if (allVerified.isEmpty)
          const Text('No fully verified users found.')
        else
          ...allVerified.map((u) => _buildKycCard(u, true)),
      ],
    );
  }

  Widget _buildBankTab() {
    final list = _bankPendingUsers;
    final allVerified = _allVerifiedUsers;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'PENDING BANK LINKING VERIFICATION',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Card(
            color: Colors.white10,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No users with pending bank details submitted.'),
            ),
          )
        else
          ...list.map((u) => _buildBankCard(u, false)),

        const SizedBox(height: 32),
        const Text(
          'FULLY VERIFIED BANKING PARTNERS',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        if (allVerified.isEmpty)
          const Text('No verified bank partners found.')
        else
          ...allVerified.map((u) => _buildBankCard(u, true)),
      ],
    );
  }

  Widget _buildKycCard(Map<String, dynamic> u, bool isVerified) {
    final pan = u['kycPan']?.toString().toUpperCase() ?? 'N/A';
    final aadhaar = u['kycAadhaar'] ?? 'N/A';
    final docUrl = u['kycDocUrl'] ?? 'intellij.png';

    return Card(
      color: AppTheme.obsidianMedium,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isVerified ? AppTheme.emeraldGreen.withOpacity(0.35) : Colors.amber.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                      u['name'] ?? 'No Name',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Role: ${u['role'] ?? 'DSA'}  |  Mobile: ${u['mobile'] ?? 'N/A'}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                isVerified
                    ? const Icon(Icons.verified, color: AppTheme.emeraldGreen)
                    : ElevatedButton(
                        onPressed: () => _toggleKycVerification(u['uid'] ?? '', true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.royalGold,
                          foregroundColor: AppTheme.obsidianDark,
                        ),
                        child: const Text('Verify KYC'),
                      ),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              children: [
                Expanded(child: _buildValueColumn('PAN NUMBER', pan)),
                Expanded(child: _buildValueColumn('AADHAAR CARD', aadhaar)),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _showDocumentPreview(docUrl, 'KYC Document Proof'),
                      icon: const Icon(Icons.remove_red_eye, size: 14),
                      label: const Text('Proof File'),
                    ),
                  ),
                ),
              ],
            ),
            if (isVerified) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _toggleKycVerification(u['uid'] ?? '', false),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.rubyRed, side: const BorderSide(color: AppTheme.rubyRed)),
                child: const Text('Revoke Verification'),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard(Map<String, dynamic> u, bool isVerified) {
    final bank = u['bankName'] ?? 'N/A';
    final accHolder = u['bankAccountHolder'] ?? 'N/A';
    final accNum = u['bankAccountNumber'] ?? 'N/A';
    final ifsc = u['bankIfsc']?.toString().toUpperCase() ?? 'N/A';
    final docUrl = u['bankProofUrl'] ?? 'intellij.png';

    return Card(
      color: AppTheme.obsidianMedium,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isVerified ? AppTheme.emeraldGreen.withOpacity(0.35) : Colors.amber.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                      u['name'] ?? 'No Name',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Role: ${u['role'] ?? 'DSA'}  |  Mobile: ${u['mobile'] ?? 'N/A'}',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                isVerified
                    ? const Icon(Icons.verified, color: AppTheme.emeraldGreen)
                    : ElevatedButton(
                        onPressed: () => _toggleBankVerification(u['uid'] ?? '', true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.royalGold,
                          foregroundColor: AppTheme.obsidianDark,
                        ),
                        child: const Text('Verify Bank Details'),
                      ),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              children: [
                Expanded(child: _buildValueColumn('BANK NAME', bank)),
                Expanded(child: _buildValueColumn('A/C HOLDER', accHolder)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildValueColumn('ACCOUNT NUMBER', accNum)),
                Expanded(child: _buildValueColumn('IFSC CODE', ifsc)),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _showDocumentPreview(docUrl, 'Bank Account Proof'),
                      icon: const Icon(Icons.remove_red_eye, size: 14),
                      label: const Text('Passbook Proof'),
                    ),
                  ),
                ),
              ],
            ),
            if (isVerified) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _toggleBankVerification(u['uid'] ?? '', false),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.rubyRed, side: const BorderSide(color: AppTheme.rubyRed)),
                child: const Text('Revoke Verification'),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildValueColumn(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}
