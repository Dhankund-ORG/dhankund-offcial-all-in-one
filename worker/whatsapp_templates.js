// WhatsApp message template management.
// Create / edit / delete / list, both on Meta and in the local D1 cache,
// with Hindi + English created together as one "template pair".

import { graphFetch, WhatsappError, extractMessageId } from './whatsapp.js';
import { all, first, run, nowIso, randomId } from './db.js';

export const TEMPLATE_CATEGORIES = ['MARKETING', 'UTILITY', 'AUTHENTICATION'];
export const TEMPLATE_LANGUAGES = ['hi', 'en'];
export const TEMPLATE_NAME_RE = /^[a-z0-9_]{1,512}$/;

export function validateTemplateName(name) {
  const value = String(name || '').trim();
  if (!value) throw new WhatsappError('Template name is required', 400);
  if (!TEMPLATE_NAME_RE.test(value)) {
    throw new WhatsappError('Template name may contain only lowercase letters, digits and underscores (max 512)', 400);
  }
  return value;
}

export function normalizeCategory(category) {
  const value = String(category || 'UTILITY').toUpperCase();
  if (TEMPLATE_CATEGORIES.indexOf(value) < 0) {
    throw new WhatsappError('Category must be one of ' + TEMPLATE_CATEGORIES.join(', '), 400);
  }
  return value;
}

export function normalizeLanguage(language) {
  const value = String(language || 'en').trim();
  if (TEMPLATE_LANGUAGES.indexOf(value) < 0) {
    throw new WhatsappError('Language must be one of ' + TEMPLATE_LANGUAGES.join(', '), 400);
  }
  return value;
}

// Build the `components` array Meta expects from a simple, readable input.
// Body variables are written as {{1}}, {{2}} … exactly like in WhatsApp Manager.
export function buildComponents(input) {
  const src = input || {};
  const components = [];

  const header = src.header;
  if (header && (header.text || header.format)) {
    const format = String(header.format || 'TEXT').toUpperCase();
    if (format === 'TEXT') {
      if (!header.text) throw new WhatsappError('Header text is required for a TEXT header', 400);
      if (String(header.text).length > 60) throw new WhatsappError('Header text limit is 60 characters', 400);
      const c = { type: 'HEADER', format: 'TEXT', text: String(header.text) };
      if (header.example && header.example.length) c.example = { header_text: header.example.map(String) };
      components.push(c);
    } else {
      const c = { type: 'HEADER', format: format };
      if (header.example) c.example = { header_handle: header.example.map(String) };
      components.push(c);
    }
  }

  if (src.body) {
    const text = String(src.body).trim();
    if (!text) throw new WhatsappError('Template body is required', 400);
    if (text.length > 1024) throw new WhatsappError('Template body limit is 1024 characters', 400);
    const c = { type: 'BODY', text: text };
    const variables = countVariables(text);
    if (variables > 0) {
      const example = Array.isArray(src.bodyExample) && src.bodyExample.length === variables
        ? src.bodyExample.map(String)
        : Array.from({ length: variables }, function (_, i) { return 'example' + (i + 1); });
      c.example = { body_text: [example] };
    }
    components.push(c);
  }

  if (src.footer) {
    const text = String(src.footer).trim();
    if (text.length > 60) throw new WhatsappError('Footer limit is 60 characters', 400);
    components.push({ type: 'FOOTER', text: text });
  }

  const buttons = Array.isArray(src.buttons) ? src.buttons : [];
  if (buttons.length) {
    if (buttons.length > 10) throw new WhatsappError('A template supports at most 10 buttons', 400);
    components.push({
      type: 'BUTTONS',
      buttons: buttons.map(function (b, index) {
        const type = String(b.type || 'QUICK_REPLY').toUpperCase();
        if (type === 'QUICK_REPLY') {
          if (!b.text) throw new WhatsappError('Quick reply button ' + (index + 1) + ' needs text', 400);
          return { type: 'QUICK_REPLY', text: String(b.text).slice(0, 25) };
        }
        if (type === 'URL') {
          if (!b.text || !b.url) throw new WhatsappError('URL button ' + (index + 1) + ' needs text and url', 400);
          const out = { type: 'URL', text: String(b.text).slice(0, 25), url: String(b.url) };
          if (b.example) out.example = [String(b.example)];
          return out;
        }
        if (type === 'PHONE_NUMBER') {
          if (!b.text || !b.phoneNumber) throw new WhatsappError('Phone button ' + (index + 1) + ' needs text and phoneNumber', 400);
          return { type: 'PHONE_NUMBER', text: String(b.text).slice(0, 25), phone_number: String(b.phoneNumber) };
        }
        throw new WhatsappError('Unsupported button type: ' + type, 400);
      }),
    });
  }

  if (!components.some(function (c) { return c.type === 'BODY'; })) {
    throw new WhatsappError('Template body is required', 400);
  }
  return components;
}

