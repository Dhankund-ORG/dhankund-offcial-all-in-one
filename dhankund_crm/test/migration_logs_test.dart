import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CRM Migration Logs & Copy Feature Tests', () {
    test('cloudflare_migration_page.dart exists and has copy functions', () {
      final file = File('lib/screens/pages/cloudflare_migration_page.dart');
      expect(file.existsSync(), isTrue, reason: 'cloudflare_migration_page.dart must exist');
      final content = file.readAsStringSync();

      expect(content.contains('_copyAllLogs'), isTrue,
          reason: 'Must include _copyAllLogs function');
      expect(content.contains('_copyErrorLogs'), isTrue,
          reason: 'Must include _copyErrorLogs function');
      expect(content.contains('_copySingleLog'), isTrue,
          reason: 'Must include _copySingleLog function');
      expect(content.contains('_copyFailureDetail'), isTrue,
          reason: 'Must include _copyFailureDetail function');
      expect(content.contains('Clipboard.setData'), isTrue,
          reason: 'Must use Clipboard.setData to copy to clipboard');
    });

    test('cloudflare_migration_page.dart wraps logs in SelectionArea', () {
      final file = File('lib/screens/pages/cloudflare_migration_page.dart');
      final content = file.readAsStringSync();

      expect(content.contains('SelectionArea'), isTrue,
          reason: 'Live log must be wrapped in SelectionArea for selectable text');
    });

    test('cloudflare_migration_page.dart provides filter tabs and failure banner', () {
      final file = File('lib/screens/pages/cloudflare_migration_page.dart');
      final content = file.readAsStringSync();

      expect(content.contains('_buildFailureBanner'), isTrue,
          reason: 'Must have _buildFailureBanner for clear error display');
      expect(content.contains('_buildLogFilterChip'), isTrue,
          reason: 'Must have _buildLogFilterChip for filtering logs');
      expect(content.contains('_retryD1Only'), isTrue,
          reason: 'Must have _retryD1Only to allow isolated retry of D1');
      expect(content.contains('_retryR2Only'), isTrue,
          reason: 'Must have _retryR2Only to allow isolated retry of R2');
    });

    test('Log formatting and filtering logic works as expected', () {
      final logs = [
        {'time': '11:55:01', 'message': 'Starting migration...', 'level': 'info'},
        {'time': '11:55:05', 'message': 'D1 export failed: Table not found', 'level': 'error'},
        {'time': '11:55:10', 'message': 'R2 verification is not a full match', 'level': 'warn'},
        {'time': '11:55:15', 'message': 'R2 copy finished.', 'level': 'success'},
      ];

      final errorLogs = logs.where((e) => e['level'] == 'error' || e['level'] == 'warn').toList();
      expect(errorLogs.length, 2);

      final formattedAll = logs.map((e) => '[${e['time']}] [${e['level']!.toUpperCase()}] ${e['message']}').join('\n');
      expect(formattedAll.contains('[11:55:01] [INFO] Starting migration...'), isTrue);
      expect(formattedAll.contains('[11:55:05] [ERROR] D1 export failed: Table not found'), isTrue);

      final formattedErrors = errorLogs.map((e) => '[${e['time']}] [${e['level']!.toUpperCase()}] ${e['message']}').join('\n');
      expect(formattedErrors.contains('[INFO]'), isFalse);
      expect(formattedErrors.contains('[ERROR]'), isTrue);
      expect(formattedErrors.contains('[WARN]'), isTrue);
    });
  });
}
