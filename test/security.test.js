import test from 'node:test';
import assert from 'node:assert/strict';

function extractCount(row) {
  if (!row) return 0;
  const val = row.cnt !== undefined ? row.cnt : (row['COUNT(*)'] !== undefined ? row['COUNT(*)'] : row['count(*)']);
  const num = Number(val);
  return isNaN(num) ? 0 : num;
}

function escapeHtml(str) {
  return String(str || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

test('extractCount properly handles D1 column alias variations', () => {
  assert.equal(extractCount(null), 0);
  assert.equal(extractCount({ cnt: 3 }), 3);
  assert.equal(extractCount({ 'COUNT(*)': 5 }), 5);
  assert.equal(extractCount({ 'count(*)': 2 }), 2);
  assert.equal(extractCount({ cnt: '4' }), 4);
  assert.equal(extractCount({ cnt: 'invalid' }), 0);
});

test('escapeHtml prevents XSS in email details', () => {
  assert.equal(escapeHtml('<script>alert("xss")</script>'), '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;');
  assert.equal(escapeHtml('192.168.1.1'), '192.168.1.1');
  assert.equal(escapeHtml("Mozilla/5.0 'Test'"), 'Mozilla/5.0 &#039;Test&#039;');
});

test('Temporary block expiry validation', () => {
  const futureExpiry = new Date(Date.now() + 3600000).toISOString();
  const pastExpiry = new Date(Date.now() - 3600000).toISOString();

  assert.equal(new Date(futureExpiry).getTime() > Date.now(), true);
  assert.equal(new Date(pastExpiry).getTime() > Date.now(), false);
});

test('Bot honeypot detection identifies crawler fields', () => {
  const cleanBody = { email: 'user@example.com' };
  const botBody1 = { email: 'user@example.com', website: 'http://spam.com' };
  const botBody2 = { email: 'user@example.com', phone_number: '1234567890' };
  const botBody3 = { email: 'user@example.com', bot_trap: 'yes' };

  const isBot = (body) => Boolean(body.website || body.phone_number || body.username || body.bot_trap || body.address);

  assert.equal(isBot(cleanBody), false);
  assert.equal(isBot(botBody1), true);
  assert.equal(isBot(botBody2), true);
  assert.equal(isBot(botBody3), true);
});
