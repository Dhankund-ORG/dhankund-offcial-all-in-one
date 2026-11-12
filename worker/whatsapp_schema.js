// WhatsApp tables. Additive only: nothing here touches an existing table,
// so CRM, DSA and the website keep working while this ships.
//
// Order matters. Tables are created first, then any missing column is added with
// ALTER TABLE, and only then are the indexes created — an index on a column that
// an older database does not have yet used to abort the whole migration and
// leave every route failing with "no such column".

export const WHATSAPP_TABLES_SQL = `
CREATE TABLE IF NOT EXISTS wa_contacts (
  id TEXT PRIMARY KEY,
  phone_e164 TEXT NOT NULL UNIQUE,
  name TEXT,
  profile_name TEXT,
  source TEXT,
  registration_id TEXT,
  loan_id TEXT,
  referral_id TEXT,
  opt_in_status TEXT NOT NULL DEFAULT 'unknown',
  opt_in_at TEXT,
  opt_out_at TEXT,
  opt_in_source TEXT,
  tags TEXT,
  notes TEXT,
  last_inbound_at TEXT,
  last_outbound_at TEXT,
  window_expires_at TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS wa_messages (
  id TEXT PRIMARY KEY,
  wa_message_id TEXT UNIQUE,
  phone_e164 TEXT NOT NULL,
  direction TEXT NOT NULL,
  type TEXT NOT NULL,
  kind TEXT,
  template_name TEXT,
  template_lang TEXT,
  body TEXT,
  caption TEXT,
  media_id TEXT,
  media_mime TEXT,
  media_r2_key TEXT,
  media_size INTEGER,
  media_filename TEXT,
  media_sha256 TEXT,
  media_animated INTEGER,
  voice INTEGER,
  latitude REAL,
  longitude REAL,
  location_name TEXT,
  location_address TEXT,
  location_url TEXT,
  interactive_id TEXT,
  interactive_title TEXT,
  flow_token TEXT,
  flow_response TEXT,
  reaction_emoji TEXT,
  reaction_to TEXT,
  system_type TEXT,
  system_new_wa_id TEXT,
  system_body TEXT,
  contacts_json TEXT,
  order_json TEXT,
  poll_json TEXT,
  referral_json TEXT,
  forwarded INTEGER,
  phone_number_id TEXT,
  conversation_category TEXT,
  pricing_category TEXT,
  status TEXT,
  error_code TEXT,
  error_title TEXT,
  error_message TEXT,
  reply_to TEXT,
  broadcast_id TEXT,
  sent_by TEXT,
  payload_hash TEXT,
  edited_at TEXT,
  sent_at TEXT,
  delivered_at TEXT,
  read_at TEXT,
  created_at TEXT,
  raw_json TEXT
);

CREATE TABLE IF NOT EXISTS wa_templates (
  id TEXT PRIMARY KEY,
  remote_id TEXT,
  name TEXT NOT NULL,
  language TEXT NOT NULL,
  category TEXT,
  status TEXT,
  components_json TEXT,
  quality TEXT,
  rejected_reason TEXT,
  synced_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  UNIQUE (name, language)
);

CREATE TABLE IF NOT EXISTS wa_broadcasts (
  id TEXT PRIMARY KEY,
  name TEXT,
  template_name TEXT,
  template_lang TEXT,
  audience_json TEXT,
  total INTEGER NOT NULL DEFAULT 0,
  sent INTEGER NOT NULL DEFAULT 0,
  delivered INTEGER NOT NULL DEFAULT 0,
  read INTEGER NOT NULL DEFAULT 0,
  failed INTEGER NOT NULL DEFAULT 0,
  skipped INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'queued',
  created_by TEXT,
  created_at TEXT,
  started_at TEXT,
  finished_at TEXT,
  last_error TEXT
);

CREATE TABLE IF NOT EXISTS wa_broadcast_recipients (
  id TEXT PRIMARY KEY,
  broadcast_id TEXT NOT NULL,
  phone_e164 TEXT NOT NULL,
  name TEXT,
  source TEXT,
  status TEXT NOT NULL DEFAULT 'queued',
  wa_message_id TEXT,
  error_code TEXT,
  error_message TEXT,
  attempts INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT,
  UNIQUE (broadcast_id, phone_e164)
);

CREATE TABLE IF NOT EXISTS wa_webhook_events (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL UNIQUE,
  kind TEXT,
  payload_json TEXT,
  processed_at TEXT
);

CREATE TABLE IF NOT EXISTS wa_settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS wa_alerts (
  id TEXT PRIMARY KEY,
  kind TEXT,
  title TEXT,
  body TEXT,
  payload_json TEXT,
  created_at TEXT
);
`;

