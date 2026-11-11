// Broadcast engine: one row per recipient in D1, sent in bounded batches so a
// Worker never runs out of CPU or memory, and a Durable Object keeps the loop
// going until the whole campaign is done.

import { all, first, run, insertRow, nowIso, randomId } from './db.js';
import { sendTemplate, extractMessageId, WhatsappError, normalizePhone } from './whatsapp.js';
import { requireApprovedTemplate } from './whatsapp_templates.js';
import { resolveAudience, audienceSummary } from './whatsapp_audience.js';

export const DEFAULT_BATCH_SIZE = 20;
export const MAX_BATCH_SIZE = 50;

export async function createBroadcast(env, input, context) {
  const b = input || {};
  const ctx = context || {};
  const name = String(b.name || '').trim() || 'Campaign ' + new Date().toISOString().slice(0, 16);
  const templateName = String(b.templateName || b.template_name || '').trim();
  const templateLang = String(b.templateLang || b.template_language || 'en').trim();
  if (!templateName) throw new WhatsappError('templateName is required', 400);

  await requireApprovedTemplate(env, templateName, templateLang);

  const resolved = await resolveAudience(env, b.audience || b);
  const summary = audienceSummary(resolved);
  if (!resolved.recipients.length) {
    throw new WhatsappError('No valid recipients after consent and duplicate filtering', 400);
  }
  if (b.dryRun) {
    return { dryRun: true, summary: summary };
  }

  const id = randomId();
  const now = nowIso();
  await insertRow(env, 'wa_broadcasts', {
    id: id,
    name: name,
    template_name: templateName,
    template_lang: templateLang,
    audience_json: JSON.stringify(summary),
    total: resolved.recipients.length,
    sent: 0,
    delivered: 0,
    read: 0,
    failed: 0,
    skipped: summary.skipped.invalid + summary.skipped.duplicate + summary.skipped.optedOut + summary.skipped.notOptedIn,
    status: 'queued',
    created_by: ctx.userId || null,
    created_at: now,
    started_at: null,
    finished_at: null,
    last_error: null,
  });

  // Chunked insert keeps a 5,000-recipient campaign inside D1 limits.
  const chunk = 50;
  for (let i = 0; i < resolved.recipients.length; i += chunk) {
    const slice = resolved.recipients.slice(i, i + chunk);
    for (const r of slice) {
      await insertRow(env, 'wa_broadcast_recipients', {
        id: randomId(),
        broadcast_id: id,
        phone_e164: r.phone,
        name: r.name || null,
        source: r.source || null,
        status: 'queued',
        wa_message_id: null,
        error_code: null,
        error_message: null,
        attempts: 0,
        updated_at: now,
      });
    }
  }

  return { id: id, total: resolved.recipients.length, summary: summary, status: 'queued' };
}

