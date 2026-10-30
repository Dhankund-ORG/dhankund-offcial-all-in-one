import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../theme/app_theme.dart';

class CloudflareMigrationPage extends StatefulWidget {
  const CloudflareMigrationPage({super.key});

  @override
  State<CloudflareMigrationPage> createState() => _CloudflareMigrationPageState();
}

class _MigrationCancelled implements Exception {}

class _LogEntry {
  final String time;
  final String message;
  final String level;

  _LogEntry(this.time, this.message, this.level);
}

class _CloudflareMigrationPageState extends State<CloudflareMigrationPage> {
  // Account 1 (source)
  final TextEditingController _sourceAccountId = TextEditingController();
  final TextEditingController _sourceToken = TextEditingController();
  final TextEditingController _sourceD1Id = TextEditingController();
  final TextEditingController _sourceBucket = TextEditingController();

  // Account 2 (destination)
  final TextEditingController _destinationAccountId = TextEditingController();
  final TextEditingController _destinationToken = TextEditingController();
  final TextEditingController _destinationD1Id = TextEditingController();
  final TextEditingController _destinationBucket = TextEditingController();

  // Options
  bool _migrateD1 = true;
  bool _migrateR2 = true;
  bool _resetDestination = false;
  bool _autoCreate = true;
  final TextEditingController _newD1Name = TextEditingController(text: 'dhankund-crm-migrated');
  final TextEditingController _newBucketName = TextEditingController(text: 'dhankund-storage-migrated');

  bool _sourceTokenVisible = false;
  bool _destinationTokenVisible = false;

  bool _isRunning = false;
  bool _cancelRequested = false;
  double? _progress;
  String _status = 'Ready to validate.';

