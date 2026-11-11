// WhatsApp Cloud API client, webhook verification and media helpers.
// Cloudflare Workers only: fetch + Web Crypto + R2. No third-party SDK, no BSP.
//
// Every function takes `env` (the Worker env) and reads:
//   WHATSAPP_ACCESS_TOKEN        permanent System User token
//   WHATSAPP_PHONE_NUMBER_ID     the number messages are sent from
//   WHATSAPP_BUSINESS_ACCOUNT_ID WABA id (templates)
//   WHATSAPP_VERIFY_TOKEN        webhook challenge token
//   WHATSAPP_APP_SECRET          Meta app secret (X-Hub-Signature-256)
//   WHATSAPP_API_VERSION         optional, defaults to v21.0

export const DEFAULT_GRAPH_VERSION = 'v21.0';
export const GRAPH_BASE = 'https://graph.facebook.com';
export const MAX_MEDIA_BYTES = 25 * 1024 * 1024; // Worker memory guard
export const OPT_OUT_KEYWORDS = ['stop', 'unsubscribe', 'opt out', 'optout', 'band karo', 'बंद', 'रोकें', 'मत भेजो'];

export class WhatsappError extends Error {
  constructor(message, status, code, title, retryable) {
    super(message);
    this.name = 'WhatsappError';
    this.status = status || 400;
    this.code = code == null ? null : code;
    this.title = title || null;
    this.retryable = !!retryable;
  }
}

// Meta error codes we actually hit in production, with an operator-readable reason.
const ERROR_HINTS = {
  100: 'Invalid parameter sent to the Graph API.',
  190: 'The WhatsApp access token is invalid or expired. Rotate WHATSAPP_ACCESS_TOKEN.',
  368: 'The WhatsApp Business Account is temporarily blocked for policy violations.',
  80007: 'Cloud API rate limit reached. Retry with backoff.',
  130429: 'Cloud API throughput limit reached. Retry with backoff.',
  131026: 'Message undeliverable: the number is not on WhatsApp or has blocked the business.',
  131047: 'The 24-hour customer service window is closed. Send an approved template instead.',
  131051: 'Unsupported message type for this number.',
  131056: 'Too many messages to the same number in a short time. Slow the batch down.',
  132000: 'Template parameter mismatch: the number of variables does not match the approved template.',
  132001: 'Template does not exist in this language. Create or sync the template first.',
  132005: 'Template is paused or disabled by Meta.',
  132007: 'Template violates the WhatsApp Business policy.',
  132012: 'Template parameter format mismatch (for example a URL button variable).',
  132015: 'Template is paused due to low quality. Review the content before resuming.',
  133010: 'The phone number is not registered on the Cloud API.',
  133016: 'The phone number is in a restricted state.',
};

const RETRYABLE_CODES = new Set([80007, 130429, 131056, 1, 2]);

export function mapMetaError(code, subcode) {
  const key = Number(code);
  const hint = ERROR_HINTS[key] || (subcode ? 'WhatsApp API subcode ' + subcode : 'WhatsApp API error.');
  return {
    code: Number.isFinite(key) ? key : null,
    subcode: subcode == null ? null : Number(subcode),
    title: ERROR_HINTS[key] ? 'WhatsApp API' : 'WhatsApp API error',
    hint,
    retryable: RETRYABLE_CODES.has(key),
  };
}

export function whatsappConfig(env) {
  return {
    token: !!env.WHATSAPP_ACCESS_TOKEN,
    phoneNumberId: env.WHATSAPP_PHONE_NUMBER_ID || '',
    wabaId: env.WHATSAPP_BUSINESS_ACCOUNT_ID || '',
    verifyToken: !!env.WHATSAPP_VERIFY_TOKEN,
    appSecret: !!env.WHATSAPP_APP_SECRET,
    pathSecret: !!env.WHATSAPP_WEBHOOK_PATH_SECRET,
    apiVersion: env.WHATSAPP_API_VERSION || DEFAULT_GRAPH_VERSION,
  };
}

export function isWhatsappConfigured(env) {
  const c = whatsappConfig(env);
  return c.token && c.phoneNumberId;
}

