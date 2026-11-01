import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Advanced EMI Calculator Calculations', () {
    test('Standard Home Loan EMI calculation (₹25L, 8.5%, 20 Yrs)', () {
      double principal = 2500000;
      double rate = 8.5;
      double tenureYears = 20;
      double months = tenureYears * 12;

      double monthlyRate = rate / 12 / 100;
      double factor = pow(1 + monthlyRate, months).toDouble();
      double emi = (principal * monthlyRate * factor) / (factor - 1);

      // Expected EMI is ~₹21,695.57
      expect(emi.round(), 21696);
      double totalPayment = emi * months;
      expect((totalPayment - 5206938).abs() <= 2, isTrue);
      double totalInterest = totalPayment - principal;
      expect((totalInterest - 2706938).abs() <= 2, isTrue);
    });

    test('Loan Amount eligibility reverse calculation', () {
      double targetEmi = 21696;
      double rate = 8.5;
      double months = 240;

      double monthlyRate = rate / 12 / 100;
      double factor = pow(1 + monthlyRate, months).toDouble();
      double principal = (targetEmi * (factor - 1)) / (monthlyRate * factor);

      // Principal should be ~₹25,00,000
      expect((principal - 2500000).abs() < 100, isTrue);
    });

    test('Tenure reverse calculation from Principal and EMI', () {
      double principal = 2500000;
      double emi = 21696;
      double rate = 8.5;
      double monthlyRate = rate / 12 / 100;

      double n = log(emi / (emi - principal * monthlyRate)) / log(1 + monthlyRate);
      expect(n.round(), 240); // 20 years
    });
  });
}
