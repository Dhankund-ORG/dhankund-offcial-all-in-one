// WhatsApp tables. Additive only: nothing here touches an existing table,
// so CRM, DSA and the website keep working while this ships.

export const WHATSAPP_SCHEMA_SQL = `
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

CREATE INDEX IF NOT EXISTS idx_wa_messages_phone ON wa_messages (phone_e164, created_at);
CREATE INDEX IF NOT EXISTS idx_wa_messages_status ON wa_messages (status);
CREATE INDEX IF NOT EXISTS idx_wa_messages_broadcast ON wa_messages (broadcast_id);
CREATE INDEX IF NOT EXISTS idx_wa_messages_kind ON wa_messages (kind);
CREATE INDEX IF NOT EXISTS idx_wa_contacts_optin ON wa_contacts (opt_in_status);
CREATE INDEX IF NOT EXISTS idx_wa_contacts_updated ON wa_contacts (updated_at);
CREATE INDEX IF NOT EXISTS idx_wa_templates_name ON wa_templates (name, language);
CREATE INDEX IF NOT EXISTS idx_wa_recipients_broadcast ON wa_broadcast_recipients (broadcast_id, status);
CREATE INDEX IF NOT EXISTS idx_wa_broadcasts_status ON wa_broadcasts (status, created_at);
`;

// Columns added after the first release. Each one is applied with ALTER TABLE
// and a swallowed error, so an older database upgrades in place and a fresh one
// simply skips them.
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

let schemaReady = false;

// Idempotent, cheap after the first call in an isolate.
export async function ensureWhatsappSchema(env) {
  if (schemaReady) return;
  await env.DB.exec(WHATSAPP_SCHEMA_SQL);
  for (const [column, type] of WHATSAPP_MESSAGE_COLUMNS) {
    try {
      await env.DB.exec('ALTER TABLE wa_messages ADD COLUMN ' + column + ' ' + type);
    } catch (_) {
      // already there
    }
  }
  schemaReady = true;
}

export async function ensureWhatsappSchemaForced(env) {
  await env.DB.exec(WHATSAPP_SCHEMA_SQL);
  for (const [column, type] of WHATSAPP_MESSAGE_COLUMNS) {
    try {
      await env.DB.exec('ALTER TABLE wa_messages ADD COLUMN ' + column + ' ' + type);
    } catch (_) {
      // already there
    }
  }
}