export function assertConfigured(env) {
  const c = whatsappConfig(env);
  const missing = [];
  if (!c.token) missing.push('WHATSAPP_ACCESS_TOKEN');
  if (!c.phoneNumberId) missing.push('WHATSAPP_PHONE_NUMBER_ID');
  if (missing.length) {
    throw new WhatsappError('WhatsApp is not configured. Missing: ' + missing.join(', '), 503);
  }
}

function sleep(ms) {
  return new Promise(function (resolve) { setTimeout(resolve, ms); });
}

function backoffMs(attempt) {
  return Math.min(4000, 300 * Math.pow(2, attempt));
}

// One place for every Graph API call: auth header, query, retries, error mapping.
export async function graphFetch(env, path, options) {
  const opts = options || {};
  assertConfigured(env);
  const version = opts.version || env.WHATSAPP_API_VERSION || DEFAULT_GRAPH_VERSION;
  const raw = String(path || '').replace(/^\/+/, '');
  const url = new URL(/^https?:\/\//.test(raw) ? raw : GRAPH_BASE + '/' + version + '/' + raw);

  if (opts.query) {
    for (const key of Object.keys(opts.query)) {
      const value = opts.query[key];
      if (value !== undefined && value !== null && value !== '') url.searchParams.set(key, String(value));
    }
  }

  const headers = Object.assign({ Authorization: 'Bearer ' + env.WHATSAPP_ACCESS_TOKEN }, opts.headers || {});
  let body;
  if (opts.form) {
    body = opts.form; // FormData: let fetch set the boundary
  } else if (opts.body !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(opts.body);
  }

  const maxRetries = opts.retries === undefined ? 2 : opts.retries;
  let attempt = 0;

  for (;;) {
    let res;
    try {
      res = await fetch(url.toString(), { method: (opts.method || 'GET').toUpperCase(), headers, body });
    } catch (err) {
      if (attempt < maxRetries) { await sleep(backoffMs(++attempt)); continue; }
      throw new WhatsappError('Could not reach WhatsApp: ' + (err && err.message ? err.message : 'network error'), 502);
    }

    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch (_) { data = { raw: text }; }

    if (res.ok) return data;

    const err = (data && data.error) || {};
    const mapped = mapMetaError(err.code, err.error_subcode);
    if ((mapped.retryable || res.status === 429 || res.status >= 500) && attempt < maxRetries) {
      await sleep(backoffMs(++attempt));
      continue;
    }
    // Upstream auth/limit problems are ours, not the caller's: report as 502 so the
    // CRM shows "WhatsApp side" instead of blaming the operator's input.
    const status = res.status === 400 || res.status === 404 ? 400 : 502;
    throw new WhatsappError(mapped.hint, status, mapped.code, err.title || mapped.title, mapped.retryable);
  }
}

// ---------- phone numbers ----------

export function normalizePhone(raw, defaultCountry) {
  const country = defaultCountry || '91';
  if (raw === null || raw === undefined) return null;
  let s = String(raw).trim();
  if (!s) return null;
  const hadPlus = s.charAt(0) === '+';
  s = s.replace(/[^\d]/g, '');
  if (!s) return null;
  if (s.indexOf('00') === 0) s = s.slice(2);
  if (!hadPlus) {
    if (s.length === 11 && s.charAt(0) === '0') s = country + s.slice(1);
    else if (s.length === 10) s = country + s;
  }
  if (s.length < 8 || s.length > 15) return null;
  if (s.charAt(0) === '0') return null;
  // Indian mobiles: 91 + 10 digits starting 6-9
  if (s.indexOf('91') === 0 && s.length === 12 && !/^[6-9]/.test(s.slice(2))) return null;
  return '+' + s;
}

export function normalizePhoneOrThrow(raw, field) {
  const phone = normalizePhone(raw);
  if (!phone) throw new WhatsappError('Invalid phone number' + (field ? ' in ' + field : '') + ': ' + String(raw || '').slice(0, 20), 400);
  return phone;
}

export function maskPhone(phone) {
  const s = String(phone || '');
  if (s.length <= 5) return '***';
  return s.slice(0, 3) + '******' + s.slice(-4);
}

// ---------- webhook security ----------

function hexToBytes(hex) {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.substr(i * 2, 2), 16);
  return out;
}

