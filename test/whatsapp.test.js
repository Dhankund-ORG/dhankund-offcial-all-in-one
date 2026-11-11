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
  describeMessage,
  normalizeInboundMessage,
  payloadHash,
  INBOUND_KINDS,
  serviceWindow,
  describeWindow,
  buildTextPayload,
  buildMediaPayload,
  buildLocationPayload,
  buildContactsPayload,
  buildInteractivePayload,
  buildReactionPayload,
  buildTemplatePayload,
  OUTBOUND_TYPES,
  WINDOW_BOUND_TYPES,
  SERVICE_WINDOW_MS,
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
  assert.deepEqual(parsed.messages, []);
  assert.deepEqual(parsed.statuses, []);
  assert.deepEqual(parsed.errors, []);
  assert.deepEqual(parsed.templateUpdates, []);
  assert.deepEqual(parsed.accountAlerts, []);
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

// ---------- every inbound type ----------

function wrap(messages, extraValue) {
  return {
    object: 'whatsapp_business_account',
    entry: [{ id: 'WABA', changes: [{ field: 'messages', value: Object.assign({
      messaging_product: 'whatsapp',
      metadata: { display_phone_number: '919000000000', phone_number_id: '1234' },
      contacts: [{ profile: { name: 'Ramesh' }, wa_id: '919876543210' }],
      messages: messages,
    }, extraValue || {}) }] }],
  };
}

function firstMessage(payload) {
  return parseWebhook(payload).messages[0];
}

test('every known WhatsApp type is classified and never dropped', () => {
  const cases = [
    ['text', { text: { body: 'hi' } }, 'text', 'hi'],
    ['image', { image: { id: 'm1', mime_type: 'image/jpeg', caption: 'PAN' } }, 'media', 'PAN'],
    ['video', { video: { id: 'm2', mime_type: 'video/mp4', caption: 'video' } }, 'media', 'video'],
    ['audio', { audio: { id: 'm3', mime_type: 'audio/ogg', voice: true } }, 'media', null],
    ['document', { document: { id: 'm4', mime_type: 'application/pdf', filename: 'aadhaar.pdf' } }, 'media', 'aadhaar.pdf'],
    ['sticker', { sticker: { id: 'm5', mime_type: 'image/webp', animated: true } }, 'media', null],
    ['location', { location: { latitude: 26.8, longitude: 80.9, name: 'Office', address: 'Lucknow' } }, 'location', null],
    ['contacts', { contacts: [{ name: { formatted_name: 'Sita Devi' }, phones: [{ phone: '+919812345678' }] }] }, 'contacts', null],
    ['button', { button: { text: 'Yes', payload: 'yes_1' } }, 'button', 'Yes'],
    ['interactive', { interactive: { button_reply: { id: 'b1', title: 'Track loan' } } }, 'interactive', 'Track loan'],
    ['order', { order: { catalog_id: 'cat1', text: 'order', product_items: [{ product_retailer_id: 'p1', quantity: 2, item_price: 100, currency: 'INR' }] } }, 'order', null],
    ['system', { system: { type: 'customer_changed_number', body: 'Number changed', new_wa_id: '919800000000' } }, 'system', 'Number changed'],
    ['poll', { poll: { question: 'Which loan?', options: [{ name: 'Home' }, { name: 'Car' }], selectable_options_count: 1 } }, 'poll', null],
    ['poll_update', { poll_update: {} }, 'poll', null],
    ['reaction', { reaction: { emoji: '👍', message_id: 'wamid.x' } }, 'reaction', null],
    ['template', { template: { name: 'hello_world', language: { code: 'en' } } }, 'template', null],
    ['unsupported', { unsupported: {} }, 'unsupported', null],
    ['something_new', { something_new: { a: 1 } }, 'unknown', null],
  ];

  for (const [type, body, kind, text] of cases) {
    const payload = wrap([Object.assign({ from: '919876543210', id: 'wamid.' + type, timestamp: '1700000000', type: type }, body)]);
    const m = firstMessage(payload);
    assert.equal(m.type, type, type + ' keeps its type');
    assert.equal(m.kind, kind, type + ' maps to kind ' + kind);
    if (text !== null) assert.equal(m.text, text, type + ' text');
    assert.ok(m.raw, type + ' keeps the raw payload');
  }
});

