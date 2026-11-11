import test from 'node:test';
import assert from 'node:assert/strict';

import {
  normalizePhone,
  maskPhone,
  mapMetaError,
  parseWebhook,
  computeSignature,
  verifyWebhookSignature,
  checkVerifyChallenge,
  checkWebhookPathSecret,
  buildTemplateComponents,
  isOptOutMessage,
  mediaExtension,
  WhatsappError,
} from '../worker/whatsapp.js';
import {
  validateTemplateName,
  buildComponents,
  countVariables,
  renderPreview,
  normalizeLanguage,
  normalizeCategory,
} from '../worker/whatsapp_templates.js';
import { dedupeRecipients, AUDIENCE_SOURCES } from '../worker/whatsapp_audience.js';

test('normalizePhone turns Indian numbers into E.164', () => {
  assert.equal(normalizePhone('9876543210'), '+919876543210');
  assert.equal(normalizePhone('09876543210'), '+919876543210');
  assert.equal(normalizePhone('+91 98765 43210'), '+919876543210');
  assert.equal(normalizePhone('919876543210'), '+919876543210');
  assert.equal(normalizePhone('98765-43210'), '+919876543210');
});

test('normalizePhone keeps international numbers and rejects junk', () => {
  assert.equal(normalizePhone('+14155552671'), '+14155552671');
  assert.equal(normalizePhone('+971501234567'), '+971501234567');
  assert.equal(normalizePhone(''), null);
  assert.equal(normalizePhone(null), null);
  assert.equal(normalizePhone('12345'), null);
  assert.equal(normalizePhone('0123456789'), null);
  assert.equal(normalizePhone('5876543210'), null); // Indian mobile cannot start with 5
  assert.equal(normalizePhone('1234567890123456'), null); // longer than E.164
});

test('maskPhone hides the middle digits in logs', () => {
  assert.equal(maskPhone('+919876543210'), '+91******3210');
  assert.equal(maskPhone('12'), '***');
});

test('mapMetaError explains the codes operators actually meet', () => {
  assert.match(mapMetaError(131047).hint, /24-hour/);
  assert.match(mapMetaError(132000).hint, /parameter mismatch/);
  assert.match(mapMetaError(131026).hint, /undeliverable/);
  assert.equal(mapMetaError(130429).retryable, true);
  assert.equal(mapMetaError(131047).retryable, false);
  assert.equal(mapMetaError(190).code, 190);
});

test('parseWebhook splits messages, statuses and errors', () => {
  const payload = {
    object: 'whatsapp_business_account',
    entry: [{
      id: 'WABA',
      changes: [{
        field: 'messages',
        value: {
          messaging_product: 'whatsapp',
          contacts: [{ profile: { name: 'Ramesh' }, wa_id: '919876543210' }],
          messages: [{
            from: '919876543210',
            id: 'wamid.1',
            timestamp: '1700000000',
            type: 'text',
            text: { body: 'Hello' },
          }],
          statuses: [{
            id: 'wamid.0',
            status: 'delivered',
            timestamp: '1700000001',
            recipient_id: '919876543210',
          }],
        },
      }],
    }],
  };
  const parsed = parseWebhook(payload);
  assert.equal(parsed.messages.length, 1);
  assert.equal(parsed.messages[0].text, 'Hello');
  assert.equal(parsed.messages[0].from, '+919876543210');
  assert.equal(parsed.messages[0].profileName, 'Ramesh');
  assert.equal(parsed.statuses.length, 1);
  assert.equal(parsed.statuses[0].status, 'delivered');
});

test('parseWebhook reads media messages', () => {
  const parsed = parseWebhook({
    entry: [{ changes: [{ value: {
      contacts: [{ profile: { name: 'Sita' }, wa_id: '919812345678' }],
      messages: [{ from: '919812345678', id: 'wamid.2', timestamp: '1700000002', type: 'image', image: { id: 'media-1', mime_type: 'image/jpeg', caption: 'PAN card' } }],
    } }] }],
  });
  assert.equal(parsed.messages[0].type, 'image');
  assert.equal(parsed.messages[0].mediaId, 'media-1');
  assert.equal(parsed.messages[0].caption, 'PAN card');
});

test('parseWebhook tolerates an empty payload', () => {
  const parsed = parseWebhook(null);
  assert.deepEqual(parsed, { messages: [], statuses: [], errors: [] });
});

test('webhook signature is verified with the app secret', async () => {
  const env = { WHATSAPP_APP_SECRET: 'top-secret' };
  const body = JSON.stringify({ hello: 'world' });
  const header = await computeSignature('top-secret', body);

  assert.equal(await verifyWebhookSignature(env, body, header), true);
  assert.equal(await verifyWebhookSignature(env, body + 'x', header), false);
  assert.equal(await verifyWebhookSignature(env, body, 'sha256=deadbeef'), false);
  assert.equal(await verifyWebhookSignature(env, body, ''), false);
  assert.equal(await verifyWebhookSignature({}, body, header), false);
});

test('verify challenge only accepts the configured token', () => {
  const env = { WHATSAPP_VERIFY_TOKEN: 'verify-me' };
  assert.equal(checkVerifyChallenge(env, 'subscribe', 'verify-me', '12345'), '12345');
  assert.equal(checkVerifyChallenge(env, 'subscribe', 'wrong', '12345'), null);
  assert.equal(checkVerifyChallenge(env, 'unsubscribe', 'verify-me', '12345'), null);
  assert.equal(checkVerifyChallenge({}, 'subscribe', 'verify-me', '12345'), null);
});