function constantTimeEqual(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

export async function computeSignature(secret, body) {
  const bytes = typeof body === 'string' ? new TextEncoder().encode(body) : new Uint8Array(body);
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, bytes));
  let hex = '';
  for (let i = 0; i < sig.length; i++) hex += sig[i].toString(16).padStart(2, '0');
  return 'sha256=' + hex;
}

export async function verifyWebhookSignature(env, rawBody, signatureHeader) {
  const secret = env.WHATSAPP_APP_SECRET;
  if (!secret) return false;
  const header = String(signatureHeader || '').trim();
  if (header.indexOf('sha256=') !== 0) return false;
  const provided = header.slice(7).toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(provided)) return false;
  const expected = (await computeSignature(secret, rawBody)).slice(7);
  return constantTimeEqual(hexToBytes(expected), hexToBytes(provided));
}

export async function payloadHash(value) {
  const text = typeof value === 'string' ? value : JSON.stringify(value);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text)));
  let hex = '';
  for (let i = 0; i < digest.length; i++) hex += digest[i].toString(16).padStart(2, '0');
  return hex.slice(0, 32);
}

// Optional extra lock: the callback URL itself carries a random segment,
// so even a leaked verify token cannot be used to POST fake events.
export function checkWebhookPathSecret(env, provided) {
  const secret = env.WHATSAPP_WEBHOOK_PATH_SECRET;
  if (!secret) return true;
  return String(provided || '') === String(secret);
}

export function checkVerifyChallenge(env, mode, token, challenge) {
  if (mode !== 'subscribe') return null;
  if (!env.WHATSAPP_VERIFY_TOKEN) return null;
  if (String(token || '') !== String(env.WHATSAPP_VERIFY_TOKEN)) return null;
  return challenge == null ? '' : String(challenge);
}

// ---------- webhook payload ----------

// Every inbound type the Cloud API can deliver. Anything Meta adds later falls
// into 'unknown' and is still stored, never dropped.
export const INBOUND_KINDS = {
  text: 'text',
  reaction: 'reaction',
  image: 'media',
  video: 'media',
  audio: 'media',
  document: 'media',
  sticker: 'media',
  location: 'location',
  contacts: 'contacts',
  button: 'button',
  interactive: 'interactive',
  order: 'order',
  system: 'system',
  poll: 'poll',
  poll_update: 'poll',
  template: 'template',
  unsupported: 'unsupported',
  unknown: 'unknown',
};

const MEDIA_TYPES = ['image', 'video', 'audio', 'document', 'sticker'];