test('media messages expose id, mime, filename and voice flag', () => {
  const audio = firstMessage(wrap([{ from: '919876543210', id: 'wamid.a', timestamp: '1700000000', type: 'audio', audio: { id: 'm3', mime_type: 'audio/ogg', voice: true } }]));
  assert.equal(audio.mediaId, 'm3');
  assert.equal(audio.voice, true);

  const doc = firstMessage(wrap([{ from: '919876543210', id: 'wamid.d', timestamp: '1700000000', type: 'document', document: { id: 'm4', mime_type: 'application/pdf', filename: 'kyc.pdf' } }]));
  assert.equal(doc.mediaFilename, 'kyc.pdf');
});

test('location messages keep coordinates and address', () => {
  const m = firstMessage(wrap([{ from: '919876543210', id: 'wamid.l', timestamp: '1700000000', type: 'location', location: { latitude: 26.85, longitude: 80.95, name: 'Head office', address: 'Lucknow, UP', url: 'https://maps.google.com/x' } }]));
  assert.equal(m.latitude, 26.85);
  assert.equal(m.longitude, 80.95);
  assert.equal(m.locationName, 'Head office');
  assert.equal(m.locationAddress, 'Lucknow, UP');
  assert.equal(m.locationUrl, 'https://maps.google.com/x');
});

test('contact cards are unpacked', () => {
  const m = firstMessage(wrap([{ from: '919876543210', id: 'wamid.c', timestamp: '1700000000', type: 'contacts', contacts: [{ name: { formatted_name: 'Sita Devi' }, phones: [{ phone: '+919812345678', type: 'CELL' }], emails: [{ email: 'sita@example.com' }], org: { company: 'Dhankund', title: 'Partner' } }] }]));
  assert.equal(m.contacts.length, 1);
  assert.equal(m.contacts[0].name, 'Sita Devi');
  assert.equal(m.contacts[0].phones[0].phone, '+919812345678');
  assert.equal(m.contacts[0].emails[0], 'sita@example.com');
  assert.equal(m.contacts[0].organization, 'Dhankund');
});

test('interactive flow replies and list replies are captured', () => {
  const list = firstMessage(wrap([{ from: '919876543210', id: 'wamid.i1', timestamp: '1700000000', type: 'interactive', interactive: { list_reply: { id: 'row_2', title: 'Home loan', description: '9.1%' } } }]));
  assert.equal(list.interactiveId, 'row_2');
  assert.equal(list.interactiveTitle, 'Home loan');

  const flow = firstMessage(wrap([{ from: '919876543210', id: 'wamid.i2', timestamp: '1700000000', type: 'interactive', interactive: { nfm_reply: { flow_token: 'tok', response_json: '{"a":1}' } } }]));
  assert.equal(flow.flowToken, 'tok');
  assert.equal(flow.flowResponse, '{"a":1}');
});

test('reactions point at the message they belong to', () => {
  const m = firstMessage(wrap([{ from: '919876543210', id: 'wamid.r', timestamp: '1700000000', type: 'reaction', reaction: { emoji: '🙏', message_id: 'wamid.original' } }]));
  assert.equal(m.reactionEmoji, '🙏');
  assert.equal(m.reactionTo, 'wamid.original');
});

test('orders and polls keep their structured payload', () => {
  const order = firstMessage(wrap([{ from: '919876543210', id: 'wamid.o', timestamp: '1700000000', type: 'order', order: { catalog_id: 'c1', text: 'two items', product_items: [{ product_retailer_id: 'sku1', quantity: 2, item_price: 500, currency: 'INR' }] } }]));
  assert.equal(order.order.catalogId, 'c1');
  assert.equal(order.order.productItems[0].quantity, 2);
  assert.equal(order.order.productItems[0].currency, 'INR');

  const poll = firstMessage(wrap([{ from: '919876543210', id: 'wamid.p', timestamp: '1700000000', type: 'poll', poll: { question: 'Which loan?', options: [{ name: 'Home' }, { name: 'Car' }], selectable_options_count: 1 } }]));
  assert.equal(poll.poll.question, 'Which loan?');
  assert.deepEqual(poll.poll.options, ['Home', 'Car']);
});