// One statement each, so a single failure cannot stop the rest.
export const WHATSAPP_INDEX_SQL = [
  'CREATE INDEX IF NOT EXISTS idx_wa_messages_phone ON wa_messages (phone_e164, created_at)',
  'CREATE INDEX IF NOT EXISTS idx_wa_messages_status ON wa_messages (status)',
  'CREATE INDEX IF NOT EXISTS idx_wa_messages_broadcast ON wa_messages (broadcast_id)',
  'CREATE INDEX IF NOT EXISTS idx_wa_messages_kind ON wa_messages (kind)',
  'CREATE INDEX IF NOT EXISTS idx_wa_contacts_optin ON wa_contacts (opt_in_status)',
  'CREATE INDEX IF NOT EXISTS idx_wa_contacts_updated ON wa_contacts (updated_at)',
  'CREATE INDEX IF NOT EXISTS idx_wa_templates_name ON wa_templates (name, language)',
  'CREATE INDEX IF NOT EXISTS idx_wa_recipients_broadcast ON wa_broadcast_recipients (broadcast_id, status)',
  'CREATE INDEX IF NOT EXISTS idx_wa_broadcasts_status ON wa_broadcasts (status, created_at)',
];

// Kept for the schema.sql snapshot and for the tests.
export const WHATSAPP_SCHEMA_SQL = WHATSAPP_TABLES_SQL + '\n' + WHATSAPP_INDEX_SQL.map(function (s) { return s + ';'; }).join('\n') + '\n';

// Columns added after the first release. Each one is applied with ALTER TABLE,
// so an older database upgrades in place.
export const WHATSAPP_MESSAGE_COLUMNS = [
  ['kind', 'TEXT'],
  ['media_filename', 'TEXT'],
  ['media_sha256', 'TEXT'],
  ['media_animated', 'INTEGER'],
  ['voice', 'INTEGER'],
  ['latitude', 'REAL'],
  ['longitude', 'REAL'],
  ['location_name', 'TEXT'],
  ['location_address', 'TEXT'],
  ['location_url', 'TEXT'],
  ['interactive_id', 'TEXT'],
  ['interactive_title', 'TEXT'],
  ['flow_token', 'TEXT'],
  ['flow_response', 'TEXT'],
  ['reaction_emoji', 'TEXT'],
  ['reaction_to', 'TEXT'],
  ['system_type', 'TEXT'],
  ['system_new_wa_id', 'TEXT'],
  ['system_body', 'TEXT'],
  ['contacts_json', 'TEXT'],
  ['order_json', 'TEXT'],
  ['poll_json', 'TEXT'],
  ['referral_json', 'TEXT'],
  ['forwarded', 'INTEGER'],
  ['phone_number_id', 'TEXT'],
  ['conversation_category', 'TEXT'],
  ['pricing_category', 'TEXT'],
  ['payload_hash', 'TEXT'],
  ['edited_at', 'TEXT'],
];

export const WHATSAPP_CONTACT_COLUMNS = [
  ['window_expires_at', 'TEXT'],
];

let schemaReady = false;

