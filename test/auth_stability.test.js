import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const workerSrc = readFileSync(join(root, 'worker.js'), 'utf8');

const loginBlock = (() => {
  const start = workerSrc.indexOf("app.post('/api/v1/auth/login'");
  const end = workerSrc.indexOf("app.get('/api/v1/auth/me'", start);
  return workerSrc.slice(start, end);
})();

test('login picks the row that can actually log in, not an arbitrary duplicate', () => {
  assert.ok(loginBlock.includes('ORDER BY (password_hash IS NOT NULL) DESC'),
    'a row with a password must win over a passwordless duplicate');
  assert.ok(loginBlock.includes("(lower(role) = 'admin') DESC"),
    'an admin row must win over a partner row for the same email');
});

test('the ADMIN_PASSWORD secret never overwrites a password the owner set', () => {
  assert.ok(loginBlock.includes('secretStillOwns'),
    'the secret fallback must be gated');
  assert.ok(loginBlock.includes('!safeJson(user.data, {}).passwordSetByUser'),
    'the gate must read the passwordSetByUser flag');
});

test('a password set from the app or a reset link is marked as owner-set', () => {
  assert.ok(workerSrc.includes('async function markPasswordSetByUser'));
  const resetRoute = workerSrc.slice(workerSrc.indexOf("app.post('/api/v1/auth/reset-password'"));
  const resetBody = resetRoute.slice(0, resetRoute.indexOf('app.post', 10));
  assert.ok(resetBody.includes('markPasswordSetByUser'),
    'reset-password must mark the row so the secret stops overriding it');
  assert.ok(workerSrc.includes('passwordSetByUser: true'),
    'a self-registered account owns its own password');
});

test('approving a registration reuses the existing account for that email', () => {
  const fn = workerSrc.slice(workerSrc.indexOf('async function upsertUserFromRegistration'));
  const body = fn.slice(0, fn.indexOf('\n// ', 10));
  assert.ok(body.includes("lower(email) = lower(?)"),
    'the upsert must look up by email before inserting a second row');
  assert.ok(body.includes('existing.id'),
    'the update must target the row that was found');
});
