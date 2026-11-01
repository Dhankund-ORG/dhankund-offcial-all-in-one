import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile, Role Identification & Banners Validation', () {
    test('Customer Unique ID generation logic', () {
      const mobile = '9876543210';
      const role = 'Customer';
      final isCustomer = role.toLowerCase().contains('customer');
      final suffix = (mobile.length >= 6) ? mobile.substring(mobile.length - 6) : '100234';
      final customId = isCustomer ? ('CUST-$suffix') : ('DK-PTR-$suffix');

      expect(customId, 'CUST-543210');
      expect(isCustomer, isTrue);
    });

    test('Partner/Banker/DSA Unique ID generation logic', () {
      const mobile = '9123456789';
      const role = 'DSA';
      final isCustomer = role.toLowerCase().contains('customer');
      final suffix = (mobile.length >= 6) ? mobile.substring(mobile.length - 6) : '100234';
      final customId = isCustomer ? ('CUST-$suffix') : ('DK-PTR-$suffix');

      expect(customId, 'DK-PTR-456789');
      expect(isCustomer, isFalse);
    });

    test('Status 24-hour expiration calculation logic', () {
      final now = DateTime.now();
      final freshStatusTime = now.subtract(const Duration(hours: 4));
      final expiredStatusTime = now.subtract(const Duration(hours: 25));

      final isFreshActive = now.difference(freshStatusTime).inHours < 24;
      final isExpiredActive = now.difference(expiredStatusTime).inHours < 24;

      expect(isFreshActive, isTrue);
      expect(isExpiredActive, isFalse);
    });

    test('Insurance Application Payload validation', () {
      final payload = {
        'insurance_type': 'Health Insurance',
        'name': 'Rahul Sharma',
        'dob': '15-08-1992',
        'mobile_number': '9876543210',
        'email': 'rahul.sharma@example.com',
        'address': 'Plot 45, Scheme 78, Vijay Nagar, Indore',
        'yearly_income': '750000',
        'dependents': '3',
        'occupation': 'Salaried',
      };

      expect(payload['insurance_type'], 'Health Insurance');
      expect(payload['mobile_number']!.length, 10);
      expect(payload['email']!.contains('@'), isTrue);
      expect(int.parse(payload['yearly_income']!), greaterThan(0));
    });

    test('Lead ID format consistency', () {
      final dt = DateTime(2026, 11, 2, 14, 30);
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = dt.year.toString().substring(2);
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      const seq = '000001';
      final leadId = '$dd$mm$yy$hh$min$seq';

      expect(leadId, '0211261430000001');
      expect(leadId.length, 16);
    });
  });
}
