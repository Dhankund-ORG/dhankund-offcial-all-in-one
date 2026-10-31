import test from 'node:test';
import assert from 'node:assert/strict';

// Helper mirror function under test
function policyColumns(b) {
  return {
    bank_name: b.bank_name || null,
    banker_name: b.banker_name || null,
    banker_mobile: b.banker_mobile || null,
    office_address: b.office_address || null,
    l1_manager_name: b.l1_manager_name || null,
    l1_manager_mobile: b.l1_manager_mobile || null,
    l2_manager_name: b.l2_manager_name || null,
    l2_manager_mobile: b.l2_manager_mobile || null,
    loan_type: b.loan_type || null,
    product_type: b.product_type || null,
    vertical: b.vertical || null,
    segment: b.segment || null,
    min_cibil: (b.min_cibil != null) ? b.min_cibil : null,
    min_income: b.min_income || null,
    min_ticket_size: b.min_ticket_size || null,
    max_ticket_size: b.max_ticket_size || null,
    ticket_size: ((b.min_ticket_size || '') + ' - ' + (b.max_ticket_size || '')),
    max_loan_amount: b.max_ticket_size || null,
    ltv_ratio: b.ltv_ratio || null,
    ltv_on_plot: b.ltv_on_plot || null,
    m_profile_allowed: b.m_profile_allowed || null,
    max_allowed_bounces: (b.max_allowed_bounces != null) ? b.max_allowed_bounces : null,
    geo_radius: b.geo_radius || null,
    login_fee: b.login_fee || null,
    interest_rate: b.interest_rate || null,
    processing_fee: b.processing_fee || null,
    special_features: b.special_features || null,
    tat_days: b.tat_days || null,
    age_limit: b.age_limit || null,
    foir_norms: b.foir_norms || null,
    existing_obligations: b.existing_obligations || null,
    employment_stability: b.employment_stability || null,
    repayment_tenure: b.repayment_tenure || null,
    road_winding_property_funding: b.road_winding_property_funding || null,
    gram_panchayat_property_funding: b.gram_panchayat_property_funding || null,
    notary_to_registry_funding: b.notary_to_registry_funding || null,
    gram_panchayat_patta_funding: b.gram_panchayat_patta_funding || null,
    dron_patta_funding: b.dron_patta_funding || null,
    highest_ticket_size_notary: b.highest_ticket_size_notary || null,
    high_tension_line_funding: b.high_tension_line_funding || null,
    without_diversion_property_funding: b.without_diversion_property_funding || null,
    only_diversion_property_funding: b.only_diversion_property_funding || null,
    akvn_property_funding: b.akvn_property_funding || null,
    green_belt_property_funding: b.green_belt_property_funding || null,
    plot_purchase: b.plot_purchase || null,
    plot_mortgage: b.plot_mortgage || null,
  };
}

test('policyColumns properly formats Home Loan & Mortgage Loan underwriting fields', () => {
  const input = {
    bank_name: 'HDFC Bank',
    banker_name: 'Rahul Sharma',
    banker_mobile: '9876543210',
    loan_type: 'Home Loan',
    vertical: 'Prime',
    segment: 'DSA',
    min_cibil: 750,
    min_ticket_size: '₹10,00,000',
    max_ticket_size: '₹5,00,00,000',
    ltv_ratio: '1L-30L: 90% | 30L-75L: 80% | >=75L: 70%',
    ltv_on_plot: '1L-30L: 80% | 30L-75L: 70% | >=75L: 70%',
    age_limit: '21 - 65 Years',
    foir_norms: '1L-7L: 60% | 7L-10L: 65% | 10L-12L: 70% | >=12L: 75%',
    existing_obligations: 'Deducted from net income',
    employment_stability: 'Min 2 years total / 1 year current company',
    repayment_tenure: 'Up to 30 Years',
    road_winding_property_funding: 'YES',
    gram_panchayat_property_funding: 'YES',
    notary_to_registry_funding: 'YES',
    gram_panchayat_patta_funding: 'YES',
    dron_patta_funding: 'YES',
    highest_ticket_size_notary: 'YES',
    high_tension_line_funding: 'NO',
    without_diversion_property_funding: 'NO',
    only_diversion_property_funding: 'YES',
    akvn_property_funding: 'YES',
    green_belt_property_funding: 'NO',
    plot_purchase: 'YES',
    plot_mortgage: 'YES',
  };

  const output = policyColumns(input);

  assert.equal(output.bank_name, 'HDFC Bank');
  assert.equal(output.loan_type, 'Home Loan');
  assert.equal(output.vertical, 'Prime');
  assert.equal(output.segment, 'DSA');
  assert.equal(output.age_limit, '21 - 65 Years');
  assert.equal(output.foir_norms, '1L-7L: 60% | 7L-10L: 65% | 10L-12L: 70% | >=12L: 75%');
  assert.equal(output.ltv_ratio, '1L-30L: 90% | 30L-75L: 80% | >=75L: 70%');
  assert.equal(output.ltv_on_plot, '1L-30L: 80% | 30L-75L: 70% | >=75L: 70%');
  assert.equal(output.repayment_tenure, 'Up to 30 Years');
  assert.equal(output.road_winding_property_funding, 'YES');
  assert.equal(output.high_tension_line_funding, 'NO');
  assert.equal(output.green_belt_property_funding, 'NO');
  assert.equal(output.plot_purchase, 'YES');
  assert.equal(output.plot_mortgage, 'YES');
});

test('policyColumns safely handles missing fields and defaults to null', () => {
  const output = policyColumns({});
  assert.equal(output.bank_name, null);
  assert.equal(output.loan_type, null);
  assert.equal(output.age_limit, null);
  assert.equal(output.foir_norms, null);
  assert.equal(output.ltv_on_plot, null);
  assert.equal(output.segment, null);
  assert.equal(output.road_winding_property_funding, null);
});
