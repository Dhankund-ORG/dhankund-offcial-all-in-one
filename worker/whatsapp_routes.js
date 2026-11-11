// HTTP surface for the WhatsApp module. Registered from worker.js with two lines,
// so worker.js keeps its own auth helpers and this file stays testable on its own.

import { all, first, run, insertRow, updateRow, nowIso, randomId, safeJson } from './db.js';
import { ensureWhatsappSchema } from './whatsapp_schema.js';
import {
  WhatsappError, whatsappConfig, isWhatsappConfigured, normalizePhone, maskPhone,
  graphFetch, sendText, sendTemplate, sendMedia, markMessageRead,
  verifyWebhookSignature, checkWebhookPathSecret, checkVerifyChallenge,
  parseWebhook, isOptOutMessage, downloadMedia, uploadMediaToMeta,
  mediaExtension, buildTemplateComponents, extractMessageId,
} from './whatsapp.js';
import {
  buildComponents, createTemplate, createTemplatePair, updateTemplate,
  deleteTemplateById, deleteTemplateByName, syncTemplates, listCachedTemplates,
  getCachedTemplate, renderPreview, normalizeLanguage,
} from './whatsapp_templates.js';
import { resolveAudience, audienceSummary, listSources } from './whatsapp_audience.js';
import {
  createBroadcast, processBroadcastBatch, broadcastSummary, listBroadcasts,
  setBroadcastStatus, applyStatusToRecipient, DEFAULT_BATCH_SIZE,
} from './whatsapp_broadcast.js';

const MEDIA_TYPES = ['image', 'video', 'audio', 'document', 'sticker'];

function fail(c, err) {
  if (err instanceof WhatsappError) {
    return c.json({ error: err.message, code: err.code == null ? undefined : err.code }, err.status || 400);
  }
  console.error('whatsapp route error', err && err.message);
  return c.json({ error: 'WhatsApp operation failed. Please try again.' }, 500);
}

function nowMonth() {
  return new Date().toISOString().slice(0, 7);
}

// ---------- contacts ----------

export async function findLeadByPhone(env, phone) {
  const local = String(phone || '').replace(/^\+91/, '').replace(/\D/g, '');
  if (!local) return null;
  const loan = await first(env, "SELECT id, full_name AS name, status FROM loan_applications WHERE mobile_number LIKE ? LIMIT 1", ['%' + local + '%']);
  if (loan) return { kind: 'loan', id: loan.id, name: loan.name, status: loan.status };
  const referral = await first(env, "SELECT id, friend_name AS name, status FROM referrals WHERE friend_mobile LIKE ? LIMIT 1", ['%' + local + '%']);
  if (referral) return { kind: 'referral', id: referral.id, name: referral.name, status: referral.status };
  const registration = await first(env, "SELECT id, name, status, role FROM registrations WHERE mobile LIKE ? LIMIT 1", ['%' + local + '%']);
  if (registration) return { kind: 'registration', id: registration.id, name: registration.name, status: registration.status };
  return null;
}

export async function upsertContact(env, input) {
  const phone = normalizePhone(input.phone);
  if (!phone) return null;
  const now = nowIso();
  const existing = await first(env, 'SELECT * FROM wa_contacts WHERE phone_e164 = ?', [phone]);

  if (existing) {
    const patch = { updated_at: now };
    if (input.profileName && !existing.profile_name) patch.profile_name = input.profileName;
    if (input.name && !existing.name) patch.name = input.name;
    if (input.direction === 'inbound') patch.last_inbound_at = input.at || now;
    if (input.direction === 'outbound') patch.last_outbound_at = input.at || now;
    await updateRow(env, 'wa_contacts', 'id', existing.id, patch);
    return Object.assign({}, existing, patch);
  }

  const lead = await findLeadByPhone(env, phone);
  const row = {
    id: randomId(),
    phone_e164: phone,
    name: input.name || (lead && lead.name) || null,
    profile_name: input.profileName || null,
    source: input.source || (lead ? lead.kind : (input.direction === 'inbound' ? 'inbound' : 'manual')),
    registration_id: lead && lead.kind === 'registration' ? lead.id : null,
    loan_id: lead && lead.kind === 'loan' ? lead.id : null,
    referral_id: lead && lead.kind === 'referral' ? lead.id : null,
    opt_in_status: input.optInStatus || 'unknown',
    opt_in_at: input.optInStatus === 'opted_in' ? now : null,
    opt_out_at: null,
    opt_in_source: input.optInSource || null,
    tags: null,
    notes: null,
    last_inbound_at: input.direction === 'inbound' ? (input.at || now) : null,
    last_outbound_at: input.direction === 'outbound' ? (input.at || now) : null,
    created_at: now,
    updated_at: now,
  };
  await insertRow(env, 'wa_contacts', row);
  return row;
}

