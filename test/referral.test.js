import test from 'node:test';
import assert from 'node:assert/strict';

function getIstDateParts(date = new Date()) {
  const istOffsetMs = 330 * 60 * 1000;
  const istTime = new Date(date.getTime() + istOffsetMs);
  const dd = String(istTime.getUTCDate()).padStart(2, '0');
  const mm = String(istTime.getUTCMonth() + 1).padStart(2, '0');
  const yy = String(istTime.getUTCFullYear()).slice(-2);
  const hh = String(istTime.getUTCHours()).padStart(2, '0');
  const min = String(istTime.getUTCMinutes()).padStart(2, '0');
  return { dd, mm, yy, hh, min, dateStr: `${dd}${mm}${yy}`, timeStr: `${hh}${min}` };
}

function formatLeadId(date = new Date(), sequence = 1) {
  const p = getIstDateParts(date);
  const seqStr = String(sequence).slice(-6).padStart(6, '0');
  return `${p.dateStr}${p.timeStr}${seqStr}`;
}

function buildWebsiteContactReferral(body, leadId) {
  const firstName = (body.firstName || '').trim();
  const lastName = (body.lastName || '').trim();
  const fullName = (body.name || `${firstName} ${lastName}`).trim();
  const mobile = (body.mobile || body.phone || '').toString().replace(/\D/g, '').slice(-10);
  const email = (body.email || '').trim();
  const message = (body.message || '').trim();
  return {
    id: leadId,
    referrer_id: 'website',
    friend_name: fullName,
    friend_mobile: mobile,
    relationship: 'Website Contact Form',
    loan_type: body.loanType || 'Website Lead',
    notes: JSON.stringify({
      source: 'Website Lead',
      email,
      message,
    }),
    status: 'Pending',
  };
}

function buildLoanFromReferral(referral, body, loanId) {
  return {
    id: loanId,
    customer_id: referral.referrer_id && referral.referrer_id !== 'website' ? referral.referrer_id : 'website_lead',
    applicant_name: body.applicantName || referral.friend_name,
    mobile: body.mobile || referral.friend_mobile,
    loan_type: (body.loanType && body.loanType !== 'Website Lead') ? body.loanType : 'Personal Loan',
    amount: Number(body.amount || 0),
    monthly_salary: Number(body.monthlySalary || 0),
    pan_number: body.panNumber || null,
    aadhar_number: body.aadharNumber || null,
    status: body.status || 'Document Pending',
    referral_id: referral.id,
  };
}

test('formatLeadId generates correct 16-character lead ID format: DDMMYYHHmm000001', () => {
  // Test with fixed date: 02 Nov 2026 12:47 IST
  // IST is UTC + 5:30. So 12:47 IST = 07:17 UTC
  const testDate = new Date('2026-11-02T07:17:00.000Z');
  const leadId = formatLeadId(testDate, 1);
  assert.equal(leadId, '0211261247000001');
  assert.equal(leadId.length, 16);
});

test('formatLeadId increments sequence and pads to 6 digits', () => {
  const testDate = new Date('2026-11-02T07:17:00.000Z');
  const leadId = formatLeadId(testDate, 42);
  assert.equal(leadId, '0211261247000042');
});

test('formatLeadId handles midnight 00:05 in 24-hour format correctly', () => {
  // 00:05 IST on 02 Nov 2026 = 18:35 UTC on 01 Nov 2026
  const midnightDate = new Date('2026-11-01T18:35:00.000Z');
  const leadId = formatLeadId(midnightDate, 5);
  assert.equal(leadId, '0211260005000005');
});

test('buildWebsiteContactReferral formats Contact Us submission as Website Lead in referrals', () => {
  const referral = buildWebsiteContactReferral({
    firstName: 'Rajesh',
    lastName: 'Khandelwal',
    mobile: '+91 98765-43210',
    email: 'rajesh@example.com',
    message: 'Need Home Loan of 50 Lakhs',
  }, '0411262230000001');

  assert.equal(referral.id, '0411262230000001');
  assert.equal(referral.referrer_id, 'website');
  assert.equal(referral.friend_name, 'Rajesh Khandelwal');
  assert.equal(referral.friend_mobile, '9876543210');
  assert.equal(referral.relationship, 'Website Contact Form');
  assert.equal(referral.loan_type, 'Website Lead');
  const parsedNotes = JSON.parse(referral.notes);
  assert.equal(parsedNotes.source, 'Website Lead');
  assert.equal(parsedNotes.email, 'rajesh@example.com');
});

test('buildLoanFromReferral converts referral or website lead into Loan Pipeline record', () => {
  const referral = {
    id: '0411262230000001',
    referrer_id: 'website',
    friend_name: 'Rajesh Khandelwal',
    friend_mobile: '9876543210',
    loan_type: 'Website Lead',
  };
  const loan = buildLoanFromReferral(referral, {
    loanType: 'Home Loan',
    amount: 5000000,
    monthlySalary: 95000,
    panNumber: 'ABCDE1234F',
    aadharNumber: '123456789012',
    status: 'Login',
  }, '0411262235000002');

  assert.equal(loan.id, '0411262235000002');
  assert.equal(loan.applicant_name, 'Rajesh Khandelwal');
  assert.equal(loan.mobile, '9876543210');
  assert.equal(loan.loan_type, 'Home Loan');
  assert.equal(loan.amount, 5000000);
  assert.equal(loan.status, 'Login');
  assert.equal(loan.referral_id, '0411262230000001');
});