export function parseWebhook(payload) {
  const messages = [];
  const statuses = [];
  const errors = [];
  const templateUpdates = [];
  const qualityUpdates = [];
  const accountAlerts = [];
  const fields = new Set();

  if (!payload || !Array.isArray(payload.entry)) {
    return { messages, statuses, errors, templateUpdates, qualityUpdates, accountAlerts, fields: [] };
  }

  for (const entry of payload.entry) {
    const changes = Array.isArray(entry.changes) ? entry.changes : [];
    for (const change of changes) {
      const field = change && change.field ? String(change.field) : 'messages';
      fields.add(field);
      const value = change && change.value ? change.value : {};
      const metadata = value.metadata || {};

      if (field === 'message_template_status_update') {
        templateUpdates.push({
          event: value.event || null,
          name: value.message_template_name || null,
          language: value.message_template_language || null,
          reason: value.reason || null,
          message: value.message || null,
        });
        continue;
      }
      if (field === 'message_template_quality_update') {
        templateUpdates.push({
          event: 'QUALITY_UPDATE',
          name: value.message_template_name || null,
          language: value.message_template_language || null,
          quality: value.new_quality_score || null,
          reason: value.previous_quality_score ? 'previous ' + value.previous_quality_score : null,
        });
        continue;
      }
      if (field === 'phone_number_quality_update') {
        qualityUpdates.push({
          displayPhoneNumber: value.display_phone_number || null,
          event: value.event || null,
          currentLimit: value.current_limit || null,
        });
        continue;
      }
      if (field === 'account_alerts' || field === 'account_update') {
        accountAlerts.push(value);
        continue;
      }

      const contact = (value.contacts && value.contacts[0]) || null;
      const contactContext = {
        profileName: contact && contact.profile ? contact.profile.name || null : null,
        waId: contact ? contact.wa_id || null : null,
        metadata: metadata,
      };

      for (const m of (value.messages || [])) {
        messages.push(normalizeInboundMessage(m, contactContext));
      }

      for (const s of (value.statuses || [])) {
        statuses.push(normalizeStatus(s, metadata));
      }

      for (const e of (value.errors || [])) {
        errors.push({
          code: e.code == null ? null : String(e.code),
          title: e.title || null,
          message: e.message || null,
          details: e.error_data ? e.error_data.details || null : null,
        });
      }

      // A message that failed validation can arrive without a `messages` entry.
      if (value.message_echoes) {
        for (const m of value.message_echoes) messages.push(normalizeInboundMessage(m, contactContext));
      }
    }
  }

  return { messages, statuses, errors, templateUpdates, qualityUpdates, accountAlerts, fields: Array.from(fields) };
}

function normalizeStatus(s, metadata) {
  const err = (s.errors && s.errors[0]) || null;
  return {
    waMessageId: s.id || null,
    status: s.status || 'unknown',
    timestamp: s.timestamp ? new Date(Number(s.timestamp) * 1000).toISOString() : null,
    recipient: s.recipient_id ? normalizePhone(s.recipient_id) || s.recipient_id : null,
    conversationCategory: s.conversation ? s.conversation.category || null : null,
    conversationId: s.conversation ? s.conversation.id || null : null,
    conversationExpiration: s.conversation && s.conversation.expiration_timestamp
      ? new Date(Number(s.conversation.expiration_timestamp) * 1000).toISOString()
      : null,
    pricingCategory: s.pricing ? s.pricing.category || null : null,
    pricingModel: s.pricing ? s.pricing.pricing_model || null : null,
    billable: s.pricing ? !!s.pricing.billable : null,
    errorCode: err ? String(err.code) : null,
    errorTitle: err ? err.title || null : null,
    errorMessage: err ? err.message || null : null,
    errorDetails: err && err.error_data ? err.error_data.details || null : null,
    phoneNumberId: metadata && metadata.phone_number_id ? String(metadata.phone_number_id) : null,
    raw: s,
  };
}