export async function processBroadcastBatch(env, broadcastId, options) {
  const opts = options || {};
  const limit = Math.max(1, Math.min(Number(opts.limit) || DEFAULT_BATCH_SIZE, MAX_BATCH_SIZE));
  const broadcast = await first(env, 'SELECT * FROM wa_broadcasts WHERE id = ?', [broadcastId]);
  if (!broadcast) throw new WhatsappError('Broadcast not found', 404);
  if (broadcast.status === 'paused' || broadcast.status === 'completed' || broadcast.status === 'cancelled') {
    return { processed: 0, sent: 0, failed: 0, remaining: 0, status: broadcast.status };
  }

  const template = await requireApprovedTemplate(env, broadcast.template_name, broadcast.template_lang);
  const queue = await all(
    env,
    "SELECT * FROM wa_broadcast_recipients WHERE broadcast_id = ? AND status = 'queued' ORDER BY rowid LIMIT " + limit,
    [broadcastId]
  );

  if (!queue.length) {
    await run(env, "UPDATE wa_broadcasts SET status = 'completed', finished_at = ? WHERE id = ? AND status IN ('queued','running')", [nowIso(), broadcastId]);
    return { processed: 0, sent: 0, failed: 0, remaining: 0, status: 'completed' };
  }

  if (broadcast.status === 'queued') {
    await run(env, "UPDATE wa_broadcasts SET status = 'running', started_at = COALESCE(started_at, ?) WHERE id = ?", [nowIso(), broadcastId]);
  }

  const audience = safeAudience(broadcast.audience_json);
  const paramsFor = opts.paramsFor || defaultParamsFor(audience);
  let sent = 0;
  let failed = 0;

  for (const recipient of queue) {
    await run(env, "UPDATE wa_broadcast_recipients SET status = 'sending', attempts = attempts + 1, updated_at = ? WHERE id = ? AND status = 'queued'", [nowIso(), recipient.id]);
    try {
      const response = await sendTemplate(env, recipient.phone_e164, {
        name: broadcast.template_name,
        language: broadcast.template_lang,
        bodyParams: paramsFor(recipient, template),
      });
      const waMessageId = extractMessageId(response);
      await run(env, "UPDATE wa_broadcast_recipients SET status = 'sent', wa_message_id = ?, updated_at = ? WHERE id = ?", [waMessageId, nowIso(), recipient.id]);
      await insertRow(env, 'wa_messages', {
        id: randomId(),
        wa_message_id: waMessageId,
        phone_e164: recipient.phone_e164,
        direction: 'outbound',
        type: 'template',
        template_name: broadcast.template_name,
        template_lang: broadcast.template_lang,
        body: null,
        caption: null,
        media_id: null,
        media_mime: null,
        media_r2_key: null,
        media_size: null,
        status: 'sent',
        error_code: null,
        error_title: null,
        error_message: null,
        reply_to: null,
        broadcast_id: broadcastId,
        sent_by: broadcast.created_by || null,
        sent_at: nowIso(),
        delivered_at: null,
        read_at: null,
        created_at: nowIso(),
        raw_json: JSON.stringify(response || {}),
      });
      await touchContactOutbound(env, recipient.phone_e164);
      sent += 1;
    } catch (err) {
      const message = err && err.message ? err.message : 'Send failed';
      const code = err && err.code != null ? String(err.code) : null;
      await run(env, "UPDATE wa_broadcast_recipients SET status = 'failed', error_code = ?, error_message = ?, updated_at = ? WHERE id = ?", [code, message, nowIso(), recipient.id]);
      await run(env, 'UPDATE wa_broadcasts SET last_error = ? WHERE id = ?', [message, broadcastId]);
      failed += 1;
      // A dead token or a blocked account fails every message; stop instead of burning the list.
      if (err && err.status === 502 && (err.code === 190 || err.code === 368)) {
        await run(env, "UPDATE wa_broadcasts SET status = 'paused', last_error = ? WHERE id = ?", [message, broadcastId]);
        break;
      }
    }
  }

  await run(env, 'UPDATE wa_broadcasts SET sent = sent + ?, failed = failed + ? WHERE id = ?', [sent, failed, broadcastId]);
  const remainingRow = await first(env, "SELECT COUNT(*) AS n FROM wa_broadcast_recipients WHERE broadcast_id = ? AND status = 'queued'", [broadcastId]);
  const remaining = remainingRow ? Number(remainingRow.n) || 0 : 0;
  if (remaining === 0) {
    await run(env, "UPDATE wa_broadcasts SET status = 'completed', finished_at = ? WHERE id = ? AND status = 'running'", [nowIso(), broadcastId]);
  }
  return { processed: queue.length, sent: sent, failed: failed, remaining: remaining };
}

// Per-recipient template variables. Body variables are filled from the recipient
// name first, so {{1}} = customer name works for most campaigns.
export function defaultParamsFor(audience) {
  const configured = audience && Array.isArray(audience.variables) ? audience.variables : null;
  return function (recipient) {
    if (configured) {
      return configured.map(function (v) {
        if (v === '{name}') return recipient.name || 'Customer';
        if (v === '{phone}') return recipient.phone_e164 || '';
        return String(v);
      });
    }
    return [recipient.name || 'Customer'];
  };
}

function safeAudience(json) {
  try { return JSON.parse(json || '{}'); } catch (_) { return {}; }
}

async function touchContactOutbound(env, phone) {
  const now = nowIso();
  await run(env, 'UPDATE wa_contacts SET last_outbound_at = ?, updated_at = ? WHERE phone_e164 = ?', [now, now, phone]);
}

export async function broadcastSummary(env, id) {
  const broadcast = await first(env, 'SELECT * FROM wa_broadcasts WHERE id = ?', [id]);
  if (!broadcast) throw new WhatsappError('Broadcast not found', 404);
  const counts = await all(env, 'SELECT status, COUNT(*) AS n FROM wa_broadcast_recipients WHERE broadcast_id = ? GROUP BY status', [id]);
  const byStatus = {};
  for (const row of counts) byStatus[row.status] = row.n;
  return Object.assign({}, broadcast, {
    audience: safeAudience(broadcast.audience_json),
    recipientsByStatus: byStatus,
  });
}