async function setOptIn(env, phone, status, source) {
  const contact = await upsertContact(env, { phone: phone, optInStatus: status, optInSource: source });
  if (!contact) throw new WhatsappError('Invalid phone number', 400);
  const now = nowIso();
  await updateRow(env, 'wa_contacts', 'id', contact.id, {
    opt_in_status: status,
    opt_in_at: status === 'opted_in' ? now : contact.opt_in_at || null,
    opt_out_at: status === 'opted_out' ? now : null,
    opt_in_source: source || contact.opt_in_source || null,
    updated_at: now,
  });
  return { phone: contact.phone_e164, opt_in_status: status };
}

// ---------- webhook ----------

export async function handleWebhookEvents(env, parsed, ctx) {
  await ensureWhatsappSchema(env);
  const summary = { messages: 0, statuses: 0, media: 0, optOuts: 0, duplicates: 0, errors: 0 };

  for (const message of parsed.messages || []) {
    if (!message.waMessageId) continue;
    const eventKey = 'msg:' + message.waMessageId;
    const seen = await first(env, 'SELECT id FROM wa_webhook_events WHERE event_id = ?', [eventKey]);
    if (seen) { summary.duplicates += 1; continue; }

    const contact = await upsertContact(env, {
      phone: message.from,
      profileName: message.profileName,
      direction: 'inbound',
      at: message.timestamp,
    });
    if (!contact) continue;

    const inserted = await first(env, 'SELECT id FROM wa_messages WHERE wa_message_id = ?', [message.waMessageId]);
    if (!inserted) {
      await insertRow(env, 'wa_messages', {
        id: randomId(),
        wa_message_id: message.waMessageId,
        phone_e164: contact.phone_e164,
        direction: 'inbound',
        type: message.type,
        template_name: message.templateName,
        template_lang: message.templateLanguage,
        body: message.text,
        caption: message.caption,
        media_id: message.mediaId,
        media_mime: message.mimeType,
        media_r2_key: null,
        media_size: null,
        status: 'received',
        error_code: null,
        error_title: null,
        error_message: null,
        reply_to: message.replyTo,
        broadcast_id: null,
        sent_by: null,
        sent_at: message.timestamp,
        delivered_at: message.timestamp,
        read_at: null,
        created_at: nowIso(),
        raw_json: JSON.stringify(message),
      });
    }

    if (message.mediaId) {
      try {
        const stored = await storeInboundMedia(env, message);
        if (stored) summary.media += 1;
      } catch (err) {
        summary.errors += 1;
        console.error('inbound media failed', message.waMessageId, err && err.message);
      }
    }

    if (isOptOutMessage(message.text)) {
      await setOptIn(env, contact.phone_e164, 'opted_out', 'whatsapp_reply');
      summary.optOuts += 1;
    }

    await insertRow(env, 'wa_webhook_events', {
      id: randomId(), event_id: eventKey, kind: 'message', payload_json: JSON.stringify(message), processed_at: nowIso(),
    });
    summary.messages += 1;

    if (ctx && typeof ctx.notifyAdmins === 'function') {
      try {
        await ctx.notifyAdmins(env, 'New WhatsApp message', (contact.name || maskPhone(contact.phone_e164)) + ': ' + String(message.text || message.type).slice(0, 120));
      } catch (_) { /* notification is best effort */ }
    }
  }

  for (const status of parsed.statuses || []) {
    if (!status.waMessageId) continue;
    const eventKey = 'status:' + status.waMessageId + ':' + status.status;
    const seen = await first(env, 'SELECT id FROM wa_webhook_events WHERE event_id = ?', [eventKey]);
    if (seen) { summary.duplicates += 1; continue; }

    const patch = { status: status.status };
    if (status.status === 'delivered') patch.delivered_at = status.timestamp || nowIso();
    if (status.status === 'read') patch.read_at = status.timestamp || nowIso();
    if (status.status === 'failed') {
      patch.error_code = status.errorCode;
      patch.error_title = status.errorTitle;
      patch.error_message = status.errorMessage;
    }
    await run(env, 'UPDATE wa_messages SET status = ?, delivered_at = COALESCE(?, delivered_at), read_at = COALESCE(?, read_at), error_code = COALESCE(?, error_code), error_title = COALESCE(?, error_title), error_message = COALESCE(?, error_message) WHERE wa_message_id = ?', [
      patch.status, patch.delivered_at || null, patch.read_at || null,
      patch.error_code || null, patch.error_title || null, patch.error_message || null,
      status.waMessageId,
    ]);
    await applyStatusToRecipient(env, status.waMessageId, status.status);

    await insertRow(env, 'wa_webhook_events', {
      id: randomId(), event_id: eventKey, kind: 'status', payload_json: JSON.stringify(status), processed_at: nowIso(),
    });
    summary.statuses += 1;
  }

  return summary;
}