// Full, lossless normalisation of one inbound message. Every field the CRM may
// want is lifted out; the untouched payload is kept in `raw` as well.
export function normalizeInboundMessage(m, ctx) {
  const context = m.context || {};
  const type = String(m.type || 'unknown');
  const kind = INBOUND_KINDS[type] || 'unknown';

  const out = {
    waMessageId: m.id || null,
    from: normalizePhone(m.from || (ctx && ctx.waId)) || (m.from ? '+' + String(m.from).replace(/\D/g, '') : null),
    profileName: ctx ? ctx.profileName || null : null,
    timestamp: m.timestamp ? new Date(Number(m.timestamp) * 1000).toISOString() : new Date().toISOString(),
    type: type,
    kind: kind,

    text: null,
    caption: null,

    mediaId: null,
    mediaMime: null,
    mediaFilename: null,
    mediaSha256: null,
    mediaAnimated: null,
    voice: false,

    latitude: null,
    longitude: null,
    locationName: null,
    locationAddress: null,
    locationUrl: null,

    contacts: [],
    interactiveId: null,
    interactiveTitle: null,
    flowToken: null,
    flowResponse: null,
    buttonPayload: null,

    reactionEmoji: null,
    reactionTo: null,

    templateName: null,
    templateLanguage: null,

    systemType: null,
    systemNewWaId: null,
    systemBody: null,

    order: null,
    poll: null,

    replyTo: context.id || null,
    forwarded: !!context.forwarded,
    frequentlyForwarded: !!context.frequently_forwarded,
    expiration: context.expiration || null,
    referral: context.referral || null,
    errors: Array.isArray(m.errors) ? m.errors.map(function (e) {
      return { code: e.code == null ? null : String(e.code), title: e.title || null, message: e.message || null };
    }) : [],

    raw: m,
  };

  switch (type) {
    case 'text':
      out.text = (m.text && m.text.body) || '';
      break;

    case 'reaction':
      out.reactionEmoji = m.reaction ? m.reaction.emoji || '' : '';
      out.reactionTo = m.reaction ? m.reaction.message_id || null : null;
      out.text = out.reactionEmoji ? 'Reacted ' + out.reactionEmoji : 'Removed a reaction';
      break;

    case 'image':
    case 'video':
    case 'audio':
    case 'document':
    case 'sticker': {
      const media = m[type] || {};
      out.mediaId = media.id || null;
      out.mediaMime = media.mime_type || null;
      out.mediaSha256 = media.sha256 || null;
      out.mediaFilename = media.filename || null;
      out.mediaAnimated = media.animated === undefined ? null : !!media.animated;
      out.voice = type === 'audio' ? !!media.voice : false;
      out.caption = media.caption || null;
      out.text = media.caption || media.filename || '[' + type + ']';
      break;
    }

    case 'location': {
      const loc = m.location || {};
      out.latitude = loc.latitude == null ? null : Number(loc.latitude);
      out.longitude = loc.longitude == null ? null : Number(loc.longitude);
      out.locationName = loc.name || null;
      out.locationAddress = loc.address || null;
      out.locationUrl = loc.url || null;
      out.text = '[location]' + (loc.name ? ' ' + loc.name : '') + (loc.address ? ' — ' + loc.address : '');
      break;
    }

    case 'contacts':
      out.contacts = (Array.isArray(m.contacts) ? m.contacts : []).map(function (c) {
        return {
          name: c.name ? c.name.formatted_name || [c.name.first_name, c.name.last_name].filter(Boolean).join(' ') : null,
          phones: (c.phones || []).map(function (p) { return { phone: p.phone || null, type: p.type || null, waId: p.wa_id || null }; }),
          emails: (c.emails || []).map(function (e) { return e.email || null; }).filter(Boolean),
          organization: c.org ? c.org.company || null : null,
          title: c.org ? c.org.title || null : null,
          urls: (c.urls || []).map(function (u) { return u.url || null; }).filter(Boolean),
          addresses: (c.addresses || []).map(function (a) { return a.full_address || null; }).filter(Boolean),
        };
      });
      out.text = '[contact] ' + out.contacts.map(function (c) { return c.name || (c.phones[0] && c.phones[0].phone) || ''; }).filter(Boolean).join(', ');
      break;

    case 'button':
      out.buttonPayload = m.button ? m.button.payload || null : null;
      out.interactiveId = out.buttonPayload;
      out.text = m.button ? m.button.text || '' : '';
      break;

    case 'interactive': {
      const i = m.interactive || {};
      if (i.button_reply) {
        out.interactiveId = i.button_reply.id || null;
        out.interactiveTitle = i.button_reply.title || null;
        out.text = i.button_reply.title || '';
      } else if (i.list_reply) {
        out.interactiveId = i.list_reply.id || null;
        out.interactiveTitle = i.list_reply.title || null;
        out.text = i.list_reply.title || (i.list_reply.description || '');
      } else if (i.nfm_reply) {
        out.flowToken = i.nfm_reply.flow_token || null;
        out.flowResponse = i.nfm_reply.response_json || null;
        out.text = '[flow response]';
      } else {
        out.text = '[interactive]';
      }
      break;
    }

    case 'order': {
      const o = m.order || {};
      out.order = {
        catalogId: o.catalog_id || null,
        text: o.text || null,
        productItems: (o.product_items || []).map(function (p) {
          return {
            productRetailerId: p.product_retailer_id || null,
            quantity: p.quantity == null ? null : Number(p.quantity),
            itemPrice: p.item_price == null ? null : Number(p.item_price),
            currency: p.currency || null,
          };
        }),
      };
      out.text = '[order] ' + (o.text || (out.order.productItems.length + ' item(s)'));
      break;
    }

    case 'system': {
      const s = m.system || {};
      out.systemType = s.type || null;
      out.systemNewWaId = s.new_wa_id || null;
      out.systemBody = s.body || null;
      out.text = s.body || '[system ' + (s.type || 'event') + ']';
      break;
    }

    case 'poll': {
      const p = m.poll || {};
      out.poll = {
        question: p.question || null,
        options: (p.options || []).map(function (o) { return o.name || o; }),
        selectableCount: p.selectable_options_count == null ? null : Number(p.selectable_options_count),
      };
      out.text = '[poll] ' + (out.poll.question || '');
      break;
    }

    case 'poll_update':
      out.text = '[poll update]';
      break;

    case 'template':
      out.templateName = m.template ? m.template.name || null : null;
      out.templateLanguage = m.template && m.template.language ? m.template.language.code || null : null;
      out.text = '[template] ' + (out.templateName || '');
      break;

    case 'unsupported':
      out.text = '[unsupported message]';
      break;

    default:
      // Unknown type: keep the payload, describe it plainly, never drop it.
      out.text = '[unsupported: ' + type + ']';
      out.kind = 'unknown';
      break;
  }

  return out;
}