test('forwarded, quoted and referral context survives', () => {
  const m = firstMessage(wrap([{ from: '919876543210', id: 'wamid.f', timestamp: '1700000000', type: 'text', text: { body: 'forwarded text' }, context: { id: 'wamid.parent', forwarded: true, frequently_forwarded: true, referral: { source_url: 'https://fb.me/x' } } }]));
  assert.equal(m.replyTo, 'wamid.parent');
  assert.equal(m.forwarded, true);
  assert.equal(m.frequentlyForwarded, true);
  assert.equal(m.referral.source_url, 'https://fb.me/x');
});

test('template status updates are picked up for the cache', () => {
  const payload = {
    entry: [{ changes: [{ field: 'message_template_status_update', value: { event: 'APPROVED', message_template_name: 'loan_status_update', message_template_language: 'hi', reason: null } }] }],
  };
  const parsed = parseWebhook(payload);
  assert.equal(parsed.templateUpdates.length, 1);
  assert.equal(parsed.templateUpdates[0].event, 'APPROVED');
  assert.equal(parsed.templateUpdates[0].language, 'hi');
  assert.equal(parsed.messages.length, 0);
});

test('statuses carry pricing, conversation and error details', () => {
  const parsed = parseWebhook(wrap([], {
    messages: [],
    statuses: [{
      id: 'wamid.s', status: 'failed', timestamp: '1700000002', recipient_id: '919876543210',
      conversation: { id: 'conv1', category: 'marketing', expiration_timestamp: '1700100000' },
      pricing: { billable: true, pricing_model: 'PMP', category: 'marketing' },
      errors: [{ code: 131047, title: 'Re-engagement', message: 'Window closed' }],
    }],
  }));
  const s = parsed.statuses[0];
  assert.equal(s.status, 'failed');
  assert.equal(s.conversationCategory, 'marketing');
  assert.equal(s.pricingCategory, 'marketing');
  assert.equal(s.billable, true);
  assert.equal(s.errorCode, '131047');
  assert.equal(s.errorTitle, 'Re-engagement');
});

test('describeMessage gives the thread list a readable line', () => {
  assert.equal(describeMessage({ text: 'hello', kind: 'text' }), 'hello');
  assert.equal(describeMessage({ kind: 'media', type: 'image', mediaFilename: null }), '[image]');
  assert.equal(describeMessage({ kind: 'media', type: 'document', mediaFilename: 'kyc.pdf' }), '[document] kyc.pdf');
  assert.equal(describeMessage({ type: 'unsupported', kind: 'unsupported' }), '[unsupported]');
});

test('payloadHash is stable for retries and different for edits', async () => {
  const a = await payloadHash({ id: 'x', text: 'one' });
  const b = await payloadHash({ id: 'x', text: 'one' });
  const c = await payloadHash({ id: 'x', text: 'two' });
  assert.equal(a, b);
  assert.notEqual(a, c);
  assert.equal(a.length, 32);
});

test('every INBOUND_KINDS entry maps to a known kind', () => {
  const allowed = ['text', 'reaction', 'media', 'location', 'contacts', 'button', 'interactive', 'order', 'system', 'poll', 'template', 'unsupported', 'unknown'];
  for (const type of Object.keys(INBOUND_KINDS)) {
    assert.ok(allowed.indexOf(INBOUND_KINDS[type]) >= 0, type + ' -> ' + INBOUND_KINDS[type]);
  }
});

// ---------- service window and outbound payloads ----------

test('service window is open for 24 hours after the last inbound message', () => {
  const now = new Date('2026-11-11T10:00:00.000Z');
  const open = serviceWindow('2026-11-11T02:00:00.000Z', now);
  assert.equal(open.open, true);
  assert.equal(open.reason, 'open');
  assert.equal(open.expiresAt, '2026-11-12T02:00:00.000Z');
  assert.equal(open.remainingSeconds, 16 * 3600);

  const closed = serviceWindow('2026-11-09T02:00:00.000Z', now);
  assert.equal(closed.open, false);
  assert.equal(closed.reason, 'window_expired');
  assert.equal(closed.remainingSeconds, 0);
});

