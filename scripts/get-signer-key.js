#!/usr/bin/env node
// Fetches Firebase Auth project config (signerKey + saltSeparator) and outputs as JSON.
// Used by deploy workflow to automatically store in D1.
const crypto = require('crypto');

async function getAccessToken(sa, scope) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: sa.client_email,
    scope: scope,
    aud: sa.token_uri || 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600
  };
  const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
  const encodedClaims = Buffer.from(JSON.stringify(claims)).toString('base64url');
  const data = encodedHeader + '.' + encodedClaims;
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(data);
  const signature = sign.sign(sa.private_key, 'base64url');
  const assertion = data + '.' + signature;
  const tokenRes = await fetch(sa.token_uri || 'https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + encodeURIComponent(assertion)
  });
  if (!tokenRes.ok) { const b = await tokenRes.text(); throw new Error('Token exchange failed: ' + tokenRes.status + ' ' + b.slice(0, 200)); }
  const td = await tokenRes.json();
  return td.access_token;
}

async function tryEndpoint(url, token, projectId) {
  const res = await fetch(url, {
    headers: { Authorization: 'Bearer ' + token, 'X-Goog-User-Project': projectId }
  });
  if (!res.ok) {
    console.error('  ' + url.slice(0, 80) + ' -> HTTP ' + res.status);
    return null;
  }
  const config = await res.json();
  console.error('  ' + url.slice(0, 80) + ' -> OK. Keys: ' + Object.keys(config).join(','));
  return config;
}

async function main() {
  const saRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!saRaw) { console.error('FIREBASE_SERVICE_ACCOUNT not set'); process.exit(1); }
  const sa = JSON.parse(saRaw);
  const projectId = sa.project_id;
  console.error('Project: ' + projectId);

  // Try with cloud-platform scope (what Firebase Admin SDK uses)
  const scopes = [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/firebase',
    'https://www.googleapis.com/auth/firebase.auth',
  ].join(' ');
  console.error('Getting OAuth2 token with cloud-platform + firebase scopes...');
  const token = await getAccessToken(sa, scopes);
  console.error('Token obtained, length=' + token.length);

  // Try multiple endpoints
  const endpoints = [
    'https://identitytoolkit.googleapis.com/v1/projects/' + projectId,
    'https://identitytoolkit.googleapis.com/v1/projects/' + projectId + '/config',
    'https://identitytoolkit.googleapis.com/admin/v2/projects/' + projectId + '/config',
    'https://identitytoolkit.googleapis.com/admin/v2/projects/' + projectId,
  ];

  for (const url of endpoints) {
    const config = await tryEndpoint(url, token, projectId);
    if (config) {
      const signIn = config.signIn || config.signInConfig || {};
      const hash = signIn.hash || signIn.passwordHashConfig || signIn.passwordHashConfiguration || {};
      const signerKey = hash.signerKey || null;
      const saltSeparator = hash.saltSeparator || 'Bw==';
      if (signerKey) {
        console.error('SUCCESS: signerKey found! length=' + signerKey.length);
        console.log(JSON.stringify({ signerKey: signerKey, saltSeparator: saltSeparator }));
        return;
      } else {
        console.error('  Config found but no signerKey in signIn.hash. signIn keys: ' + Object.keys(signIn).join(','));
      }
    }
  }

  // If REST API fails, try firebase-admin SDK as fallback
  console.error('REST API failed. Trying firebase-admin SDK...');
  try {
    const admin = require('firebase-admin');
    const cred = admin.credential.cert(sa);
    admin.initializeApp({ credential: cred, projectId: projectId });
    const auth = admin.auth();
    // Try projectConfig (available in newer SDK versions)
    if (typeof auth.projectConfig === 'function') {
      const config = await auth.projectConfig();
      const signIn = config.signIn || {};
      const hash = signIn.hash || {};
      if (hash.signerKey) {
        console.error('SUCCESS via firebase-admin: signerKey found!');
        console.log(JSON.stringify({ signerKey: hash.signerKey, saltSeparator: hash.saltSeparator || 'Bw==' }));
        process.exit(0);
      }
    }
    // Try getUser - password hash contains the salt info
    console.error('projectConfig not available. Trying getUser for hash parameters...');
    const userRecord = await auth.getUserByEmail((await auth.listUsers(1)).users[0].email);
    if (userRecord.passwordHash && userRecord.passwordSalt) {
      console.error('Got password hash from user record.');
      console.error('NOTE: signerKey cannot be obtained from user records. It is a project-level config.');
    }
  } catch (sdkErr) {
    console.error('firebase-admin SDK failed: ' + sdkErr.message);
  }

  console.error('FAILED: Could not obtain signerKey from any method.');
  console.error('Please set it manually via POST /api/v1/migrate/set-signer-key');
  process.exit(1);
}

main().catch(e => { console.error(e.message); process.exit(1); });