// worker/migrate.js Ã¢ÂÂ Firestore to D1 migration module
// Reads from Firebase Firestore via REST API, compares with D1, and imports.
// Reuses the RS256 JWT signing pattern from worker/fcm.js with datastore scope.

import { all, first, run, safeJson, nowIso, randomId } from './db.js';

const encoder = new TextEncoder();

// ==================== Firestore OAuth2 Access Token ====================

let cachedToken = null;
let cachedTokenExpiry = 0;

function pemBodyToArrayBuffer(pem) {
  const cleaned = pem.replace(/-----[A-Z ]+-----/g, '').replace(/\s+/g, '');
  const bin = atob(cleaned);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

function b64url(buf) {
  let bin = '';
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function signJwtRs256(privateKeyPem, header, claims) {
  const keyData = pemBodyToArrayBuffer(privateKeyPem);
  const key = await crypto.subtle.importKey('pkcs8', keyData, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const h = b64url(encoder.encode(JSON.stringify(header)));
  const p = b64url(encoder.encode(JSON.stringify(claims)));
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(h + '.' + p));
  return h + '.' + p + '.' + b64url(sig);
}

async function getFirestoreAccessToken(env) {
  if (cachedToken && Date.now() < cachedTokenExpiry) return cachedToken;
  const raw = env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT is not configured. Set it as a Worker secret.');
  const sa = JSON.parse(raw);
  const nowSec = Math.floor(Date.now() / 1000);
  const tokenUri = sa.token_uri || 'https://oauth2.googleapis.com/token';
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = { iss: sa.client_email, scope: 'https://www.googleapis.com/auth/datastore', aud: tokenUri, iat: nowSec, exp: nowSec + 3600 };
  const assertion = await signJwtRs256(sa.private_key, header, claims);
  const res = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=' + encodeURIComponent(assertion)
  });
  if (!res.ok) { const body = await res.text(); throw new Error('Firestore token exchange failed: ' + res.status + ' ' + body.slice(0, 500)); }
  const data = await res.json();
  cachedToken = data.access_token;
  cachedTokenExpiry = Date.now() + ((data.expires_in || 3600) - 60) * 1000;
  return cachedToken;
}


// ==================== Identity Toolkit OAuth2 Token ====================

let cachedItToken = null;
let cachedItTokenExpiry = 0;

async function getIdentityToolkitAccessToken(env) {
  if (cachedItToken && Date.now() < cachedItTokenExpiry) return cachedItToken;
  const raw = env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT is not configured.');
  const sa = JSON.parse(raw);
  const nowSec = Math.floor(Date.now() / 1000);
  const tokenUri = sa.token_uri || 'https://oauth2.googleapis.com/token';
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = { iss: sa.client_email, scope: 'https://www.googleapis.com/auth/identitytoolkit', aud: tokenUri, iat: nowSec, exp: nowSec + 3600 };
  const assertion = await signJwtRs256(sa.private_key, header, claims);
  const res = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=' + encodeURIComponent(assertion)
  });
  if (!res.ok) { const body = await res.text(); throw new Error('Identity Toolkit token exchange failed: ' + res.status + ' ' + body.slice(0, 500)); }
  const data = await res.json();
  cachedItToken = data.access_token;
  cachedItTokenExpiry = Date.now() + ((data.expires_in || 3600) - 60) * 1000;
  return cachedItToken;
}

function getProjectId(env) {
  const raw = env.FIREBASE_SERVICE_ACCOUNT;
  if (raw) { try { const sa = JSON.parse(raw); if (sa.project_id) return sa.project_id; } catch (e) {} }
  return env.FIREBASE_PROJECT_ID || 'dhankund';
}

// ==================== Firestore Document Parsing ====================

function toIso(v) {
  if (!v) return null;
  if (typeof v === 'string') return v;
  if (typeof v === 'object') {
    const s = (v._seconds !== undefined) ? v._seconds : (v.seconds !== undefined ? v.seconds : null);
    const ns = (v._nanoseconds !== undefined) ? v._nanoseconds : (v.nanoseconds !== undefined ? v.nanoseconds : 0);
    if (s !== null) return new Date(s * 1000 + ns / 1e6).toISOString();
  }
  return null;
}

