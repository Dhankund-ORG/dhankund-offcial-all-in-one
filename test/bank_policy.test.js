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
    approved_pincodes: b.approved_pincodes || b.approvedPincodes || null,
    one_pager_policy_url: b.one_pager_policy_url || b.onePagerPolicyUrl || null,
    status: b.status || 'approved',
    uploaded_by_uid: b.uploaded_by_uid || b.uploadedByUid || null,
    uploaded_by_name: b.uploaded_by_name || b.uploadedByName || null,
    uploaded_by_mobile: b.uploaded_by_mobile || b.uploadedByMobile || null,
    rejection_reason: b.rejection_reason || b.rejectionReason || null,
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
    is_salary_slip_required: b.is_salary_slip_required || null,
    residence_ownership_type: b.residence_ownership_type || null,
    business_ownership_type: b.business_ownership_type || null,
    is_gst_required: b.is_gst_required || null,
    is_itr_required: b.is_itr_required || null,
    is_udyam_required: b.is_udyam_required || null,
    is_current_account_required: b.is_current_account_required || null,
    bankings_considered: b.bankings_considered || null,
  };
}

function extractPincodesFromText(text) {
  const pinSet = new Set();
  const regex = /(?:^|[^\d])([1-9]\d{5})(?!\d)/g;
  let m;
  while ((m = regex.exec(text)) !== null) {
    pinSet.add(m[1]);
  }
  return Array.from(pinSet);
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
    geo_radius: '50 KM',
    approved_pincodes: '452001, 452010, 452016',
    one_pager_policy_url: 'https://api.dhankund.com/api/v1/storage/one_pager_policies/doc.pdf',
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
  assert.equal(output.approved_pincodes, '452001, 452010, 452016');
  assert.equal(output.one_pager_policy_url, 'https://api.dhankund.com/api/v1/storage/one_pager_policies/doc.pdf');
  assert.equal(output.status, 'approved');
});

test('policyColumns handles Personal Loan policies without LTV and with salary/residence norms', () => {
  const input = {
    bank_name: 'ICICI Bank',
    loan_type: 'Personal Loan',
    ltv_ratio: null,
    max_allowed_bounces: 0,
    is_salary_slip_required: 'YES - Mandatory (अनिवार्य)',
    residence_ownership_type: 'Owned Only Required (केवल खुद का मकान)',
    approvedPincodes: '462001, 462011',
  };

  const output = policyColumns(input);

  assert.equal(output.bank_name, 'ICICI Bank');
  assert.equal(output.loan_type, 'Personal Loan');
  assert.equal(output.ltv_ratio, null);
  assert.equal(output.max_allowed_bounces, 0);
  assert.equal(output.is_salary_slip_required, 'YES - Mandatory (अनिवार्य)');
  assert.equal(output.residence_ownership_type, 'Owned Only Required (केवल खुद का मकान)');
  assert.equal(output.approved_pincodes, '462001, 462011');
});

test('policyColumns handles Business Loan policies without LTV and with business/doc norms', () => {
  const input = {
    bank_name: 'Axis Bank',
    loan_type: 'Business Loan',
    ltv_ratio: null,
    business_ownership_type: 'At least One Owned Required (Residence or Office)',
    is_gst_required: 'YES',
    is_itr_required: 'YES',
    is_udyam_required: 'YES',
    is_current_account_required: 'YES',
    bankings_considered: '6+',
  };

  const output = policyColumns(input);

  assert.equal(output.bank_name, 'Axis Bank');
  assert.equal(output.loan_type, 'Business Loan');
  assert.equal(output.ltv_ratio, null);
  assert.equal(output.business_ownership_type, 'At least One Owned Required (Residence or Office)');
  assert.equal(output.is_gst_required, 'YES');
  assert.equal(output.is_itr_required, 'YES');
  assert.equal(output.is_udyam_required, 'YES');
  assert.equal(output.is_current_account_required, 'YES');
  assert.equal(output.bankings_considered, '6+');
});

test('policyColumns supports App Uploaded Policy pending_approval workflow and admin modification merge', () => {
  const bankerSubmission = policyColumns({
    bank_name: 'State Bank of India (SBI)',
    banker_name: 'Amit Verma',
    banker_mobile: '9988776655',
    loan_type: 'Home Loan',
    geo_radius: '40 KM',
    approved_pincodes: '452001, 452002',
    one_pager_policy_url: 'https://api.dhankund.com/api/v1/storage/one_pager_policies/sbi.pdf',
    status: 'pending_approval',
    uploaded_by_uid: 'banker-uid-1',
    uploaded_by_name: 'Amit Verma',
    uploaded_by_mobile: '9988776655',
  });

  assert.equal(bankerSubmission.status, 'pending_approval');
  assert.equal(bankerSubmission.uploaded_by_uid, 'banker-uid-1');
  assert.equal(bankerSubmission.approved_pincodes, '452001, 452002');

  // Admin modifies approved_pincodes and interest_rate before approving
  const adminModifications = {
    approved_pincodes: '452001, 452002, 452010',
    interest_rate: '8.40% p.a.',
  };
  const approvedPolicy = policyColumns({
    ...bankerSubmission,
    ...adminModifications,
    status: 'approved',
    rejection_reason: null,
  });

  assert.equal(approvedPolicy.status, 'approved');
  assert.equal(approvedPolicy.bank_name, 'State Bank of India (SBI)');
  assert.equal(approvedPolicy.approved_pincodes, '452001, 452002, 452010');
  assert.equal(approvedPolicy.interest_rate, '8.40% p.a.');
  assert.equal(approvedPolicy.one_pager_policy_url, 'https://api.dhankund.com/api/v1/storage/one_pager_policies/sbi.pdf');
});

test('extractPincodesFromText extracts unique 6-digit Indian PIN codes and ignores non-pincodes', () => {
  const sampleCsv = 'City,Pincode,Phone\nIndore,452001,9876543210\nIndore Vijay Nagar,452010,000123\nBhopal,462001,452001';
  const pins = extractPincodesFromText(sampleCsv);
  assert.deepEqual(pins, ['452001', '452010', '462001']);
});

test('policyColumns safely handles missing fields and defaults to null', () => {
  const output = policyColumns({});
  assert.equal(output.bank_name, null);
  assert.equal(output.loan_type, null);
  assert.equal(output.age_limit, null);
  assert.equal(output.foir_norms, null);
  assert.equal(output.ltv_on_plot, null);
  assert.equal(output.segment, null);
  assert.equal(output.approved_pincodes, null);
  assert.equal(output.one_pager_policy_url, null);
  assert.equal(output.status, 'approved');
  assert.equal(output.road_winding_property_funding, null);
  assert.equal(output.is_salary_slip_required, null);
  assert.equal(output.residence_ownership_type, null);
  assert.equal(output.business_ownership_type, null);
  assert.equal(output.is_gst_required, null);
  assert.equal(output.is_itr_required, null);
  assert.equal(output.is_udyam_required, null);
  assert.equal(output.is_current_account_required, null);
  assert.equal(output.bankings_considered, null);
});
