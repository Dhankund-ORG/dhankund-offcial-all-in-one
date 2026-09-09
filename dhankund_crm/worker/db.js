export async function all(env, sql, params) {
  const stmt = env.DB.prepare(sql).bind(...(params || []));
  const result = await stmt.all();
  return result.results || [];
}

export async function first(env, sql, params) {
  const rows = await all(env, sql, params);
  return rows.length ? rows[0] : null;
}

export async function run(env, sql, params) {
  const stmt = env.DB.prepare(sql).bind(...(params || []));
  return await stmt.run();
}

export async function insertRow(env, table, obj) {
  const keys = Object.keys(obj);
  if (!keys.length) throw new Error('insertRow: empty object');
  const sql = 'INSERT INTO ' + table + ' (' + keys.join(', ') + ') VALUES (' + keys.map(function () { return '?'; }).join(', ') + ')';
  return await run(env, sql, keys.map(function (k) { return obj[k]; }));
}

export async function updateRow(env, table, idField, idValue, obj) {
  const keys = Object.keys(obj);
  if (!keys.length) throw new Error('updateRow: empty object');
  const sql = 'UPDATE ' + table + ' SET ' + keys.map(function (k) { return k + ' = ?'; }).join(', ') + ' WHERE ' + idField + ' = ?';
  return await run(env, sql, keys.map(function (k) { return obj[k]; }).concat([idValue]));
}

export function safeJson(str, fallback) {
  if (str == null) return fallback;
  try { return JSON.parse(str); } catch (e) { return fallback; }
}

export function nowIso() {
  return new Date().toISOString();
}

export function randomId() {
  return crypto.randomUUID();
}