test('service window handles contacts who never wrote in', () => {
  const w = serviceWindow(null);
  assert.equal(w.open, false);
  assert.equal(w.reason, 'no_inbound_message');
  assert.match(describeWindow(w), /never messaged/);
});

test('window expires exactly 24 hours later', () => {
  const last = new Date('2026-11-10T12:00:00.000Z');
  const justBefore = new Date(last.getTime() + SERVICE_WINDOW_MS - 1000);
  const justAfter = new Date(last.getTime() + SERVICE_WINDOW_MS + 1000);
  assert.equal(serviceWindow(last.toISOString(), justBefore).open, true);
  assert.equal(serviceWindow(last.toISOString(), justAfter).open, false);
});

test('describeWindow explains what to do next', () => {
  const open = describeWindow(serviceWindow(new Date().toISOString()));
  assert.match(open, /Service window open/);
  const closed = describeWindow(serviceWindow('2020-01-01T00:00:00.000Z'));
  assert.match(closed, /24-hour service window is closed/);
  assert.match(closed, /template/);
});

test('text payload validates length and keeps the recipient clean', () => {
  const payload = buildTextPayload('+919876543210', ' Namaste ', { previewUrl: true });
  assert.equal(payload.to, '919876543210');
  assert.equal(payload.text.body, 'Namaste');
  assert.equal(payload.text.preview_url, true);
  assert.throws(function () { buildTextPayload('+919876543210', ''); }, WhatsappError);
  assert.throws(function () { buildTextPayload('+919876543210', 'x'.repeat(4097)); }, WhatsappError);
});

test('media payload covers image, video, audio, document and sticker', () => {
  for (const type of ['image', 'video', 'audio', 'document', 'sticker']) {
    const payload = buildMediaPayload('+919876543210', { type: type, mediaId: 'mid', caption: 'cap', filename: 'a.pdf' });
    assert.equal(payload.type, type);
    assert.equal(payload[type].id, 'mid');
  }
  const doc = buildMediaPayload('+919876543210', { type: 'document', mediaId: 'mid', filename: 'kyc.pdf' });
  assert.equal(doc.document.filename, 'kyc.pdf');
  const audio = buildMediaPayload('+919876543210', { type: 'audio', mediaId: 'mid', caption: 'ignored' });
  assert.equal(audio.audio.caption, undefined);
  assert.throws(function () { buildMediaPayload('+919876543210', { type: 'image' }); }, WhatsappError);
  assert.throws(function () { buildMediaPayload('+919876543210', { type: 'hologram', mediaId: 'x' }); }, WhatsappError);
});

test('location and contact payloads are built correctly', () => {
  const loc = buildLocationPayload('+919876543210', { latitude: 26.85, longitude: 80.95, name: 'Office', address: 'Lucknow' });
  assert.equal(loc.location.latitude, 26.85);
  assert.equal(loc.location.name, 'Office');
  assert.throws(function () { buildLocationPayload('+919876543210', {}); }, WhatsappError);

  const card = buildContactsPayload('+919876543210', { name: 'Sita Devi', phone: '+919812345678', organization: 'Dhankund', emails: ['sita@example.com'] });
  assert.equal(card.contacts[0].name.formatted_name, 'Sita Devi');
  assert.equal(card.contacts[0].phones[0].phone, '+919812345678');
  assert.equal(card.contacts[0].org.company, 'Dhankund');
  assert.throws(function () { buildContactsPayload('+919876543210', [{ name: 'A' }, { name: 'B' }]); }, WhatsappError);
});

test('interactive payloads cover buttons, lists and flows', () => {
  const buttons = buildInteractivePayload('+919876543210', {
    body: 'Kya karna hai?',
    buttons: [{ id: 'track', title: 'Track loan' }, { id: 'call', title: 'Call me' }],
  });
  assert.equal(buttons.interactive.type, 'button');
  assert.equal(buttons.interactive.action.buttons.length, 2);
  assert.equal(buttons.interactive.action.buttons[0].reply.id, 'track');

  const list = buildInteractivePayload('+919876543210', {
    kind: 'list',
    body: 'Loan chunein',
    buttonText: 'Choose',
    sections: [{ title: 'Loans', rows: [{ id: 'home', title: 'Home loan', description: '9.1%' }] }],
  });
  assert.equal(list.interactive.type, 'list');
  assert.equal(list.interactive.action.sections[0].rows[0].id, 'home');

  const flow = buildInteractivePayload('+919876543210', { kind: 'flow', body: 'Apply', flowId: '123', cta: 'Start' });
  assert.equal(flow.interactive.type, 'flow');
  assert.equal(flow.interactive.action.parameters.flow_id, '123');

  assert.throws(function () { buildInteractivePayload('+919876543210', { body: 'x', buttons: [] }); }, WhatsappError);
  assert.throws(function () { buildInteractivePayload('+919876543210', { body: 'x', buttons: [{ title: 'a' }, { title: 'b' }, { title: 'c' }, { title: 'd' }] }); }, WhatsappError);
});

