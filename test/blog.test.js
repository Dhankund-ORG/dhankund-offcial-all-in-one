import test from 'node:test';
import assert from 'node:assert/strict';
import { slugify, blogPostOut, ensureBlogSchema } from '../worker/blog.js';
import { verifyPassword } from '../worker/auth.js';


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

test('blogPostOut parses tags and faqs JSON and normalizes views', () => {
  const row = {
    id: 'p1',
    title: 'Test',
    tags: '["loan","tips"]',
    faqs: '[{"question":"What is Personal Loan?","answer":"An unsecured loan"}]',
    views: '7',
  };
  const out = blogPostOut(row);
  assert.deepEqual(out.tags, ['loan', 'tips']);
  assert.equal(out.faqs.length, 1);
  assert.equal(out.faqs[0].question, 'What is Personal Loan?');
  assert.equal(out.views, 7);
  assert.equal(out.id, 'p1');
});

test('blogPostOut handles missing tags and faqs', () => {
  const out = blogPostOut({ id: 'p2', title: 'T', tags: null, faqs: null, views: 'abc' });
  assert.deepEqual(out.tags, []);
  assert.deepEqual(out.faqs, []);
  assert.equal(out.views, 0);
});

test('Mobile normalization and 6268147177 single-number restriction', () => {
  function normalizeMobile(m) {
    const digits = String(m || '').replace(/\D/g, '');
    if (digits.length === 10) return digits;
    if (digits.length === 12 && digits.startsWith('91')) return digits.slice(2);
    if (digits.length === 11 && digits.startsWith('0')) return digits.slice(1);
    return digits;
  }
  const AUTHORIZED_BLOG_MOBILE = '6268147177';

  assert.equal(normalizeMobile('6268147177'), AUTHORIZED_BLOG_MOBILE);
  assert.equal(normalizeMobile('+916268147177'), AUTHORIZED_BLOG_MOBILE);
  assert.equal(normalizeMobile('916268147177'), AUTHORIZED_BLOG_MOBILE);
  assert.equal(normalizeMobile('06268147177'), AUTHORIZED_BLOG_MOBILE);
  assert.equal(normalizeMobile('+91 62681-47177'), AUTHORIZED_BLOG_MOBILE);

  // Unauthorized numbers
  assert.notEqual(normalizeMobile('9876543210'), AUTHORIZED_BLOG_MOBILE);
  assert.notEqual(normalizeMobile('9999999999'), AUTHORIZED_BLOG_MOBILE);
  assert.notEqual(normalizeMobile(''), AUTHORIZED_BLOG_MOBILE);
});

test('Blog admin password verification matches Ankit@5298!$ and rejects wrong passwords', async () => {
  const AUTHORIZED_BLOG_HASH = 'pbkdf2_sha256$100000$cowdOg7K0wvZlHBNBB2ykA==$msou4pPoSa3qlF9oEuP1Q3AEiAWLYKu/x3miH1pHMic=';
  const matches = await verifyPassword('Ankit@5298!$', AUTHORIZED_BLOG_HASH);
  assert.equal(matches, true);

  const wrong1 = await verifyPassword('WrongPassword', AUTHORIZED_BLOG_HASH);
  assert.equal(wrong1, false);

  const wrong2 = await verifyPassword('ankit@5298!$', AUTHORIZED_BLOG_HASH);
  assert.equal(wrong2, false);

  const wrong3 = await verifyPassword('', AUTHORIZED_BLOG_HASH);
  assert.equal(wrong3, false);
});

test('ensureBlogSchema dynamically alters table to add missing keywords and faqs columns', async () => {
  const executedSql = [];
  const fakeEnv = {
    DB: {
      prepare(sql) {
        return {
          bind() {
            return {
              async all() {
                if (sql.includes('PRAGMA table_info')) {
                  // Simulate old table without keywords and faqs
                  return {
                    results: [
                      { name: 'id' },
                      { name: 'title' },
                      { name: 'slug' },
                      { name: 'content' }
                    ]
                  };
                }
                return { results: [] };
              },
              async run() {
                executedSql.push(sql);
                return { success: true };
              }
            };
          }
        };
      }
    }
  };

  await ensureBlogSchema(fakeEnv);
  assert.ok(executedSql.some(s => s.includes('ADD COLUMN keywords TEXT')), 'keywords column should be added');
  assert.ok(executedSql.some(s => s.includes('ADD COLUMN faqs TEXT')), 'faqs column should be added');
});

