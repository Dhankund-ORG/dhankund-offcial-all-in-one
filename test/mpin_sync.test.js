import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const workerSrc = readFileSync(join(root, 'worker.js'), 'utf8');
const schemaSql = readFileSync(join(root, 'schema.sql'), 'utf8');
const apiService = readFileSync(join(root, 'DSA-Banker-flutter app/lib/services/api_service.dart'), 'utf8');
const profileScreen = readFileSync(join(root, 'DSA-Banker-flutter app/lib/presentation/shared/my_profile_screen.dart'), 'utf8');

const route = (name) => {
  const start = workerSrc.indexOf(name);
  assert.ok(start > 0, name + ' must exist');
  return workerSrc.slice(start, workerSrc.indexOf('\napp.', start + 10));
};

test('the MPIN is stored hashed in D1, never as typed', () => {
  const setRoute = route("app.post('/api/v1/me/mpin'");
  assert.ok(setRoute.includes('hashPassword(mpin)'), 'the PIN must be hashed before it is stored');
  assert.equal(/mpin_hash: mpin\b/.test(setRoute), false, 'the raw PIN must never be written to the column');
  assert.ok(setRoute.includes('MPIN_PATTERN'), 'only 4-6 digit PINs are accepted');
});

test('verifying the MPIN compares hashes and counts failures', () => {
  const verifyRoute = route("app.post('/api/v1/me/mpin/verify'");
  assert.ok(verifyRoute.includes('verifyPassword(mpin, row.mpin_hash)'));
  assert.ok(verifyRoute.includes('recordAuthFailure'), 'a wrong PIN must feed the IP guard like a wrong password');
});

test('the profile says whether a PIN exists', () => {
  assert.ok(workerSrc.includes('mpinSet: !!row.mpin_hash'));
});

test('the column exists for new and existing databases', () => {
  assert.ok(schemaSql.includes('mpin_hash TEXT'), 'fresh databases need the column');
  assert.ok(workerSrc.includes("ALTER TABLE users ADD COLUMN mpin_hash TEXT"), 'existing databases need the migration');
});

test('the app saves the PIN through the API instead of plain SharedPreferences', () => {
  assert.ok(apiService.includes("'/api/v1/me/mpin'"), 'the client must call the API');
  assert.ok(apiService.includes('setMpin'), 'setMpin must exist');
  assert.ok(apiService.includes('verifyMpin'), 'verifyMpin must exist');
  assert.equal(profileScreen.includes("setString('app_mpin'"), false, 'the plain-text local copy must be gone');
  assert.ok(profileScreen.includes('setMpin('), 'the screen must save through the API');
});