function parseValue(v) {
  if (v == null) return null;
  if (v.nullValue !== undefined) return null;
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.integerValue !== undefined) return Number(v.integerValue);
  if (v.doubleValue !== undefined) return v.doubleValue;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.timestampValue !== undefined) return toIso(v.timestampValue);
  if (v.arrayValue !== undefined) return (v.arrayValue.values || []).map(parseValue);
  if (v.mapValue !== undefined) return parseFields(v.mapValue.fields || {});
  if (v.referenceValue !== undefined) return v.referenceValue;
  if (v.bytesValue !== undefined) return v.bytesValue;
  if (v.geoPointValue !== undefined) return v.geoPointValue;
  return null;
}

function parseFields(fields) {
  const obj = {};
  for (const [key, value] of Object.entries(fields)) obj[key] = parseValue(value);
  return obj;
}

function parseDoc(doc) {
  return Object.assign({ _id: doc.name.split('/').pop() }, parseFields(doc.fields || {}));
}

// ==================== Read All Documents from a Collection ====================

async function readCollection(accessToken, projectId, collection) {
  const docs = [];
  let pageToken = null;
  do {
    let url = 'https://firestore.googleapis.com/v1/projects/' + projectId + '/databases/(default)/documents/' + collection + '?pageSize=300';
    if (pageToken) url += '&pageToken=' + encodeURIComponent(pageToken);
    const res = await fetch(url, { headers: { Authorization: 'Bearer ' + accessToken } });
    if (res.status === 404) return docs;
    if (!res.ok) { const body = await res.text(); throw new Error('Firestore list "' + collection + '" failed: ' + res.status + ' ' + body.slice(0, 500)); }
    const data = await res.json();
    if (data.documents) { for (const doc of data.documents) docs.push(parseDoc(doc)); }
    pageToken = data.nextPageToken || null;
  } while (pageToken);
  return docs;
}

// ==================== Mappers: Firestore Doc to D1 Row ====================

function mapUser(doc) {
  const id = doc.uid || doc._id;
  const knownKeys = new Set(['_id', 'uid', 'email', 'role', 'name', 'mobile',
    'kycCompleted', 'bankDetailsCompleted', 'profileCompleted', 'profilePictureUrl', 'fcmToken',
    'kycPan', 'kycAadhaar', 'kycDocUrl',
    'bankName', 'bankAccountHolder', 'bankAccountNumber', 'bankIfsc', 'bankProofUrl',
    'gender', 'company', 'address', 'currentExp', 'totalExp', 'segment', 'profession', 'about',
    'partnerName', 'partnerMobile', 'gumastaUrl', 'idCardUrl',
    'managerName', 'managerMobile', 'areaManagerName', 'areaManagerMobile',
    'nomineeName', 'officeAddress',
    'createdAt', 'updatedAt', 'created_at', 'updated_at', 'passwordHash', 'password_hash']);
  const extra = {};
  for (const [k, v] of Object.entries(doc)) { if (!knownKeys.has(k)) extra[k] = v; }
  if (!extra.uid) extra.uid = id;
  return {
    id: id, email: doc.email || null, password_hash: doc.passwordHash || doc.password_hash || null,
    role: doc.role || null, name: doc.name || null, mobile: doc.mobile || null,
    kyc_completed: doc.kycCompleted ? 1 : 0, bank_details_completed: doc.bankDetailsCompleted ? 1 : 0,
    profile_completed: doc.profileCompleted ? 1 : 0,
    profile_picture_url: doc.profilePictureUrl || null,
    fcm_token: doc.fcmToken || null,
    kyc_pan: doc.kycPan || null, kyc_aadhaar: doc.kycAadhaar || null, kyc_doc_url: doc.kycDocUrl || null,
    bank_name: doc.bankName || null, bank_account_holder: doc.bankAccountHolder || null,
    bank_account_number: doc.bankAccountNumber || null, bank_ifsc: doc.bankIfsc || null, bank_proof_url: doc.bankProofUrl || null,
    gender: doc.gender || null, company: doc.company || null, address: doc.address || null,
    current_experience: doc.currentExp || null, total_experience: doc.totalExp || null,
    segment: doc.segment || null, profession: doc.profession || null, about: doc.about || null,
    partner_name: doc.partnerName || null, partner_mobile: doc.partnerMobile || null,
    gumasta_url: doc.gumastaUrl || null, id_card_url: doc.idCardUrl || null,
    manager_name: doc.managerName || null, manager_mobile: doc.managerMobile || null,
    area_manager_name: doc.areaManagerName || null, area_manager_mobile: doc.areaManagerMobile || null,
    nominee_name: doc.nomineeName || null, office_address: doc.officeAddress || null,
    data: Object.keys(extra).length > 0 ? JSON.stringify(extra) : null,
    created_at: toIso(doc.createdAt) || toIso(doc.created_at) || null,
    updated_at: toIso(doc.updatedAt) || toIso(doc.updated_at) || null
  };
}

