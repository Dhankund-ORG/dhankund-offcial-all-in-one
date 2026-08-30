import 'package:flutter/material.dart';
import '../../firebase_service.dart';
import '../../aws_service.dart';
import '../../theme/app_theme.dart';

class RegistrationsPage extends StatefulWidget {
  const RegistrationsPage({super.key});

  @override
  State<RegistrationsPage> createState() => _RegistrationsPageState();
}

class _RegistrationsPageState extends State<RegistrationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final AwsService _awsService = AwsService();

  bool _isLoading = false;
  List<Map<String, dynamic>> _registrations = [];
  String _filterStatus = 'pending'; // 'pending', 'approved', 'rejected', 'all'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadRegistrations();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    _loadRegistrations();
  }

  String get _currentRoleType {
    switch (_tabController.index) {
      case 0:
        return 'DSA';
      case 1:
        return 'Banker';
      case 2:
      default:
        return 'Partner';
    }
  }

  Future<void> _loadRegistrations() async {
    setState(() => _isLoading = true);
    try {
      final list = await _firestoreService.fetchRegistrations(_currentRoleType);
      setState(() {
        _registrations = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching registrations: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRegistrations {
    if (_filterStatus == 'all') {
      return _registrations;
    }
    return _registrations.where((reg) {
      final status = reg['status']?.toString().toLowerCase() ?? 'pending';
      return status == _filterStatus;
    }).toList();
  }

  Future<void> _handleApproval({
    required Map<String, dynamic> reg,
    required String status,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    try {
      final collection = reg['_source_collection'] ?? '';
      final docId = reg['id'] ?? '';
      final uid = reg['uid'] ?? '';
      final role = reg['role'] ?? _currentRoleType; // e.g. Builder/Broker or DSA/Banker

      // Prepare user profile sync payload
      final Map<String, dynamic> userDetails = {
        'name': reg['name'],
        'email': reg['email'],
        'mobile': reg['mobile'],
        'gender': reg['gender'],
        'company': reg['company'],
        'address': reg['address'] ?? reg['officeAddress'],
        'currentExp': reg['currentExp'],
        'totalExp': reg['totalExp'],
        'segment': reg['segment'],
        'profession': reg['profession'],
        'about': reg['about'],
      };

      await _firestoreService.updateRegistrationStatus(
        collection: collection,
        docId: docId,
        uid: uid,
        status: status,
        role: role,
        userDetails: userDetails,
      );

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Registration successfully marked as ${status.toUpperCase()}'),
          backgroundColor: status == 'approved' ? AppTheme.emeraldGreen : AppTheme.rubyRed,
        ),
      );

      _loadRegistrations();
    } catch (e) {
      debugPrint("Error updating registration status: $e");
      setState(() => _isLoading = false);
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to update registration status.'),
          backgroundColor: AppTheme.rubyRed,
        ),
      );
    }
  }

  void _showRegistrationDetails(Map<String, dynamic> reg) {
    showDialog(
      context: context,
      builder: (context) {
        String documentField = '';
        String documentName = 'Document Proof';
        if (_currentRoleType == 'DSA') {
          documentField = 'gumastaUrl';
          documentName = 'Gumasta Certificate';
        } else if (_currentRoleType == 'Banker') {
          documentField = 'idCardUrl';
          documentName = 'Identity / Work ID Card';
        } else {
          documentField = 'gumastaUrl'; // default fallbacks
        }

        final documentKey = reg[documentField] ?? 'intellij.png';

        return AlertDialog(
          backgroundColor: AppTheme.obsidianMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  reg['name'] ?? 'Registration Details',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusChip(reg['status']),
                  const SizedBox(height: 16),
                  _buildDetailRow('Email', reg['email'] ?? 'N/A'),
                  _buildDetailRow('Mobile', reg['mobile'] ?? 'N/A'),
                  _buildDetailRow('Gender', reg['gender'] ?? 'N/A'),
                  _buildDetailRow('Company', reg['company'] ?? 'N/A'),
                  _buildDetailRow('Address', reg['address'] ?? reg['officeAddress'] ?? 'N/A'),
                  _buildDetailRow('Experience', '${reg['currentExp'] ?? 0} yrs current / ${reg['totalExp'] ?? 0} yrs total'),
                  _buildDetailRow('Segment', reg['segment'] ?? 'N/A'),
                  _buildDetailRow('Profession Style', reg['profession'] ?? 'N/A'),
                  if (_currentRoleType == 'Partner') _buildDetailRow('Role Type', reg['role'] ?? 'N/A'),
                  const Divider(color: Colors.white10, height: 24),
                  const Text('About / Bio:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.goldAccent)),
                  const SizedBox(height: 4),
                  Text(
                    reg['about'] ?? 'No bio provided.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  
                  // Document Proof Section
                  Text('$documentName:', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.goldAccent)),
                  const SizedBox(height: 8),
                  FutureBuilder<String?>(
                    future: _awsService.getBankerDocumentUrl(documentKey),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppTheme.royalGold));
                      }
                      final url = snapshot.data;
                      if (url == null) {
                        return const Text('Failed to load document path.', style: TextStyle(color: AppTheme.rubyRed));
                      }
                      
                      final isImage = documentKey.toLowerCase().endsWith('.png') || 
                                      documentKey.toLowerCase().endsWith('.jpg') || 
                                      documentKey.toLowerCase().endsWith('.jpeg');
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isImage)
                            Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Text('Document preview placeholder'),
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            ListTile(
                              leading: const Icon(Icons.insert_drive_file, color: AppTheme.royalGold),
                              title: Text(documentKey),
                              subtitle: const Text('Presigned S3 Document URL ready'),
                            ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              debugPrint("Presigned Link: $url");
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Document Link: $url')),
                              );
                            },
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Access Document URL'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (reg['status']?.toString().toLowerCase() == 'pending') ...[
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleApproval(reg: reg, status: 'rejected');
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.rubyRed, side: const BorderSide(color: AppTheme.rubyRed)),
                child: const Text('Reject'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleApproval(reg: reg, status: 'approved');
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen, foregroundColor: Colors.white),
                child: const Text('Approve & Sync Profile'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ]
          ],
        );
      },
    );
  }

  Widget _buildStatusChip(String? status) {
    Color bg = Colors.white10;
    Color fg = AppTheme.textSecondary;
    final stat = status?.toLowerCase() ?? 'pending';

    if (stat == 'approved') {
      bg = AppTheme.emeraldGreen.withOpacity(0.1);
      fg = AppTheme.emeraldGreen;
    } else if (stat == 'rejected') {
      bg = AppTheme.rubyRed.withOpacity(0.1);
      fg = AppTheme.rubyRed;
    } else if (stat == 'pending') {
      bg = Colors.amber.withOpacity(0.1);
      fg = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        stat.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Registration Verifications'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.royalGold,
          labelColor: AppTheme.royalGold,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'DSAs (Direct Sales)'),
            Tab(text: 'Bankers (Financial)'),
            Tab(text: 'Partners (Builder/Broker)'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'List of ${widget.key == null ? _currentRoleType : ""} Registrations',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                DropdownButton<String>(
                  value: _filterStatus,
                  dropdownColor: AppTheme.obsidianMedium,
                  underline: const SizedBox(),
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Filter: PENDING')),
                    DropdownMenuItem(value: 'approved', child: Text('Filter: APPROVED')),
                    DropdownMenuItem(value: 'rejected', child: Text('Filter: REJECTED')),
                    DropdownMenuItem(value: 'all', child: Text('Filter: ALL')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _filterStatus = val;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // Main List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.royalGold))
                : _filteredRegistrations.isEmpty
                    ? Center(
                        child: Text(
                          'No ${_filterStatus.toUpperCase()} registrations found.',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredRegistrations.length,
                        itemBuilder: (context, index) {
                          final reg = _filteredRegistrations[index];
                          return Card(
                            color: AppTheme.obsidianMedium,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              title: Row(
                                children: [
                                  Text(
                                    reg['name'] ?? 'No Name Provided',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  if (_currentRoleType == 'Partner' && reg['role'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.royalGold.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        reg['role'].toString().toUpperCase(),
                                        style: const TextStyle(color: AppTheme.royalGold, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Email: ${reg['email'] ?? 'N/A'}  |  Mobile: ${reg['mobile'] ?? 'N/A'}'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Company: ${reg['company'] ?? 'N/A'}  |  Exp: ${reg['totalExp'] ?? '0'} yrs total',
                                      style: const TextStyle(color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildStatusChip(reg['status']),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textSecondary),
                                ],
                              ),
                              onTap: () => _showRegistrationDetails(reg),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