  Map<String, dynamic>? _validation;
  Map<String, dynamic>? _plan;
  bool _lastRunHadErrors = false;
  final List<_LogEntry> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _sourceAccountId.dispose();
    _sourceToken.dispose();
    _sourceD1Id.dispose();
    _sourceBucket.dispose();
    _destinationAccountId.dispose();
    _destinationToken.dispose();
    _destinationD1Id.dispose();
    _destinationBucket.dispose();
    _newD1Name.dispose();
    _newBucketName.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value == null ? '' : value.toString()) ?? 0;
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toStringAsFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';
    return (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2) + ' GB';
  }

  String _nowLabel() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return two(now.hour) + ':' + two(now.minute) + ':' + two(now.second);
  }

  void _log(String message, {String level = 'info'}) {
    if (!mounted) return;
    setState(() {
      _logs.add(_LogEntry(_nowLabel(), message, level));
      if (_logs.length > 400) _logs.removeAt(0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logScrollController.hasClients) return;
      _logScrollController.animateTo(
        _logScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _setStatus(String status, {double? progress}) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _progress = progress;
    });
  }

  void _checkCancelled() {
    if (_cancelRequested) throw _MigrationCancelled();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.rubyRed),
    );
  }

  Map<String, dynamic> _accountPayload({
    required TextEditingController accountId,
    required TextEditingController token,
    required TextEditingController d1Id,
    required TextEditingController bucket,
  }) {
    return {
      'account_id': accountId.text.trim(),
      'api_token': token.text.trim(),
      'd1_database_id': d1Id.text.trim(),
      'r2_bucket': bucket.text.trim(),
    };
  }

  Map<String, dynamic> get _sourcePayload => _accountPayload(
        accountId: _sourceAccountId,
        token: _sourceToken,
        d1Id: _sourceD1Id,
        bucket: _sourceBucket,
      );

  Map<String, dynamic> get _destinationPayload => _accountPayload(
        accountId: _destinationAccountId,
        token: _destinationToken,
        d1Id: _destinationD1Id,
        bucket: _destinationBucket,
      );

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final result = await ApiClient.post(path, body);
    return _asMap(result);
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _validateAccounts() async {
    _setStatus('Validating both Cloudflare accounts...', progress: 0.02);
    _log('Checking account IDs, API tokens, D1 databases and R2 buckets...');
    final result = await _post('/api/v1/admin/cloudflare/validate', {
      'source': _sourcePayload,
      'destination': _destinationPayload,
      'check_d1': _migrateD1,
      'check_r2': _migrateR2,
    });
    if (mounted) setState(() => _validation = result);

    final source = _asMap(result['source']);
    final destination = _asMap(result['destination']);
    if (source['error'] != null) {
      throw Exception('Source account: ' + source['error'].toString());
    }
    if (destination['error'] != null) {
      throw Exception('Destination account: ' + destination['error'].toString());
    }
    _log(
      'Source account: ' + (source['account_name']?.toString() ?? 'verified') +
          ' (token ' + (source['token_status']?.toString() ?? 'unknown') + ').',
      level: 'success',
    );
    _log(
      'Destination account: ' + (destination['account_name']?.toString() ?? 'verified') +
          ' (token ' + (destination['token_status']?.toString() ?? 'unknown') + ').',
      level: 'success',
    );

    final sourceD1 = _asMap(source['d1']);
    final destinationD1 = _asMap(destination['d1']);
    final sourceR2 = _asMap(source['r2']);
    final destinationR2 = _asMap(destination['r2']);

    if (_migrateD1) {
      if (sourceD1['error'] != null) {
        throw Exception('Source D1 database: ' + sourceD1['error'].toString());
      }
      _log(
        'Source D1: ' + (sourceD1['name']?.toString() ?? 'database') +
            ' with ' + _asInt(sourceD1['tables']).toString() + ' tables.',
      );
      if (destinationD1['error'] != null) {
        _log('Destination D1: ' + destinationD1['error'].toString(), level: 'warn');
      } else {
        _log(
          'Destination D1: ' + (destinationD1['name']?.toString() ?? 'database') +
              ' with ' + _asInt(destinationD1['tables']).toString() + ' tables.',
        );
      }
    }

    if (_migrateR2) {
      if (sourceR2['error'] != null) {
        throw Exception('Source R2 bucket: ' + sourceR2['error'].toString());
      }
      _log(
        'Source R2: ' + (sourceR2['bucket']?.toString() ?? 'bucket') +
            ', ' + _asInt(sourceR2['count']).toString() + ' objects (' +
            _formatBytes(_asInt(sourceR2['bytes'])) + ')' +
            (_asMap(result['source'])['r2'] != null && sourceR2['truncated'] == true
                ? ' - count capped at first 2,000 objects.'
                : '.'),
      );
      if (destinationR2['error'] != null) {
        _log('Destination R2: ' + destinationR2['error'].toString(), level: 'warn');
      } else {
        _log(
          'Destination R2: ' + (destinationR2['bucket']?.toString() ?? 'bucket') +
              ', ' + _asInt(destinationR2['count']).toString() + ' objects.',
        );
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Migration
  // ---------------------------------------------------------------------------

  Future<void> _startMigration() async {
    if (_isRunning) return;

    if (_sourceAccountId.text.trim().isEmpty || _sourceToken.text.trim().isEmpty) {
      _showError('Source account ID and API token are required.');
      return;
    }
    if (_destinationAccountId.text.trim().isEmpty || _destinationToken.text.trim().isEmpty) {
      _showError('Destination account ID and API token are required.');
      return;
    }
    if (!_migrateD1 && !_migrateR2) {
      _showError('Select D1, R2 or both to migrate.');
      return;
    }
    if (_resetDestination && _migrateD1) {
      final confirmed = await _confirmReset();
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isRunning = true;
      _cancelRequested = false;
      _progress = 0;
      _status = 'Starting migration...';
      _lastRunHadErrors = false;
      _voidPlan();
      _logs.clear();
    });
    _log('One-click migration started. Credentials stay in this request only and are never stored.');
    _log('Step 1/3: validate accounts and scan exactly what will be migrated.');

    try {
      await _migrateAll();
      if (_lastRunHadErrors) {
        _setStatus('Migration finished with errors. Review the plan and live log.');
        _log('Migration finished with errors. Failed objects remain in the source.', level: 'error');
      } else {
        _setStatus('Migration finished successfully.', progress: 1);
        _log('Migration finished successfully. D1 and R2 are both verified.', level: 'success');
      }
    } on _MigrationCancelled {
      _setStatus('Migration stopped by user.');
      _log('Migration stopped by user. Data already copied remains in the destination.', level: 'warn');
    } catch (e) {
      _setStatus('Migration failed.');
      _log('Migration failed: ' + e.toString(), level: 'error');
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  void _voidPlan() {
    _plan = null;
  }

  Future<void> _migrateAll() async {
    await _validateAccounts();
    _checkCancelled();

    _log('Step 2/3: scan migration contents and compare schemas.');
    final plan = await _loadPlan();
    _checkCancelled();

    final resetAllowed = await _confirmPlanResetIfNeeded(plan);
    if (!resetAllowed) throw _MigrationCancelled();

    _log('Step 3/3: migrate data. D1 and R2 run independently.');
    var d1Done = !_migrateD1;
    var r2Done = !_migrateR2;

    if (_migrateD1) {
      try {
        await _migrateD1Database();
        d1Done = true;
      } on _MigrationCancelled {
        rethrow;
      } catch (e) {
        final message = e.toString();
        _log('D1 migration failed: ' + message, level: 'error');
        _log('R2 migration will continue because D1 and R2 are independent.', level: 'warn');
      }
    }
    _checkCancelled();

    if (_migrateR2) {
      try {
        await _migrateR2Bucket();
        r2Done = true;
      } on _MigrationCancelled {
        rethrow;
      } catch (e) {
        final message = e.toString();
        _log('R2 migration failed: ' + message, level: 'error');
      }
    }

    final parts = <String>[];
    if (_migrateD1) parts.add('D1: ' + (d1Done ? 'COMPLETE' : 'FAILED'));
    if (_migrateR2) parts.add('R2: ' + (r2Done ? 'COMPLETE' : 'FAILED'));
    _lastRunHadErrors = (_migrateD1 && !d1Done) || (_migrateR2 && !r2Done);
    _setStatus(
      _lastRunHadErrors ? 'Migration finished with errors.' : 'Migration finished.',
      progress: 1,
    );
    _log(
      'FINAL SUMMARY - ' + parts.join(' | ') +
          (_lastRunHadErrors ? '. Fix the errors above and run the failed part again.' : '.'),
      level: _lastRunHadErrors ? 'error' : 'success',
    );
  }

  Future<Map<String, dynamic>> _loadPlan() async {
    _setStatus('Scanning migration contents...', progress: 0.35);
    _log('Building the migration plan. No data is changed during this scan.');

    final plan = <String, dynamic>{};

    if (_migrateD1) {
      final destinationId = _destinationD1Id.text.trim();
      final d1 = await _post('/api/v1/admin/cloudflare/d1/plan', {
        'source': _sourcePayload,
        'source_database_id': _sourceD1Id.text.trim(),
        'destination': _destinationPayload,
        'destination_database_id': destinationId.isEmpty ? null : destinationId,
      });
      plan['d1'] = d1;

      final source = _asMap(d1['source']);
      final totals = _asMap(source['totals']);
      _log(
        'D1 scan: ' + _asInt(totals['tables']).toString() + ' tables, ' +
            _asInt(totals['rows']).toString() + ' rows, ' +
            _asInt(totals['columns']).toString() + ' columns, ' +
            _asInt(totals['indexes']).toString() + ' indexes, ' +
            _asInt(totals['triggers']).toString() + ' triggers.',
        level: 'success',
      );

      final diff = _asMap(d1['diff']);
      final missingTables = _asList(diff['missing_tables']);
      final overlap = _asList(diff['overlapping_tables']);
      final missingColumns = _asList(diff['missing_columns']);
      final extraColumns = _asList(diff['extra_columns']);
      final typeMismatches = _asList(diff['type_mismatches']);
      final orderMismatches = _asList(diff['column_order_mismatches']);
      final extraTables = _asList(diff['extra_tables']);

      if (destinationId.isEmpty) {
        _log('Destination D1 is blank: a new database will be created and all source tables imported.', level: 'warn');
      } else if (overlap.isNotEmpty) {
        _log('Destination already has ' + overlap.length.toString() + ' table(s) with the same name as source.', level: 'warn');
      }
      if (missingTables.isNotEmpty) {
        _log('New tables that will be created: ' + missingTables.take(12).join(', ') +
            (missingTables.length > 12 ? ' +' + (missingTables.length - 12).toString() + ' more' : '') + '.');
      }
      if (missingColumns.isNotEmpty) {
        _log('Destination tables missing source columns: ' + missingColumns.length.toString() + ' table(s).', level: 'warn');
      }
      if (extraColumns.isNotEmpty) {
        _log('Destination tables with extra columns: ' + extraColumns.length.toString() + ' table(s).', level: 'warn');
      }
      if (typeMismatches.isNotEmpty) {
        _log('Columns with a different declared type: ' + typeMismatches.length.toString() + '.', level: 'warn');
      }
      if (orderMismatches.isNotEmpty) {
        _log('Tables with a different column order: ' + orderMismatches.length.toString() + '.', level: 'warn');
      }
      if (extraTables.isNotEmpty) {
        _log('Destination-only tables that stay untouched: ' + extraTables.take(12).join(', ') + '.', level: 'warn');
      }
      if (d1['reset_required'] == true) {
        _log('Reset is required before the D1 import because destination tables collide with source tables.', level: 'warn');
      }
      for (final warning in _asList(d1['warnings'])) {
        _log('D1 plan warning: ' + warning.toString(), level: 'warn');
      }
      if (d1['destination_error'] != null) {
        _log('Destination D1 could not be inspected: ' + d1['destination_error'].toString(), level: 'error');
      }
    }

    if (_migrateR2) {
      final r2 = await _post('/api/v1/admin/cloudflare/r2/plan', {
        'source': _sourcePayload,
        'source_bucket': _sourceBucket.text.trim(),
        'max_pages': 20,
      });
      plan['r2'] = r2;
      _log(
        'R2 scan: ' + _asInt(r2['count']).toString() + ' objects (' +
            _formatBytes(_asInt(r2['bytes'])) + ')' +
            (r2['truncated'] == true ? ' - only the first 2,000 objects were scanned.' : '.'),
        level: r2['truncated'] == true ? 'warn' : 'success',
      );
      final oversized = _asList(r2['oversized']);
      if (oversized.isNotEmpty) {
        _log('Oversized objects that will be skipped (> 50 MB): ' + oversized.length.toString() + '.', level: 'warn');
        for (final item in oversized.take(10)) {
          final row = _asMap(item);
          _log('  SKIP ' + (row['key']?.toString() ?? '?') + ' (' + _formatBytes(_asInt(row['size'])) + ')', level: 'warn');
        }
      }
      for (final warning in _asList(r2['warnings'])) {
        _log('R2 plan warning: ' + warning.toString(), level: 'warn');
      }
    }

    if (mounted) setState(() => _plan = plan);
    _setStatus('Scan complete. Review the migration plan below.', progress: 0.55);
    return plan;
  }

  Future<bool> _confirmPlanResetIfNeeded(Map<String, dynamic> plan) async {
    if (!_migrateD1 || _resetDestination) return true;
    final d1 = _asMap(plan['d1']);
    final diff = _asMap(d1['diff']);
    final overlap = _asList(diff['overlapping_tables']);
    if (d1['reset_required'] != true && overlap.isEmpty) return true;

    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset is required for D1'),
          content: Text(
            'The destination database already contains ' + overlap.length.toString() +
                ' table(s) with the same name as the source: ' +
                overlap.take(8).join(', ') + (overlap.length > 8 ? '...' : '') +
                '.\n\nThe import cannot create these tables again. Enable "Reset destination D1" to drop '
                'all destination tables after the source export succeeds, or cancel and use a new destination database.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel migration'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rubyRed),
              child: const Text('Reset and continue'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      _log('Migration cancelled: destination tables overlap and Reset is off.', level: 'warn');
      return false;
    }
    if (mounted) setState(() => _resetDestination = true);
    _log('Reset enabled after plan check. Destination tables will be dropped after a successful export.', level: 'warn');
    return true;
  }

  Future<bool?> _confirmReset() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reset destination D1?'),
          content: const Text(
            'Every table in the destination D1 database will be dropped before the import. '
            'This cannot be undone. Make sure the destination database does not contain production data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rubyRed),
              child: const Text('Yes, reset and migrate'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _migrateD1Database() async {
    _setStatus('Preparing destination D1 database...', progress: 0.05);

    final providedDestinationId = _destinationD1Id.text.trim();
    if (providedDestinationId.isNotEmpty) {
      final destinationInfo = _asMap(_asMap(_asMap(_validation)['destination'])['d1']);
      if (destinationInfo['error'] != null) {
        throw Exception('Destination D1 database is not usable: ' + destinationInfo['error'].toString());
      }
    }

    if (_destinationD1Id.text.trim().isEmpty) {
      if (!_autoCreate) {
        throw Exception('Destination D1 database ID is empty. Enable auto-create or enter an existing ID.');
      }
      final name = _newD1Name.text.trim();
      if (name.isEmpty) throw Exception('New D1 database name is required.');
      _log('Creating destination D1 database "' + name + '"...');
      final created = await _post('/api/v1/admin/cloudflare/d1/create', {
        'destination': _destinationPayload,
        'name': name,
      });
      final database = _asMap(created['database']);
      final uuid = (database['uuid'] ?? '').toString();
      if (uuid.isEmpty) throw Exception('Cloudflare did not return a database ID.');
      if (mounted) setState(() => _destinationD1Id.text = uuid);
      _log('Created destination D1 database: ' + uuid, level: 'success');
    }
    _checkCancelled();

    final destinationD1Id = _destinationD1Id.text.trim();

    // 1. Export the source database.
    _setStatus('Exporting source D1 database...', progress: 0.12);
    _log('Starting D1 export on the source account. D1 may be briefly unavailable during export.');
    var exportResult = await _post('/api/v1/admin/cloudflare/d1/export', {
      'source': _sourcePayload,
      'database_id': _sourceD1Id.text.trim(),
    });

    var attempts = 0;
    while (exportResult['signed_url'] == null) {
      _checkCancelled();
      final exportStatus = (exportResult['status'] ?? '').toString().toLowerCase();
      if (exportResult['error'] != null || exportStatus == 'error' || exportStatus == 'failed') {
        throw Exception('D1 export failed: ' + (exportResult['error']?.toString() ?? exportStatus));
      }
      final bookmark = (exportResult['bookmark'] ?? '').toString();
      if (bookmark.isEmpty) throw Exception('D1 export did not return a bookmark.');
      if (attempts++ >= 300) throw Exception('D1 export timed out after 10 minutes.');
      _setStatus(
        'Exporting source D1 database... (' + _asInt(attempts).toString() + ')',
        progress: 0.12 + (attempts > 60 ? 0.06 : attempts * 0.001),
      );
      await Future.delayed(const Duration(seconds: 2));
      exportResult = await _post('/api/v1/admin/cloudflare/d1/export/poll', {
        'source': _sourcePayload,
        'database_id': _sourceD1Id.text.trim(),
        'bookmark': bookmark,
      });
    }

    final signedUrl = exportResult['signed_url'].toString();
    _log('D1 export ready: ' + (exportResult['filename']?.toString() ?? 'database.sql'), level: 'success');
    _checkCancelled();

    // Reset only after the source export has succeeded, so a failed export
    // never leaves the destination database empty.
    if (_resetDestination) {
      _setStatus('Dropping destination tables...', progress: 0.26);
      _log('Dropping all tables in the destination database (reset requested)...', level: 'warn');
      final reset = await _post('/api/v1/admin/cloudflare/d1/reset', {
        'destination': _destinationPayload,
        'database_id': destinationD1Id,
        'confirm': 'RESET',
      });
      final dropped = reset['dropped'];
      final count = dropped is List ? dropped.length : 0;
      _log('Dropped ' + count.toString() + ' tables.', level: 'success');
    }
    _checkCancelled();

    // 2. Import into the destination database.
    _setStatus('Importing into destination D1...', progress: 0.30);
    _log('Downloading the export and importing it into the destination database...');
    var importResult = await _post('/api/v1/admin/cloudflare/d1/import', {
      'destination': _destinationPayload,
      'database_id': destinationD1Id,
      'signed_url': signedUrl,
      'reset': false,
    });

    attempts = 0;
    while ((importResult['status'] ?? '').toString() != 'complete') {
      _checkCancelled();
      final importStatus = (importResult['status'] ?? '').toString().toLowerCase();
      if (importResult['error'] != null || importStatus == 'error' || importStatus == 'failed') {
        throw Exception('D1 import failed: ' + (importResult['error']?.toString() ?? importStatus));
      }
      final bookmark = (importResult['bookmark'] ?? '').toString();
      if (bookmark.isEmpty) throw Exception('D1 import did not return a bookmark.');
      if (attempts++ >= 300) throw Exception('D1 import timed out after 10 minutes.');
      _setStatus(
        'Importing into destination D1... (' + _asInt(attempts).toString() + ')',
        progress: 0.30 + (attempts > 60 ? 0.20 : attempts * 0.003),
      );
      await Future.delayed(const Duration(seconds: 2));
      importResult = await _post('/api/v1/admin/cloudflare/d1/import/poll', {
        'destination': _destinationPayload,
        'database_id': destinationD1Id,
        'bookmark': bookmark,
      });
    }
    _log('D1 import complete.', level: 'success');
    _checkCancelled();

    // 3. Verify row counts.
    _setStatus('Verifying D1 table row counts...', progress: 0.55);
    final verification = await _post('/api/v1/admin/cloudflare/d1/verify', {
      'source': _sourcePayload,
      'source_database_id': _sourceD1Id.text.trim(),
      'destination': _destinationPayload,
      'destination_database_id': destinationD1Id,
    });
    final tables = verification['tables'];
    if (tables is List) {
      var mismatches = 0;
      for (final item in tables) {
        final row = _asMap(item);
        final matched = row['match'] == true;
        if (!matched) mismatches += 1;
        _log(
          '  ' + (row['table']?.toString() ?? '?') + ': source=' +
              (row['source']?.toString() ?? '?') + ', destination=' +
              (row['destination']?.toString() ?? '?') + (matched ? ' OK' : ' MISMATCH'),
          level: matched ? 'info' : 'warn',
        );
      }
      _log(
        mismatches == 0
            ? 'D1 verification passed: all table row counts match.'
            : 'D1 verification found ' + mismatches.toString() + ' mismatched tables.',
        level: mismatches == 0 ? 'success' : 'warn',
      );
    }
  }

  Future<void> _migrateR2Bucket() async {
    _setStatus('Preparing destination R2 bucket...', progress: 0.60);

    final providedDestinationBucket = _destinationBucket.text.trim();
    if (providedDestinationBucket.isNotEmpty) {
      final destinationInfo = _asMap(_asMap(_asMap(_validation)['destination'])['r2']);
      if (destinationInfo['error'] != null) {
        if (!_autoCreate) {
          throw Exception('Destination R2 bucket is not usable: ' + destinationInfo['error'].toString());
        }
        _log('Destination bucket not found. Creating "' + providedDestinationBucket + '"...');
        await _post('/api/v1/admin/cloudflare/r2/create', {
          'destination': _destinationPayload,
          'bucket': providedDestinationBucket,
        });
        _log('Destination bucket ready: ' + providedDestinationBucket, level: 'success');
      }
    }

    if (_destinationBucket.text.trim().isEmpty) {
      if (!_autoCreate) {
        throw Exception('Destination R2 bucket is empty. Enable auto-create or enter an existing bucket name.');
      }
      final name = _newBucketName.text.trim();
      if (name.isEmpty) throw Exception('New R2 bucket name is required.');
      _log('Creating destination R2 bucket "' + name + '"...');
      await _post('/api/v1/admin/cloudflare/r2/create', {
        'destination': _destinationPayload,
        'bucket': name,
      });
      if (mounted) setState(() => _destinationBucket.text = name);
      _log('Destination bucket ready: ' + name, level: 'success');
    }
    _checkCancelled();

    final validationSource = _asMap(_asMap(_validation)['source']);
    final sourceR2 = _asMap(validationSource['r2']);
    final totalObjects = _asInt(sourceR2['count']);
    _log(
      'Starting R2 copy. Objects larger than 50 MB are skipped; use rclone for those files.',
      level: 'warn',
    );

    final sourceBucket = _sourceBucket.text.trim();
    final destinationBucket = _destinationBucket.text.trim();
    String? cursor;
    var skip = 0;
    var copied = 0;
    var failed = 0;
    var skipped = 0;
    var bytes = 0;
    var batch = 0;
    var done = false;

    while (!done) {
      _checkCancelled();
      batch += 1;
      final result = await _post('/api/v1/admin/cloudflare/r2/copy', {
        'source': _sourcePayload,
        'source_bucket': sourceBucket,
        'destination': _destinationPayload,
        'destination_bucket': destinationBucket,
        'cursor': cursor,
        'skip': skip,
        'limit': 10,
      });

      copied += _asInt(result['copied']);
      failed += _asInt(result['failed']);
      skipped += _asInt(result['skipped']);
      bytes += _asInt(result['bytes']);

      final errors = result['errors'];
      if (errors is List) {
        for (final item in errors) {
          final row = _asMap(item);
          _log('  COPY FAILED: ' + (row['key']?.toString() ?? '?') + ' - ' + (row['error']?.toString() ?? ''), level: 'error');
        }
      }
      final oversized = result['oversized'];
      if (oversized is List) {
        for (final item in oversized) {
          final row = _asMap(item);
          _log('  SKIPPED (> 50 MB): ' + (row['key']?.toString() ?? '?') +
              ' (' + _formatBytes(_asInt(row['size'])) + ')', level: 'warn');
        }
      }

      cursor = result['next_cursor'] == null ? null : result['next_cursor'].toString();
      skip = _asInt(result['next_skip']);
      done = result['done'] == true;

      final processed = copied + failed + skipped;
      final fraction = totalObjects > 0 ? (processed / totalObjects).clamp(0.0, 1.0) : null;
      _setStatus(
        'Copying R2 objects... ' + processed.toString() +
            (totalObjects > 0 ? ' / ~' + totalObjects.toString() : '') +
            ' (batch ' + batch.toString() + ')',
        progress: fraction == null ? null : 0.60 + fraction * 0.30,
      );
      _log(
        'Batch ' + batch.toString() + ': copied=' + copied.toString() +
            ', failed=' + failed.toString() + ', skipped=' + skipped.toString() +
            ', ' + _formatBytes(bytes) + '.',
        level: failed > 0 ? 'warn' : 'info',
      );
      if (batch >= 5000) throw Exception('R2 copy stopped after 5,000 batches.');
      if (!done) await Future.delayed(const Duration(milliseconds: 250));
    }

    _log(
      'R2 copy finished. Copied ' + copied.toString() + ' objects (' + _formatBytes(bytes) + ')' +
          (failed > 0 ? ', ' + failed.toString() + ' failed' : '') + '.',
      level: failed > 0 ? 'warn' : 'success',
    );

    _setStatus('Verifying R2 objects...', progress: 0.94);
    final verify = await _post('/api/v1/admin/cloudflare/r2/verify', {
      'source': _sourcePayload,
      'source_bucket': sourceBucket,
      'destination': _destinationPayload,
      'destination_bucket': destinationBucket,
      'max_pages': 20,
    });
    final sourceInfo = _asMap(verify['source']);
    final destinationInfo = _asMap(verify['destination']);
    _log(
      'R2 verification: source=' + _asInt(sourceInfo['count']).toString() +
          ' objects, destination=' + _asInt(destinationInfo['count']).toString() + ' objects.',
    );
    final missing = verify['missing'];
    final mismatched = verify['size_mismatch'];
    final extra = verify['extra'];
    if (missing is List && missing.isNotEmpty) {
      _log('R2 missing objects (' + missing.length.toString() + '): ' + missing.take(10).join(', '), level: 'warn');
    }
    if (mismatched is List && mismatched.isNotEmpty) {
      _log('R2 size mismatches (' + mismatched.length.toString() + '): ' + mismatched.take(10).join(', '), level: 'warn');
    }
    if (extra is List && extra.isNotEmpty) {
      _log('R2 extra objects in destination (' + extra.length.toString() + '): ' + extra.take(10).join(', '), level: 'warn');
    }
    if (verify['match'] == true) {
      _log('R2 verification passed: every object exists with the same size.', level: 'success');
    } else {
      _log(
        'R2 verification is not a full match' +
            (sourceInfo['truncated'] == true || destinationInfo['truncated'] == true
                ? ' (only the first 2,000 objects were compared).'
                : '.'),
        level: 'warn',
      );
    }
  }

  Future<void> _scanAndPreview() async {
    if (_isRunning) return;
    if (_sourceAccountId.text.trim().isEmpty || _sourceToken.text.trim().isEmpty ||
        _destinationAccountId.text.trim().isEmpty || _destinationToken.text.trim().isEmpty) {
      _showError('Both account IDs and API tokens are required.');
      return;
    }
    if (!_migrateD1 && !_migrateR2) {
      _showError('Select D1, R2 or both to scan.');
      return;
    }
    if (_migrateD1 && _sourceD1Id.text.trim().isEmpty) {
      _showError('Source D1 database ID is required to preview D1.');
      return;
    }
    if (_migrateR2 && _sourceBucket.text.trim().isEmpty) {
      _showError('Source R2 bucket name is required to preview R2.');
      return;
    }
    setState(() {
      _isRunning = true;
      _cancelRequested = false;
      _progress = 0;
      _status = 'Scanning...';
      _plan = null;
      _logs.clear();
    });
    try {
      await _validateAccounts();
      await _loadPlan();
      _setStatus('Preview ready. Review the plan, then press MIGRATE ALL.', progress: 1);
      _log('Preview ready. The migration has not started and no data has been changed.', level: 'success');
    } catch (e) {
      _setStatus('Scan failed.');
      _log('Scan failed: ' + e.toString(), level: 'error');
    } finally {
      if (mounted) setState(() => _isRunning = false);
    }
  }

  void _stopMigration() {
    setState(() => _cancelRequested = true);
    _log('Stop requested. The current Cloudflare API call will finish first.', level: 'warn');
  }

  void _clearCredentials() {
    if (_isRunning) return;
    setState(() {
      _sourceAccountId.clear();
      _sourceToken.clear();
      _sourceD1Id.clear();
      _sourceBucket.clear();
      _destinationAccountId.clear();
      _destinationToken.clear();
      _destinationD1Id.clear();
      _destinationBucket.clear();
      _validation = null;
    });
    _log('Credential fields cleared from this screen.');
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildSourceCard()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildDestinationCard()),
                  ],
                )
              else ...[
                _buildSourceCard(),
                const SizedBox(height: 20),
                _buildDestinationCard(),
              ],
              const SizedBox(height: 20),
              _buildOptionsCard(),
              const SizedBox(height: 20),
              _buildPlanCard(),
              const SizedBox(height: 20),
              _buildActionsCard(),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPreflightCard()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildLogCard()),
                  ],
                )
              else ...[
                _buildPreflightCard(),
                const SizedBox(height: 20),
                _buildLogCard(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.royalGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.royalGold.withOpacity(0.2)),
            ),
            child: const Icon(Icons.cloud_sync, color: AppTheme.royalGold, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Cloudflare Migration',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.royalGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.royalGold.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'ADMIN ONLY',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Move a D1 database and an R2 bucket from one Cloudflare account to another. '
                  'Tokens are used in memory for each request only; they are never written to D1, R2 or logs.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline, size: 15, color: AppTheme.royalGold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Least-privilege token: Account Settings (Read), D1 (Edit), Workers R2 Storage (Edit), '
                        'scoped to the specific account. Use a different token for each account.',
                        style: TextStyle(color: AppTheme.royalGold.withOpacity(0.9), fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard() {
    return _buildAccountCard(
      title: 'Account 1 - Source',
      subtitle: 'The account that currently holds your data.',
      icon: Icons.cloud_download_outlined,
      color: AppTheme.brightGold,
      accountId: _sourceAccountId,
      token: _sourceToken,
      d1Id: _sourceD1Id,
      bucket: _sourceBucket,
      tokenVisible: _sourceTokenVisible,
      onToggleToken: () => setState(() => _sourceTokenVisible = !_sourceTokenVisible),
      sourceSide: true,
    );
  }

  Widget _buildDestinationCard() {
    return _buildAccountCard(
      title: 'Account 2 - Destination',
      subtitle: 'The account that will receive the data.',
      icon: Icons.cloud_upload_outlined,
      color: AppTheme.emeraldGreen,
      accountId: _destinationAccountId,
      token: _destinationToken,
      d1Id: _destinationD1Id,
      bucket: _destinationBucket,
      tokenVisible: _destinationTokenVisible,
      onToggleToken: () => setState(() => _destinationTokenVisible = !_destinationTokenVisible),
      sourceSide: false,
    );
  }

  Widget _buildAccountCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required TextEditingController accountId,
    required TextEditingController token,
    required TextEditingController d1Id,
    required TextEditingController bucket,
    required bool tokenVisible,
    required VoidCallback onToggleToken,
    required bool sourceSide,
  }) {
    final validation = _asMap(_asMap(_validation)[sourceSide ? 'source' : 'destination']);
    final hasError = validation['error'] != null;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (_validation != null)
                _statusChip(
                  hasError ? 'ERROR' : 'VERIFIED',
                  hasError ? AppTheme.rubyRed : AppTheme.emeraldGreen,
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: accountId,
            label: 'Cloudflare Account ID',
            hint: '32-character account ID',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: token,
            label: 'Cloudflare API Token',
            hint: 'Token with D1 + R2 permissions',
            icon: Icons.key_outlined,
            obscure: !tokenVisible,
            suffix: IconButton(
              onPressed: onToggleToken,
              icon: Icon(tokenVisible ? Icons.visibility_off : Icons.visibility, size: 20, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: d1Id,
            label: sourceSide ? 'D1 Database ID' : 'D1 Database ID (blank = create)',
            hint: sourceSide ? 'Source database ID' : 'Destination database ID',
            icon: Icons.storage_outlined,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: bucket,
            label: sourceSide ? 'R2 Bucket Name' : 'R2 Bucket Name (blank = create)',
            hint: sourceSide ? 'Source bucket name' : 'Destination bucket name',
            icon: Icons.inventory_2_outlined,
          ),
          if (validation['error'] != null) ...[
            const SizedBox(height: 12),
            Text(
              validation['error'].toString(),
              style: const TextStyle(color: AppTheme.rubyRed, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool obscure = false,
    Widget? suffix,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled && !_isRunning,
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, color: AppTheme.textSecondary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppTheme.obsidianLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.6),
      ),
    );
  }

  Widget _buildOptionsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: AppTheme.royalGold, size: 22),
              SizedBox(width: 10),
              Text('Migration options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          _buildCheckbox(
            value: _migrateD1,
            onChanged: _isRunning ? null : (value) => setState(() => _migrateD1 = value),
            title: 'D1 database',
            subtitle: 'Export the source database and import schema + rows into the destination.',
          ),
          _buildCheckbox(
            value: _migrateR2,
            onChanged: _isRunning ? null : (value) => setState(() => _migrateR2 = value),
            title: 'R2 storage',
            subtitle: 'Copy every object. Files larger than 50 MB are skipped; use rclone for those.',
          ),
          _buildCheckbox(
            value: _autoCreate,
            onChanged: _isRunning ? null : (value) => setState(() => _autoCreate = value),
            title: 'Auto-create destination resources',
            subtitle: 'Create a destination D1 database / R2 bucket when its ID or name is left blank.',
          ),
          if (_autoCreate) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _newD1Name,
                    label: 'New D1 database name',
                    icon: Icons.storage_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTextField(
                    controller: _newBucketName,
                    label: 'New R2 bucket name',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.rubyRed.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.rubyRed.withOpacity(0.25)),
            ),
            child: Column(
              children: [
                _buildCheckbox(
                  value: _resetDestination,
                  onChanged: _isRunning ? null : (value) => setState(() => _resetDestination = value),
                  title: 'Reset destination D1 before import',
                  subtitle: 'Drops every table in the destination database first. This cannot be undone.',
                  titleColor: AppTheme.rubyRed,
                  dense: true,
                ),
                if (_resetDestination)
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.rubyRed, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Only use this on an empty or disposable destination database.',
                          style: TextStyle(color: AppTheme.rubyRed, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox({
    required bool value,
    required ValueChanged<bool>? onChanged,
    required String title,
    required String subtitle,
    Color titleColor = AppTheme.textPrimary,
    bool dense = false,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged == null ? null : (v) => onChanged(v ?? false),
      activeColor: AppTheme.royalGold,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: dense,
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor, fontSize: dense ? 13 : 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    );
  }

  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isRunning ? null : _scanAndPreview,
                      icon: const Icon(Icons.search_outlined, size: 18),
                      label: const Text('SCAN & PREVIEW'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isRunning ? null : _startMigration,
                      icon: _isRunning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.rocket_launch_outlined, size: 18),
                      label: Text(_isRunning ? 'MIGRATION RUNNING...' : 'MIGRATE ALL (ONE CLICK)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalGold,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_isRunning)
                      OutlinedButton.icon(
                        onPressed: _cancelRequested ? null : _stopMigration,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: Text(_cancelRequested ? 'STOPPING...' : 'STOP'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.rubyRed,
                          side: const BorderSide(color: AppTheme.rubyRed),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _isRunning ? null : _clearCredentials,
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: const Text('Clear credentials'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _status,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
              ),
              if (_progress != null)
                Text(
                  (_progress! * 100).clamp(0, 100).toStringAsFixed(0) + '%',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _isRunning ? _progress : (_progress ?? 0),
              minHeight: 8,
              backgroundColor: AppTheme.obsidianLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.royalGold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard() {
    final plan = _plan;
    final d1 = _asMap(plan?['d1']);
    final r2 = _asMap(plan?['r2']);
    final diff = _asMap(d1['diff']);
    final hasD1 = _migrateD1;
    final hasR2 = _migrateR2;
    final resetRequired = d1['reset_required'] == true;

    String badge = 'NOT SCANNED';
    Color badgeColor = AppTheme.textSecondary;
    if (plan != null) {
      if (resetRequired) {
        badge = 'RESET REQUIRED';
        badgeColor = AppTheme.rubyRed;
      } else {
        badge = 'PLAN READY';
        badgeColor = AppTheme.emeraldGreen;
      }
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, color: AppTheme.royalGold, size: 22),
                    const SizedBox(width: 10),
                    Text('MIGRATION PLAN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withOpacity(0.4)),
                ),
                child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (plan == null || (hasD1 && d1.isEmpty && hasR2 && r2.isEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No plan yet. Press "SCAN & PREVIEW" to list every D1 table, row count, column and R2 object, and to flag anything missing before migration starts. The plan is built fresh on every migration.',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasD1) _buildD1PlanSection(d1, diff),
                if (hasD1 && hasR2) const Divider(height: 26, color: Color(0xFFE2E8F0)),
                if (hasR2) _buildR2PlanSection(r2),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.royalGold.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.royalGold.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppTheme.rubyRed, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('MIGRATION WARNINGS & LIMITS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.rubyRed, letterSpacing: 0.8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_migrateD1) ...[
                        for (final warning in _asList(d1['warnings'])) _buildPlanWarning(warning.toString()),
                        for (final warning in _asList(r2['warnings'])) _buildPlanWarning(warning.toString()),
                      ] else ...[
                        for (final warning in _asList(r2['warnings'])) _buildPlanWarning(warning.toString()),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPlanWarning(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 13, color: AppTheme.rubyRed),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12, color: AppTheme.rubyRed, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildD1PlanSection(Map<String, dynamic> d1, Map<String, dynamic> diff) {
    final source = _asMap(d1['source']);
    final sourceDatabase = _asMap(source['database']);
    final totals = _asMap(source['totals']);
    final destination = _asMap(d1['destination']);
    final destinationDatabase = _asMap(destination['database']);
    final objects = _asList(source['objects']);
    final missingTables = _asList(diff['missing_tables']);
    final overlap = _asList(diff['overlapping_tables']);
    final extraTables = _asList(diff['extra_tables']);
    final missingColumns = _asList(diff['missing_columns']);
    final extraColumns = _asList(diff['extra_columns']);
    final typeMismatches = _asList(diff['type_mismatches']);
    final orderMismatches = _asList(diff['column_order_mismatches']);
    final missingIndexes = _asList(diff['missing_indexes']);
    final missingTriggers = _asList(diff['missing_triggers']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.storage_outlined, color: AppTheme.brightGold, size: 18),
            const SizedBox(width: 8),
            Text('D1 DATABASE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.brightGold, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 8),
        _buildPlanRow('Source D1', (sourceDatabase['name']?.toString() ?? sourceDatabase['id']?.toString() ?? 'source') + ' - ' + _asInt(sourceDatabase['file_size']).toString() + ' bytes, ' + _asInt(totals['tables']).toString() + ' tables, ' + _asInt(totals['rows']).toString() + ' rows, ' + _asInt(totals['columns']).toString() + ' columns, ' + _asInt(totals['indexes']).toString() + ' indexes, ' + _asInt(totals['triggers']).toString() + ' triggers', badge: 'SOURCE'),
        _buildPlanRow('Destination D1', destination['error'] != null ? 'Unavailable: ' + destination['error'].toString() : (destinationDatabase['name']?.toString() ?? 'destination') + ' - ' + _asInt(destinationDatabase['num_tables']).toString() + ' tables' + (_asInt(destinationDatabase['num_tables']).toInt() > 0 ? ' (exists)' : ' (new)'), badge: 'DESTINATION'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPlanChip('SOURCE TABLES: ' + _asInt(totals['tables']).toString(), AppTheme.brightGold),
            _buildPlanChip('SOURCE ROWS: ' + _asInt(totals['rows']).toString(), AppTheme.brightGold),
            _buildPlanChip('SOURCE COLUMNS: ' + _asInt(totals['columns']).toString(), AppTheme.brightGold),
            _buildPlanChip('SOURCE INDEXES: ' + _asInt(totals['indexes']).toString(), AppTheme.brightGold),
            _buildPlanChip('SOURCE TRIGGERS: ' + _asInt(totals['triggers']).toString(), AppTheme.brightGold),
            _buildPlanChip('NEW TABLES TO CREATE: ' + missingTables.length.toString(), AppTheme.emeraldGreen),
            _buildPlanChip('OVERLAP: ' + overlap.length.toString(), AppTheme.rubyRed),
            _buildPlanChip('EXTRA DEST COLUMNS: ' + extraColumns.length.toString(), AppTheme.rubyRed),
          ],
        ),
        const SizedBox(height: 10),
        _buildPlanItemRow('NEW TABLES TO CREATE', missingTables, AppTheme.emeraldGreen),
        _buildPlanItemRow('DESTINATION ALREADY HAS SAME TABLE (RESET REQUIRED)', overlap, AppTheme.rubyRed),
        _buildPlanItemRow('DESTINATION ONLY TABLES (KEEP UNLESS RESET)', extraTables, AppTheme.textSecondary),
        _buildPlanItemRow('MISSING COLUMNS (DESTINATION NEEDS SOURCE)', missingColumns, AppTheme.rubyRed),
        _buildPlanItemRow('EXTRA COLUMNS IN DESTINATION', extraColumns, AppTheme.rubyRed),
        _buildPlanItemRow('TYPE MISMATCHES', typeMismatches, AppTheme.rubyRed),
        _buildPlanItemRow('COLUMN ORDER MISMATCHES', orderMismatches, AppTheme.rubyRed),
        _buildPlanItemRow('MISSING INDEXES', missingIndexes, AppTheme.rubyRed),
        _buildPlanItemRow('MISSING TRIGGERS', missingTriggers, AppTheme.rubyRed),
        const SizedBox(height: 10),
        Text('SOURCE TABLE DETAIL (what will be migrated)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        if (objects.isEmpty)
          const Text('No source tables found.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
        else
          SizedBox(
            height: 220,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: ListView.builder(
                itemCount: objects.length,
                itemBuilder: (context, index) {
                  final object = _asMap(objects[index]);
                  final name = object['name']?.toString() ?? '';
                  final rows = _asInt(object['rows']);
                  final columns = _asInt(object['columns']?.length);
                  final isOverlap = overlap.any((item) => _asMap(item)['table']?.toString() == name);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isOverlap ? Icons.block : Icons.check_circle_outline,
                          size: 14,
                          color: isOverlap ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            name + ' - ' + rows.toString() + ' rows, ' + columns.toString() + ' columns' + (isOverlap ? ' (OVERLAP)' : ''),
                            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: const Color(0xFFCBD5E1), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlanRow(String label, String value, {required String badge}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label + ': ',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.royalGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.royalGold.withOpacity(0.3)),
            ),
            child: Text(badge, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.4),
      ),
    );
  }

  Widget _buildPlanItemRow(String label, List<dynamic> items, Color color) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label + ': none', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label + ': ' + items.take(14).map((item) => _formatPlanItem(item)).join(', ') +
            (items.length > 14 ? ' + ' + (items.length - 14).toString() + ' more' : ''),
        style: TextStyle(fontSize: 12, color: color, height: 1.5),
      ),
    );
  }

  String _formatPlanItem(dynamic item) {
    final row = _asMap(item);
    final key = row['key']?.toString() ?? row['table']?.toString() ?? '';
    if (row['columns'] is List) {
      return key + ': ' + _joinList(row['columns']);
    }
    if (row['indexes'] is List) {
      return key + ': ' + _joinList(row['indexes']);
    }
    if (row['triggers'] is List) {
      return key + ': ' + _joinList(row['triggers']);
    }
    if (row['source'] is List && row['destination'] is List) {
      return key + ' order: source=[' + _joinList(row['source']) + '] destination=[' + _joinList(row['destination']) + ']';
    }
    if (row['column'] != null && row['source'] != null && row['destination'] != null) {
      final sourceValue = _asList(row['source']).isNotEmpty ? _joinList(row['source']) : row['source'].toString();
      final destinationValue = _asList(row['destination']).isNotEmpty ? _joinList(row['destination']) : row['destination'].toString();
      return key + ' ' + (row['column']?.toString() ?? '') + ': ' + sourceValue + ' -> ' + destinationValue;
    }
    if (row['size'] != null) {
      return key + ' (' + _formatBytes(_asInt(row['size'])) + ')';
    }
    return key;
  }

  String _joinList(dynamic value) {
    final list = _asList(value);
    final parts = list.map((item) => _asMap(item)['name']?.toString() ?? item.toString()).toList();
    final joined = parts.join(', ');
    return joined.length > 140 ? joined.substring(0, 140) + '...' : joined;
  }

  Widget _buildR2PlanSection(Map<String, dynamic> r2) {
    final count = _asInt(r2['count']);
    final bytes = _asInt(r2['bytes']);
    final oversized = _asList(r2['oversized']);
    final largest = _asList(r2['largest']);
    final sample = _asList(r2['sample']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.inventory_2_outlined, color: AppTheme.emeraldGreen, size: 18),
            const SizedBox(width: 8),
            Text('R2 STORAGE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.emeraldGreen, letterSpacing: 1.0)),
          ],
        ),
        const SizedBox(height: 8),
        _buildPlanRow('Source R2 bucket', (r2['bucket']?.toString() ?? 'bucket') + ' - ' + count.toString() + ' objects (' + _formatBytes(bytes) + ') scanned over ' + _asInt(r2['pages']).toString() + ' page(s)', badge: 'SOURCE R2'),
        const SizedBox(height: 8),
        _buildPlanRow('Objects larger than 50 MB that will be SKIPPED', oversized.isEmpty ? 'none' : oversized.length.toString() + ' object(s) - use rclone for those files', badge: 'LIMIT'),
        const SizedBox(height: 8),
        if (largest.isNotEmpty)
          Text('Largest objects: ' + largest.take(5).map((item) => _formatPlanItem(item)).join(', '), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
        if (sample.isNotEmpty)
          Text('Sample objects: ' + sample.take(10).map((item) => _asMap(item)['key']?.toString() ?? '').where((key) => key.isNotEmpty).join(', '), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
      ],
    );
  }

  Widget _buildPreflightCard() {
    final source = _asMap(_asMap(_validation)['source']);
    final destination = _asMap(_asMap(_validation)['destination']);
    return Container(
      height: 360,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: AppTheme.royalGold, size: 20),
              SizedBox(width: 8),
              Text('PREFLIGHT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _validation == null
                ? const Center(
                    child: Text(
                      'Run "Validate accounts" to see account names,\nD1 tables and R2 object counts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  )
                : ListView(
                    children: [
                      _buildPreflightAccount('SOURCE', source, AppTheme.brightGold),
                      const Divider(height: 26, color: Color(0xFFE2E8F0)),
                      _buildPreflightAccount('DESTINATION', destination, AppTheme.emeraldGreen),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreflightAccount(String label, Map<String, dynamic> data, Color color) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label + ': not validated', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      );
    }
    final d1 = _asMap(data['d1']);
    final r2 = _asMap(data['r2']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _statusChip(label, color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data['account_name']?.toString() ?? data['account_id']?.toString() ?? 'Unknown account',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (data['token_status'] != null)
              Text(
                data['token_status'].toString(),
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_migrateD1)
          _buildPreflightLine(
            icon: Icons.storage_outlined,
            text: d1['error'] != null
                ? 'D1: ' + d1['error'].toString()
                : 'D1: ' + (d1['name']?.toString() ?? 'not set') +
                    ' - ' + _asInt(d1['tables']).toString() + ' tables',
            isError: d1['error'] != null,
          ),
        if (_migrateR2)
          _buildPreflightLine(
            icon: Icons.inventory_2_outlined,
            text: r2['error'] != null
                ? 'R2: ' + r2['error'].toString()
                : 'R2: ' + (r2['bucket']?.toString() ?? 'not set') +
                    ' - ' + _asInt(r2['count']).toString() + ' objects (' +
                    _formatBytes(_asInt(r2['bytes'])) + ')' +
                    (r2['truncated'] == true ? ' [capped]' : ''),
            isError: r2['error'] != null,
          ),
        if (data['error'] != null)
          _buildPreflightLine(icon: Icons.error_outline, text: data['error'].toString(), isError: true),
      ],
    );
  }

  Widget _buildPreflightLine({required IconData icon, required String text, bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: isError ? AppTheme.rubyRed : AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: isError ? AppTheme.rubyRed : AppTheme.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard() {
    return Container(
      height: 360,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.terminal, color: AppTheme.royalGold, size: 20),
                  SizedBox(width: 8),
                  Text('LIVE LOG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalGold, letterSpacing: 1.0)),
                ],
              ),
              Text(
                _logs.length.toString() + ' lines',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Migration steps will appear here.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.builder(
                      controller: _logScrollController,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final entry = _logs[index];
                        Color color;
                        if (entry.level == 'error') {
                          color = const Color(0xFFFCA5A5);
                        } else if (entry.level == 'warn') {
                          color = const Color(0xFFFCD34D);
                        } else if (entry.level == 'success') {
                          color = const Color(0xFF6EE7B7);
                        } else {
                          color = const Color(0xFFCBD5E1);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            '[' + entry.time + '] ' + entry.message,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              fontFamily: 'monospace',
                              color: color,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
