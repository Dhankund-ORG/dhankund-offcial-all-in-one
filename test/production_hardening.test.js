import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { allowedOrigins, isOriginAllowed } from '../worker/cors.js';
import { WHATSAPP_INDEX_SQL } from '../worker/whatsapp_schema.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const workerSrc = readFileSync(join(root, 'worker.js'), 'utf8');
const whatsappSrc = readFileSync(join(root, 'worker/whatsapp_routes.js'), 'utf8');
const schemaSql = readFileSync(join(root, 'schema.sql'), 'utf8');

// ---------- CORS ----------
test('CORS only echoes origins that are on the allow list', () => {
  const defaults = allowedOrigins({});
  assert.ok(defaults.includes('https://crm.dhankund.com'));
  assert.ok(defaults.includes('https://www.dhankund.com'));
  assert.equal(defaults.includes('*'), false);

  const overridden = allowedOrigins({ ALLOWED_ORIGINS: 'https://a.example, https://b.example ,' });
  assert.deepEqual(overridden, ['https://a.example', 'https://b.example']);

  assert.equal(isOriginAllowed({}, 'https://crm.dhankund.com'), true);
  assert.equal(isOriginAllowed({}, 'https://evil.example'), false);
  assert.equal(isOriginAllowed({}, ''), false);
  assert.equal(isOriginAllowed({ ALLOWED_ORIGINS: 'https://only.example' }, 'https://crm.dhankund.com'), false);
});

test('the API never answers with a wildcard CORS origin', () => {
  assert.equal(workerSrc.includes("'Access-Control-Allow-Origin', '*'"), false);
  assert.ok(workerSrc.includes('isOriginAllowed(c.env, origin)'));
});

test('security headers are set on every response', () => {
  for (const header of ['X-Content-Type-Options', 'X-Frame-Options', 'Referrer-Policy', 'Strict-Transport-Security']) {
    assert.ok(workerSrc.includes(header), header + ' must be set');
  }
});

// ---------- login protection ----------
test('the login route checks the IP block list and counts failures', () => {
  const login = workerSrc.slice(workerSrc.indexOf("app.post('/api/v1/auth/login'"));
  const route = login.slice(0, login.indexOf("app.post('/api/v1/auth/register'"));
  assert.ok(route.includes('checkClientIpBlocked(c)'), 'login must consult the IP block list');
  assert.ok(route.includes('recordAuthFailure(c, email'), 'failed logins must be recorded');
});

// ---------- profile saves ----------
test('profile saves merge the JSON inside one statement, not read-modify-write', () => {
  const fn = workerSrc.slice(workerSrc.indexOf('async function mergeUserData('));
  const body = fn.slice(0, fn.indexOf('\nfunction '));
  assert.ok(body.includes('json_patch('), 'the data column must be patched atomically');
  assert.equal(body.includes('JSON.stringify(merged)'), false, 'the old read-modify-write write must be gone');
  assert.ok(body.includes('json_valid(data)'), 'a row with invalid JSON must still be writable');
});

test('clearing a field writes NULL instead of keeping the old value', () => {
  const fn = workerSrc.slice(workerSrc.indexOf('async function mergeUserData('));
  const body = fn.slice(0, fn.indexOf('\nfunction '));
  assert.ok(body.includes("(value === null || value === '')"), 'empty values must clear the column');
});

test('the custom id save no longer swallows its error', () => {
  assert.equal(workerSrc.includes("{ custom_id: profile.customId }); } catch (_) {}"), false);
  assert.ok(workerSrc.includes("{ custom_id: profile.customId });"));
});

test('fields the API does not map are reported, not dropped silently', () => {
  assert.ok(workerSrc.includes('warnDroppedFields'));
  assert.ok(workerSrc.includes("warnDroppedFields('loan application'"));
  assert.ok(workerSrc.includes("warnDroppedFields('registration'"));
});

// ---------- WhatsApp inbound ----------
test('a failed contact upsert leaves the webhook event retryable', () => {
  // Anchor on the webhook loop branch, not the earlier setOptIn guard.
  const anchor = 'if (!contact) {\n      summary.errors += 1;';
  const start = whatsappSrc.indexOf(anchor);
  assert.ok(start > 0, 'the webhook contact failure branch must exist');
  const end = whatsappSrc.indexOf('continue;', start) + 'continue;'.length;
  const branch = whatsappSrc.slice(start, end);
  assert.equal(branch.includes('record('), false, 'recording the event made Meta retries look like duplicates');
  assert.ok(branch.endsWith('continue;'), 'the message must be skipped without marking the event processed');
});

// ---------- schema ----------
test('the OTP and security lookups have indexes', () => {
  for (const index of ['idx_otp_rate_limits_email', 'idx_password_reset_otps_email', 'idx_users_email_lower', 'idx_registrations_role_created']) {
    assert.ok(schemaSql.includes(index), index + ' must exist');
  }
});

test('schema.sql and the WhatsApp migration list the same wa_ indexes', () => {
  const fromMigration = WHATSAPP_INDEX_SQL
    .map((statement) => (statement.match(/idx_wa_[a-z_]+/) || [])[0])
    .filter(Boolean)
    .sort();
  const fromSnapshot = (schemaSql.match(/idx_wa_[a-z_]+/g) || []).sort();
  assert.deepEqual(fromSnapshot, fromMigration, 'the two schema sources must not drift');
});