test('reaction and template payloads are built correctly', () => {
  const reaction = buildReactionPayload('+919876543210', { messageId: 'wamid.1', emoji: '👍' });
  assert.equal(reaction.type, 'reaction');
  assert.equal(reaction.reaction.message_id, 'wamid.1');
  assert.throws(function () { buildReactionPayload('+919876543210', {}); }, WhatsappError);

  const template = buildTemplatePayload('+919876543210', { name: 'loan_status', language: 'hi', bodyParams: ['Ramesh'] });
  assert.equal(template.type, 'template');
  assert.equal(template.template.language.code, 'hi');
  assert.equal(template.template.components[0].parameters[0].text, 'Ramesh');
});

test('every outbound type is either window-bound or a template', () => {
  assert.ok(OUTBOUND_TYPES.indexOf('template') >= 0);
  for (const type of OUTBOUND_TYPES) {
    if (type === 'template') continue;
    assert.ok(WINDOW_BOUND_TYPES.indexOf(type) >= 0, type + ' must need an open window');
  }
  assert.equal(WINDOW_BOUND_TYPES.indexOf('template'), -1);
});

// ---------- database migration ----------

import { WHATSAPP_SCHEMA_SQL, WHATSAPP_MESSAGE_COLUMNS, WHATSAPP_CONTACT_COLUMNS } from '../worker/whatsapp_schema.js';

function tableBlock(sql, table) {
  const start = sql.indexOf('CREATE TABLE IF NOT EXISTS ' + table);
  if (start < 0) return '';
  const end = sql.indexOf(');', start);
  return sql.slice(start, end);
}

test('schema creates every WhatsApp table', () => {
  for (const table of ['wa_contacts', 'wa_messages', 'wa_templates', 'wa_broadcasts', 'wa_broadcast_recipients', 'wa_webhook_events', 'wa_settings', 'wa_alerts']) {
    assert.ok(WHATSAPP_SCHEMA_SQL.includes('CREATE TABLE IF NOT EXISTS ' + table), table + ' must be created');
  }
});

test('every migration column already exists in the create-table statement', () => {
  const messages = tableBlock(WHATSAPP_SCHEMA_SQL, 'wa_messages');
  for (const [column] of WHATSAPP_MESSAGE_COLUMNS) {
    assert.ok(new RegExp('\\b' + column + '\\b').test(messages), 'wa_messages.' + column + ' missing from the create statement');
  }
  const contacts = tableBlock(WHATSAPP_SCHEMA_SQL, 'wa_contacts');
  for (const [column] of WHATSAPP_CONTACT_COLUMNS) {
    assert.ok(new RegExp('\\b' + column + '\\b').test(contacts), 'wa_contacts.' + column + ' missing from the create statement');
  }
});

test('schema is additive: it never drops or alters an existing table', () => {
  assert.equal(/DROP\s+TABLE/i.test(WHATSAPP_SCHEMA_SQL), false);
  assert.equal(/ALTER\s+TABLE/i.test(WHATSAPP_SCHEMA_SQL), false);
  assert.equal(/DELETE\s+FROM/i.test(WHATSAPP_SCHEMA_SQL), false);
});

test('indexes are declared for the queries the inbox runs', () => {
  for (const index of ['idx_wa_messages_phone', 'idx_wa_recipients_broadcast', 'idx_wa_contacts_optin', 'idx_wa_templates_name']) {
    assert.ok(WHATSAPP_SCHEMA_SQL.includes(index), index + ' must exist');
  }
});
