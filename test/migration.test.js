import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {
  md5Hex,
  encodeObjectKey,
  isAllowedSignedUrl,
  accountFrom,
  bucketFrom,
  sanitizeMessage,
  r2CopyBatch,
  buildD1Diff,
} from '../worker/cloudflare.js';

test('md5Hex matches known MD5 vectors', () => {
  assert.equal(md5Hex(new Uint8Array(0)), 'd41d8cd98f00b204e9800998ecf8427e');
  assert.equal(md5Hex(new TextEncoder().encode('abc')), '900150983cd24fb0d6963f7d28e17f72');
  assert.equal(
    md5Hex(new TextEncoder().encode('The quick brown fox jumps over the lazy dog')),
    '9e107d9d372bb6826bd81d3542a419d6',
  );
});

test('md5Hex matches node:crypto across block boundaries', () => {
  const lengths = [1, 3, 55, 56, 57, 63, 64, 65, 127, 128, 129, 1000, 4096];
  for (const length of lengths) {
    const bytes = new Uint8Array(length);
    for (let i = 0; i < length; i++) bytes[i] = (i * 31 + length) % 256;
    const expected = crypto.createHash('md5').update(bytes).digest('hex');
    assert.equal(md5Hex(bytes), expected, 'length ' + length);
  }
});

test('encodeObjectKey keeps slashes but encodes reserved characters', () => {
  assert.equal(encodeObjectKey('kyc/docs/file name.pdf'), 'kyc/docs/file%20name.pdf');
  assert.equal(encodeObjectKey('a/b+c?d#e.txt'), 'a/b%2Bc%3Fd%23e.txt');
  assert.equal(encodeObjectKey('नमस्ते/फाइल.pdf'), '%E0%A4%A8%E0%A4%AE%E0%A4%B8%E0%A5%8D%E0%A4%A4%E0%A5%87/%E0%A4%AB%E0%A4%BE%E0%A4%87%E0%A4%B2.pdf');
});

test('isAllowedSignedUrl only accepts Cloudflare HTTPS hosts', () => {
  assert.equal(isAllowedSignedUrl('https://abc.r2.cloudflarestorage.com/bucket/file.sql'), true);
  assert.equal(isAllowedSignedUrl('https://example.cloudflare.com/file.sql'), true);
  assert.equal(isAllowedSignedUrl('https://pub-123.r2.dev/file.sql'), true);
  assert.equal(isAllowedSignedUrl('https://worker.example.workers.dev/file.sql'), true);
  assert.equal(isAllowedSignedUrl('http://abc.r2.cloudflarestorage.com/file.sql'), false);
  assert.equal(isAllowedSignedUrl('https://abc.r2.cloudflarestorage.com.evil.example/file.sql'), false);
  assert.equal(isAllowedSignedUrl('not a url'), false);
  assert.equal(isAllowedSignedUrl(''), false);
});

test('accountFrom validates account ID and token', () => {
  const account = accountFrom({
    account_id: '0123456789abcdef0123456789abcdef',
    api_token: 'abcdefghijklmnopqrstuvwxyz0123456789',
  }, 'Source account');
  assert.deepEqual(account, {
    account_id: '0123456789abcdef0123456789abcdef',
    api_token: 'abcdefghijklmnopqrstuvwxyz0123456789',
  });

  assert.throws(() => accountFrom({ account_id: 'short', api_token: 'x'.repeat(40) }), /invalid Cloudflare account ID/);
  assert.throws(() => accountFrom({ account_id: '0123456789abcdef0123456789abcdef', api_token: 'short' }), /API token is required/);
  assert.throws(() => accountFrom(null, 'Destination account'), /Destination account: invalid Cloudflare account ID/);
});

test('bucketFrom validates R2 bucket names', () => {
  assert.equal(bucketFrom('dhankund-storage'), 'dhankund-storage');
  assert.equal(bucketFrom('abc'), 'abc');
  assert.throws(() => bucketFrom('ab'), /invalid R2 bucket name/);
  assert.throws(() => bucketFrom('UPPERCASE'), /invalid R2 bucket name/);
  assert.throws(() => bucketFrom('bad_bucket'), /invalid R2 bucket name/);
  assert.throws(() => bucketFrom(''), /invalid R2 bucket name/);
});

test('sanitizeMessage redacts credentials', () => {
  const message = sanitizeMessage('failed with Bearer abcdefghijklmnopqrstuvwxyz0123456789');
  assert.equal(message.includes('abcdefghijklmnopqrstuvwxyz0123456789'), false);
  assert.match(message, /Bearer \*\*\*/);
  assert.equal(sanitizeMessage('api_token: abcdefghijklmnopqrstuvwxyz0123456789').includes('abcdefghijklmnopqrstuvwxyz'), false);
  assert.equal(sanitizeMessage(undefined), 'Cloudflare request failed');
});

