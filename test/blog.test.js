import test from 'node:test';
import assert from 'node:assert/strict';
import { slugify, blogPostOut } from '../worker/blog.js';

test('slugify produces clean English slugs', () => {
  assert.equal(slugify('Loan Tips for 2026'), 'loan-tips-for-2026');
  assert.equal(slugify('  Home   Loans!  '), 'home-loans');
  assert.equal(slugify('What is a DSA?'), 'what-is-a-dsa');
  assert.equal(slugify('Business & Finance'), 'business-finance');
  assert.equal(slugify("It's a Test"), 'its-a-test');
});

test('slugify keeps Devanagari letters and strips punctuation', () => {
  assert.equal(slugify('लोन टिप्स 2026'), 'लोन-टिप्स-2026');
  assert.equal(slugify('होम लोन!'), 'होम-लोन');
  assert.equal(slugify('DSA गाइड'), 'dsa-गाइड');
});

test('slugify handles edge cases', () => {
  assert.equal(slugify(''), '');
  assert.equal(slugify('   '), '');
  assert.equal(slugify('!!!'), '');
  assert.equal(slugify('123'), '123');
  assert.equal(slugify('---'), '');
});

test('blogPostOut parses tags JSON and normalizes views', () => {
  const row = {
    id: 'p1',
    title: 'Test',
    tags: '["loan","tips"]',
    views: '7',
  };
  const out = blogPostOut(row);
  assert.deepEqual(out.tags, ['loan', 'tips']);
  assert.equal(out.views, 7);
  assert.equal(out.id, 'p1');
});

test('blogPostOut handles missing tags and non-numeric views', () => {
  const out = blogPostOut({ id: 'p2', title: 'T', tags: null, views: 'abc' });
  assert.deepEqual(out.tags, []);
  assert.equal(out.views, 0);
});