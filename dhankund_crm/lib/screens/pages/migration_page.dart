import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class MigrationPage extends StatefulWidget {
  const MigrationPage({super.key});

  @override
  State<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends State<MigrationPage> {
  final ApiService _api = ApiService();
  bool _isLoadingDiff = false;
  bool _isMigrating = false;
  Map<String, dynamic>? _diffResult;
  Map<String, dynamic>? _importResult;
  String? _error;
  Map<String, dynamic>? _authResult;
  bool _isImportingAuth = false;
  Map<String, dynamic>? _schemaResult;
  bool _isMigratingSchema = false;
  String _selectedCollection = 'All Collections';

  static const List<String> _collections = [
    'All Collections', 'users', 'loan_applications', 'referrals',
    'dsa_registrations', 'banker_registrations', 'partner_registrations',
    'admin_posts', 'news_feed', 'statuses', 'bank_policies', 'broadcast_history',
  ];

  String? _collectionParam() {
    return _selectedCollection == 'All Collections' ? null : _selectedCollection;
  }

  Future<void> _fetchDiff() async {
    setState(() { _isLoadingDiff = true; _error = null; _diffResult = null; });
    try {
      final result = await _api.fetchMigrationDiff(collection: _collectionParam());
      setState(() { _diffResult = result; _isLoadingDiff = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoadingDiff = false; });
    }
  }

  Future<void> _runMigration(bool dryRun) async {
    setState(() { _isMigrating = true; _error = null; _importResult = null; });
    try {
      final result = await _api.importFirestoreData(collection: _collectionParam(), dryRun: dryRun);
      setState(() { _importResult = result; _isMigrating = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isMigrating = false; });
    }
  }

  Future<void> _importAuth(bool dryRun) async {
    setState(() { _isImportingAuth = true; _error = null; _authResult = null; });
    try {
      final result = await _api.importAuthData(dryRun: dryRun);
      setState(() { _authResult = result; _isImportingAuth = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isImportingAuth = false; });
    }
  }

  Future<void> _runSchemaMigration() async {
    setState(() { _isMigratingSchema = true; _error = null; _schemaResult = null; });
    try {
      final result = await _api.migrateSchema();
      setState(() { _schemaResult = result; _isMigratingSchema = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isMigratingSchema = false; });
    }
  }

  Future<void> _confirmMigrate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.obsidianMedium,
        title: const Text('Confirm Migration', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'This will import ALL data from Firestore into D1 using INSERT OR REPLACE. '
          'Existing D1 records with matching IDs will be overwritten. Continue?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen),
            child: const Text('Migrate', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _runMigration(false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Firestore to D1 Migration',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Back up, compare, and migrate Firebase Firestore data to Cloudflare D1.',
            style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),

          // Controls panel
          GlassCard(
            padding: 20.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text('Collection:  ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  Expanded(child: DropdownButton<String>(
                    value: _selectedCollection,
                    isExpanded: true,
                    dropdownColor: AppTheme.obsidianMedium,
                    items: _collections.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _selectedCollection = v); },
                  )),
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  ElevatedButton.icon(
                    onPressed: _isLoadingDiff ? null : _fetchDiff,
                    icon: _isLoadingDiff
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.compare_arrows, size: 18),
                    label: Text(_isLoadingDiff ? 'Comparing...' : 'Show Difference'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isMigrating ? null : () => _runMigration(true),
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('Dry Run'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isMigrating ? null : _confirmMigrate,
                    icon: _isMigrating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.cloud_upload, size: 18),
                    label: Text(_isMigrating ? 'Migrating...' : 'Migrate All Data'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emeraldGreen),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isImportingAuth ? null : () => _importAuth(false),
                    icon: _isImportingAuth
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.password, size: 18),
                    label: Text(_isImportingAuth ? 'Importing...' : 'Import Passwords'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isMigratingSchema ? null : _runSchemaMigration,
                    icon: _isMigratingSchema
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.schema, size: 18),
                    label: Text(_isMigratingSchema ? 'Updating...' : 'Update Schema'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_error != null) ...[
            GlassCard(padding: 16.0, child: Row(children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
            ])),
            const SizedBox(height: 24),
          ],

          if (_diffResult != null) _buildDiffResults(),
          if (_importResult != null) ...[
            const SizedBox(height: 24),
            _buildImportResults(),
          ],
          if (_authResult != null) ...[
            const SizedBox(height: 24),
            _buildAuthResults(),
          ],
          if (_schemaResult != null) ...[
            const SizedBox(height: 24),
            _buildSchemaResults(),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffResults() {
    final summary = (_diffResult!['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final collections = (_diffResult!['collections'] as List?)?.cast<Map>() ?? [];
    final errors = (_diffResult!['errors'] as List?)?.cast<Map>() ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Difference Report', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.royalGold)),
      const SizedBox(height: 4),
      Text('Generated: ${_diffResult!['generated_at'] ?? '-'}  |  Project: ${_diffResult!['project_id'] ?? '-'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        int count = constraints.maxWidth > 1000 ? 6 : (constraints.maxWidth > 500 ? 3 : 2);
        return GridView.count(crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0, children: [
          _summaryCard('Firestore Total', '${summary['total_firestore'] ?? 0}', Icons.cloud, AppTheme.royalGold),
          _summaryCard('D1 Total', '${summary['total_d1'] ?? 0}', Icons.storage, Colors.lightBlue),
          _summaryCard('New (insert)', '${summary['total_new'] ?? 0}', Icons.add_circle, Colors.green),
          _summaryCard('Changed (update)', '${summary['total_changed'] ?? 0}', Icons.edit, Colors.orange),
          _summaryCard('Same (skip)', '${summary['total_same'] ?? 0}', Icons.check_circle, Colors.grey),
          _summaryCard('Only in D1', '${summary['total_only_in_d1'] ?? 0}', Icons.archive, Colors.purple),
        ]);
      }),
      const SizedBox(height: 24),
      GlassCard(padding: 16.0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Per-Collection Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Collection')),
            DataColumn(label: Text('Firestore'), numeric: true),
            DataColumn(label: Text('D1'), numeric: true),
            DataColumn(label: Text('New'), numeric: true),
            DataColumn(label: Text('Changed'), numeric: true),
            DataColumn(label: Text('Same'), numeric: true),
            DataColumn(label: Text('Only D1'), numeric: true),
          ],
          rows: collections.map((c) {
            final m = c.cast<String, dynamic>();
            return DataRow(cells: [
              DataCell(Text('${m['collection'] ?? '-'}${m['role'] != null ? ' (${m['role']})' : ''}')),
              DataCell(Text('${m['firestore_count'] ?? 0}')),
              DataCell(Text('${m['d1_count'] ?? 0}')),
              DataCell(Text('${m['new'] ?? 0}', style: const TextStyle(color: Colors.green))),
              DataCell(Text('${m['changed'] ?? 0}', style: const TextStyle(color: Colors.orange))),
              DataCell(Text('${m['same'] ?? 0}', style: const TextStyle(color: Colors.grey))),
              DataCell(Text('${m['only_in_d1'] ?? 0}', style: const TextStyle(color: Colors.purple))),
            ]);
          }).toList(),
        )),
      ])),
      ...collections.where((c) => (c['changed_samples'] as List?)?.isNotEmpty == true).map((c) {
        final samples = (c['changed_samples'] as List).cast<Map>();
        return Padding(padding: const EdgeInsets.only(top: 16), child: GlassCard(padding: 16.0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Changed fields in "${c['collection']}" (sample)', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.royalGold)),
          const SizedBox(height: 8),
          ...samples.map((s) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            Text('ID: ${s['id']}  ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Expanded(child: Text('Fields: ${(s['fields'] as List).join(', ')}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
          ])),
        )])));
      }),
      if (errors.isNotEmpty) ...[
        const SizedBox(height: 16),
        GlassCard(padding: 16.0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Collection Errors (${errors.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          ...errors.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${e['collection']}: ${e['error']}', style: const TextStyle(color: Colors.red, fontSize: 12)))),
        ])),
      ],
    ]);
  }

  Widget _buildImportResults() {
    final summary = (_importResult!['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final results = (_importResult!['results'] as List?)?.cast<Map>() ?? [];
    final warnings = (_importResult!['warnings'] as List?) ?? [];
    final errors = (_importResult!['errors'] as List?)?.cast<Map>() ?? [];
    final isDryRun = _importResult!['dry_run'] == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${isDryRun ? 'Dry Run' : 'Migration'} Results', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: isDryRun ? Colors.blueGrey : AppTheme.emeraldGreen)),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        int count = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0, children: [
          _summaryCard('Total Records', '${summary['total_records'] ?? 0}', Icons.list, Colors.blue),
          _summaryCard('Inserted', '${summary['total_inserted'] ?? 0}', Icons.add, Colors.green),
          _summaryCard('Updated', '${summary['total_updated'] ?? 0}', Icons.update, Colors.orange),
          _summaryCard('Failed', '${summary['total_failed'] ?? 0}', Icons.error, Colors.red),
        ]);
      }),
      const SizedBox(height: 24),
      if (warnings.isNotEmpty) ...[
        GlassCard(padding: 16.0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Warnings (${warnings.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(height: 8),
          ...warnings.map((w) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning, color: Colors.amber, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(w.toString(), style: const TextStyle(color: Colors.amber, fontSize: 12))),
          ])),
        )])),
        const SizedBox(height: 16),
      ],
      GlassCard(padding: 16.0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Per-Collection Results', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Collection')),
            DataColumn(label: Text('Total'), numeric: true),
            DataColumn(label: Text('Inserted'), numeric: true),
            DataColumn(label: Text('Updated'), numeric: true),
            DataColumn(label: Text('Failed'), numeric: true),
          ],
          rows: results.map((r) {
            final m = r.cast<String, dynamic>();
            return DataRow(cells: [
              DataCell(Text('${m['collection'] ?? '-'}${m['role'] != null ? ' (${m['role']})' : ''}')),
              DataCell(Text('${m['total'] ?? 0}')),
              DataCell(Text('${m['inserted'] ?? 0}', style: const TextStyle(color: Colors.green))),
              DataCell(Text('${m['updated'] ?? 0}', style: const TextStyle(color: Colors.orange))),
              DataCell(Text('${m['failed'] ?? 0}', style: TextStyle(color: (m['failed'] ?? 0) > 0 ? Colors.red : Colors.grey))),
            ]);
          }).toList(),
        )),
      ])),
      ...results.where((r) => (r['errors'] as List?)?.isNotEmpty == true).map((r) {
        final recErrors = (r['errors'] as List).cast<Map>();
        return Padding(padding: const EdgeInsets.only(top: 16), child: GlassCard(padding: 16.0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Errors in "${r['collection']}" (${recErrors.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          ...recErrors.map((e) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('ID: ${e['id']} -> ${e['error']}', style: const TextStyle(color: Colors.red, fontSize: 12)))),
        ])));
      }),
      if (errors.isNotEmpty) ...[
        const SizedBox(height: 16),
        GlassCard(padding: 16.0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Collection Errors (${errors.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 8),
          ...errors.map((e) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${e['collection']}: ${e['error']}', style: const TextStyle(color: Colors.red, fontSize: 12)))),
        ])),
      ],
    ]);
  }

  Widget _buildSchemaResults() {
    final results = (_schemaResult!['results'] as Map?)?.cast<String, dynamic>() ?? {};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Schema Migration Results', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.indigo)),
      const SizedBox(height: 8),
      Text('Migrated at: ' + (_schemaResult!['migrated_at'] ?? '-').toString(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      const SizedBox(height: 16),
      ...results.entries.map((entry) {
        final tableData = (entry.value as Map).cast<String, dynamic>();
        final added = (tableData['added'] as List?)?.cast() ?? [];
        final existingCount = tableData['existing_columns'] ?? 0;
        final addedCount = tableData['added_count'] ?? 0;
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: GlassCard(padding: 16.0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.key.toString() + ' table', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
          const SizedBox(height: 4),
          Text('Existing columns: ' + existingCount.toString() + '  |  Added: ' + addedCount.toString(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          if (added.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: added.map((col) => Chip(
              label: Text(col.toString(), style: const TextStyle(fontSize: 11)),
              backgroundColor: Colors.indigo.withOpacity(0.15),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            )).toList()),
          ] else ...[
            const SizedBox(height: 4),
            Text('All columns already exist.', style: const TextStyle(color: Colors.green, fontSize: 12)),
          ],
        ])),
        );
      }),
      const SizedBox(height: 8),
      GlassCard(padding: 16.0, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info, color: Colors.amber, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text('After updating the schema, run Migrate All Data to populate the new columns.', style: const TextStyle(color: Colors.amber, fontSize: 12))),
      ])),
    ]);
  }
  Widget _buildAuthResults() {
    final summary = (_authResult!['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final errors = (_authResult!['errors'] as List?)?.cast<Map>() ?? [];
    final isDryRun = _authResult!['dry_run'] == true;
    final projectConfig = (_authResult!['project_config'] as Map?)?.cast<String, dynamic>() ?? {};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Firebase Auth Import ${isDryRun ? '(Dry Run)' : ''}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
      const SizedBox(height: 8),
      Text('Project: ${_authResult!['project_id'] ?? '-'}  |  Signer Key: ${projectConfig['signer_key'] ?? '-'}  |  Salt Separator: ${projectConfig['salt_separator'] ?? '-'}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        int count = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(crossAxisCount: count, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0, children: [
          _summaryCard('Auth Users', '${summary['total_auth_users'] ?? 0}', Icons.people, Colors.blue),
          _summaryCard('With Password', '${summary['users_with_password'] ?? 0}', Icons.lock, Colors.green),
          _summaryCard('Updated', '${summary['updated'] ?? 0}', Icons.update, Colors.orange),
          _summaryCard('Failed', '${summary['failed'] ?? 0}', Icons.error, Colors.red),
        ]);
      }),
      const SizedBox(height: 16),
      GlassCard(padding: 16.0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Created: ${summary['created'] ?? 0}  |  Updated: ${summary['updated'] ?? 0}  |  Failed: ${summary['failed'] ?? 0}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        if (errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Errors (${errors.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 4),
          ...errors.take(10).map((e) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text('${e['email']}: ${e['error']}', style: const TextStyle(color: Colors.red, fontSize: 12)))),
        ],
      ])),
      const SizedBox(height: 12),
      GlassCard(padding: 16.0, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info, color: Colors.amber, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text('After importing passwords, users can login with their Firebase credentials. On first login, the password is verified via Firebase scrypt and immediately upgraded to PBKDF2. Subsequent logins use D1 directly.', style: const TextStyle(color: Colors.amber, fontSize: 12))),
      ])),
    ]);
  }
  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.obsidianMedium,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), textAlign: TextAlign.center),
      ]),
    );
  }
}