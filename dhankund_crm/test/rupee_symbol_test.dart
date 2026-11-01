import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verify CRM screens do not contain mojibake symbols', () {
    final files = [
      'lib/screens/pages/banker_policies_page.dart',
      'lib/screens/pages/leads_report_page.dart',
      'lib/screens/pages/referrals_page.dart',
    ];

    for (final filePath in files) {
      final file = File(filePath);
      expect(file.existsSync(), isTrue, reason: '$filePath should exist');
      final content = file.readAsStringSync();
      expect(content.contains('â'), isFalse, reason: '$filePath should not contain mojibake â');
      expect(content.contains('₹'), isTrue, reason: '$filePath should contain Indian Rupee symbol ₹');
    }
  });
}