test('r2CopyBatch resumes a partially processed page and skips oversized objects', async () => {
  const source = { account_id: '0'.repeat(32), api_token: 't'.repeat(40) };
  const destination = { account_id: '1'.repeat(32), api_token: 'd'.repeat(40) };
  const pages = {
    '': {
      objects: [
        { key: 'a.txt', size: 5 },
        { key: 'b.txt', size: 7 },
        { key: 'c.txt', size: 9 },
        { key: 'huge.bin', size: 60 * 1024 * 1024 },
      ],
      is_truncated: true,
      cursor: 'page-2',
    },
    'page-2': {
      objects: [{ key: 'd.txt', size: 11 }],
      is_truncated: false,
      cursor: null,
    },
  };
  const uploads = [];
  const originalFetch = globalThis.fetch;

  globalThis.fetch = async (url, options = {}) => {
    const target = new URL(String(url));
    const method = options.method || 'GET';
    if (method === 'GET' && target.pathname.endsWith('/objects')) {
      const cursor = target.searchParams.get('cursor') || '';
      const page = pages[cursor];
      assert.ok(page, 'unexpected cursor ' + cursor);
      return new Response(JSON.stringify({
        success: true,
        result: page.objects,
        result_info: { cursor: page.cursor, is_truncated: page.is_truncated, per_page: 50 },
      }), { status: 200, headers: { 'content-type': 'application/json' } });
    }
    if (method === 'GET') {
      const key = decodeURIComponent(target.pathname.split('/').pop());
      const object = Object.values(pages).flatMap((page) => page.objects).find((item) => item.key === key);
      assert.ok(object, 'unexpected object download ' + key);
      return new Response(new Uint8Array(object.size), {
        status: 200,
        headers: { 'content-type': 'application/octet-stream' },
      });
    }
    if (method === 'PUT') {
      uploads.push(decodeURIComponent(target.pathname.split('/').pop()));
      return new Response(JSON.stringify({ success: true, result: {} }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    }
    throw new Error('unexpected request ' + method + ' ' + target);
  };

  try {
    const first = await r2CopyBatch(source, 'source-bucket', destination, 'destination-bucket', { limit: 2 });
    assert.equal(first.copied, 2);
    assert.equal(first.next_cursor, null);
    assert.equal(first.next_skip, 2);
    assert.equal(first.done, false);

    const second = await r2CopyBatch(source, 'source-bucket', destination, 'destination-bucket', {
      limit: 2,
      skip: first.next_skip,
    });
    assert.equal(second.copied, 1);
    assert.equal(second.skipped, 1);
    assert.equal(second.failed, 0);
    assert.equal(second.oversized.length, 1);
    assert.equal(second.oversized[0].key, 'huge.bin');
    assert.match(second.oversized[0].error, /50 MB per object/);
    assert.equal(second.next_cursor, 'page-2');
    assert.equal(second.next_skip, 0);
    assert.equal(second.done, false);

    const third = await r2CopyBatch(source, 'source-bucket', destination, 'destination-bucket', {
      limit: 2,
      cursor: second.next_cursor,
    });
    assert.equal(third.copied, 1);
    assert.equal(third.done, true);
    assert.deepEqual(uploads, ['a.txt', 'b.txt', 'c.txt', 'd.txt']);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

function schemaObject(name, options = {}) {
  return Object.assign({
    name: name,
    columns: [],
    indexes: [],
    triggers: [],
  }, options);
}

test('buildD1Diff flags missing and extra tables', () => {
  const source = [
    schemaObject('customers', { columns: [{ name: 'id', type: 'INTEGER' }] }),
    schemaObject('loans', { columns: [{ name: 'id', type: 'INTEGER' }] }),
  ];
  const destination = [
    schemaObject('customers', { columns: [{ name: 'id', type: 'INTEGER' }] }),
    schemaObject('old_table', { columns: [{ name: 'id', type: 'INTEGER' }] }),
  ];
  const diff = buildD1Diff(source, destination);
  assert.deepEqual(diff.missing_tables, ['loans']);
  assert.deepEqual(diff.extra_tables, ['old_table']);
  assert.deepEqual(diff.overlapping_tables, ['customers']);
  assert.equal(diff.safe_without_reset, false);
  assert.equal(diff.schema_match, false);
});

test('buildD1Diff flags missing and extra columns', () => {
  const source = [schemaObject('t', {
    columns: [
      { name: 'id', type: 'INTEGER' },
      { name: 'amount', type: 'REAL' },
      { name: 'note', type: 'TEXT' },
    ],
  })];
  const destination = [schemaObject('t', {
    columns: [
      { name: 'id', type: 'INTEGER' },
      { name: 'amount', type: 'REAL' },
      { name: 'legacy', type: 'TEXT' },
    ],
  })];
  const diff = buildD1Diff(source, destination);
  assert.deepEqual(diff.missing_columns, [{ table: 't', columns: ['note'] }]);
  assert.deepEqual(diff.extra_columns, [{ table: 't', columns: ['legacy'] }]);
  assert.equal(diff.safe_without_reset, false);
});

test('buildD1Diff flags type mismatches ignoring case', () => {
  const source = [schemaObject('t', {
    columns: [
      { name: 'id', type: 'INTEGER' },
      { name: 'amount', type: 'REAL' },
      { name: 'note', type: 'TEXT' },
    ],
  })];
  const destination = [schemaObject('t', {
    columns: [
      { name: 'id', type: 'integer' },
      { name: 'amount', type: 'NUMERIC' },
      { name: 'note', type: 'TEXT' },
    ],
  })];
  const diff = buildD1Diff(source, destination);
  assert.equal(diff.type_mismatches.length, 1);
  assert.deepEqual(diff.type_mismatches[0], {
    table: 't',
    column: 'amount',
    source: 'REAL',
    destination: 'NUMERIC',
  });
  assert.equal(diff.schema_match, false);
});

test('buildD1Diff flags column order mismatches for shared columns', () => {
  const source = [schemaObject('t', {
    columns: [
      { name: 'id', type: 'INTEGER' },
      { name: 'amount', type: 'REAL' },
    ],
  })];
  const destination = [schemaObject('t', {
    columns: [
      { name: 'amount', type: 'REAL' },
      { name: 'id', type: 'INTEGER' },
    ],
  })];
  const diff = buildD1Diff(source, destination);
  assert.equal(diff.column_order_mismatches.length, 1);
  assert.deepEqual(diff.column_order_mismatches[0].table, 't');
  assert.deepEqual(diff.column_order_mismatches[0].source, ['id', 'amount']);
  assert.deepEqual(diff.column_order_mismatches[0].destination, ['amount', 'id']);
  assert.equal(diff.safe_without_reset, false);
});

test('buildD1Diff flags missing indexes and triggers', () => {
  const source = [schemaObject('t', {
    columns: [{ name: 'id', type: 'INTEGER' }],
    indexes: ['idx_a', 'idx_b'],
    triggers: ['trg_x'],
  })];
  const destination = [schemaObject('t', {
    columns: [{ name: 'id', type: 'INTEGER' }],
    indexes: ['IDX_B'],
    triggers: [],
  })];
  const diff = buildD1Diff(source, destination);
  assert.deepEqual(diff.missing_indexes, [{ table: 't', indexes: ['idx_a'] }]);
  assert.deepEqual(diff.missing_triggers, [{ table: 't', triggers: ['trg_x'] }]);
});

test('buildD1Diff overlap makes reset required', () => {
  const source = [schemaObject('customers', { columns: [{ name: 'id', type: 'INTEGER' }] })];
  const destination = [schemaObject('customers', { columns: [{ name: 'id', type: 'INTEGER' }] })];
  const diff = buildD1Diff(source, destination);
  assert.deepEqual(diff.overlapping_tables, ['customers']);
  assert.equal(diff.safe_without_reset, false);
  assert.equal(diff.destination_available, true);
});

test('buildD1Diff without destination is safe without reset', () => {
  const source = [schemaObject('customers', { columns: [{ name: 'id', type: 'INTEGER' }] })];
  const diff = buildD1Diff(source, null);
  assert.equal(diff.destination_available, false);
  assert.equal(diff.safe_without_reset, true);
  assert.equal(diff.schema_match, false);
  assert.deepEqual(diff.missing_tables, ['customers']);
  assert.deepEqual(diff.overlapping_tables, []);
});

test('buildD1Diff empty source produces empty diff lists', () => {
  const diff = buildD1Diff([], [schemaObject('legacy', { columns: [{ name: 'id', type: 'INTEGER' }] })]);
  assert.deepEqual(diff.missing_tables, []);
  assert.deepEqual(diff.overlapping_tables, []);
  assert.deepEqual(diff.extra_tables, ['legacy']);
  assert.equal(diff.safe_without_reset, true);
});