test('path secret locks the webhook URL when configured', () => {
  assert.equal(checkWebhookPathSecret({}, 'anything'), true);
  assert.equal(checkWebhookPathSecret({ WHATSAPP_WEBHOOK_PATH_SECRET: 'abc' }, 'abc'), true);
  assert.equal(checkWebhookPathSecret({ WHATSAPP_WEBHOOK_PATH_SECRET: 'abc' }, 'xyz'), false);
});

test('buildTemplateComponents builds header, body and button parameters', () => {
  const components = buildTemplateComponents({
    headerParams: ['Dhankund'],
    bodyParams: ['Ramesh', '500000'],
    buttonParams: ['https://crm.dhankund.com/lead/1'],
  });
  assert.equal(components.length, 3);
  assert.deepEqual(components[0], { type: 'header', parameters: [{ type: 'text', text: 'Dhankund' }] });
  assert.equal(components[1].parameters.length, 2);
  assert.equal(components[2].sub_type, 'url');
  assert.equal(components[2].index, '0');
});

test('buildComponents creates a bilingual-ready template definition', () => {
  const components = buildComponents({
    header: { text: 'Dhankund' },
    body: 'नमस्ते {{1}}, आपका लोन {{2}} स्वीकृत हुआ है।',
    footer: 'Dhankund Global Pvt Ltd',
    buttons: [{ type: 'QUICK_REPLY', text: 'धन्यवाद' }],
  });
  assert.equal(components[0].type, 'HEADER');
  assert.equal(components[1].type, 'BODY');
  assert.equal(components[1].example.body_text[0].length, 2);
  assert.equal(components[2].type, 'FOOTER');
  assert.equal(components[3].buttons[0].type, 'QUICK_REPLY');
});

test('buildComponents refuses an empty body', () => {
  assert.throws(function () { buildComponents({ header: { text: 'Hi' } }), WhatsappError });
});

test('countVariables counts distinct placeholders', () => {
  assert.equal(countVariables('Hi {{1}}, your loan {{2}} and {{1}} again'), 2);
  assert.equal(countVariables('No variables here'), 0);
});

test('renderPreview fills placeholders for the CRM preview', () => {
  const components = buildComponents({ body: 'Hello {{1}}, loan {{2}} approved' });
  const preview = renderPreview(components, ['Ramesh', '₹5,00,000']);
  assert.equal(preview.body, 'Hello Ramesh, loan ₹5,00,000 approved');
});

test('template name, language and category are validated', () => {
  assert.equal(validateTemplateName('loan_approved_hi'), 'loan_approved_hi');
  assert.throws(function () { validateTemplateName('Loan Approved'); }, WhatsappError);
  assert.throws(function () { validateTemplateName(''); }, WhatsappError);
  assert.equal(normalizeLanguage('hi'), 'hi');
  assert.throws(function () { normalizeLanguage('fr'); }, WhatsappError);
  assert.equal(normalizeCategory('utility'), 'UTILITY');
  assert.throws(function () { normalizeCategory('spam'); }, WhatsappError);
});

test('dedupeRecipients removes duplicates, bad numbers and opted-out contacts', () => {
  const result = dedupeRecipients([
    { phone: '9876543210', name: 'A', source: 'loans' },
    { phone: '+919876543210', name: 'A duplicate', source: 'referrals' },
    { phone: '12345', name: 'Bad', source: 'loans' },
    { phone: '9812345678', name: 'B', source: 'loans' },
    { phone: '9799999999', name: 'Opted out', source: 'contacts' },
  ], { optOut: ['+919799999999'], optIn: ['+919876543210', '+919812345678'] });

  assert.equal(result.recipients.length, 2);
  assert.equal(result.stats.duplicate, 1);
  assert.equal(result.stats.invalid, 1);
  assert.equal(result.stats.optedOut, 1);
  assert.equal(result.stats.notOptedIn, 0);
});

test('dedupeRecipients enforces consent when required', () => {
  const rows = [{ phone: '9876543210', name: 'A' }, { phone: '9812345678', name: 'B' }];
  const strict = dedupeRecipients(rows, { optIn: ['+919876543210'], requireOptIn: true });
  assert.equal(strict.recipients.length, 1);
  const loose = dedupeRecipients(rows, { optIn: ['+919876543210'], requireOptIn: false });
  assert.equal(loose.recipients.length, 2);
});

test('opt-out keywords are recognised in Hindi and English', () => {
  assert.equal(isOptOutMessage('STOP'), true);
  assert.equal(isOptOutMessage('stop'), true);
  assert.equal(isOptOutMessage('unsubscribe'), true);
  assert.equal(isOptOutMessage('बंद'), true);
  assert.equal(isOptOutMessage('hello there'), false);
  assert.equal(isOptOutMessage(''), false);
});

test('mediaExtension maps mime types to file extensions', () => {
  assert.equal(mediaExtension('image/jpeg'), 'jpg');
  assert.equal(mediaExtension('application/pdf'), 'pdf');
  assert.equal(mediaExtension('audio/ogg; codecs=opus'), 'ogg');
  assert.equal(mediaExtension('application/x-unknown', 'bin'), 'bin');
});

test('every audience source points at real columns', () => {
  const expected = ['registrations', 'loans', 'referrals', 'insurance', 'users', 'contacts'];
  assert.deepEqual(Object.keys(AUDIENCE_SOURCES).sort(), expected.sort());
  for (const key of expected) {
    const def = AUDIENCE_SOURCES[key];
    assert.ok(def.table, key + ' needs a table');
    assert.ok(def.phone, key + ' needs a phone column');
    assert.ok(def.name, key + ' needs a name column');
  }
});
