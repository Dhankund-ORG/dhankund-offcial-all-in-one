export const endpoints = [
  { method: 'GET', path: '/api/health', auth: false, summary: 'Health check' },
  { method: 'GET', path: '/api', auth: false, summary: 'API route index' },
  { method: 'GET', path: '/api/openapi.json', auth: false, summary: 'OpenAPI 3.1 spec' },
  { method: 'GET', path: '/docs', auth: false, summary: 'API docs' },
  { method: 'POST', path: '/api/v1/auth/signup', auth: false, summary: 'Email/password signup (dsa/banker/partner/customer)' },
  { method: 'POST', path: '/api/v1/auth/login', auth: false, summary: 'Email/password login (any role, JWT)' },
  { method: 'GET', path: '/api/v1/auth/me', auth: true, summary: 'Current session user' },
  { method: 'POST', path: '/api/v1/auth/logout', auth: true, summary: 'Logout' },
  { method: 'POST', path: '/api/v1/auth/verify-password', auth: true, summary: 'Verify password before destructive action' },
  { method: 'GET', path: '/api/v1/me/profile', auth: true, summary: 'Current user profile + completion flag' },
  { method: 'GET', path: '/api/v1/me/loans', auth: true, summary: 'Loans belonging to the current user' },
  { method: 'GET', path: '/api/v1/me/referrals', auth: true, summary: 'Referrals made by the current user' },
  { method: 'POST', path: '/api/v1/registrations', auth: true, summary: 'Submit a DSA/Banker/Partner registration' },
  { method: 'POST', path: '/api/v1/loans', auth: true, summary: 'Create loan application' },
  { method: 'POST', path: '/api/v1/referrals', auth: true, summary: 'Create referral' },
  { method: 'GET', path: '/api/v1/news-feed', auth: true, summary: 'List news feed' },
  { method: 'GET', path: '/api/v1/statuses', auth: true, summary: 'List status updates' },
  { method: 'GET', path: '/api/v1/admin-posts', auth: true, summary: 'List admin posts' },
  { method: 'GET', path: '/api/v1/bank-policies', auth: true, summary: 'List bank policies' },
  { method: 'POST', path: '/api/v1/devices', auth: false, summary: 'Register FCM device token' },
  { method: 'GET', path: '/api/v1/download/{filename}', auth: false, summary: 'Download a file from R2' },
  { method: 'POST', path: '/api/v1/upload', auth: true, summary: 'Upload a file to R2' },
  { method: 'GET', path: '/api/v1/overview', auth: 'admin', summary: 'Dashboard metrics (admin)' },
  { method: 'GET', path: '/api/v1/registrations', auth: 'admin', summary: 'List registrations by role (admin)' },
  { method: 'PATCH', path: '/api/v1/registrations/{id}', auth: 'admin', summary: 'Update registration status (admin)' },
  { method: 'GET', path: '/api/v1/kyc-bank-users', auth: 'admin', summary: 'List users for KYC/bank verification (admin)' },
  { method: 'PATCH', path: '/api/v1/users/{uid}/kyc', auth: 'admin', summary: 'Toggle KYC verification (admin)' },
  { method: 'PATCH', path: '/api/v1/users/{uid}/bank', auth: 'admin', summary: 'Toggle bank verification (admin)' },
  { method: 'DELETE', path: '/api/v1/users/{uid}', auth: 'admin', summary: 'Delete a user record (admin)' },
  { method: 'GET', path: '/api/v1/loans', auth: 'admin', summary: 'List all loan applications (admin)' },
  { method: 'PUT', path: '/api/v1/loans/{id}', auth: 'admin', summary: 'Update loan application (admin)' },
  { method: 'PATCH', path: '/api/v1/loans/{id}/status', auth: 'admin', summary: 'Update loan status (admin)' },
  { method: 'GET', path: '/api/v1/referrals', auth: 'admin', summary: 'List all referrals (admin)' },
  { method: 'PATCH', path: '/api/v1/referrals/{id}/status', auth: 'admin', summary: 'Update referral status (admin)' },
  { method: 'POST', path: '/api/v1/admin-posts', auth: 'admin', summary: 'Create admin post (admin)' },
  { method: 'POST', path: '/api/v1/bank-policies', auth: 'admin', summary: 'Create bank policy (admin)' },
  { method: 'PUT', path: '/api/v1/bank-policies/{id}', auth: 'admin', summary: 'Update bank policy (admin)' },
  { method: 'GET', path: '/api/v1/broadcasts', auth: 'admin', summary: 'List broadcast history (admin)' },
  { method: 'POST', path: '/api/v1/broadcasts', auth: 'admin', summary: 'Create broadcast (admin)' },
  { method: 'POST', path: '/api/v1/push', auth: 'admin', summary: 'Send an FCM push notification (admin)' },
  { method: 'GET', path: '/api/v1/migrate/diff', auth: 'admin', summary: 'Compare Firestore vs D1 data (admin)' },
  { method: 'GET', path: '/api/v1/migrate/export', auth: 'admin', summary: 'Export Firestore data as JSON backup (admin)' },
  { method: 'POST', path: '/api/v1/migrate/import', auth: 'admin', summary: 'Import all Firestore data into D1 (admin)' },
  { method: 'POST', path: '/api/v1/migrate/import-auth', auth: 'admin', summary: 'Import Firebase Auth passwords into D1 (admin)' },
  { method: 'POST', path: '/api/v1/migrate/schema', auth: 'admin', summary: 'Add missing columns to users + registrations tables (admin)' },
  { method: 'POST', path: '/api/v1/migrate/set-signer-key', auth: 'admin', summary: 'Manually set Firebase Auth signer key for password verification (admin)' }
];