function mapLoan(doc) {
  return {
    id: doc._id, loan_type: doc.loan_type || null, full_name: doc.full_name || null,
    pan_number: doc.pan_number || null, aadhaar_number: doc.aadhaar_number || null,
    mobile_number: doc.mobile_number || null, email: doc.email || null,
    loan_amount: doc.loan_amount || null, salary: doc.salary || null, turnover: doc.turnover || null,
    father_name: doc.father_name || null, mother_name: doc.mother_name || null,
    marital_status: doc.marital_status || null, spouse_name: doc.spouse_name || null,
    occupation: doc.occupation || null, personal_email: doc.personal_email || null,
    official_email: doc.official_email || null, current_address: doc.current_address || null,
    office_address: doc.office_address || null, ref1_name: doc.ref1_name || null,
    ref1_mobile: doc.ref1_mobile || null, ref1_address: doc.ref1_address || null,
    ref2_name: doc.ref2_name || null, ref2_mobile: doc.ref2_mobile || null,
    ref2_address: doc.ref2_address || null,
    applicant_documents: doc.applicant_documents != null ? JSON.stringify(doc.applicant_documents) : null,
    co_applicants: doc.co_applicants != null ? JSON.stringify(doc.co_applicants) : null,
    status: doc.status || 'Pending', login_company_name: doc.login_company_name || null,
    bank_executive_name: doc.bank_executive_name || null, gender: doc.gender || null,
    applicant_cibil: (doc.applicant_cibil != null) ? Number(doc.applicant_cibil) : null,
    submitted_at: toIso(doc.submitted_at), updated_at: toIso(doc.updated_at)
  };
}

function mapReferral(doc) {
  return {
    id: doc._id, referrer_id: doc.referrer_id || doc.dsaId || null,
    friend_name: doc.friend_name || null, friend_mobile: doc.friend_mobile || null,
    friend_email: doc.friend_email || null, relationship: doc.relationship || null,
    loan_type: doc.loan_type || null, estimated_amount: doc.estimated_amount || null,
    consent_given: doc.consent_given ? 1 : 0, status: doc.status || 'Invited',
    created_at: toIso(doc.created_at)
  };
}

function mapRegistration(doc, role) {
  const knownKeys = new Set(['_id', 'uid', 'userId', 'role', 'status', 'timestamp', 'created_at',
    'name', 'mobile', 'email', 'gender', 'company', 'address',
    'currentExp', 'totalExp', 'segment', 'profession', 'about',
    'partnerName', 'partnerMobile', 'gumastaUrl', 'idCardUrl',
    'managerName', 'managerMobile', 'areaManagerName', 'areaManagerMobile',
    'nomineeName', 'officeAddress']);
  const extra = {};
  for (const [k, v] of Object.entries(doc)) { if (!knownKeys.has(k)) extra[k] = v; }
  return {
    id: doc._id, uid: doc.uid || doc.userId || null, role: role, status: doc.status || 'pending',
    name: doc.name || null, mobile: doc.mobile || null, email: doc.email || null,
    gender: doc.gender || null, company: doc.company || null, address: doc.address || null,
    current_experience: doc.currentExp || null, total_experience: doc.totalExp || null,
    segment: doc.segment || null, profession: doc.profession || null, about: doc.about || null,
    partner_name: doc.partnerName || null, partner_mobile: doc.partnerMobile || null,
    gumasta_url: doc.gumastaUrl || null, id_card_url: doc.idCardUrl || null,
    manager_name: doc.managerName || null, manager_mobile: doc.managerMobile || null,
    area_manager_name: doc.areaManagerName || null, area_manager_mobile: doc.areaManagerMobile || null,
    nominee_name: doc.nomineeName || null, office_address: doc.officeAddress || null,
    data: Object.keys(extra).length > 0 ? JSON.stringify(extra) : null,
    created_at: toIso(doc.timestamp) || toIso(doc.created_at) || null
  };
}