async function storeInboundMedia(env, message) {
  if (!env.R2_BUCKET) return null;
  const media = await downloadMedia(env, message.mediaId);
  const ext = mediaExtension(media.mimeType, message.type === 'document' ? 'bin' : 'jpg');
  const key = 'wa-media/in/' + nowMonth() + '/' + message.waMessageId + '.' + ext;
  await env.R2_BUCKET.put(key, media.bytes, { httpMetadata: { contentType: media.mimeType } });
  await run(env, 'UPDATE wa_messages SET media_r2_key = ?, media_mime = ?, media_size = ? WHERE wa_message_id = ?', [
    key, media.mimeType, media.size, message.waMessageId,
  ]);
  return key;
}

// ---------- routes ----------

export function registerWhatsappRoutes(app, ctx) {
  const auth = ctx.auth;
  const requireAdmin = ctx.requireAdmin;
  const readJson = ctx.readJson;

  // --- public webhook (locked by verify token + HMAC + optional path secret) ---
  const webhookGet = async function (c) {
    if (!checkWebhookPathSecret(c.env, c.req.param('secret'))) return c.json({ error: 'Not found' }, 404);
    const challenge = checkVerifyChallenge(
      c.env,
      c.req.query('hub.mode'),
      c.req.query('hub.verify_token'),
      c.req.query('hub.challenge')
    );
    if (challenge === null) return c.json({ error: 'Verification failed' }, 403);
    return c.text(challenge, 200);
  };

  const webhookPost = async function (c) {
    if (!checkWebhookPathSecret(c.env, c.req.param('secret'))) return c.json({ error: 'Not found' }, 404);
    const raw = await c.req.text();
    const signature = c.req.header('X-Hub-Signature-256') || c.req.header('x-hub-signature-256');
    const valid = await verifyWebhookSignature(c.env, raw, signature);
    if (!valid) return c.json({ error: 'Invalid signature' }, 401);

    let payload;
    try { payload = JSON.parse(raw || '{}'); } catch (_) { return c.json({ error: 'Invalid JSON body' }, 400); }

    const parsed = parseWebhook(payload);
    const work = handleWebhookEvents(c.env, parsed, ctx).catch(function (err) {
      console.error('webhook processing failed', err && err.message);
    });
    try { c.executionCtx.waitUntil(work); } catch (_) { await work; }
    return c.json({ received: true, messages: parsed.messages.length, statuses: parsed.statuses.length });
  };

  app.get('/api/v1/whatsapp/webhook', webhookGet);
  app.get('/api/v1/whatsapp/webhook/:secret', webhookGet);
  app.post('/api/v1/whatsapp/webhook', webhookPost);
  app.post('/api/v1/whatsapp/webhook/:secret', webhookPost);

  // --- diagnostics ---
  app.get('/api/v1/whatsapp/status', requireAdmin, async function (c) {
    await ensureWhatsappSchema(c.env);
    const cfg = whatsappConfig(c.env);
    const contacts = await first(c.env, 'SELECT COUNT(*) AS n FROM wa_contacts');
    const messages = await first(c.env, 'SELECT COUNT(*) AS n FROM wa_messages');
    const templates = await all(c.env, 'SELECT status, COUNT(*) AS n FROM wa_templates GROUP BY status');
    const lastEvent = await first(c.env, 'SELECT processed_at FROM wa_webhook_events ORDER BY processed_at DESC LIMIT 1');
    const pending = await first(c.env, "SELECT COUNT(*) AS n FROM wa_broadcasts WHERE status IN ('queued','running')");
    return c.json({
      configured: isWhatsappConfigured(c.env),
      token: cfg.token,
      phone_number_id: cfg.phoneNumberId ? '…' + String(cfg.phoneNumberId).slice(-4) : null,
      waba_id: cfg.wabaId ? '…' + String(cfg.wabaId).slice(-4) : null,
      webhook: { verify_token: cfg.verifyToken, signature: cfg.appSecret, path_secret: cfg.pathSecret, last_event_at: lastEvent ? lastEvent.processed_at : null },
      api_version: cfg.apiVersion,
      contacts: contacts ? contacts.n : 0,
      messages: messages ? messages.n : 0,
      templates: templates,
      active_broadcasts: pending ? pending.n : 0,
    });
  });

  // --- inbox ---
  app.get('/api/v1/whatsapp/threads', requireAdmin, async function (c) {
    await ensureWhatsappSchema(c.env);
    const search = (c.req.query('search') || '').trim();
    const limit = Math.max(1, Math.min(Number(c.req.query('limit')) || 50, 200));
    const params = [];
    let where = '';
    if (search) {
      where = ' WHERE (c.phone_e164 LIKE ? OR c.name LIKE ? OR c.profile_name LIKE ?)';
      params.push('%' + search + '%', '%' + search + '%', '%' + search + '%');
    }
    const rows = await all(
      c.env,
      'SELECT c.phone_e164 AS phone, c.name, c.profile_name, c.opt_in_status, c.source, c.last_inbound_at, c.last_outbound_at, ' +
      '(SELECT body FROM wa_messages m WHERE m.phone_e164 = c.phone_e164 ORDER BY m.created_at DESC LIMIT 1) AS last_body, ' +
      '(SELECT type FROM wa_messages m WHERE m.phone_e164 = c.phone_e164 ORDER BY m.created_at DESC LIMIT 1) AS last_type, ' +
      '(SELECT created_at FROM wa_messages m WHERE m.phone_e164 = c.phone_e164 ORDER BY m.created_at DESC LIMIT 1) AS last_at, ' +
      "(SELECT COUNT(*) FROM wa_messages m WHERE m.phone_e164 = c.phone_e164 AND m.direction = 'inbound' AND m.read_at IS NULL) AS unread " +
      'FROM wa_contacts c' + where + ' ORDER BY COALESCE(last_at, c.updated_at) DESC LIMIT ' + limit,
      params
    );
    return c.json(rows);
  });

  app.get('/api/v1/whatsapp/messages', requireAdmin, async function (c) {
    await ensureWhatsappSchema(c.env);
    const phone = normalizePhone(c.req.query('phone'));
    if (!phone) return c.json({ error: 'Valid phone query parameter is required' }, 400);
    const limit = Math.max(1, Math.min(Number(c.req.query('limit')) || 100, 300));
    const rows = await all(c.env, 'SELECT * FROM wa_messages WHERE phone_e164 = ? ORDER BY created_at ASC LIMIT ' + limit, [phone]);
    if (c.req.query('mark_read') === '1') {
      await run(c.env, "UPDATE wa_messages SET read_at = COALESCE(read_at, ?) WHERE phone_e164 = ? AND direction = 'inbound'", [nowIso(), phone]);
    }
    return c.json({ phone: phone, messages: rows });
  });

  app.post('/api/v1/whatsapp/mark-read', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      if (b.waMessageId) {
        await markMessageRead(c.env, b.waMessageId);
        await run(c.env, 'UPDATE wa_messages SET read_at = COALESCE(read_at, ?) WHERE wa_message_id = ?', [nowIso(), b.waMessageId]);
        return c.json({ success: true });
      }
      const phone = normalizePhone(b.phone);
      if (!phone) return c.json({ error: 'phone or waMessageId is required' }, 400);
      const last = await first(c.env, "SELECT wa_message_id FROM wa_messages WHERE phone_e164 = ? AND direction = 'inbound' ORDER BY created_at DESC LIMIT 1", [phone]);
      if (last && last.wa_message_id) {
        await markMessageRead(c.env, last.wa_message_id);
        await run(c.env, 'UPDATE wa_messages SET read_at = COALESCE(read_at, ?) WHERE phone_e164 = ?', [nowIso(), phone]);
      }
      return c.json({ success: true });
    } catch (err) { return fail(c, err); }
  });

  // --- sending ---
  app.post('/api/v1/whatsapp/send', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      await ensureWhatsappSchema(c.env);
      const phone = normalizePhone(b.to || b.phone);
      if (!phone) return c.json({ error: 'Valid recipient number is required' }, 400);
      const type = String(b.type || 'text').toLowerCase();
      const user = c.get('user') || {};

      let response;
      let bodyText = b.text || b.body || null;
      let templateName = null;
      let templateLang = null;

      if (type === 'text') {
        response = await sendText(c.env, phone, bodyText, { previewUrl: b.previewUrl, replyTo: b.replyTo });
      } else if (type === 'template') {
        const t = b.template || {};
        templateName = t.name || b.templateName;
        templateLang = t.language || b.templateLang || 'en';
        response = await sendTemplate(c.env, phone, {
          name: templateName,
          language: templateLang,
          components: t.components || buildTemplateComponents({ headerParams: t.headerParams, bodyParams: t.bodyParams, buttonParams: t.buttonParams, buttonIndex: t.buttonIndex, buttonSubType: t.buttonSubType }),
        });
        bodyText = null;
      } else if (MEDIA_TYPES.indexOf(type) >= 0) {
        response = await sendMedia(c.env, phone, { type: type, mediaId: b.mediaId, link: b.link, caption: b.caption, filename: b.filename, replyTo: b.replyTo });
      } else {
        return c.json({ error: 'Unsupported message type: ' + type }, 400);
      }

      const waMessageId = extractMessageId(response);
      await insertRow(c.env, 'wa_messages', {
        id: randomId(),
        wa_message_id: waMessageId,
        phone_e164: phone,
        direction: 'outbound',
        type: type,
        template_name: templateName,
        template_lang: templateLang,
        body: bodyText,
        caption: b.caption || null,
        media_id: b.mediaId || null,
        media_mime: null,
        media_r2_key: b.r2Key || null,
        media_size: null,
        status: 'sent',
        error_code: null,
        error_title: null,
        error_message: null,
        reply_to: b.replyTo || null,
        broadcast_id: null,
        sent_by: user.uid || user.id || null,
        sent_at: nowIso(),
        delivered_at: null,
        read_at: null,
        created_at: nowIso(),
        raw_json: JSON.stringify(response || {}),
      });
      await upsertContact(c.env, { phone: phone, direction: 'outbound' });
      return c.json({ success: true, wa_message_id: waMessageId, to: phone });
    } catch (err) { return fail(c, err); }
  });

  // --- media ---
  app.post('/api/v1/whatsapp/media', requireAdmin, async function (c) {
    try {
      await ensureWhatsappSchema(c.env);
      const contentType = (c.req.header('Content-Type') || '').toLowerCase();
      let bytes;
      let mime;
      let filename;

      if (contentType.indexOf('multipart/form-data') === 0) {
        const form = await c.req.formData();
        const file = form.get('file');
        if (!file || typeof file === 'string') return c.json({ error: 'file field is required' }, 400);
        bytes = new Uint8Array(await file.arrayBuffer());
        mime = file.type || 'application/octet-stream';
        filename = file.name || 'upload';
      } else {
        const query = c.req.query();
        filename = query.filename || 'upload';
        mime = contentType || 'application/octet-stream';
        bytes = new Uint8Array(await c.req.raw.arrayBuffer());
      }

      if (!bytes.length) return c.json({ error: 'Empty file' }, 400);
      if (bytes.length > 25 * 1024 * 1024) return c.json({ error: 'File is larger than 25 MB' }, 413);

      const ext = mediaExtension(mime, 'bin');
      const key = 'wa-media/out/' + nowMonth() + '/' + randomId() + '-' + String(filename).replace(/[^a-zA-Z0-9._-]/g, '_').slice(-60) + (filename.indexOf('.') > -1 ? '' : '.' + ext);
      if (c.env.R2_BUCKET) await c.env.R2_BUCKET.put(key, bytes, { httpMetadata: { contentType: mime } });

      let mediaId = null;
      if (c.req.query('upload') !== '0') {
        try { mediaId = await uploadMediaToMeta(c.env, bytes, mime, filename); } catch (err) { mediaId = null; }
      }
      return c.json({ success: true, r2_key: key, url: '/api/v1/whatsapp/media/' + encodeURIComponent(key), media_id: mediaId, mime: mime, size: bytes.length });
    } catch (err) { return fail(c, err); }
  });

  app.get('/api/v1/whatsapp/media/:key', requireAdmin, async function (c) {
    try {
      const key = decodeURIComponent(c.req.param('key'));
      if (key.indexOf('wa-media/') !== 0) return c.json({ error: 'Not found' }, 404);
      if (!c.env.R2_BUCKET) return c.json({ error: 'R2 bucket is not bound' }, 503);
      const object = await c.env.R2_BUCKET.get(key);
      if (!object) return c.json({ error: 'Not found' }, 404);
      const headers = new Headers();
      headers.set('Content-Type', (object.httpMetadata && object.httpMetadata.contentType) || 'application/octet-stream');
      headers.set('Cache-Control', 'private, max-age=3600');
      return new Response(object.body, { headers: headers });
    } catch (err) { return fail(c, err); }
  });

  // --- templates ---
  app.get('/api/v1/whatsapp/templates', requireAdmin, async function (c) {
    await ensureWhatsappSchema(c.env);
    const rows = await listCachedTemplates(c.env, {
      language: c.req.query('language') || null,
      status: c.req.query('status') || null,
      search: c.req.query('search') || null,
    });
    return c.json(rows);
  });

  app.post('/api/v1/whatsapp/templates/sync', requireAdmin, async function (c) {
    try {
      await ensureWhatsappSchema(c.env);
      const result = await syncTemplates(c.env);
      return c.json(Object.assign({ success: true }, result));
    } catch (err) { return fail(c, err); }
  });

  app.post('/api/v1/whatsapp/templates/preview', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      const components = b.components || buildComponents(b);
      return c.json({ preview: renderPreview(components, b.params || []), components: components });
    } catch (err) { return fail(c, err); }
  });

  app.post('/api/v1/whatsapp/templates', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      await ensureWhatsappSchema(c.env);
      const languages = String(b.language || 'both').toLowerCase();
      if (languages === 'both' || languages === 'all') {
        const result = await createTemplatePair(c.env, {
          name: b.name,
          category: b.category,
          perLanguage: b.perLanguage,
          body: b.body,
          header: b.header,
          footer: b.footer,
          buttons: b.buttons,
          bodyExample: b.bodyExample,
        });
        if (!result.created.length) return c.json({ error: 'Template creation failed for every language', details: result.failed }, 400);
        return c.json(Object.assign({ success: true }, result), 201);
      }
      const result = await createTemplate(c.env, {
        name: b.name,
        language: normalizeLanguage(languages),
        category: b.category,
        components: b.components,
        body: b.body,
        header: b.header,
        footer: b.footer,
        buttons: b.buttons,
        bodyExample: b.bodyExample,
      });
      return c.json(Object.assign({ success: true }, result), 201);
    } catch (err) { return fail(c, err); }
  });

  app.put('/api/v1/whatsapp/templates/:id', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      const result = await updateTemplate(c.env, c.req.param('id'), b);
      return c.json(Object.assign({ success: true }, result));
    } catch (err) { return fail(c, err); }
  });

  app.delete('/api/v1/whatsapp/templates/:id', requireAdmin, async function (c) {
    try {
      const result = await deleteTemplateById(c.env, c.req.param('id'));
      return c.json(Object.assign({ success: true }, result));
    } catch (err) { return fail(c, err); }
  });

  app.delete('/api/v1/whatsapp/templates/by-name/:name', requireAdmin, async function (c) {
    try {
      const result = await deleteTemplateByName(c.env, c.req.param('name'));
      return c.json(Object.assign({ success: true }, result));
    } catch (err) { return fail(c, err); }
  });

  // --- audience ---
  app.get('/api/v1/whatsapp/audience/sources', requireAdmin, async function (c) {
    return c.json({ sources: listSources() });
  });

  app.post('/api/v1/whatsapp/audience/preview', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      await ensureWhatsappSchema(c.env);
      const resolved = await resolveAudience(c.env, b);
      return c.json(audienceSummary(resolved));
    } catch (err) { return fail(c, err); }
  });

  // --- broadcasts ---
  app.get('/api/v1/whatsapp/broadcasts', requireAdmin, async function (c) {
    await ensureWhatsappSchema(c.env);
    return c.json(await listBroadcasts(c.env, c.req.query('limit')));
  });

  app.get('/api/v1/whatsapp/broadcasts/:id', requireAdmin, async function (c) {
    try { return c.json(await broadcastSummary(c.env, c.req.param('id'))); } catch (err) { return fail(c, err); }
  });

  app.post('/api/v1/whatsapp/broadcasts', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      await ensureWhatsappSchema(c.env);
      const user = c.get('user') || {};
      const created = await createBroadcast(c.env, b, { userId: user.uid || user.id || null });
      if (created.dryRun) return c.json(created);

      // Kick the Durable Object when it is bound; otherwise the cron picks it up.
      try {
        if (c.env.WHATSAPP_SENDER && c.env.WHATSAPP_SENDER.idFromName) {
          const id = c.env.WHATSAPP_SENDER.idFromName(created.id);
          const stub = c.env.WHATSAPP_SENDER.get(id);
          c.executionCtx.waitUntil(stub.fetch('https://do/start', { method: 'POST', body: JSON.stringify({ broadcastId: created.id }) }));
        }
      } catch (_) { /* cron fallback */ }

      return c.json(Object.assign({ success: true }, created), 201);
    } catch (err) { return fail(c, err); }
  });

  app.post('/api/v1/whatsapp/broadcasts/:id/tick', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      const result = await processBroadcastBatch(c.env, c.req.param('id'), { limit: b.limit || DEFAULT_BATCH_SIZE });
      return c.json(result);
    } catch (err) { return fail(c, err); }
  });

  app.post('/api/v1/whatsapp/broadcasts/:id/pause', requireAdmin, async function (c) {
    try { return c.json(await setBroadcastStatus(c.env, c.req.param('id'), 'paused')); } catch (err) { return fail(c, err); }
  });

  app.post('/api/v1/whatsapp/broadcasts/:id/resume', requireAdmin, async function (c) {
    try {
      const result = await setBroadcastStatus(c.env, c.req.param('id'), 'running');
      try {
        if (c.env.WHATSAPP_SENDER && c.env.WHATSAPP_SENDER.idFromName) {
          const id = c.env.WHATSAPP_SENDER.idFromName(c.req.param('id'));
          c.executionCtx.waitUntil(c.env.WHATSAPP_SENDER.get(id).fetch('https://do/start', { method: 'POST', body: JSON.stringify({ broadcastId: c.req.param('id') }) }));
        }
      } catch (_) { /* cron fallback */ }
      return c.json(result);
    } catch (err) { return fail(c, err); }
  });

  // --- contacts and consent ---
  app.get('/api/v1/whatsapp/contacts', requireAdmin, async function (c) {
    await ensureWhatsappSchema(c.env);
    const search = (c.req.query('search') || '').trim();
    const status = (c.req.query('opt_in_status') || '').trim();
    const limit = Math.max(1, Math.min(Number(c.req.query('limit')) || 100, 500));
    const where = [];
    const params = [];
    if (search) { where.push('(phone_e164 LIKE ? OR name LIKE ? OR profile_name LIKE ?)'); params.push('%' + search + '%', '%' + search + '%', '%' + search + '%'); }
    if (status) { where.push('opt_in_status = ?'); params.push(status); }
    const rows = await all(c.env, 'SELECT * FROM wa_contacts' + (where.length ? ' WHERE ' + where.join(' AND ') : '') + ' ORDER BY updated_at DESC LIMIT ' + limit, params);
    return c.json(rows);
  });

  app.post('/api/v1/whatsapp/contacts/opt-in', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      await ensureWhatsappSchema(c.env);
      const status = String(b.status || b.opt_in_status || '').toLowerCase();
      if (['opted_in', 'opted_out', 'unknown'].indexOf(status) < 0) {
        return c.json({ error: 'status must be opted_in, opted_out or unknown' }, 400);
      }
      return c.json(Object.assign({ success: true }, await setOptIn(c.env, b.phone, status, b.source || 'crm')));
    } catch (err) { return fail(c, err); }
  });

  // Turn a WhatsApp conversation into a lead the sales team already understands.
  app.post('/api/v1/whatsapp/contacts/:id/convert-lead', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      await ensureWhatsappSchema(c.env);
      const contact = await first(c.env, 'SELECT * FROM wa_contacts WHERE id = ?', [c.req.param('id')]);
      if (!contact) return c.json({ error: 'Contact not found' }, 404);
      if (contact.referral_id) return c.json({ success: true, already_linked: true, referral_id: contact.referral_id });

      const leadId = typeof ctx.formatLeadId === 'function' ? ctx.formatLeadId(new Date(), 1) : String(Date.now());
      const id = randomId();
      await insertRow(c.env, 'referrals', {
        id: id,
        lead_id: leadId,
        referrer_id: 'whatsapp',
        friend_name: contact.name || contact.profile_name || 'WhatsApp Contact',
        friend_mobile: String(contact.phone_e164 || '').replace(/^\+91/, ''),
        friend_email: b.email || null,
        relationship: 'WhatsApp Enquiry',
        loan_type: b.loanType || b.loan_type || 'WhatsApp Lead',
        estimated_amount: b.notes || null,
        document_url: null,
        consent_given: contact.opt_in_status === 'opted_in' ? 1 : 0,
        status: 'Invited',
        created_at: nowIso(),
      });
      await updateRow(c.env, 'wa_contacts', 'id', contact.id, { referral_id: id, source: contact.source || 'whatsapp', updated_at: nowIso() });
      return c.json({ success: true, referral_id: id, lead_id: leadId }, 201);
    } catch (err) { return fail(c, err); }
  });

  // --- settings ---
  app.get('/api/v1/whatsapp/settings', requireAdmin, async function (c) {
    await ensureWhatsappSchema(c.env);
    const rows = await all(c.env, 'SELECT * FROM wa_settings');
    const out = { default_language: 'en', require_opt_in: '1', daily_limit: '1000', business_hours_only: '0' };
    for (const r of rows) out[r.key] = r.value;
    return c.json(out);
  });

  app.put('/api/v1/whatsapp/settings', requireAdmin, async function (c) {
    const b = await readJson(c);
    try {
      await ensureWhatsappSchema(c.env);
      const allowed = ['default_language', 'require_opt_in', 'daily_limit', 'business_hours_only'];
      const updated = [];
      for (const key of allowed) {
        if (b[key] === undefined) continue;
        await run(c.env, 'INSERT INTO wa_settings (key, value, updated_at) VALUES (?,?,?) ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at', [key, String(b[key]), nowIso()]);
        updated.push(key);
      }
      return c.json({ success: true, updated: updated });
    } catch (err) { return fail(c, err); }
  });

  return app;
}