// Short, human line for the thread list and notifications.
export function describeMessage(message) {
  const m = message || {};
  if (m.text) return String(m.text).slice(0, 200);
  if (m.kind === 'media') return '[' + m.type + ']' + (m.mediaFilename ? ' ' + m.mediaFilename : '');
  return '[' + (m.type || 'message') + ']';
}

export function isOptOutMessage(text) {
  const t = String(text || '').trim().toLowerCase();
  if (!t) return false;
  return OPT_OUT_KEYWORDS.some(function (k) { return t === k || t.indexOf(k) === 0; });
}

// ---------- sending ----------

function toRecipient(to) {
  const phone = normalizePhoneOrThrow(to, 'recipient');
  return phone.replace(/^\+/, '');
}

export async function sendText(env, to, body, options) {
  const opts = options || {};
  const text = String(body || '').trim();
  if (!text) throw new WhatsappError('Message text is empty', 400);
  if (text.length > 4096) throw new WhatsappError('WhatsApp text limit is 4096 characters', 400);
  const payload = {
    messaging_product: 'whatsapp',
    recipient_type: 'individual',
    to: toRecipient(to),
    type: 'text',
    text: { preview_url: !!opts.previewUrl, body: text },
  };
  if (opts.replyTo) payload.context = { message_id: opts.replyTo };
  return graphFetch(env, env.WHATSAPP_PHONE_NUMBER_ID + '/messages', { method: 'POST', body: payload });
}

export async function sendTemplate(env, to, template) {
  const t = template || {};
  if (!t.name) throw new WhatsappError('Template name is required', 400);
  const payload = {
    messaging_product: 'whatsapp',
    recipient_type: 'individual',
    to: toRecipient(to),
    type: 'template',
    template: {
      name: String(t.name),
      language: { code: String(t.language || 'en') },
    },
  };
  const components = t.components || buildTemplateComponents(t);
  if (components && components.length) payload.template.components = components;
  return graphFetch(env, env.WHATSAPP_PHONE_NUMBER_ID + '/messages', { method: 'POST', body: payload });
}

export async function sendMedia(env, to, media) {
  const m = media || {};
  const type = m.type || 'image';
  if (['image', 'video', 'audio', 'document', 'sticker'].indexOf(type) < 0) {
    throw new WhatsappError('Unsupported media type: ' + type, 400);
  }
  if (!m.mediaId && !m.link) throw new WhatsappError('Media needs either mediaId or a public link', 400);
  const mediaObject = {};
  if (m.mediaId) mediaObject.id = m.mediaId;
  else mediaObject.link = m.link;
  if (m.caption && type !== 'audio' && type !== 'sticker') mediaObject.caption = String(m.caption);
  if (m.filename && type === 'document') mediaObject.filename = String(m.filename);

  const payload = {
    messaging_product: 'whatsapp',
    recipient_type: 'individual',
    to: toRecipient(to),
    type: type,
  };
  payload[type] = mediaObject;
  if (m.replyTo) payload.context = { message_id: m.replyTo };
  return graphFetch(env, env.WHATSAPP_PHONE_NUMBER_ID + '/messages', { method: 'POST', body: payload });
}

