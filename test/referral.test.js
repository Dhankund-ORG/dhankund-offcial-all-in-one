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