export function routeIndex() {
  return endpoints.map(function (e) { return { method: e.method, path: e.path, auth: e.auth, summary: e.summary }; });
}

export function openApiSpec() {
  const paths = {};
  for (const e of endpoints) {
    const method = e.method.toLowerCase();
    const pathItem = paths[e.path] || {};
    const security = e.auth === 'admin' ? [{ bearerAuth: [] }] : (e.auth ? [{ bearerAuth: [] }] : []);
    pathItem[method] = { summary: e.summary, security: security, responses: { '200': { description: 'Success' } } };
    paths[e.path] = pathItem;
  }
  return {
    openapi: '3.1.0',
    info: { title: 'Dhankund API', version: '1.0.0', description: 'Shared Hono.js API on Cloudflare Workers. CRM admin panel + DSA user app both talk to this one API. Data in D1, files in R2, FCM for push.' },
    servers: [{ url: 'https://dhankund-api.nssite.workers.dev' }],
    components: { securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } } },
    paths: paths
  };
}

export function docsHtml() {
  const rows = endpoints.map(function (e) {
    const authLabel = e.auth === 'admin' ? 'Admin JWT' : (e.auth ? 'JWT' : 'Public');
    return '<tr><td>' + e.method + '</td><td>' + e.path + '</td><td>' + authLabel + '</td><td>' + e.summary + '</td></tr>';
  }).join('');
  return '<!doctype html><html><head><meta charset="utf-8"><title>Dhankund API</title><style>body{font-family:system-ui,sans-serif;margin:2rem;background:#0f172a;color:#e2e8f0}table{border-collapse:collapse;width:100%}td,th{border:1px solid #334155;padding:.5rem;text-align:left}a{color:#7dd3fc}h1{color:#f8fafc}</style></head><body><h1>Dhankund API</h1><p>OpenAPI: <a href="/api/openapi.json">/api/openapi.json</a> &middot; Index: <a href="/api">/api</a></p><table><thead><tr><th>Method</th><th>Path</th><th>Auth</th><th>Description</th></tr></thead><tbody>' + rows + '</tbody></table></body></html>';
}
