import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home Loan and Mortgage Loan policy parameter verification', () {
    final policy = {
      'loan_type': 'Home Loan',
      'vertical': 'Prime',
      'segment': 'DSA',
      'age_limit': '21 - 65 Years',
      'foir_norms': '1L-7L: 60% | 7L-10L: 65% | 10L-12L: 70% | >=12L: 75%',
      'ltv_ratio': '1L-30L: 90% | 30L-75L: 80% | >=75L: 70%',
      'ltv_on_plot': '1L-30L: 90%/80%/70% | 30L-75L: 90%/80%/70% | >=75L: 90%/80%/70%',
      'repayment_tenure': 'Up to 30 Years',
      'road_winding_property_funding': 'YES',
      'gram_panchayat_property_funding': 'YES',
      'notary_to_registry_funding': 'YES',
      'gram_panchayat_patta_funding': 'YES',
      'dron_patta_funding': 'YES',
      'highest_ticket_size_notary': 'YES',
      'high_tension_line_funding': 'NO',
      'without_diversion_property_funding': 'NO',
      'only_diversion_property_funding': 'YES',
      'akvn_property_funding': 'YES',
      'green_belt_property_funding': 'NO',
      'plot_purchase': 'YES',
      'plot_mortgage': 'YES',
    };

    expect(policy['loan_type'], 'Home Loan');
    expect(policy['vertical'], 'Prime');
    expect(policy['segment'], 'DSA');
    expect(policy['road_winding_property_funding'], 'YES');
    expect(policy['high_tension_line_funding'], 'NO');
    expect(policy['plot_purchase'], 'YES');
    expect(policy['plot_mortgage'], 'YES');
  });
}