function mapAdminPost(doc) {
  return { id: doc._id, uid: doc.uid || 'admin', name: doc.name || 'Admin',
    title: doc.title || null, content: doc.content || null,
    imageUrl: doc.imageUrl || null, timestamp: toIso(doc.timestamp) };
}

function mapNewsFeed(doc) {
  return { id: doc._id, uid: doc.uid || null, name: doc.name || null,
    role: doc.role || null, company: doc.company || null,
    profilePictureUrl: doc.profilePictureUrl || null, mobile: doc.mobile || null,
    content: doc.content || null, imageUrl: doc.imageUrl || null,
    likes: doc.likes != null ? JSON.stringify(doc.likes) : '[]',
    timestamp: toIso(doc.timestamp) };
}

function mapStatus(doc) {
  return { id: doc._id, uid: doc.uid || null, name: doc.name || null,
    role: doc.role || null, company: doc.company || null, mobile: doc.mobile || null,
    text: doc.text || null, gradientIndex: (doc.gradientIndex != null) ? Number(doc.gradientIndex) : null,
    mediaUrl: doc.mediaUrl || null, mediaType: doc.mediaType || null,
    profilePictureUrl: doc.profilePictureUrl || null, timestamp: toIso(doc.timestamp) };
}

function mapBankPolicy(doc) {
  return {
    id: doc._id, bank_name: doc.bank_name || null, banker_name: doc.banker_name || null,
    banker_mobile: doc.banker_mobile || null, office_address: doc.office_address || null,
    l1_manager_name: doc.l1_manager_name || null, l1_manager_mobile: doc.l1_manager_mobile || null,
    l2_manager_name: doc.l2_manager_name || null, l2_manager_mobile: doc.l2_manager_mobile || null,
    loan_type: doc.loan_type || null, product_type: doc.product_type || null, vertical: doc.vertical || null,
    min_cibil: (doc.min_cibil != null) ? Number(doc.min_cibil) : null,
    min_income: doc.min_income || null, min_ticket_size: doc.min_ticket_size || null,
    max_ticket_size: doc.max_ticket_size || null, ticket_size: doc.ticket_size || null,
    max_loan_amount: doc.max_loan_amount || null, ltv_ratio: doc.ltv_ratio || null,
    m_profile_allowed: doc.m_profile_allowed || null,
    max_allowed_bounces: (doc.max_allowed_bounces != null) ? Number(doc.max_allowed_bounces) : null,
    geo_radius: doc.geo_radius || null, login_fee: doc.login_fee || null,
    interest_rate: doc.interest_rate || null, processing_fee: doc.processing_fee || null,
    special_features: doc.special_features || null, tat_days: doc.tat_days || null,
    updated_at: toIso(doc.updated_at)
  };
}

function mapBroadcast(doc) {
  return {
    id: doc._id,
    audiences: doc.audiences != null ? JSON.stringify(doc.audiences) : '[]',
    send_whatsapp: doc.send_whatsapp ? 1 : 0, send_email: doc.send_email ? 1 : 0,
    send_push: doc.send_push ? 1 : 0, subject: doc.subject || null, message: doc.message || null,
    recipient_count: (doc.recipient_count != null) ? Number(doc.recipient_count) : 0,
    timestamp: toIso(doc.timestamp)
  };
}

// ==================== Table Schema & Collection Map ====================

