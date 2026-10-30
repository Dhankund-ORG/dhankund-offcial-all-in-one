// Cloudflare account-to-account migration helpers.
// All functions in this file are stateless: credentials are passed in, used for
// the outbound request, and never written to D1, logs, or R2.

const CF_API = 'https://api.cloudflare.com/client/v4';
const MAX_D1_BYTES = 90 * 1024 * 1024;
// A Worker has 128 MB of memory. Keep each object small enough that the
// downloaded blob plus the outgoing upload fit comfortably.
const MAX_R2_OBJECT_BYTES = 50 * 1024 * 1024;
const MAX_R2_BATCH_BYTES = 96 * 1024 * 1024;
const R2_BATCH_TIME_MS = 20000;

export class CloudflareError extends Error {
  constructor(message, status) {
    super(message);
    this.name = 'CloudflareError';
    this.status = status || 502;
  }
}

export function sanitizeMessage(message) {
  return String(message == null ? 'Cloudflare request failed' : message)
    .replace(/Bearer\s+[A-Za-z0-9._~+\/=-]+/gi, 'Bearer ***')
    .replace(/(api[_-]?token|authorization)["']?\s*[:=]\s*["']?[A-Za-z0-9._~+\/=-]{20,}/gi, '$1: ***')
    .slice(0, 600);
}

export function accountFrom(input, label) {
  const src = input || {};
  const accountId = (src.account_id || src.accountId || '').toString().trim();
  const apiToken = (src.api_token || src.apiToken || src.token || '').toString().trim();
  const prefix = label ? label + ': ' : '';
  if (!/^[a-f0-9]{32}$/i.test(accountId)) {
    throw new CloudflareError(prefix + 'invalid Cloudflare account ID (32 hex characters required)', 400);
  }
  if (apiToken.length < 20) {
    throw new CloudflareError(prefix + 'Cloudflare API token is required', 400);
  }
  return { account_id: accountId, api_token: apiToken };
}

export function encodeObjectKey(key) {
  return String(key == null ? '' : key)
    .split('/')
    .map(function (part) { return encodeURIComponent(part); })
    .join('/');
}

export function isAllowedSignedUrl(value) {
  let url;
  try {
    url = new URL(String(value));
  } catch (e) {
    return false;
  }
  if (url.protocol !== 'https:') return false;
  const host = url.hostname.toLowerCase();
  return host.endsWith('.r2.cloudflarestorage.com') ||
    host.endsWith('.cloudflare.com') ||
    host.endsWith('.r2.dev') ||
    host.endsWith('.workers.dev');
}

export function bucketFrom(value, label) {
  const name = (value || '').toString().trim();
  if (!/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/.test(name)) {
    throw new CloudflareError((label || 'R2 bucket') + ': invalid R2 bucket name', 400);
  }
  return name;
}

async function cfJson(account, path, options) {
  const opts = options || {};
  const headers = Object.assign({ Authorization: 'Bearer ' + account.api_token }, opts.headers || {});
  let body = opts.body;
  if (body !== undefined && !(body instanceof FormData) && typeof body !== 'string' && !(body instanceof ArrayBuffer) && !(body instanceof Uint8Array)) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(body);
  }
  const res = await fetch(CF_API + path, { method: opts.method || 'GET', headers: headers, body: body });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch (e) {}
  if (!res.ok || !json || json.success === false) {
    const first = json && Array.isArray(json.errors) && json.errors.length ? json.errors[0] : null;
    const message = first
      ? (first.message + (first.code ? ' [code: ' + first.code + ']' : ''))
      : ('Cloudflare API HTTP ' + res.status);
    throw new CloudflareError(sanitizeMessage(message), res.status >= 400 && res.status < 500 ? 400 : 502);
  }
  return json;
}

async function cfRaw(account, path) {
  const res = await fetch(CF_API + path, {
    method: 'GET',
    headers: { Authorization: 'Bearer ' + account.api_token },
  });
  if (!res.ok) {
    let message = 'Cloudflare API HTTP ' + res.status;
    try {
      const json = await res.json();
      if (json && Array.isArray(json.errors) && json.errors.length) message = json.errors[0].message;
    } catch (e) {}
    throw new CloudflareError(sanitizeMessage(message), res.status >= 400 && res.status < 500 ? 400 : 502);
  }
  return res;
}

// ---------- Accounts ----------

export async function cfValidateAccount(input) {
  const account = accountFrom(input, 'Account');
  const details = await cfJson(account, '/accounts/' + account.account_id);
  let tokenStatus = 'unknown';
  try {
    const verify = await cfJson(account, '/accounts/' + account.account_id + '/tokens/verify');
    tokenStatus = (verify.result && verify.result.status) || tokenStatus;
  } catch (e) {
    try {
      const verify = await cfJson(account, '/user/tokens/verify');
      tokenStatus = (verify.result && verify.result.status) || tokenStatus;
    } catch (e2) {}
  }
  return {
    account_id: account.account_id,
    name: (details.result && details.result.name) || null,
    token_status: tokenStatus,
  };
}

// ---------- D1 ----------

export async function d1Query(account, databaseId, sql, params) {
  const dbId = (databaseId || '').toString().trim();
  if (!dbId) throw new CloudflareError('D1 database ID is required', 400);
  const json = await cfJson(account, '/accounts/' + account.account_id + '/d1/database/' + dbId + '/query', {
    method: 'POST',
    body: { sql: sql, params: params || [] },
  });
  const item = Array.isArray(json.result) ? json.result[0] : json.result;
  if (!item || item.success === false) {
    const message = (item && item.error) || 'D1 query failed';
    throw new CloudflareError(sanitizeMessage(message), 400);
  }
  return item.results || [];
}

export async function d1ListTables(account, databaseId) {
  const rows = await d1Query(account, databaseId,
    "SELECT name FROM sqlite_schema WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name <> '_cf_KV' ORDER BY name");
  return rows.map(function (row) { return String(row.name); });
}

export async function d1Info(input, databaseId) {
  const account = accountFrom(input, 'Account');
  const dbId = (databaseId || '').toString().trim();
  if (!dbId) throw new CloudflareError('D1 database ID is required', 400);
  const json = await cfJson(account, '/accounts/' + account.account_id + '/d1/database/' + dbId);
  const tables = await d1ListTables(account, dbId);
  return { database: json.result || {}, tables: tables };
}

function quoteIdent(value) {
  return '"' + String(value == null ? '' : value).replace(/"/g, '""') + '"';
}

function sqlString(value) {
  return "'" + String(value == null ? '' : value).replace(/'/g, "''") + "'";
}

function normalizeColumnType(value) {
  return String(value == null ? '' : value).trim().toUpperCase().replace(/\s+/g, '');
}

async function d1RowCounts(account, databaseId, tableNames) {
  const names = (tableNames || []).filter(Boolean);
  if (!names.length) return {};
  const sql = names.map(function (name) {
    return 'SELECT ' + sqlString(name) + ' AS table_name, COUNT(*) AS n FROM ' + quoteIdent(name);
  }).join(' UNION ALL ');
  const rows = await d1Query(account, databaseId, sql);
  const counts = {};
  for (const row of rows) counts[String(row.table_name)] = Number(row.n) || 0;
  return counts;
}

// Reads the full table/view/column/index/trigger shape of a D1 database.
// The column query uses pragma_table_info as a table-valued function so a
// database with many tables still fits in a small number of API calls.
async function d1Schema(account, databaseId) {
  const dbId = (databaseId || '').toString().trim();
  if (!dbId) throw new CloudflareError('D1 database ID is required', 400);

  const dbJson = await cfJson(account, '/accounts/' + account.account_id + '/d1/database/' + dbId);
  const database = dbJson.result || {};
  const objectRows = await d1Query(account, dbId,
    "SELECT name, type FROM sqlite_schema " +
    "WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%' AND name <> '_cf_KV' " +
    "ORDER BY CASE type WHEN 'view' THEN 1 ELSE 0 END, name");

  const objects = objectRows.map(function (row) {
    return {
      name: String(row.name),
      type: row.type === 'view' ? 'view' : 'table',
      rows: null,
      columns: [],
      indexes: [],
      triggers: [],
    };
  });
  const byName = new Map();
  for (const object of objects) byName.set(String(object.name).toLowerCase(), object);

  let columnRows = null;
  try {
    columnRows = await d1Query(account, dbId,
      "SELECT m.name AS object_name, p.cid AS cid, p.name AS column_name, p.type AS column_type, " +
      "p.\"notnull\" AS not_null, p.dflt_value AS default_value, p.pk AS pk " +
      "FROM sqlite_schema AS m JOIN pragma_table_info(m.name) AS p " +
      "WHERE m.type IN ('table', 'view') AND m.name NOT LIKE 'sqlite_%' AND m.name <> '_cf_KV' " +
      "ORDER BY m.name, p.cid");
  } catch (e) {
    // Older/local SQLite builds may not accept the table-valued pragma form.
    // Fall back to one PRAGMA per object so preview still works.
    columnRows = [];
    for (const object of objects) {
      try {
        const rows = await d1Query(account, dbId,
          'SELECT cid, name, type, "notnull" AS not_null, dflt_value AS default_value, pk ' +
          'FROM pragma_table_info(' + sqlString(object.name) + ') ORDER BY cid');
        for (const row of rows) columnRows.push(Object.assign({ object_name: object.name }, row));
      } catch (e2) {}
    }
  }

  for (const row of columnRows) {
    const object = byName.get(String(row.object_name || '').toLowerCase());
    if (!object) continue;
    object.columns.push({
      cid: Number(row.cid) || 0,
      name: String(row.column_name || ''),
      type: String(row.column_type || ''),
      not_null: Number(row.not_null) ? true : false,
      default_value: row.default_value == null ? null : String(row.default_value),
      pk: Number(row.pk) || 0,
    });
  }

  const indexRows = await d1Query(account, dbId,
    "SELECT name, tbl_name, type FROM sqlite_schema " +
    "WHERE type IN ('index', 'trigger') AND sql IS NOT NULL ORDER BY name");
  for (const row of indexRows) {
    const object = byName.get(String(row.tbl_name || '').toLowerCase());
    if (!object) continue;
    if (row.type === 'trigger') object.triggers.push(String(row.name));
    else object.indexes.push(String(row.name));
  }

  const tableNames = objects.filter(function (object) { return object.type === 'table'; }).map(function (object) { return object.name; });
  if (tableNames.length) {
    try {
      const counts = await d1RowCounts(account, dbId, tableNames);
      for (const object of objects) {
        if (object.type !== 'table') continue;
        object.rows = Object.prototype.hasOwnProperty.call(counts, object.name) ? counts[object.name] : null;
      }
    } catch (e) {
      for (const name of tableNames) {
        try {
          const rows = await d1Query(account, dbId, 'SELECT COUNT(*) AS n FROM ' + quoteIdent(name));
          const object = byName.get(name.toLowerCase());
          if (object) object.rows = Number(rows[0] && rows[0].n) || 0;
        } catch (e2) {}
      }
    }
  }

  const totals = {
    tables: objects.filter(function (object) { return object.type === 'table'; }).length,
    views: objects.filter(function (object) { return object.type === 'view'; }).length,
    columns: objects.reduce(function (sum, object) { return sum + object.columns.length; }, 0),
    rows: objects.reduce(function (sum, object) { return sum + (object.rows || 0); }, 0),
    indexes: objects.reduce(function (sum, object) { return sum + object.indexes.length; }, 0),
    triggers: objects.reduce(function (sum, object) { return sum + object.triggers.length; }, 0),
  };

  return {
    database: {
      id: database.uuid || database.id || dbId,
      name: database.name || null,
      file_size: Number(database.file_size) || null,
      num_tables: Number(database.num_tables) || null,
    },
    objects: objects,
    totals: totals,
  };
}

// Compares source and destination schemas. A null destination means the
// destination database will be created, so every source table is "new".
export function buildD1Diff(sourceObjects, destinationObjects) {
  const source = Array.isArray(sourceObjects) ? sourceObjects : [];
  const hasDestination = Array.isArray(destinationObjects);
  const destination = hasDestination ? destinationObjects : [];

  const sourceByName = new Map();
  for (const object of source) sourceByName.set(String(object.name).toLowerCase(), object);
  const destinationByName = new Map();
  for (const object of destination) destinationByName.set(String(object.name).toLowerCase(), object);

  const missing_tables = [];
  const overlapping_tables = [];
  const missing_columns = [];
  const extra_columns = [];
  const type_mismatches = [];
  const column_order_mismatches = [];
  const missing_indexes = [];
  const missing_triggers = [];

  for (const sourceObject of source) {
    const destinationObject = destinationByName.get(String(sourceObject.name).toLowerCase());
    if (!destinationObject) {
      missing_tables.push(sourceObject.name);
      continue;
    }
    overlapping_tables.push(sourceObject.name);

    const sourceColumns = sourceObject.columns || [];
    const destinationColumns = destinationObject.columns || [];
    const sourceColumnMap = new Map();
    for (const column of sourceColumns) sourceColumnMap.set(String(column.name).toLowerCase(), column);
    const destinationColumnMap = new Map();
    for (const column of destinationColumns) destinationColumnMap.set(String(column.name).toLowerCase(), column);

    const missing = sourceColumns
      .filter(function (column) { return !destinationColumnMap.has(String(column.name).toLowerCase()); })
      .map(function (column) { return column.name; });
    if (missing.length) missing_columns.push({ table: sourceObject.name, columns: missing });

    const extra = destinationColumns
      .filter(function (column) { return !sourceColumnMap.has(String(column.name).toLowerCase()); })
      .map(function (column) { return column.name; });
    if (extra.length) extra_columns.push({ table: sourceObject.name, columns: extra });

    for (const column of sourceColumns) {
      const destinationColumn = destinationColumnMap.get(String(column.name).toLowerCase());
      if (destinationColumn && normalizeColumnType(column.type) !== normalizeColumnType(destinationColumn.type)) {
        type_mismatches.push({
          table: sourceObject.name,
          column: column.name,
          source: column.type || '',
          destination: destinationColumn.type || '',
        });
      }
    }

    const commonSource = sourceColumns
      .filter(function (column) { return destinationColumnMap.has(String(column.name).toLowerCase()); })
      .map(function (column) { return String(column.name).toLowerCase(); });
    const commonDestination = destinationColumns
      .filter(function (column) { return sourceColumnMap.has(String(column.name).toLowerCase()); })
      .map(function (column) { return String(column.name).toLowerCase(); });
    if (commonSource.length === commonDestination.length && commonSource.some(function (name, index) { return name !== commonDestination[index]; })) {
      column_order_mismatches.push({
        table: sourceObject.name,
        source: sourceColumns.map(function (column) { return column.name; }),
        destination: destinationColumns.map(function (column) { return column.name; }),
      });
    }

    const destinationIndexes = new Set((destinationObject.indexes || []).map(function (name) { return String(name).toLowerCase(); }));
    const missingIndexes = (sourceObject.indexes || []).filter(function (name) { return !destinationIndexes.has(String(name).toLowerCase()); });
    if (missingIndexes.length) missing_indexes.push({ table: sourceObject.name, indexes: missingIndexes });

    const destinationTriggers = new Set((destinationObject.triggers || []).map(function (name) { return String(name).toLowerCase(); }));
    const missingTriggers = (sourceObject.triggers || []).filter(function (name) { return !destinationTriggers.has(String(name).toLowerCase()); });
    if (missingTriggers.length) missing_triggers.push({ table: sourceObject.name, triggers: missingTriggers });
  }

  const extra_tables = destination
    .filter(function (object) { return !sourceByName.has(String(object.name).toLowerCase()); })
    .map(function (object) { return object.name; });

  const schema_match = hasDestination &&
    missing_tables.length === 0 &&
    missing_columns.length === 0 &&
    extra_columns.length === 0 &&
    type_mismatches.length === 0 &&
    column_order_mismatches.length === 0;

  return {
    destination_available: hasDestination,
    missing_tables: missing_tables,
    extra_tables: extra_tables,
    overlapping_tables: overlapping_tables,
    missing_columns: missing_columns,
    extra_columns: extra_columns,
    type_mismatches: type_mismatches,
    column_order_mismatches: column_order_mismatches,
    missing_indexes: missing_indexes,
    missing_triggers: missing_triggers,
    schema_match: schema_match,
    // Existing tables with the same name will collide with CREATE TABLE in
    // the export SQL, so a reset (or a new database) is required.
    safe_without_reset: !hasDestination || overlapping_tables.length === 0,
  };
}

export async function d1Plan(source, sourceDatabaseId, destination, destinationDatabaseId) {
  const sourceAccount = accountFrom(source, 'Source account');
  const sourceDbId = (sourceDatabaseId || '').toString().trim();
  if (!sourceDbId) throw new CloudflareError('Source D1 database ID is required', 400);

  const sourceSchema = await d1Schema(sourceAccount, sourceDbId);
  const destinationDbId = (destinationDatabaseId || '').toString().trim();
  let destinationSchema = null;
  let destinationError = null;

  if (destinationDbId) {
    try {
      const destinationAccount = accountFrom(destination, 'Destination account');
      destinationSchema = await d1Schema(destinationAccount, destinationDbId);
    } catch (e) {
      destinationError = sanitizeMessage(e && e.message);
    }
  }

  const diff = buildD1Diff(
    sourceSchema.objects,
    destinationSchema ? destinationSchema.objects : null,
  );
  const safeWithoutReset = !destinationDbId ||
    (!destinationError && diff.overlapping_tables.length === 0);
  const warnings = [];

  if (sourceSchema.database.file_size && sourceSchema.database.file_size > MAX_D1_BYTES) {
    warnings.push(
      'Source D1 reports ' + Math.round(sourceSchema.database.file_size / 1048576) +
      ' MB. The SQL export may exceed the 90 MB web limit; use wrangler for larger databases.');
  }
  if (destinationDbId && destinationError) {
    warnings.push('Destination D1 could not be inspected: ' + destinationError);
  }
  if (!destinationDbId) {
    warnings.push('Destination D1 is blank: a new database will be created and every source object will be created.');
  } else if (destinationSchema && destinationSchema.objects.length === 0) {
    warnings.push('Destination D1 is empty: no reset is needed.');
  }
  if (diff.overlapping_tables.length) {
    warnings.push(
      'Destination already contains ' + diff.overlapping_tables.length +
      ' table(s)/view(s) with the same name as source. Enable Reset or use a new destination database.');
  }
  if (diff.missing_columns.length) {
    warnings.push('Some destination tables are missing source columns; see the table list below.');
  }
  if (diff.extra_columns.length) {
    warnings.push('Some destination tables have extra columns; the import SQL may fail without Reset.');
  }
  if (diff.type_mismatches.length) {
    warnings.push('Some destination columns have a different declared type.');
  }
  if (diff.column_order_mismatches.length) {
    warnings.push('Some destination tables have columns in a different order; Reset is recommended.');
  }
  if (diff.extra_tables.length) {
    warnings.push('Destination has ' + diff.extra_tables.length + ' extra table(s)/view(s); they remain unless Reset is used.');
  }

  return {
    source: sourceSchema,
    destination: destinationSchema,
    destination_error: destinationError,
    diff: diff,
    safe_without_reset: safeWithoutReset,
    reset_required: !!destinationDbId && !destinationError && !safeWithoutReset,
    limits: { max_d1_bytes: MAX_D1_BYTES },
    warnings: warnings,
  };
}

export async function d1CreateDatabase(input, name) {
  const account = accountFrom(input, 'Destination account');
  const dbName = (name || '').toString().trim();
  if (!dbName) throw new CloudflareError('D1 database name is required', 400);
  const json = await cfJson(account, '/accounts/' + account.account_id + '/d1/database', {
    method: 'POST',
    body: { name: dbName },
  });
  const result = json.result || {};
  return { uuid: result.uuid || result.id || null, name: result.name || dbName };
}

export async function d1ResetTables(input, databaseId) {
  const account = accountFrom(input, 'Destination account');
  const dbId = (databaseId || '').toString().trim();
  if (!dbId) throw new CloudflareError('D1 database ID is required', 400);
  const objects = await d1Query(account, dbId,
    "SELECT name, type FROM sqlite_schema " +
    "WHERE type IN ('view', 'table') AND name NOT LIKE 'sqlite_%' AND name <> '_cf_KV' " +
    "ORDER BY CASE type WHEN 'view' THEN 0 ELSE 1 END, name");
  const dropped = [];
  for (const object of objects) {
    const name = String(object.name || '');
    if (!name) continue;
    const type = object.type === 'view' ? 'VIEW' : 'TABLE';
    await d1Query(account, dbId, 'DROP ' + type + ' IF EXISTS "' + name.replace(/"/g, '""') + '"');
    dropped.push(name);
  }
  return dropped;
}

export async function d1ExportPoll(input, databaseId, bookmark) {
  const account = accountFrom(input, 'Source account');
  const dbId = (databaseId || '').toString().trim();
  if (!dbId) throw new CloudflareError('D1 database ID is required', 400);
  const body = { output_format: 'polling' };
  if (bookmark) body.current_bookmark = bookmark;
  const json = await cfJson(account, '/accounts/' + account.account_id + '/d1/database/' + dbId + '/export', {
    method: 'POST',
    body: body,
  });
  const result = json.result || {};
  return {
    status: result.status || 'in_progress',
    bookmark: result.at_bookmark || bookmark || null,
    signed_url: (result.result && result.result.signed_url) || null,
    filename: (result.result && result.result.filename) || null,
    error: result.error || null,
    messages: result.messages || [],
  };
}

async function downloadSql(signedUrl) {
  if (!isAllowedSignedUrl(signedUrl)) {
    throw new CloudflareError('Invalid D1 export download URL', 400);
  }
  const res = await fetch(signedUrl);
  if (!res.ok) {
    throw new CloudflareError('Failed to download D1 export (HTTP ' + res.status + ')', 502);
  }
  const declared = Number(res.headers.get('content-length') || 0);
  if (declared && declared > MAX_D1_BYTES) {
    throw new CloudflareError(
      'D1 export is ' + Math.round(declared / 1048576) + ' MB. The web migration tool supports up to ' +
      Math.round(MAX_D1_BYTES / 1048576) + ' MB. Use the wrangler CLI for larger databases.', 400);
  }
  const bytes = await res.arrayBuffer();
  if (bytes.byteLength > MAX_D1_BYTES) {
    throw new CloudflareError(
      'D1 export is ' + Math.round(bytes.byteLength / 1048576) + ' MB. The web migration tool supports up to ' +
      Math.round(MAX_D1_BYTES / 1048576) + ' MB. Use the wrangler CLI for larger databases.', 400);
  }
  return bytes;
}

function normalizeImport(result) {
  const payload = result || {};
  const meta = (payload.result && payload.result.meta) || null;
  return {
    status: payload.status || 'in_progress',
    bookmark: payload.at_bookmark || null,
    error: payload.error || null,
    filename: payload.filename || null,
    num_queries: (payload.result && payload.result.num_queries) || 0,
    meta: meta,
    messages: payload.messages || [],
  };
}

export async function d1ImportStart(input, databaseId, signedUrl, reset) {
  const account = accountFrom(input, 'Destination account');
  const dbId = (databaseId || '').toString().trim();
  if (!dbId) throw new CloudflareError('D1 database ID is required', 400);
  if (!signedUrl) throw new CloudflareError('D1 export signed URL is required', 400);

  // Download the export first: if the download fails, the destination database
  // must not have been reset.
  const bytes = await downloadSql(signedUrl);
  if (reset) await d1ResetTables(account, dbId);
  const etag = md5Hex(bytes);
  const path = '/accounts/' + account.account_id + '/d1/database/' + dbId + '/import';

  const init = await cfJson(account, path, {
    method: 'POST',
    body: { action: 'init', etag: etag },
  });
  const initResult = init.result || {};
  const uploadUrl = initResult.upload_url;
  const filename = initResult.filename;
  if (!uploadUrl || !filename) {
    throw new CloudflareError('D1 import did not return an upload URL', 502);
  }

  const upload = await fetch(uploadUrl, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/octet-stream' },
    body: bytes,
  });
  if (!upload.ok) {
    throw new CloudflareError('Failed to upload SQL to D1 (HTTP ' + upload.status + ')', 502);
  }

  const ingest = await cfJson(account, path, {
    method: 'POST',
    body: { action: 'ingest', etag: etag, filename: filename },
  });
  return normalizeImport(ingest.result || {});
}

export async function d1ImportPoll(input, databaseId, bookmark) {
  const account = accountFrom(input, 'Destination account');
  const dbId = (databaseId || '').toString().trim();
  if (!dbId) throw new CloudflareError('D1 database ID is required', 400);
  if (!bookmark) throw new CloudflareError('D1 import bookmark is required', 400);
  const json = await cfJson(account, '/accounts/' + account.account_id + '/d1/database/' + dbId + '/import', {
    method: 'POST',
    body: { action: 'poll', current_bookmark: bookmark },
  });
  return normalizeImport(json.result || {});
}

export async function d1Compare(source, sourceDatabaseId, destination, destinationDatabaseId) {
  const sourceAccount = accountFrom(source, 'Source account');
  const destinationAccount = accountFrom(destination, 'Destination account');
  const sourceTables = await d1ListTables(sourceAccount, sourceDatabaseId);
  const destinationTables = await d1ListTables(destinationAccount, destinationDatabaseId);
  const names = Array.from(new Set(sourceTables.concat(destinationTables))).sort();
  if (!names.length) return [];

  // One UNION ALL query per database instead of one COUNT per table keeps the
  // number of Worker subrequests small even for large schemas.
  const sourceCounts = await d1RowCounts(sourceAccount, sourceDatabaseId, sourceTables);
  const destinationCounts = await d1RowCounts(destinationAccount, destinationDatabaseId, destinationTables);

  return names.map(function (name) {
    const sourceCount = Object.prototype.hasOwnProperty.call(sourceCounts, name) ? sourceCounts[name] : null;
    const destinationCount = Object.prototype.hasOwnProperty.call(destinationCounts, name) ? destinationCounts[name] : null;
    return {
      table: name,
      source: sourceCount,
      destination: destinationCount,
      match: sourceCount !== null && sourceCount === destinationCount,
    };
  });
}

// ---------- R2 ----------

export async function r2ListObjects(input, bucket, options) {
  const account = accountFrom(input, 'Account');
  const bucketName = bucketFrom(bucket, 'R2 bucket');
  const opts = options || {};
  const perPage = Math.max(1, Math.min(100, Number(opts.perPage) || 25));
  const query = new URLSearchParams();
  query.set('per_page', String(perPage));
  if (opts.cursor) query.set('cursor', String(opts.cursor));
  if (opts.prefix) query.set('prefix', String(opts.prefix));
  const json = await cfJson(account,
    '/accounts/' + account.account_id + '/r2/buckets/' + bucketName + '/objects?' + query.toString());
  const info = json.result_info || {};
  return {
    objects: Array.isArray(json.result) ? json.result : [],
    cursor: info.cursor || null,
    is_truncated: !!info.is_truncated,
  };
}

export async function r2GetObject(input, bucket, key) {
  const account = accountFrom(input, 'Source account');
  const bucketName = bucketFrom(bucket, 'Source R2 bucket');
  const res = await cfRaw(account,
    '/accounts/' + account.account_id + '/r2/buckets/' + bucketName + '/objects/' + encodeObjectKey(key));
  const declared = Number(res.headers.get('content-length') || 0);
  if (declared && declared > MAX_R2_OBJECT_BYTES) {
    throw new CloudflareError(
      'Object "' + key + '" is ' + Math.round(declared / 1048576) + ' MB. The web migration tool supports up to ' +
      Math.round(MAX_R2_OBJECT_BYTES / 1048576) + ' MB per object. Use the R2 S3 API or rclone for larger files.', 400);
  }
  // Use blob() instead of arrayBuffer() so the bytes are only buffered once.
  const blob = await res.blob();
  if (blob.size > MAX_R2_OBJECT_BYTES) {
    throw new CloudflareError(
      'Object "' + key + '" is ' + Math.round(blob.size / 1048576) + ' MB. The web migration tool supports up to ' +
      Math.round(MAX_R2_OBJECT_BYTES / 1048576) + ' MB per object. Use the R2 S3 API or rclone for larger files.', 400);
  }
  return {
    blob: blob,
    size: blob.size,
    contentType: res.headers.get('content-type') || blob.type || 'application/octet-stream',
  };
}

export async function r2PutObject(input, bucket, key, object) {
  const account = accountFrom(input, 'Destination account');
  const bucketName = bucketFrom(bucket, 'Destination R2 bucket');
  const data = object || {};
  const contentType = data.contentType || 'application/octet-stream';
  const blob = data.blob || new Blob([data.bytes || new Uint8Array(0)], { type: contentType });
  // The R2 REST API accepts the raw object body. Sending the Blob directly
  // avoids an extra multipart copy of large files in the Worker's memory.
  const res = await fetch(CF_API + '/accounts/' + account.account_id + '/r2/buckets/' + bucketName + '/objects/' + encodeObjectKey(key), {
    method: 'PUT',
    headers: {
      Authorization: 'Bearer ' + account.api_token,
      'Content-Type': contentType,
    },
    body: blob,
  });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch (e) {}
  if (!res.ok || !json || json.success === false) {
    const first = json && Array.isArray(json.errors) && json.errors.length ? json.errors[0] : null;
    throw new CloudflareError(
      sanitizeMessage('R2 upload failed for "' + key + '": ' + (first ? first.message : 'HTTP ' + res.status)), 502);
  }
  return json.result || {};
}

export async function r2CreateBucket(input, name) {
  const account = accountFrom(input, 'Destination account');
  const bucketName = bucketFrom(name, 'R2 bucket');
  try {
    const json = await cfJson(account, '/accounts/' + account.account_id + '/r2/buckets', {
      method: 'POST',
      body: { name: bucketName },
    });
    return json.result || { name: bucketName };
  } catch (e) {
    if (/already exists|already owned|already created|10004/i.test((e && e.message) || '')) {
      return { name: bucketName, existing: true };
    }
    throw e;
  }
}

// The listing page size is fixed so that a cursor stays valid while the client
// resumes a partially processed page with `skip`.
const R2_PAGE_SIZE = 50;

export async function r2CopyBatch(source, sourceBucket, destination, destinationBucket, options) {
  const sourceAccount = accountFrom(source, 'Source account');
  const destinationAccount = accountFrom(destination, 'Destination account');
  const sourceBucketName = bucketFrom(sourceBucket, 'Source R2 bucket');
  const destinationBucketName = bucketFrom(destinationBucket, 'Destination R2 bucket');
  const opts = options || {};
  const cursor = opts.cursor ? String(opts.cursor) : null;
  const startSkip = Math.max(0, Math.min(R2_PAGE_SIZE - 1, Number(opts.skip) || 0));
  const maxObjects = Math.max(1, Math.min(25, Number(opts.limit) || 10));
  const startedAt = Date.now();

  const page = await r2ListObjects(sourceAccount, sourceBucketName, { cursor: cursor, perPage: R2_PAGE_SIZE });
  let copied = 0;
  let skipped = 0;
  let bytes = 0;
  let consumed = 0;
  const errors = [];
  const oversized = [];

  for (let index = startSkip; index < page.objects.length; index++) {
    if (copied + skipped + errors.length >= maxObjects) {
      break;
    }
    if (consumed > 0 && Date.now() - startedAt > R2_BATCH_TIME_MS) {
      break;
    }
    const object = page.objects[index];
    const key = object && object.key;
    if (!key) {
      consumed += 1;
      continue;
    }
    const size = Number(object.size) || 0;
    if (key.endsWith('/') && size === 0) {
      consumed += 1;
      skipped += 1;
      continue;
    }
    if (copied > 0 && bytes + size > MAX_R2_BATCH_BYTES) {
      // Leave this object for the next request; resume from the same cursor.
      break;
    }
    consumed += 1;
    if (size > MAX_R2_OBJECT_BYTES) {
      // Oversized objects are deliberately skipped, not retried: they are
      // listed in the migration plan and must be moved with rclone instead.
      skipped += 1;
      oversized.push({
        key: key,
        size: size,
        error: 'Object is ' + Math.round(size / 1048576) + ' MB; skipped because the web tool supports up to ' +
          Math.round(MAX_R2_OBJECT_BYTES / 1048576) + ' MB per object. Use rclone for this file.',
      });
      continue;
    }
    try {
      const data = await r2GetObject(sourceAccount, sourceBucketName, key);
      await r2PutObject(destinationAccount, destinationBucketName, key, data);
      copied += 1;
      bytes += data.size;
    } catch (e) {
      errors.push({ key: key, error: sanitizeMessage(e && e.message) });
    }
  }

  const pageFinished = startSkip + consumed >= page.objects.length;
  const nextCursor = pageFinished ? (page.is_truncated ? page.cursor : null) : cursor;
  const nextSkip = pageFinished ? 0 : startSkip + consumed;

  return {
    copied: copied,
    skipped: skipped,
    failed: errors.length,
    bytes: bytes,
    errors: errors.slice(0, 20),
    oversized: oversized.slice(0, 20),
    next_cursor: nextCursor,
    next_skip: nextSkip,
    done: nextCursor === null && nextSkip === 0,
  };
}

export async function r2Compare(source, sourceBucket, destination, destinationBucket, maxPages) {
  const sourceAccount = accountFrom(source, 'Source account');
  const destinationAccount = accountFrom(destination, 'Destination account');
  const sourceBucketName = bucketFrom(sourceBucket, 'Source R2 bucket');
  const destinationBucketName = bucketFrom(destinationBucket, 'Destination R2 bucket');
  const max = Math.max(1, Math.min(50, Number(maxPages) || 20));

  async function listing(account, bucketName) {
    const map = new Map();
    let cursor = null;
    let count = 0;
    let bytes = 0;
    let pages = 0;
    let truncated = false;
    while (pages < max) {
      const page = await r2ListObjects(account, bucketName, { cursor: cursor, perPage: 100 });
      pages += 1;
      for (const object of page.objects) {
        if (!object || !object.key) continue;
        count += 1;
        bytes += Number(object.size) || 0;
        map.set(String(object.key), Number(object.size) || 0);
      }
      if (!page.is_truncated || !page.cursor) {
        cursor = null;
        break;
      }
      cursor = page.cursor;
      if (pages >= max) truncated = true;
    }
    return { map: map, count: count, bytes: bytes, truncated: truncated };
  }

  const src = await listing(sourceAccount, sourceBucketName);
  const dest = await listing(destinationAccount, destinationBucketName);
  const missing = [];
  const size_mismatch = [];
  for (const entry of src.map.entries()) {
    if (!dest.map.has(entry[0])) missing.push(entry[0]);
    else if (dest.map.get(entry[0]) !== entry[1]) size_mismatch.push(entry[0]);
  }
  const extra = [];
  for (const key of dest.map.keys()) {
    if (!src.map.has(key)) extra.push(key);
  }

  return {
    source: { count: src.count, bytes: src.bytes, truncated: src.truncated },
    destination: { count: dest.count, bytes: dest.bytes, truncated: dest.truncated },
    missing: missing.slice(0, 50),
    size_mismatch: size_mismatch.slice(0, 50),
    extra: extra.slice(0, 50),
    match: !src.truncated && !dest.truncated && missing.length === 0 && size_mismatch.length === 0 && extra.length === 0,
  };
}

export async function r2CountObjects(input, bucket, maxPages) {
  const account = accountFrom(input, 'Account');
  const bucketName = bucketFrom(bucket, 'R2 bucket');
  const max = Math.max(1, Number(maxPages) || 20);
  let cursor = null;
  let count = 0;
  let bytes = 0;
  let pages = 0;
  let truncated = false;

  while (pages < max) {
    const page = await r2ListObjects(account, bucketName, { cursor: cursor, perPage: 100 });
    pages += 1;
    for (const object of page.objects) {
      count += 1;
      bytes += Number(object.size) || 0;
    }
    if (!page.is_truncated || !page.cursor) {
      cursor = null;
      break;
    }
    cursor = page.cursor;
    if (pages >= max) {
      truncated = true;
      break;
    }
  }

  return { count: count, bytes: bytes, truncated: truncated };
}

export async function r2Plan(input, bucket, options) {
  const account = accountFrom(input, 'Source account');
  const bucketName = bucketFrom(bucket, 'Source R2 bucket');
  const opts = options || {};
  const maxPages = Math.max(1, Math.min(50, Number(opts.maxPages) || 20));
  let cursor = null;
  let count = 0;
  let bytes = 0;
  let pages = 0;
  let truncated = false;
  const oversized = [];
  const largest = [];
  const sample = [];

  while (pages < maxPages) {
    const page = await r2ListObjects(account, bucketName, { cursor: cursor, perPage: 100 });
    pages += 1;
    for (const object of page.objects) {
      const key = object && object.key;
      if (!key) continue;
      const size = Number(object.size) || 0;
      count += 1;
      bytes += size;
      if (sample.length < 25) sample.push({ key: String(key), size: size });
      if (size > MAX_R2_OBJECT_BYTES) oversized.push({ key: String(key), size: size });
      largest.push({ key: String(key), size: size });
    }
    if (!page.is_truncated || !page.cursor) {
      cursor = null;
      break;
    }
    cursor = page.cursor;
    if (pages >= maxPages) {
      truncated = true;
      break;
    }
  }

  largest.sort(function (a, b) { return b.size - a.size; });
  const warnings = [];
  if (truncated) warnings.push('Only the first ' + (maxPages * 100) + ' objects were scanned; counts and warnings are partial.');
  if (oversized.length) warnings.push(oversized.length + ' object(s) exceed the 50 MB per-object limit and will be skipped during copy.');
  if (count === 0) warnings.push('The source R2 bucket is empty.');

  return {
    bucket: bucketName,
    count: count,
    bytes: bytes,
    pages: pages,
    truncated: truncated,
    oversized: oversized.slice(0, 50),
    largest: largest.slice(0, 10),
    sample: sample,
    limits: {
      max_object_bytes: MAX_R2_OBJECT_BYTES,
      batch_bytes: MAX_R2_BATCH_BYTES,
      batch_time_ms: R2_BATCH_TIME_MS,
      page_size: R2_PAGE_SIZE,
    },
    warnings: warnings,
  };
}

// ---------- MD5 (required by the D1 import API for the etag) ----------

const MD5_SHIFTS = [7, 12, 17, 22, 5, 9, 14, 20, 4, 11, 16, 23, 6, 10, 15, 21];
const MD5_K = new Uint32Array(64);
for (let i = 0; i < 64; i++) {
  MD5_K[i] = Math.floor(Math.abs(Math.sin(i + 1)) * 0x100000000) >>> 0;
}

function md5Transform(state, view, offset) {
  const words = new Uint32Array(16);
  for (let i = 0; i < 16; i++) {
    words[i] = view.getUint32(offset + i * 4, true);
  }
  let a = state[0];
  let b = state[1];
  let c = state[2];
  let d = state[3];
  for (let i = 0; i < 64; i++) {
    let f;
    let g;
    if (i < 16) {
      f = (b & c) | (~b & d);
      g = i;
    } else if (i < 32) {
      f = (d & b) | (~d & c);
      g = (5 * i + 1) % 16;
    } else if (i < 48) {
      f = b ^ c ^ d;
      g = (3 * i + 5) % 16;
    } else {
      f = c ^ (b | ~d);
      g = (7 * i) % 16;
    }
    const sum = (f + a + MD5_K[i] + words[g]) >>> 0;
    a = d;
    d = c;
    c = b;
    const shift = MD5_SHIFTS[(i >> 4) * 4 + (i % 4)];
    b = (b + ((sum << shift) | (sum >>> (32 - shift)))) >>> 0;
  }
  state[0] = (state[0] + a) >>> 0;
  state[1] = (state[1] + b) >>> 0;
  state[2] = (state[2] + c) >>> 0;
  state[3] = (state[3] + d) >>> 0;
}

// Streaming implementation: no full padded copy of the input is allocated, so
// a near-100 MB D1 export stays within a Worker's memory limit.
export function md5Hex(buffer) {
  const bytes = buffer instanceof Uint8Array ? buffer : new Uint8Array(buffer);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const state = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476];

  const fullBlocks = Math.floor(bytes.length / 64);
  for (let i = 0; i < fullBlocks; i++) {
    md5Transform(state, view, i * 64);
  }

  const remainder = bytes.length - fullBlocks * 64;
  const finalLength = remainder < 56 ? 64 : 128;
  const tail = new Uint8Array(finalLength);
  tail.set(bytes.subarray(fullBlocks * 64));
  tail[remainder] = 0x80;
  const tailView = new DataView(tail.buffer);
  const bitLength = bytes.length * 8;
  tailView.setUint32(finalLength - 8, bitLength >>> 0, true);
  tailView.setUint32(finalLength - 4, Math.floor(bitLength / 0x100000000) >>> 0, true);
  for (let offset = 0; offset < finalLength; offset += 64) {
    md5Transform(state, tailView, offset);
  }

  const out = new Uint8Array(16);
  const outView = new DataView(out.buffer);
  outView.setUint32(0, state[0], true);
  outView.setUint32(4, state[1], true);
  outView.setUint32(8, state[2], true);
  outView.setUint32(12, state[3], true);
  return Array.from(out).map(function (byte) { return byte.toString(16).padStart(2, '0'); }).join('');
}
