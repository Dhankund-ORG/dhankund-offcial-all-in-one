const encoder = new TextEncoder();

let cachedAccessToken = null;
let cachedAccessTokenExpiry = 0;

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

async function getAccessToken(env) {
  if (cachedAccessToken && Date.now() < cachedAccessTokenExpiry) return cachedAccessToken;
  const raw = env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) throw new Error('FIREBASE_SERVICE_ACCOUNT is not configured');
  const sa = JSON.parse(raw);
  const nowSec = Math.floor(Date.now() / 1000);
  const tokenUri = sa.token_uri || 'https://oauth2.googleapis.com/token';
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = { iss: sa.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: tokenUri, iat: nowSec, exp: nowSec + 3600 };
  const assertion = await signJwtRs256(sa.private_key, header, claims);
  const res = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=' + encodeURIComponent(assertion)
  });
  if (!res.ok) throw new Error('FCM token exchange failed: ' + res.status);
  const data = await res.json();
  cachedAccessToken = data.access_token;
  cachedAccessTokenExpiry = Date.now() + ((data.expires_in || 3600) - 60) * 1000;
  return cachedAccessToken;
}

function toFcmData(data) {
  const out = {};
  if (data && typeof data === 'object') {
    for (const k of Object.keys(data)) {
      const v = data[k];
      out[k] = (v == null) ? '' : String(v);
    }
  }
  return out;
}

export async function sendFcm(env, message) {
  const projectId = env.FIREBASE_PROJECT_ID || 'dhankund';
  const accessToken = await getAccessToken(env);
  const payload = { message: { token: message.token, notification: { title: message.title || '', body: message.body || '' }, data: toFcmData(message.data) } };
  const res = await fetch('https://fcm.googleapis.com/v1/projects/' + projectId + '/messages:send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + accessToken },
    body: JSON.stringify(payload)
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error('FCM send failed: ' + res.status + ' ' + text.slice(0, 300));
  }
  return await res.json();
}