const TABLE_COLUMNS = {
  users: ['id', 'email', 'password_hash', 'role', 'name', 'mobile', 'kyc_completed', 'bank_details_completed',
    'profile_completed', 'profile_picture_url', 'fcm_token',
    'kyc_pan', 'kyc_aadhaar', 'kyc_doc_url',
    'bank_name', 'bank_account_holder', 'bank_account_number', 'bank_ifsc', 'bank_proof_url',
    'gender', 'company', 'address', 'current_experience', 'total_experience',
    'segment', 'profession', 'about',
    'partner_name', 'partner_mobile', 'gumasta_url', 'id_card_url',
    'manager_name', 'manager_mobile', 'area_manager_name', 'area_manager_mobile',
    'nominee_name', 'office_address',
    'data', 'created_at', 'updated_at'],
  loan_applications: ['id', 'loan_type', 'full_name', 'pan_number', 'aadhaar_number', 'mobile_number', 'email', 'loan_amount', 'salary', 'turnover', 'father_name', 'mother_name', 'marital_status', 'spouse_name', 'occupation', 'personal_email', 'official_email', 'current_address', 'office_address', 'ref1_name', 'ref1_mobile', 'ref1_address', 'ref2_name', 'ref2_mobile', 'ref2_address', 'applicant_documents', 'co_applicants', 'status', 'login_company_name', 'bank_executive_name', 'gender', 'applicant_cibil', 'submitted_at', 'updated_at'],
  referrals: ['id', 'referrer_id', 'friend_name', 'friend_mobile', 'friend_email', 'relationship', 'loan_type', 'estimated_amount', 'consent_given', 'status', 'created_at'],
  registrations: ['id', 'uid', 'role', 'status',
    'name', 'mobile', 'email', 'gender', 'company', 'address',
    'current_experience', 'total_experience', 'segment', 'profession', 'about',
    'partner_name', 'partner_mobile', 'gumasta_url', 'id_card_url',
    'manager_name', 'manager_mobile', 'area_manager_name', 'area_manager_mobile',
    'nominee_name', 'office_address',
    'data', 'created_at'],
  admin_posts: ['id', 'uid', 'name', 'title', 'content', 'imageUrl', 'timestamp'],
  news_feed: ['id', 'uid', 'name', 'role', 'company', 'profilePictureUrl', 'mobile', 'content', 'imageUrl', 'likes', 'timestamp'],
  statuses: ['id', 'uid', 'name', 'role', 'company', 'mobile', 'text', 'gradientIndex', 'mediaUrl', 'mediaType', 'profilePictureUrl', 'timestamp'],
  bank_policies: ['id', 'bank_name', 'banker_name', 'banker_mobile', 'office_address', 'l1_manager_name', 'l1_manager_mobile', 'l2_manager_name', 'l2_manager_mobile', 'loan_type', 'product_type', 'vertical', 'min_cibil', 'min_income', 'min_ticket_size', 'max_ticket_size', 'ticket_size', 'max_loan_amount', 'ltv_ratio', 'm_profile_allowed', 'max_allowed_bounces', 'geo_radius', 'login_fee', 'interest_rate', 'processing_fee', 'special_features', 'tat_days', 'updated_at'],
  broadcast_history: ['id', 'audiences', 'send_whatsapp', 'send_email', 'send_push', 'subject', 'message', 'recipient_count', 'timestamp']
};

const COLLECTION_MAP = [
  { collection: 'users', table: 'users', role: null, mapper: mapUser },
  { collection: 'loan_applications', table: 'loan_applications', role: null, mapper: mapLoan },
  { collection: 'referrals', table: 'referrals', role: null, mapper: mapReferral },
  { collection: 'dsa_registrations', table: 'registrations', role: 'dsa', mapper: mapRegistration },
  { collection: 'banker_registrations', table: 'registrations', role: 'banker', mapper: mapRegistration },
  { collection: 'partner_registrations', table: 'registrations', role: 'partner', mapper: mapRegistration },
  { collection: 'admin_posts', table: 'admin_posts', role: null, mapper: mapAdminPost },
  { collection: 'news_feed', table: 'news_feed', role: null, mapper: mapNewsFeed },
  { collection: 'statuses', table: 'statuses', role: null, mapper: mapStatus },
  { collection: 'bank_policies', table: 'bank_policies', role: null, mapper: mapBankPolicy },
  { collection: 'broadcast_history', table: 'broadcast_history', role: null, mapper: mapBroadcast }
];

// ==================== Upsert Helper ====================

async function upsertRow(env, table, columns, row) {
  const placeholders = columns.map(function () { return '?'; }).join(', ');
  const sql = 'INSERT OR REPLACE INTO ' + table + ' (' + columns.join(', ') + ') VALUES (' + placeholders + ')';
  const values = columns.map(function (col) { const v = row[col]; return (v === undefined) ? null : v; });
  await run(env, sql, values);
}

// ==================== Diff Comparison Helpers ====================

function normVal(v) {
  if (v === null || v === undefined || v === '') return null;
  if (typeof v === 'boolean') return v ? 1 : 0;
  if (typeof v === 'number') return v;
  return String(v);
}

