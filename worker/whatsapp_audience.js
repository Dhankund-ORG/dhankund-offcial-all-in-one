// Audience builder. Pulls phone numbers out of the tables the CRM already has,
// normalises them, removes duplicates and applies the consent rules before
// anything is queued for sending.

import { all } from './db.js';
import { normalizePhone, WhatsappError } from './whatsapp.js';

// `filters` maps a request key to the real column name.
export const AUDIENCE_SOURCES = {
  registrations: {
    label: 'Partner / DSA registrations',
    table: 'registrations',
    phone: 'mobile',
    name: 'name',
    id: 'id',
    filters: { role: 'role', status: 'status' },
  },
  loans: {
    label: 'Loan applications',
    table: 'loan_applications',
    phone: 'mobile_number',
    name: 'full_name',
    id: 'id',
    filters: { status: 'status', loan_type: 'loan_type' },
  },
  referrals: {
    label: 'Referral and website leads',
    table: 'referrals',
    phone: 'friend_mobile',
    name: 'friend_name',
    id: 'id',
    filters: { status: 'status', loan_type: 'loan_type' },
  },
  insurance: {
    label: 'Insurance applications',
    table: 'insurance_applications',
    phone: 'mobile_number',
    name: 'name',
    id: 'id',
    filters: { status: 'status', insurance_type: 'insurance_type' },
  },
  users: {
    label: 'Registered users',
    table: 'users',
    phone: 'mobile',
    name: 'name',
    id: 'id',
    filters: { role: 'role' },
  },
  contacts: {
    label: 'WhatsApp contacts',
    table: 'wa_contacts',
    phone: 'phone_e164',
    name: 'name',
    id: 'id',
    filters: { opt_in_status: 'opt_in_status' },
  },
};

export function listSources() {
  return Object.keys(AUDIENCE_SOURCES).map(function (key) {
    return { key: key, label: AUDIENCE_SOURCES[key].label, filters: Object.keys(AUDIENCE_SOURCES[key].filters) };
  });
}

function normalizeSourceList(spec) {
  const requested = Array.isArray(spec.sources) && spec.sources.length ? spec.sources : [spec.source || 'contacts'];
  const out = [];
  for (const s of requested) {
    const key = String(s || '').trim();
    if (!AUDIENCE_SOURCES[key]) throw new WhatsappError('Unknown audience source: ' + key, 400);
    if (out.indexOf(key) < 0) out.push(key);
  }
  return out;
}

// Pure: used by the resolver and by the tests.
export function dedupeRecipients(rows, options) {
  const opts = options || {};
  const optOut = opts.optOut instanceof Set ? opts.optOut : new Set(opts.optOut || []);
  const optIn = opts.optIn instanceof Set ? opts.optIn : new Set(opts.optIn || []);
  const seen = new Set();
  const recipients = [];
  const stats = { input: 0, valid: 0, invalid: 0, duplicate: 0, optedOut: 0, notOptedIn: 0 };

  for (const row of rows || []) {
    stats.input += 1;
    const phone = normalizePhone(row.phone);
    if (!phone) { stats.invalid += 1; continue; }
    if (seen.has(phone)) { stats.duplicate += 1; continue; }
    if (optOut.has(phone)) { stats.optedOut += 1; continue; }
    if (opts.requireOptIn && !optIn.has(phone)) { stats.notOptedIn += 1; continue; }
    seen.add(phone);
    stats.valid += 1;
    recipients.push({
      phone: phone,
      name: row.name || null,
      source: row.source || null,
      refId: row.refId || null,
    });
  }
  return { recipients: recipients, stats: stats };
}

export async function loadConsentSets(env) {
  const rows = await all(env, "SELECT phone_e164, opt_in_status FROM wa_contacts WHERE opt_in_status IN ('opted_in','opted_out')");
  const optIn = new Set();
  const optOut = new Set();
  for (const r of rows) {
    if (r.opt_in_status === 'opted_in') optIn.add(r.phone_e164);
    else optOut.add(r.phone_e164);
  }
  return { optIn: optIn, optOut: optOut };
}

async function readSourceRows(env, key, filters, max) {
  const def = AUDIENCE_SOURCES[key];
  const where = [];
  const params = [];
  for (const name of Object.keys(def.filters || {})) {
    const value = filters ? filters[name] : undefined;
    if (value === undefined || value === null || value === '' || value === 'all') continue;
    where.push(def.filters[name] + ' = ?');
    params.push(String(value));
  }
  if (filters && filters.search) {
    where.push('(' + def.name + ' LIKE ? OR ' + def.phone + ' LIKE ?)');
    params.push('%' + filters.search + '%');
    params.push('%' + filters.search + '%');
  }

  const pageSize = 500;
  const limit = Math.max(1, Math.min(Number(max) || 20000, 50000));
  const rows = [];
  let offset = 0;
  for (;;) {
    const sql = 'SELECT ' + def.phone + ' AS phone, ' + def.name + ' AS name, ' + def.id + ' AS refId FROM ' + def.table +
      (where.length ? ' WHERE ' + where.join(' AND ') : '') + ' LIMIT ' + pageSize + ' OFFSET ' + offset;
    const page = await all(env, sql, params);
    for (const r of page) rows.push({ phone: r.phone, name: r.name, source: key, refId: r.refId });
    if (page.length < pageSize || rows.length >= limit) break;
    offset += pageSize;
  }
  return rows.slice(0, limit);
}

export async function resolveAudience(env, spec) {
  const s = spec || {};
  const sources = normalizeSourceList(s);
  const limit = Math.max(1, Math.min(Number(s.limit) || 20000, 50000));
  const requireOptIn = s.requireOptIn !== false;

  const collected = [];
  const perSource = {};
  for (const key of sources) {
    const rows = await readSourceRows(env, key, s.filters || {}, limit);
    perSource[key] = rows.length;
    for (const r of rows) collected.push(r);
  }

  const consent = await loadConsentSets(env);
  const result = dedupeRecipients(collected, {
    optIn: consent.optIn,
    optOut: consent.optOut,
    requireOptIn: requireOptIn,
  });

  return {
    sources: sources,
    perSource: perSource,
    requireOptIn: requireOptIn,
    stats: result.stats,
    sample: result.recipients.slice(0, 10),
    recipients: result.recipients,
  };
}

// Kept separate so the broadcast route can preview without holding the list.
export function audienceSummary(resolved) {
  const r = resolved || {};
  const stats = r.stats || {};
  return {
    sources: r.sources || [],
    perSource: r.perSource || {},
    requireOptIn: !!r.requireOptIn,
    total: stats.valid || 0,
    skipped: {
      invalid: stats.invalid || 0,
      duplicate: stats.duplicate || 0,
      optedOut: stats.optedOut || 0,
      notOptedIn: stats.notOptedIn || 0,
    },
    sample: r.sample || [],
  };
}