export async function listBroadcasts(env, limit) {
  const rows = await all(env, 'SELECT * FROM wa_broadcasts ORDER BY created_at DESC LIMIT ' + Math.max(1, Math.min(Number(limit) || 50, 200)));
  return rows.map(function (r) { return Object.assign({}, r, { audience: safeAudience(r.audience_json) }); });
}

export async function setBroadcastStatus(env, id, status) {
  const allowed = ['paused', 'running', 'cancelled'];
  if (allowed.indexOf(status) < 0) throw new WhatsappError('Status must be one of ' + allowed.join(', '), 400);
  await run(env, 'UPDATE wa_broadcasts SET status = ? WHERE id = ?', [status, id]);
  return { id: id, status: status };
}

// Webhook delivery/read receipts land here.
export async function applyStatusToRecipient(env, waMessageId, status) {
  const column = status === 'delivered' ? 'delivered_at' : (status === 'read' ? 'read_at' : null);
  if (column) {
    await run(env, 'UPDATE wa_messages SET status = ?, ' + column + ' = ? WHERE wa_message_id = ?', [status, nowIso(), waMessageId]);
  }
  if (status === 'delivered') {
    await run(env, "UPDATE wa_broadcast_recipients SET status = 'delivered', updated_at = ? WHERE wa_message_id = ?", [nowIso(), waMessageId]);
    await run(env, 'UPDATE wa_broadcasts SET delivered = delivered + 1 WHERE id = (SELECT broadcast_id FROM wa_broadcast_recipients WHERE wa_message_id = ?)', [waMessageId]);
  } else if (status === 'read') {
    await run(env, "UPDATE wa_broadcast_recipients SET status = 'read', updated_at = ? WHERE wa_message_id = ?", [nowIso(), waMessageId]);
    await run(env, 'UPDATE wa_broadcasts SET read = read + 1 WHERE id = (SELECT broadcast_id FROM wa_broadcast_recipients WHERE wa_message_id = ?)', [waMessageId]);
  } else if (status === 'failed') {
    await run(env, "UPDATE wa_broadcast_recipients SET status = 'failed', updated_at = ? WHERE wa_message_id = ?", [nowIso(), waMessageId]);
  }
}

// Cron: pick up campaigns that stopped half way (isolate died, deploy happened).
export async function resumePendingBroadcasts(env, options) {
  const opts = options || {};
  const max = Math.max(1, Math.min(Number(opts.maxBroadcasts) || 3, 10));
  const rows = await all(
    env,
    "SELECT id FROM wa_broadcasts WHERE status IN ('queued','running') ORDER BY created_at LIMIT " + max
  );
  const results = [];
  for (const row of rows) {
    try {
      const result = await processBroadcastBatch(env, row.id, { limit: opts.limit || DEFAULT_BATCH_SIZE });
      results.push({ id: row.id, result: result });
    } catch (err) {
      results.push({ id: row.id, error: err && err.message ? err.message : 'failed' });
    }
  }
  return { resumed: results.length, results: results };
}

// ---------- Durable Object ----------

// One instance per broadcast; the alarm keeps the batch loop alive without
// holding a single request open for the whole campaign.
export class WhatsappBroadcastSender {
  constructor(state, env) {
    this.state = state;
    this.env = env;
  }

  async fetch(request) {
    let body = {};
    try { body = await request.json(); } catch (_) { body = {}; }
    const broadcastId = body.broadcastId;
    if (!broadcastId) return new Response(JSON.stringify({ error: 'broadcastId is required' }), { status: 400 });
    await this.state.storage.put('broadcastId', broadcastId);
    const result = await this.step(broadcastId, body.limit);
    return new Response(JSON.stringify(result), { headers: { 'Content-Type': 'application/json' } });
  }

  async step(broadcastId, limit) {
    const result = await processBroadcastBatch(this.env, broadcastId, { limit: limit || DEFAULT_BATCH_SIZE });
    if (result.remaining > 0) {
      await this.state.storage.setAlarm(Date.now() + 1500);
    } else {
      await this.state.storage.deleteAlarm();
    }
    return result;
  }

  async alarm() {
    const broadcastId = await this.state.storage.get('broadcastId');
    if (!broadcastId) return;
    try {
      await this.step(broadcastId);
    } catch (err) {
      console.error('broadcast alarm failed', err && err.message);
      await this.state.storage.setAlarm(Date.now() + 30000);
    }
  }
}