function findChangedFields(mappedRow, d1Row, columns) {
  const changed = [];
  for (const col of columns) {
    if (normVal(mappedRow[col]) !== normVal(d1Row ? d1Row[col] : null)) changed.push(col);
  }
  return changed;
}

async function getD1Rows(env, table, role) {
  if (role) return await all(env, 'SELECT * FROM ' + table + ' WHERE lower(role) = lower(?)', [role]);
  return await all(env, 'SELECT * FROM ' + table);
}

function filterCols(filterCollection) {
  if (!filterCollection) return COLLECTION_MAP;
  const filtered = COLLECTION_MAP.filter(function (c) { return c.collection === filterCollection; });
  if (!filtered.length) throw new Error('Unknown collection: ' + filterCollection + '. Available: ' + COLLECTION_MAP.map(function (c) { return c.collection; }).join(', '));
  return filtered;
}

// ==================== Public API: Diff ====================

export async function computeDiff(env, filterCollection) {
  const token = await getFirestoreAccessToken(env);
  const projectId = getProjectId(env);
  const cols = filterCols(filterCollection);
  const results = [];
  const summary = { total_firestore: 0, total_d1: 0, total_new: 0, total_changed: 0, total_same: 0, total_only_in_d1: 0 };
  const errors = [];
  for (const col of cols) {
    try {
      const fsDocs = await readCollection(token, projectId, col.collection);
      const d1Rows = await getD1Rows(env, col.table, col.role);
      const d1ById = {}; for (const r of d1Rows) d1ById[r.id] = r;
      const d1Ids = new Set(Object.keys(d1ById));
      const fsIds = new Set();
      let newCount = 0, changedCount = 0, sameCount = 0;
      const changedSamples = [];
      const columns = TABLE_COLUMNS[col.table];
      for (const doc of fsDocs) {
        const mapped = col.mapper(doc, col.role);
        fsIds.add(mapped.id);
        if (!d1Ids.has(mapped.id)) { newCount++; }
        else { const changed = findChangedFields(mapped, d1ById[mapped.id], columns);
          if (changed.length > 0) { changedCount++; if (changedSamples.length < 5) changedSamples.push({ id: mapped.id, fields: changed }); }
          else { sameCount++; } }
      }
      let onlyInD1 = 0; for (const id of d1Ids) { if (!fsIds.has(id)) onlyInD1++; }
      summary.total_firestore += fsDocs.length; summary.total_d1 += d1Rows.length;
      summary.total_new += newCount; summary.total_changed += changedCount;
      summary.total_same += sameCount; summary.total_only_in_d1 += onlyInD1;
      results.push({ collection: col.collection, table: col.table, role: col.role,
        firestore_count: fsDocs.length, d1_count: d1Rows.length,
        new: newCount, changed: changedCount, same: sameCount, only_in_d1: onlyInD1,
        changed_samples: changedSamples });
    } catch (e) {
      errors.push({ collection: col.collection, error: e.message });
      results.push({ collection: col.collection, table: col.table, role: col.role, error: e.message });
    }
  }
  return { project_id: projectId, generated_at: nowIso(), collections: results, summary: summary, errors: errors };
}

// ==================== Public API: Export ====================

export async function exportData(env, filterCollection) {
  const token = await getFirestoreAccessToken(env);
  const projectId = getProjectId(env);
  const cols = filterCols(filterCollection);
  const collections = {};
  const errors = [];
  for (const col of cols) {
    try { collections[col.collection] = await readCollection(token, projectId, col.collection); }
    catch (e) { errors.push({ collection: col.collection, error: e.message }); }
  }
  return { project_id: projectId, exported_at: nowIso(), collections: collections, errors: errors };
}

// ==================== Public API: Import ====================