// SQLite exposes table_info both as a PRAGMA and as a table-valued function.
// D1 accepts the function form everywhere; the PRAGMA form is tried next, and
// if neither answers we simply attempt the ALTER and ignore "duplicate column".
async function listColumns(env, table) {
  try {
    const r = await env.DB.prepare('SELECT name FROM pragma_table_info(?)').bind(table).all();
    if (r && Array.isArray(r.results)) return new Set(r.results.map(function (x) { return x.name; }));
  } catch (_) { /* fall through */ }
  try {
    const r = await env.DB.prepare('PRAGMA table_info(' + table + ')').all();
    if (r && Array.isArray(r.results)) return new Set(r.results.map(function (x) { return x.name; }));
  } catch (_) { /* fall through */ }
  return null;
}

async function addMissingColumns(env, table, columns, added, steps) {
  const existing = await listColumns(env, table);
  if (existing) {
    for (const [column, type] of columns) {
      if (existing.has(column)) continue;
      await env.DB.exec('ALTER TABLE ' + table + ' ADD COLUMN ' + column + ' ' + type);
      added.push(table + '.' + column);
    }
    return;
  }
  // Column list unknown: try each ALTER, keep going when the column is already there.
  steps.push({ step: 'list_columns:' + table, ok: false, error: 'could not read column list, tried ALTER directly' });
  for (const [column, type] of columns) {
    try {
      await env.DB.exec('ALTER TABLE ' + table + ' ADD COLUMN ' + column + ' ' + type);
      added.push(table + '.' + column);
    } catch (_) { /* already exists */ }
  }
}

// Every step is reported, so a failure says exactly which statement broke
// instead of surfacing as a blank 500.
export async function runWhatsappMigrations(env) {
  const steps = [];
  const added = [];

  try {
    await env.DB.exec(WHATSAPP_TABLES_SQL);
    steps.push({ step: 'create_tables', ok: true });
  } catch (err) {
    steps.push({ step: 'create_tables', ok: false, error: err && err.message ? err.message : String(err) });
    return { ok: false, steps: steps, tables: [], added_columns: added, failed_indexes: [] };
  }

  try {
    await addMissingColumns(env, 'wa_messages', WHATSAPP_MESSAGE_COLUMNS, added, steps);
    await addMissingColumns(env, 'wa_contacts', WHATSAPP_CONTACT_COLUMNS, added, steps);
    steps.push({ step: 'add_missing_columns', ok: true });
  } catch (err) {
    steps.push({ step: 'add_missing_columns', ok: false, error: err && err.message ? err.message : String(err) });
  }

  // Indexes last: they depend on columns that may only just have been added.
  const failedIndexes = [];
  for (const statement of WHATSAPP_INDEX_SQL) {
    try {
      await env.DB.exec(statement);
    } catch (err) {
      failedIndexes.push({ statement: statement, error: err && err.message ? err.message : String(err) });
    }
  }
  steps.push({ step: 'create_indexes', ok: failedIndexes.length === 0, error: failedIndexes.length ? JSON.stringify(failedIndexes) : undefined });

  let tables = [];
  try {
    const r = await env.DB.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'wa_%' ORDER BY name").all();
    tables = (r.results || []).map(function (x) { return x.name; });
    steps.push({ step: 'list_tables', ok: true });
  } catch (err) {
    steps.push({ step: 'list_tables', ok: false, error: err && err.message ? err.message : String(err) });
  }

  return {
    ok: steps.every(function (s) { return s.ok; }),
    tables: tables,
    added_columns: added,
    failed_indexes: failedIndexes,
    steps: steps,
    ran_at: new Date().toISOString(),
  };
}

// A schema problem must never turn a working route into a 500: log it and carry
// on, because the tables are usually already there.
export async function ensureWhatsappSchema(env) {
  if (schemaReady) return;
  try {
    const report = await runWhatsappMigrations(env);
    if (report.ok) schemaReady = true;
    else console.error('whatsapp schema not fully applied', JSON.stringify(report.steps));
  } catch (err) {
    console.error('whatsapp schema check failed', err && err.message ? err.message : err);
  }
}

export async function ensureWhatsappSchemaForced(env) {
  return await runWhatsappMigrations(env);
}
