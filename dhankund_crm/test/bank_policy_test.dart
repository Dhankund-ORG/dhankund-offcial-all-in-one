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

  test('Personal Loan policy parameter verification - LTV null and salary/residence norms', () {
    final personalLoanPolicy = {
      'loan_type': 'Personal Loan',
      'vertical': 'Prime',
      'segment': 'DSA',
      'ltv_ratio': null,
      'max_allowed_bounces': 0,
      'is_salary_slip_required': 'YES - Mandatory (अनिवार्य)',
      'residence_ownership_type': 'Owned Only Required (केवल खुद का मकान)',
    };

    expect(personalLoanPolicy['loan_type'], 'Personal Loan');
    expect(personalLoanPolicy['ltv_ratio'], isNull);
    expect(personalLoanPolicy['is_salary_slip_required'], 'YES - Mandatory (अनिवार्य)');
    expect(personalLoanPolicy['residence_ownership_type'], 'Owned Only Required (केवल खुद का मकान)');
  });

  test('Business Loan policy parameter verification - LTV null, doc mandatory checks and bankings', () {
    final businessLoanPolicy = {
      'loan_type': 'Business Loan',
      'vertical': 'Prime',
      'segment': 'DSA',
      'ltv_ratio': null,
      'business_ownership_type': 'At least One Owned Required (Residence or Office)',
      'is_gst_required': 'YES',
      'is_itr_required': 'YES',
      'is_udyam_required': 'YES',
      'is_current_account_required': 'YES',
      'bankings_considered': '6+',
    };

    expect(businessLoanPolicy['loan_type'], 'Business Loan');
    expect(businessLoanPolicy['ltv_ratio'], isNull);
    expect(businessLoanPolicy['business_ownership_type'], 'At least One Owned Required (Residence or Office)');
    expect(businessLoanPolicy['is_gst_required'], 'YES');
    expect(businessLoanPolicy['is_itr_required'], 'YES');
    expect(businessLoanPolicy['is_udyam_required'], 'YES');
    expect(businessLoanPolicy['is_current_account_required'], 'YES');
    expect(businessLoanPolicy['bankings_considered'], '6+');
  });
}