export function countVariables(text) {
  const found = String(text || '').match(/\{\{\s*\d+\s*\}\}/g) || [];
  const numbers = new Set();
  for (const token of found) numbers.add(token.replace(/[^\d]/g, ''));
  return numbers.size;
}

// Text preview used by the CRM before anything is sent to Meta.
export function renderPreview(components, params) {
  const values = params || [];
  const byType = {};
  for (const c of components || []) byType[String(c.type).toUpperCase()] = c;
  function fill(text) {
    return String(text || '').replace(/\{\{\s*(\d+)\s*\}\}/g, function (_m, n) {
      const v = values[Number(n) - 1];
      return v === undefined || v === null || v === '' ? '{{' + n + '}}' : String(v);
    });
  }
  return {
    header: byType.HEADER && byType.HEADER.text ? fill(byType.HEADER.text) : null,
    body: byType.BODY ? fill(byType.BODY.text) : '',
    footer: byType.FOOTER ? byType.FOOTER.text : null,
    buttons: byType.BUTTONS ? (byType.BUTTONS.buttons || []).map(function (b) { return b.text || b.type; }) : [],
  };
}

// ---------- Meta side ----------

function wabaId(env) {
  if (!env.WHATSAPP_BUSINESS_ACCOUNT_ID) {
    throw new WhatsappError('WHATSAPP_BUSINESS_ACCOUNT_ID is not configured', 503);
  }
  return env.WHATSAPP_BUSINESS_ACCOUNT_ID;
}

export async function listRemoteTemplates(env, options) {
  const opts = options || {};
  const data = await graphFetch(env, wabaId(env) + '/message_templates', {
    query: {
      fields: 'id,name,status,category,language,components,quality_score,rejected_reason',
      limit: opts.limit || 200,
      after: opts.after || '',
    },
  });
  return {
    templates: Array.isArray(data && data.data) ? data.data : [],
    next: data && data.paging ? data.paging.next || null : null,
  };
}

export async function createTemplate(env, input) {
  const name = validateTemplateName(input.name);
  const language = normalizeLanguage(input.language);
  const category = normalizeCategory(input.category);
  const components = Array.isArray(input.components) ? input.components : buildComponents(input);

  const body = { name: name, language: language, category: category, components: components };
  if (input.allowCategoryChange !== false) body.allow_category_change = true;

  const data = await graphFetch(env, wabaId(env) + '/message_templates', { method: 'POST', body: body });
  const remoteId = data && data.id ? String(data.id) : null;
  await upsertCache(env, {
    remoteId: remoteId,
    name: name,
    language: language,
    category: category,
    status: (data && data.status) || 'PENDING',
    components: components,
  });
  return { id: remoteId, name: name, language: language, category: category, status: (data && data.status) || 'PENDING' };
}

// Create the same template in Hindi and English in one call.
// Partial success is reported, never hidden: the CRM shows which language failed.
export async function createTemplatePair(env, input) {
  const name = validateTemplateName(input.name);
  const category = normalizeCategory(input.category);
  const languages = Array.isArray(input.languages) && input.languages.length ? input.languages : TEMPLATE_LANGUAGES;
  const created = [];
  const failed = [];

  for (const language of languages.map(normalizeLanguage)) {
    const perLanguage = input.perLanguage && input.perLanguage[language] ? input.perLanguage[language] : input;
    try {
      const result = await createTemplate(env, {
        name: name,
        language: language,
        category: category,
        components: perLanguage.components || buildComponents(perLanguage),
        allowCategoryChange: input.allowCategoryChange,
      });
      created.push(result);
    } catch (err) {
      failed.push({
        language: language,
        error: err && err.message ? err.message : 'Template creation failed',
        code: err && err.code != null ? err.code : null,
      });
    }
  }
  return { name: name, category: category, created: created, failed: failed };
}

export async function updateTemplate(env, templateId, input) {
  if (!templateId) throw new WhatsappError('Template id is required', 400);
  const body = {};
  if (input.category) body.category = normalizeCategory(input.category);
  if (input.components) body.components = input.components;
  else if (input.body || input.header || input.footer || input.buttons) body.components = buildComponents(input);
  if (!Object.keys(body).length) throw new WhatsappError('Nothing to update: send category or components', 400);

  const data = await graphFetch(env, String(templateId), { method: 'POST', body: body });
  const row = await first(env, 'SELECT * FROM wa_templates WHERE remote_id = ?', [String(templateId)]);
  if (row) {
    await run(env, 'UPDATE wa_templates SET status = ?, components_json = ?, category = ?, updated_at = ? WHERE id = ?', [
      'PENDING',
      JSON.stringify(body.components || JSON.parse(row.components_json || '[]')),
      body.category || row.category,
      nowIso(),
      row.id,
    ]);
  }
  return { id: String(templateId), status: (data && data.status) || 'PENDING' };
}