export async function importData(env, filterCollection, dryRun) {
  const token = await getFirestoreAccessToken(env);
  const projectId = getProjectId(env);
  const cols = filterCols(filterCollection);
  const results = [];
  const summary = { total_records: 0, total_inserted: 0, total_updated: 0, total_failed: 0 };
  const errors = [];
  const warnings = [];
  if (cols.some(function (c) { return c.collection === 'users'; })) {
    warnings.push('Firebase Auth passwords are not stored in Firestore. Migrated users will have null password_hash.');
  }
  for (const col of cols) {
    try {
      const docs = await readCollection(token, projectId, col.collection);
      const existingIds = new Set((await getD1Rows(env, col.table, col.role)).map(function (r) { return r.id; }));
      const columns = TABLE_COLUMNS[col.table];
      let inserted = 0, updated = 0, failed = 0;
      const colErrors = [];
      for (const doc of docs) {
        try {
          const row = col.mapper(doc, col.role);
          if (!dryRun) await upsertRow(env, col.table, columns, row);
          if (existingIds.has(row.id)) updated++; else inserted++;
        } catch (e) { failed++; colErrors.push({ id: doc._id, error: e.message }); }
      }
      results.push({ collection: col.collection, table: col.table, role: col.role,
        total: docs.length, inserted: inserted, updated: updated, failed: failed,
        errors: colErrors, dry_run: !!dryRun });
      summary.total_records += docs.length; summary.total_inserted += inserted;
      summary.total_updated += updated; summary.total_failed += failed;
    } catch (e) {
      errors.push({ collection: col.collection, error: e.message });
      results.push({ collection: col.collection, table: col.table, role: col.role, error: e.message });
    }
  }
  return { project_id: projectId, imported_at: nowIso(), dry_run: !!dryRun,
    results: results, summary: summary, warnings: warnings, errors: errors };
}

// ==================== Public API: Import Auth Data ====================

export async function importAuthData(env, dryRun) {
  const token = await getIdentityToolkitAccessToken(env);
  const projectId = getProjectId(env);
  const results = { project_id: projectId, imported_at: nowIso(), dry_run: !!dryRun };
  const errors = [];

  // 1. Fetch project config (signerKey + saltSeparator for Firebase scrypt)
  let signerKey = null;
  let saltSeparator = null;
  try {
    const configRes = await fetch('https://identitytoolkit.googleapis.com/v1/projects/' + projectId, {
      headers: { Authorization: 'Bearer ' + token }
    });
    if (!configRes.ok) {
      const body = await configRes.text();
      throw new Error('Project config fetch failed: ' + configRes.status + ' ' + body.slice(0, 500));
    }
    const config = await configRes.json();
    const hash = (config.signIn && config.signIn.hash) || {};
    signerKey = hash.signerKey || null;
    saltSeparator = hash.saltSeparator || 'Bw==';
  } catch (e) {
    return Object.assign(results, { error: 'Failed to fetch project config: ' + e.message, errors: errors });
  }

  // 2. Store config in D1 migration_config table
  if (!dryRun) {
    await run(env, 'CREATE TABLE IF NOT EXISTS migration_config (key TEXT PRIMARY KEY, value TEXT)');
    if (signerKey) await run(env, 'INSERT OR REPLACE INTO migration_config (key, value) VALUES (?, ?)', ['firebase_signer_key', signerKey]);
    if (saltSeparator) await run(env, 'INSERT OR REPLACE INTO migration_config (key, value) VALUES (?, ?)', ['firebase_salt_separator', saltSeparator]);
  }

  // 3. Fetch all Firebase Auth users with passwordHash + salt (paginated)
  let pageToken = null;
  let totalUsers = 0, withPassword = 0, updated = 0, created = 0, failed = 0;
  do {
    let url = 'https://identitytoolkit.googleapis.com/v1/projects/' + projectId + '/accounts:batchGet?maxResults=1000';
    if (pageToken) url += '&nextPageToken=' + encodeURIComponent(pageToken);
    const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
    if (!res.ok) {
      const body = await res.text();
      throw new Error('Identity Toolkit list users failed: ' + res.status + ' ' + body.slice(0, 500));
    }
    const data = await res.json();
    const users = data.users || [];
    for (const u of users) {
      totalUsers++;
      const email = (u.email || '').toString().toLowerCase();
      const passwordHash = u.passwordHash || null;
      const salt = u.salt || null;
      if (!email || !passwordHash || !salt) continue;
      withPassword++;
      try {
        const existing = await first(env, 'SELECT * FROM users WHERE lower(email) = lower(?)', [email]);
        if (existing) {
          if (!dryRun) {
            const data = safeJson(existing.data, '{}');
            data.firebasePasswordHash = passwordHash;
            data.firebaseSalt = salt;
            await run(env, 'UPDATE users SET data = ?, updated_at = ? WHERE id = ?', [JSON.stringify(data), nowIso(), existing.id]);
          }
          updated++;
        } else {
          if (!dryRun) {
            const uid = u.localId || randomId();
            const data = { uid: uid, role: 'customer', profileCompleted: false, firebasePasswordHash: passwordHash, firebaseSalt: salt };
            await run(env, 'INSERT OR REPLACE INTO users (id, email, password_hash, role, name, mobile, kyc_completed, bank_details_completed, data, created_at, updated_at) VALUES (?, ?, NULL, ?, ?, ?, 0, 0, ?, ?, ?)', [uid, email, 'customer', u.displayName || null, u.phoneNumber || null, JSON.stringify(data), nowIso(), nowIso()]);
          }
          created++;
        }
      } catch (e) {
        failed++;
        errors.push({ email: email, error: e.message });
      }
    }
    pageToken = data.nextPageToken || null;
  } while (pageToken);

  return Object.assign(results, {
    project_config: { signer_key: signerKey ? 'stored' : 'missing', salt_separator: saltSeparator ? 'stored' : 'missing' },
    summary: { total_auth_users: totalUsers, users_with_password: withPassword, updated: updated, created: created, failed: failed },
    errors: errors
  });
}