export async function markMessageRead(env, waMessageId) {
  if (!waMessageId) throw new WhatsappError('waMessageId is required', 400);
  return graphFetch(env, env.WHATSAPP_PHONE_NUMBER_ID + '/messages', {
    method: 'POST',
    body: { messaging_product: 'whatsapp', status: 'read', message_id: String(waMessageId) },
  });
}

// Body/header variables for an approved template.
export function buildTemplateComponents(input) {
  const src = input || {};
  const components = [];
  const headerParams = src.headerParams || [];
  const bodyParams = src.bodyParams || [];
  const buttonParams = src.buttonParams || [];

  if (headerParams.length) {
    components.push({ type: 'header', parameters: headerParams.map(textParam) });
  }
  if (bodyParams.length) {
    components.push({ type: 'body', parameters: bodyParams.map(textParam) });
  }
  if (buttonParams.length) {
    components.push({
      type: 'button',
      sub_type: src.buttonSubType || 'url',
      index: String(src.buttonIndex == null ? 0 : src.buttonIndex),
      parameters: buttonParams.map(textParam),
    });
  }
  return components;
}

function textParam(value) {
  if (value && typeof value === 'object') return value;
  return { type: 'text', text: String(value == null ? '' : value) };
}

export function extractMessageId(response) {
  return response && response.messages && response.messages[0] ? response.messages[0].id : null;
}

// ---------- media ----------

export async function uploadMediaToMeta(env, bytes, mimeType, filename) {
  assertConfigured(env);
  const form = new FormData();
  form.append('messaging_product', 'whatsapp');
  form.append('type', mimeType || 'application/octet-stream');
  const blob = new Blob([bytes], { type: mimeType || 'application/octet-stream' });
  form.append('file', blob, filename || 'upload');
  const data = await graphFetch(env, env.WHATSAPP_PHONE_NUMBER_ID + '/media', { method: 'POST', form: form });
  return data && data.id ? data.id : null;
}

export async function getMediaInfo(env, mediaId) {
  if (!mediaId) throw new WhatsappError('mediaId is required', 400);
  return graphFetch(env, String(mediaId));
}

export async function downloadMedia(env, mediaId, maxBytes) {
  assertConfigured(env);
  const info = await getMediaInfo(env, mediaId);
  const limit = maxBytes || MAX_MEDIA_BYTES;
  if (info && info.file_size && Number(info.file_size) > limit) {
    throw new WhatsappError('Media is larger than the ' + Math.round(limit / (1024 * 1024)) + ' MB worker limit', 413);
  }
  const res = await fetch(info.url, { headers: { Authorization: 'Bearer ' + env.WHATSAPP_ACCESS_TOKEN } });
  if (!res.ok) throw new WhatsappError('Could not download media from WhatsApp (HTTP ' + res.status + ')', 502);
  const buffer = await res.arrayBuffer();
  if (buffer.byteLength > limit) throw new WhatsappError('Media is larger than the worker limit', 413);
  return {
    bytes: new Uint8Array(buffer),
    mimeType: info.mime_type || res.headers.get('content-type') || 'application/octet-stream',
    size: buffer.byteLength,
    sha256: info.sha256 || null,
  };
}

export function mediaExtension(mimeType, fallback) {
  const map = {
    'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp',
    'video/mp4': 'mp4', 'video/3gpp': '3gp',
    'audio/aac': 'aac', 'audio/mp4': 'm4a', 'audio/mpeg': 'mp3', 'audio/amr': 'amr', 'audio/ogg': 'ogg',
    'application/pdf': 'pdf',
  };
  const clean = String(mimeType || '').toLowerCase().split(';')[0].trim();
  return map[clean] || fallback || 'bin';
}