export async function deleteTemplateById(env, templateId) {
  if (!templateId) throw new WhatsappError('Template id is required', 400);
  await graphFetch(env, String(templateId), { method: 'DELETE' });
  await run(env, 'DELETE FROM wa_templates WHERE remote_id = ?', [String(templateId)]);
  return { deleted: true, id: String(templateId) };
}

// Deletes every language of that template name on Meta.
export async function deleteTemplateByName(env, name) {
  const value = validateTemplateName(name);
  await graphFetch(env, wabaId(env) + '/message_templates', { method: 'DELETE', query: { name: value } });
  await run(env, 'DELETE FROM wa_templates WHERE name = ?', [value]);
  return { deleted: true, name: value };
}

// ---------- local cache ----------

export async function upsertCache(env, t) {
  const now = nowIso();
  const existing = await first(env, 'SELECT id FROM wa_templates WHERE name = ? AND language = ?', [t.name, t.language]);
  const components = Array.isArray(t.components) ? JSON.stringify(t.components) : t.components || '[]';
  if (existing) {
    await run(
      env,
      'UPDATE wa_templates SET remote_id = COALESCE(?, remote_id), category = ?, status = ?, components_json = ?, quality = ?, rejected_reason = ?, synced_at = ?, updated_at = ? WHERE id = ?',
      [t.remoteId || null, t.category || null, t.status || null, components, t.quality || null, t.rejectedReason || null, now, now, existing.id]
    );
    return existing.id;
  }
  const id = randomId();
  await run(
    env,
    'INSERT INTO wa_templates (id, remote_id, name, language, category, status, components_json, quality, rejected_reason, synced_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
    [id, t.remoteId || null, t.name, t.language, t.category || null, t.status || null, components, t.quality || null, t.rejectedReason || null, now, now, now]
  );
  return id;
}

export async function syncTemplates(env) {
  const remote = await listRemoteTemplates(env);
  let synced = 0;
  for (const t of remote.templates) {
    await upsertCache(env, {
      remoteId: t.id,
      name: t.name,
      language: t.language,
      category: t.category,
      status: t.status,
      components: t.components,
      quality: t.quality_score ? t.quality_score.score || null : null,
      rejectedReason: t.rejected_reason || null,
    });
    synced += 1;
  }
  const rows = await all(env, 'SELECT status, COUNT(*) AS n FROM wa_templates GROUP BY status');
  const counts = {};
  for (const r of rows) counts[r.status || 'UNKNOWN'] = r.n;
  return { synced: synced, counts: counts };
}

export async function listCachedTemplates(env, filters) {
  const f = filters || {};
  const where = [];
  const params = [];
  if (f.language) { where.push('language = ?'); params.push(f.language); }
  if (f.status) { where.push('status = ?'); params.push(f.status); }
  if (f.search) { where.push('name LIKE ?'); params.push('%' + f.search + '%'); }
  const sql = 'SELECT * FROM wa_templates' + (where.length ? ' WHERE ' + where.join(' AND ') : '') + ' ORDER BY name, language';
  const rows = await all(env, sql, params);
  return rows.map(function (r) {
    return Object.assign({}, r, { components: safeComponents(r.components_json) });
  });
}

export async function getCachedTemplate(env, name, language) {
  const row = await first(env, 'SELECT * FROM wa_templates WHERE name = ? AND language = ?', [name, language]);
  if (!row) return null;
  return Object.assign({}, row, { components: safeComponents(row.components_json) });
}

export async function requireApprovedTemplate(env, name, language) {
  const row = await getCachedTemplate(env, name, language);
  if (!row) {
    throw new WhatsappError('Template "' + name + '" (' + language + ') is not in the local cache. Run a template sync first.', 400);
  }
  if (String(row.status).toUpperCase() !== 'APPROVED') {
    throw new WhatsappError('Template "' + name + '" (' + language + ') is ' + (row.status || 'not approved') + '. Only approved templates can be sent.', 400);
  }
  return row;
}

function safeComponents(json) {
  try { return JSON.parse(json || '[]'); } catch (_) { return []; }
}

export { extractMessageId };
