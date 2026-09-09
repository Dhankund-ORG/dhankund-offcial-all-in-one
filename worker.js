import { Hono } from 'hono';
import { all, first, run, insertRow, updateRow, safeJson, nowIso, randomId } from './worker/db.js';
import { hashPassword, verifyPassword, signSession, verifySession } from './worker/auth.js';
import { sendFcm } from './worker/fcm.js';
import { routeIndex, openApiSpec, docsHtml } from './worker/openapi.js';

const app = new Hono();

app.use('*', async function (c, next) {
  c.header('Access-Control-Allow-Origin', '*');
  c.header('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  c.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (c.req.method === 'OPTIONS') return c.text('', 204);
  await next();
});

app.onError(function (err, c) {
  console.error('API error', err);
  const message = (err && err.message) ? err.message : 'Internal Server Error';
  return c.json({ error: message }, 500);
});

async function readJson(c) {
  try { return await c.req.json(); } catch (e) { return {}; }
}

function roleKey(role) {
  const r = (role || '').toLowerCase();
  if (r === 'dsa') return 'dsa';
  if (r === 'banker') return 'banker';
  if (r === 'partner' || r === 'builder' || r === 'connector') return 'partner';
  if (r === 'customer') return 'customer';
  return 'partner';
}

function isAdminRole(role) {
  const r = (role || '').toLowerCase();
  return r === 'admin' || r === 'staff';
}

async function _verify(c) {
  const header = c.req.header('Authorization') || '';
  const token = header.indexOf('Bearer ') === 0 ? header.slice(7) : '';
  if (!token) return null;
  const payload = await verifySession(token, c.env.SESSION_SECRET || '');
  if (!payload) return null;
  return payload;
}

const auth = async function (c, next) {
  const payload = await _verify(c);
  if (!payload) return c.json({ error: 'Unauthorized' }, 401);
  c.set('user', payload);
  await next();
};

const requireAdmin = async function (c, next) {
  const payload = await _verify(c);
  if (!payload) return c.json({ error: 'Unauthorized' }, 401);
  if (!isAdminRole(payload.role)) return c.json({ error: 'Admin access required' }, 403);
  c.set('user', payload);
  await next();
};

function rowToRegistration(row) {
  const data = safeJson(row.data, {});
  const merged = Object.assign({}, data, {
    id: row.id,
    uid: row.uid,
    status: row.status,
    role: row.role,
    _source_collection: roleKey(row.role) + '_registrations'
  });
  if (!merged.timestamp) merged.timestamp = row.created_at || nowIso();
  return merged;
}

function rowToUser(row) {
  const data = safeJson(row.data, {});
  return Object.assign({}, data, {
    id: row.id,
    uid: row.id,
    email: row.email,
    role: row.role,
    name: row.name || data.name || '',
    mobile: row.mobile || data.mobile || '',
    kycCompleted: !!row.kyc_completed,
    bankDetailsCompleted: !!row.bank_details_completed,
    profileCompleted: (data.profileCompleted == null) ? true : data.profileCompleted
  });
}

function rowToLoan(row) {
  return Object.assign({}, row, {
    applicant_documents: safeJson(row.applicant_documents, null),
    co_applicants: safeJson(row.co_applicants, null)
  });
}

function boolify(rows, fields) {
  return rows.map(function (r) {
    const o = Object.assign({}, r);
    for (const f of fields) { if (f in o) o[f] = !!o[f]; }
    return o;
  });
}

function parseJsonList(rows, field) {
  return rows.map(function (r) {
    const o = Object.assign({}, r);
    o[field] = safeJson(r[field], []);
    return o;
  });
}

async function upsertUserFromRegistration(env, uid, role, userDetails) {
  const now = nowIso();
  const details = userDetails || {};
  const data = Object.assign({}, details, { uid: uid, role: role, profileCompleted: true, updatedAt: now });
  delete data.id; delete data.status; delete data.timestamp; delete data._source_collection;
  const email = (details.email || '').toString().trim() || null;
  const name = (details.name || '').toString();
  const mobile = (details.mobile || '').toString();
  const existing = await first(env, 'SELECT id FROM users WHERE id = ?', [uid]);
  if (existing) {
    await updateRow(env, 'users', 'id', uid, { role: role, name: name, mobile: mobile, data: JSON.stringify(data), updated_at: now });
  } else {
    await insertRow(env, 'users', { id: uid, email: email, role: role, name: name, mobile: mobile, kyc_completed: 0, bank_details_completed: 0, data: JSON.stringify(data), created_at: now, updated_at: now });
  }
}

function loanColumns(b) {
  return {
    loan_type: b.loan_type || null,
    full_name: b.full_name || null,
    pan_number: b.pan_number || null,
    aadhaar_number: b.aadhaar_number || null,
    mobile_number: b.mobile_number || null,
    email: b.email || null,
    loan_amount: b.loan_amount || null,
    salary: b.salary || null,
    turnover: b.turnover || null,
    father_name: b.father_name || null,
    mother_name: b.mother_name || null,
    marital_status: b.marital_status || null,
    spouse_name: b.spouse_name || null,
    occupation: b.occupation || null,
    personal_email: b.personal_email || null,
    official_email: b.official_email || null,
    current_address: b.current_address || null,
    office_address: b.office_address || null,
    ref1_name: b.ref1_name || null,
    ref1_mobile: b.ref1_mobile || null,
    ref1_address: b.ref1_address || null,
    ref2_name: b.ref2_name || null,
    ref2_mobile: b.ref2_mobile || null,
    ref2_address: b.ref2_address || null,
    applicant_documents: b.applicant_documents ? JSON.stringify(b.applicant_documents) : null,
    co_applicants: b.co_applicants ? JSON.stringify(b.co_applicants) : null,
    status: b.status || 'Pending',
    login_company_name: b.login_company_name || null,
    bank_executive_name: b.bank_executive_name || null,
    gender: b.gender || null,
    applicant_cibil: (b.applicant_cibil != null) ? b.applicant_cibil : null
  };
}

function policyColumns(b) {
  return {
    bank_name: b.bank_name || null,
    banker_name: b.banker_name || null,
    banker_mobile: b.banker_mobile || null,
    office_address: b.office_address || null,
    l1_manager_name: b.l1_manager_name || null,
    l1_manager_mobile: b.l1_manager_mobile || null,
    l2_manager_name: b.l2_manager_name || null,
    l2_manager_mobile: b.l2_manager_mobile || null,
    loan_type: b.loan_type || null,
    product_type: b.product_type || null,
    vertical: b.vertical || null,
    min_cibil: (b.min_cibil != null) ? b.min_cibil : null,
    min_income: b.min_income || null,
    min_ticket_size: b.min_ticket_size || null,
    max_ticket_size: b.max_ticket_size || null,
    ticket_size: ((b.min_ticket_size || '') + ' - ' + (b.max_ticket_size || '')),
    max_loan_amount: b.max_ticket_size || null,
    ltv_ratio: b.ltv_ratio || null,
    m_profile_allowed: b.m_profile_allowed || null,
    max_allowed_bounces: (b.max_allowed_bounces != null) ? b.max_allowed_bounces : null,
    geo_radius: b.geo_radius || null,
    login_fee: b.login_fee || null,
    interest_rate: b.interest_rate || null,
    processing_fee: b.processing_fee || null,
    special_features: b.special_features || null,
    tat_days: b.tat_days || null,
    updated_at: nowIso()
  };
}

// ---------- public ----------
app.get('/api/health', function (c) { return c.json({ ok: true, service: 'dhankund-api' }); });
app.get('/api', function (c) { return c.json({ name: 'Dhankund API', version: '1.0.0', endpoints: routeIndex() }); });
app.get('/api/openapi.json', function (c) { return c.json(openApiSpec()); });
app.get('/docs', function (c) { return c.html(docsHtml()); });

// ---------- auth ----------
app.post('/api/v1/auth/signup', async function (c) {
  const b = await readJson(c);
  const email = (b.email || '').toString().trim().toLowerCase();
  const password = (b.password || '').toString();
  const role = roleKey(b.role || 'customer');
  const name = (b.name || '').toString();
  if (!email || !password) return c.json({ error: 'Email and password are required' }, 400);
  if (password.length < 6) return c.json({ error: 'Password must be at least 6 characters' }, 400);
  const existing = await first(c.env, 'SELECT id FROM users WHERE lower(email) = lower(?)', [email]);
  if (existing) return c.json({ error: 'An account with this email already exists' }, 409);
  const now = nowIso();
  const uid = randomId();
  const hash = await hashPassword(password);
  const data = JSON.stringify({ uid: uid, role: role, name: name, profileCompleted: false, createdAt: now });
  await insertRow(c.env, 'users', { id: uid, email: email, password_hash: hash, role: role, name: name, mobile: '', kyc_completed: 0, bank_details_completed: 0, data: data, created_at: now, updated_at: now });
  const payload = { sub: uid, email: email, role: role, name: name, exp: Math.floor(Date.now() / 1000) + (8 * 60 * 60) };
  const token = await signSession(payload, c.env.SESSION_SECRET || '');
  return c.json({ token: token, user: { id: uid, email: email, role: role, name: name } });
});

app.post('/api/v1/auth/login', async function (c) {
  const body = await readJson(c);
  const email = (body.email || '').toString().trim().toLowerCase();
  const password = (body.password || '').toString();
  if (!email || !password) return c.json({ error: 'Email and password are required' }, 400);

  let user = await first(c.env, 'SELECT * FROM users WHERE lower(email) = lower(?)', [email]);

  if (!user) {
    const adminEmail = (c.env.ADMIN_EMAIL || '').toString().trim().toLowerCase();
    const adminPassword = (c.env.ADMIN_PASSWORD || '').toString();
    if (adminEmail && email === adminEmail && password === adminPassword) {
      const now = nowIso();
      const uid = randomId();
      const hash = await hashPassword(password);
      await insertRow(c.env, 'users', { id: uid, email: email, password_hash: hash, role: 'admin', name: 'Admin', mobile: null, kyc_completed: 0, bank_details_completed: 0, data: JSON.stringify({ uid: uid, role: 'admin', profileCompleted: true }), created_at: now, updated_at: now });
      user = await first(c.env, 'SELECT * FROM users WHERE id = ?', [uid]);
    } else {
      return c.json({ error: 'Invalid email or password' }, 401);
    }
  }

  if (!user.password_hash) {
    const adminEmail = (c.env.ADMIN_EMAIL || '').toString().trim().toLowerCase();
    if ((c.env.ADMIN_PASSWORD || '').toString() === password && email === adminEmail) {
      const hash = await hashPassword(password);
      await updateRow(c.env, 'users', 'id', user.id, { password_hash: hash });
      user.password_hash = hash;
    } else {
      return c.json({ error: 'Invalid email or password' }, 401);
    }
  }

  const ok = await verifyPassword(password, user.password_hash);
  if (!ok) return c.json({ error: 'Invalid email or password' }, 401);

  const payload = { sub: user.id, email: user.email, role: user.role, name: user.name, exp: Math.floor(Date.now() / 1000) + (8 * 60 * 60) };
  const token = await signSession(payload, c.env.SESSION_SECRET || '');
  return c.json({ token: token, user: { id: user.id, email: user.email, role: user.role, name: user.name } });
});

app.get('/api/v1/auth/me', auth, async function (c) {
  const me = c.get('user');
  const user = await first(c.env, 'SELECT * FROM users WHERE id = ?', [me.sub]);
  if (!user) return c.json({ error: 'Not found' }, 404);
  return c.json({ id: user.id, email: user.email, role: user.role, name: user.name, mobile: user.mobile });
});

app.post('/api/v1/auth/logout', auth, function (c) { return c.json({ success: true }); });

app.post('/api/v1/auth/verify-password', auth, async function (c) {
  const body = await readJson(c);
  const me = c.get('user');
  const user = await first(c.env, 'SELECT * FROM users WHERE id = ?', [me.sub]);
  if (!user || !user.password_hash) return c.json({ error: 'Not found' }, 404);
  const ok = await verifyPassword((body.password || '').toString(), user.password_hash);
  if (!ok) return c.json({ error: 'Incorrect password' }, 401);
  return c.json({ success: true });
});

// ---------- user profile / scoped reads ----------
app.get('/api/v1/me/profile', auth, async function (c) {
  const me = c.get('user');
  const user = await first(c.env, 'SELECT * FROM users WHERE id = ?', [me.sub]);
  if (!user) return c.json({ error: 'Not found' }, 404);
  const profile = rowToUser(user);
  // Determine profile completion from registrations too (like the DSA app used to)
  if (!profile.profileCompleted) {
    const reg = await first(c.env, 'SELECT id FROM registrations WHERE uid = ? LIMIT 1', [me.sub]);
    if (reg) profile.profileCompleted = true;
  }
  return c.json(profile);
});

app.get('/api/v1/me/loans', auth, async function (c) {
  const me = c.get('user');
  const email = (me.email || '').toString().toLowerCase();
  const rows = await all(c.env, 'SELECT * FROM loan_applications WHERE lower(email) = lower(?) ORDER BY submitted_at DESC', [email]);
  return c.json(rows.map(rowToLoan));
});

app.get('/api/v1/me/referrals', auth, async function (c) {
  const me = c.get('user');
  const rows = await all(c.env, 'SELECT * FROM referrals WHERE referrer_id = ? ORDER BY created_at DESC', [me.sub]);
  return c.json(boolify(rows, ['consent_given']));
});

// ---------- user submissions ----------
app.post('/api/v1/registrations', auth, async function (c) {
  const me = c.get('user');
  const b = await readJson(c);
  const role = roleKey(b.role || 'customer');
  const now = nowIso();
  const id = randomId();
  const data = Object.assign({}, b.details || {}, { uid: me.sub, email: me.email, role: role, timestamp: now });
  delete data.id; delete data.status;
  await insertRow(c.env, 'registrations', { id: id, uid: me.sub, role: role, status: 'pending', data: JSON.stringify(data), created_at: now });
  // mirror profile fields into users table
  await upsertUserFromRegistration(c.env, me.sub, role, Object.assign({}, b.details || {}, { email: me.email }));
  return c.json({ success: true, id: id });
});

app.post('/api/v1/loans', auth, async function (c) {
  const me = c.get('user');
  const b = await readJson(c);
  const id = randomId();
  const cols = loanColumns(b);
  if (!cols.email) cols.email = me.email;
  await insertRow(c.env, 'loan_applications', Object.assign({ id: id, submitted_at: nowIso() }, cols));
  return c.json({ success: true, id: id });
});

app.post('/api/v1/referrals', auth, async function (c) {
  const me = c.get('user');
  const b = await readJson(c);
  const id = randomId();
  await insertRow(c.env, 'referrals', {
    id: id,
    referrer_id: me.sub,
    friend_name: b.friend_name || null,
    friend_mobile: b.friend_mobile || null,
    friend_email: b.friend_email || null,
    relationship: b.relationship || null,
    loan_type: b.loan_type || null,
    estimated_amount: b.estimated_amount || null,
    consent_given: b.consent_given ? 1 : 0,
    status: b.status || 'Invited',
    created_at: nowIso()
  });
  return c.json({ success: true, id: id });
});

// ---------- shared read endpoints (any logged-in user) ----------
app.get('/api/v1/news-feed', auth, async function (c) {
  const rows = await all(c.env, 'SELECT * FROM news_feed ORDER BY timestamp DESC');
  return c.json(parseJsonList(rows, 'likes'));
});

app.get('/api/v1/statuses', auth, async function (c) {
  const rows = await all(c.env, 'SELECT * FROM statuses ORDER BY timestamp DESC');
  return c.json(rows);
});

app.get('/api/v1/admin-posts', auth, async function (c) {
  const rows = await all(c.env, 'SELECT * FROM admin_posts ORDER BY timestamp DESC');
  return c.json(rows);
});

app.get('/api/v1/bank-policies', auth, async function (c) {
  const rows = await all(c.env, 'SELECT * FROM bank_policies ORDER BY updated_at DESC');
  return c.json(rows);
});

app.post('/api/v1/devices', async function (c) {
  const b = await readJson(c);
  if (!b.token) return c.json({ error: 'token is required' }, 400);
  const now = nowIso();
  const existing = await first(c.env, 'SELECT token FROM fcm_tokens WHERE token = ?', [String(b.token)]);
  if (existing) {
    await updateRow(c.env, 'fcm_tokens', 'token', String(b.token), { user_id: b.user_id || null, platform: b.platform || null, updated_at: now });
  } else {
    await insertRow(c.env, 'fcm_tokens', { token: String(b.token), user_id: b.user_id || null, platform: b.platform || null, created_at: now, updated_at: now });
  }
  return c.json({ success: true });
});

app.get('/api/v1/download/:filename', async function (c) {
  const filename = c.req.param('filename');
  const object = await c.env.R2_BUCKET.get(filename);
  if (!object) return c.json({ error: 'Not found' }, 404);
  const headers = {};
  if (object.httpMetadata && object.httpMetadata.contentType) headers['Content-Type'] = object.httpMetadata.contentType;
  return new Response(object.body, { headers: headers });
});

app.post('/api/v1/upload', auth, async function (c) {
  const filename = c.req.query('filename');
  if (!filename) return c.json({ error: 'filename query parameter is required' }, 400);
  const contentType = c.req.header('Content-Type') || 'application/octet-stream';
  const body = await c.req.raw.arrayBuffer();
  await c.env.R2_BUCKET.put(filename, body, { httpMetadata: { contentType: contentType } });
  return c.json({ success: true, url: '/api/v1/download/' + encodeURIComponent(filename) });
});

// ---------- admin: overview ----------
app.get('/api/v1/overview', requireAdmin, async function (c) {
  const env = c.env;
  const totalUsers = ((await first(env, 'SELECT COUNT(*) AS n FROM users')) || {}).n || 0;
  const totalLoans = ((await first(env, 'SELECT COUNT(*) AS n FROM loan_applications')) || {}).n || 0;
  const totalReferrals = ((await first(env, 'SELECT COUNT(*) AS n FROM referrals')) || {}).n || 0;
  const pendingApprovals = ((await first(env, "SELECT COUNT(*) AS n FROM registrations WHERE lower(status) = 'pending'")) || {}).n || 0;
  const refs = await all(env, 'SELECT status FROM referrals');
  let disbursedCommission = 0;
  let pendingCommission = 0;
  for (const r of refs) {
    const s = (r.status || '').toLowerCase();
    if (s === 'earned') disbursedCommission += 5000;
    else if (s === 'approved') pendingCommission += 5000;
  }
  return c.json({ totalUsers: totalUsers, totalLoans: totalLoans, totalReferrals: totalReferrals, pendingApprovals: pendingApprovals, disbursedCommission: disbursedCommission, pendingCommission: pendingCommission });
});

// ---------- admin: registrations ----------
app.get('/api/v1/registrations', requireAdmin, async function (c) {
  const role = (c.req.query('role') || '').toLowerCase();
  const rows = await all(c.env, 'SELECT * FROM registrations WHERE lower(role) = lower(?) ORDER BY created_at DESC', [role]);
  return c.json(rows.map(rowToRegistration));
});

app.patch('/api/v1/registrations/:id', requireAdmin, async function (c) {
  const id = c.req.param('id');
  const body = await readJson(c);
  const status = (body.status || 'pending').toString();
  const uid = (body.uid || '').toString();
  const role = (body.role || '').toString();
  await updateRow(c.env, 'registrations', 'id', id, { status: status });
  if (status.toLowerCase() === 'approved' && uid) {
    await upsertUserFromRegistration(c.env, uid, role, (body.userDetails && typeof body.userDetails === 'object') ? body.userDetails : {});
  }
  return c.json({ success: true });
});

// ---------- admin: kyc/bank users ----------
app.get('/api/v1/kyc-bank-users', requireAdmin, async function (c) {
  const rows = await all(c.env, 'SELECT * FROM users ORDER BY created_at DESC');
  return c.json(rows.map(rowToUser));
});

app.patch('/api/v1/users/:uid/kyc', requireAdmin, async function (c) {
  const uid = c.req.param('uid');
  const body = await readJson(c);
  await updateRow(c.env, 'users', 'id', uid, { kyc_completed: body.completed ? 1 : 0 });
  return c.json({ success: true });
});

app.patch('/api/v1/users/:uid/bank', requireAdmin, async function (c) {
  const uid = c.req.param('uid');
  const body = await readJson(c);
  await updateRow(c.env, 'users', 'id', uid, { bank_details_completed: body.completed ? 1 : 0 });
  return c.json({ success: true });
});

app.delete('/api/v1/users/:uid', requireAdmin, async function (c) {
  const uid = c.req.param('uid');
  const body = await readJson(c);
  await run(c.env, 'DELETE FROM users WHERE id = ?', [uid]);
  if (body.docId) { await run(c.env, 'DELETE FROM registrations WHERE id = ?', [String(body.docId)]); }
  return c.json({ success: true });
});

// ---------- admin: loans ----------
app.get('/api/v1/loans', requireAdmin, async function (c) {
  const rows = await all(c.env, 'SELECT * FROM loan_applications ORDER BY submitted_at DESC');
  return c.json(rows.map(rowToLoan));
});

app.put('/api/v1/loans/:id', requireAdmin, async function (c) {
  const id = c.req.param('id');
  const b = await readJson(c);
  await updateRow(c.env, 'loan_applications', 'id', id, loanColumns(b));
  return c.json({ success: true });
});

app.patch('/api/v1/loans/:id/status', requireAdmin, async function (c) {
  const id = c.req.param('id');
  const b = await readJson(c);
  await updateRow(c.env, 'loan_applications', 'id', id, { status: (b.status || 'Pending').toString(), updated_at: nowIso() });
  return c.json({ success: true });
});

// ---------- admin: referrals ----------
app.get('/api/v1/referrals', requireAdmin, async function (c) {
  const rows = await all(c.env, 'SELECT * FROM referrals ORDER BY created_at DESC');
  return c.json(boolify(rows, ['consent_given']));
});

app.patch('/api/v1/referrals/:id/status', requireAdmin, async function (c) {
  const id = c.req.param('id');
  const b = await readJson(c);
  await updateRow(c.env, 'referrals', 'id', id, { status: (b.status || 'Invited').toString() });
  return c.json({ success: true });
});

// ---------- admin: posts / policies ----------
app.post('/api/v1/admin-posts', requireAdmin, async function (c) {
  const b = await readJson(c);
  const id = randomId();
  await insertRow(c.env, 'admin_posts', { id: id, uid: 'admin', name: 'Admin', title: b.title || null, content: b.content || null, imageUrl: b.imageUrl || null, timestamp: nowIso() });
  return c.json({ success: true, id: id });
});

app.post('/api/v1/bank-policies', requireAdmin, async function (c) {
  const b = await readJson(c);
  const id = randomId();
  await insertRow(c.env, 'bank_policies', Object.assign({ id: id }, policyColumns(b)));
  return c.json({ success: true, id: id });
});

app.put('/api/v1/bank-policies/:id', requireAdmin, async function (c) {
  const id = c.req.param('id');
  const b = await readJson(c);
  await updateRow(c.env, 'bank_policies', 'id', id, policyColumns(b));
  return c.json({ success: true });
});

// ---------- admin: broadcasts / push ----------
app.get('/api/v1/broadcasts', requireAdmin, async function (c) {
  const rows = await all(c.env, 'SELECT * FROM broadcast_history ORDER BY timestamp DESC');
  return c.json(parseJsonList(boolify(rows, ['send_whatsapp', 'send_email', 'send_push']), 'audiences'));
});

app.post('/api/v1/broadcasts', requireAdmin, async function (c) {
  const b = await readJson(c);
  const id = randomId();
  const audiences = Array.isArray(b.audiences) ? b.audiences : [];
  const sendPush = !!b.send_push || !!b.sendPush;
  await insertRow(c.env, 'broadcast_history', {
    id: id, audiences: JSON.stringify(audiences),
    send_whatsapp: b.send_whatsapp ? 1 : 0, send_email: b.send_email ? 1 : 0, send_push: sendPush ? 1 : 0,
    subject: b.subject || null, message: b.message || null, recipient_count: (b.recipient_count != null) ? b.recipient_count : 0, timestamp: nowIso()
  });
  let pushSent = 0;
  if (sendPush) {
    const tokens = await all(c.env, 'SELECT token FROM fcm_tokens');
    for (const t of tokens) {
      try { await sendFcm(c.env, { token: t.token, title: b.subject || 'Dhankund', body: b.message || '', data: {} }); pushSent += 1; } catch (e) { console.error('push failed', e.message); }
    }
  }
  return c.json({ success: true, id: id, push_sent: pushSent });
});

app.post('/api/v1/push', requireAdmin, async function (c) {
  const b = await readJson(c);
  if (!b.token) return c.json({ error: 'token is required' }, 400);
  await sendFcm(c.env, { token: String(b.token), title: b.title || '', body: b.body || '', data: b.data || {} });
  return c.json({ success: true });
});

export default app;