// ==================== Schema Migration (Add Missing Columns) ====================

const SCHEMA_COLUMNS = {
  users: [
    ['profile_completed', 'INTEGER DEFAULT 0'],
    ['profile_picture_url', 'TEXT'],
    ['fcm_token', 'TEXT'],
    ['kyc_pan', 'TEXT'],
    ['kyc_aadhaar', 'TEXT'],
    ['kyc_doc_url', 'TEXT'],
    ['bank_name', 'TEXT'],
    ['bank_account_holder', 'TEXT'],
    ['bank_account_number', 'TEXT'],
    ['bank_ifsc', 'TEXT'],
    ['bank_proof_url', 'TEXT'],
    ['gender', 'TEXT'],
    ['company', 'TEXT'],
    ['address', 'TEXT'],
    ['current_experience', 'TEXT'],
    ['total_experience', 'TEXT'],
    ['segment', 'TEXT'],
    ['profession', 'TEXT'],
    ['about', 'TEXT'],
    ['partner_name', 'TEXT'],
    ['partner_mobile', 'TEXT'],
    ['gumasta_url', 'TEXT'],
    ['id_card_url', 'TEXT'],
    ['manager_name', 'TEXT'],
    ['manager_mobile', 'TEXT'],
    ['area_manager_name', 'TEXT'],
    ['area_manager_mobile', 'TEXT'],
    ['nominee_name', 'TEXT'],
    ['office_address', 'TEXT']
  ],
  registrations: [
    ['name', 'TEXT'],
    ['mobile', 'TEXT'],
    ['email', 'TEXT'],
    ['gender', 'TEXT'],
    ['company', 'TEXT'],
    ['address', 'TEXT'],
    ['current_experience', 'TEXT'],
    ['total_experience', 'TEXT'],
    ['segment', 'TEXT'],
    ['profession', 'TEXT'],
    ['about', 'TEXT'],
    ['partner_name', 'TEXT'],
    ['partner_mobile', 'TEXT'],
    ['gumasta_url', 'TEXT'],
    ['id_card_url', 'TEXT'],
    ['manager_name', 'TEXT'],
    ['manager_mobile', 'TEXT'],
    ['area_manager_name', 'TEXT'],
    ['area_manager_mobile', 'TEXT'],
    ['nominee_name', 'TEXT'],
    ['office_address', 'TEXT']
  ]
};

export async function migrateSchema(env) {
  const results = {};
  for (const [table, columns] of Object.entries(SCHEMA_COLUMNS)) {
    const rows = await all(env, 'PRAGMA table_info(' + table + ')');
    const existing = new Set(rows.map(function (r) { return r.name; }));
    const added = [];
    for (const [colName, colType] of columns) {
      if (!existing.has(colName)) {
        await run(env, 'ALTER TABLE ' + table + ' ADD COLUMN ' + colName + ' ' + colType);
        added.push(colName);
      }
    }
    results[table] = { existing_columns: existing.size, added: added, added_count: added.length };
  }
  return { migrated_at: nowIso(), results: results };
}
