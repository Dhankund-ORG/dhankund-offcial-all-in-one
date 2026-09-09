export const endpoints = [
  { method: 'GET', path: '/api/health', auth: false, summary: 'Health check' },
  { method: 'GET', path: '/api', auth: false, summary: 'API route index' },
  { method: 'GET', path: '/api/openapi.json', auth: false, summary: 'OpenAPI 3.1 spec' },
  { method: 'POST', path: '/api/v1/auth/login', auth: false, summary: 'Email/password login (JWT)' },
  { method: 'GET', path: '/api/v1/auth/me', auth: true, summary: 'Current session user' },
  { method: 'POST', path: '/api/v1/auth/logout', auth: true, summary: 'Logout' },
  { method: 'POST', path: '/api/v1/auth/verify-password', auth: true, summary: 'Verify password before destructive action' },
  { method: 'GET', path: '/api/v1/overview', auth: true, summary: 'Dashboard metrics' },
  { method: 'GET', path: '/api/v1/registrations', auth: true, summary: 'List registrations by role' },
  { method: 'PATCH', path: '/api/v1/registrations/{collection}/{id}', auth: true, summary: 'Update registration status' },
  { method: 'GET', path: '/api/v1/kyc-bank-users', auth: true, summary: 'List users for KYC/bank verification' },
  { method: 'PATCH', path: '/api/v1/users/{uid}/kyc', auth: true, summary: 'Toggle KYC verification' },
  { method: 'PATCH', path: '/api/v1/users/{uid}/bank', auth: true, summary: 'Toggle bank verification' },
  { method: 'DELETE', path: '/api/v1/users/{uid}', auth: true, summary: 'Delete a user record' },
  { method: 'GET', path: '/api/v1/loans', auth: true, summary: 'List loan applications' },
  { method: 'POST', path: '/api/v1/loans', auth: true, summary: 'Create loan application' },
  { method: 'PUT', path: '/api/v1/loans/{id}', auth: true, summary: 'Update loan application' },
  { method: 'PATCH', path: '/api/v1/loans/{id}/status', auth: true, summary: 'Update loan status' },
  { method: 'GET', path: '/api/v1/referrals', auth: true, summary: 'List referrals' },
  { method: 'POST', path: '/api/v1/referrals', auth: true, summary: 'Create referral' },
  { method: 'PATCH', path: '/api/v1/referrals/{id}/status', auth: true, summary: 'Update referral status' },
  { method: 'GET', path: '/api/v1/admin-posts', auth: true, summary: 'List admin posts' },
  { method: 'POST', path: '/api/v1/admin-posts', auth: true, summary: 'Create admin post' },
  { method: 'GET', path: '/api/v1/news-feed', auth: true, summary: 'List news feed' },
  { method: 'GET', path: '/api/v1/statuses', auth: true, summary: 'List status updates' },
  { method: 'GET', path: '/api/v1/bank-policies', auth: true, summary: 'List bank policies' },
  { method: 'POST', path: '/api/v1/bank-policies', auth: true, summary: 'Create bank policy' },
  { method: 'PUT', path: '/api/v1/bank-policies/{id}', auth: true, summary: 'Update bank policy' },
  { method: 'GET', path: '/api/v1/broadcasts', auth: true, summary: 'List broadcast history' },
  { method: 'POST', path: '/api/v1/broadcasts', auth: true, summary: 'Create broadcast (WhatsApp/Email/Push)' },
  { method: 'POST', path: '/api/v1/devices', auth: false, summary: 'Register FCM device token' },
  { method: 'POST', path: '/api/v1/push', auth: true, summary: 'Send an FCM push notification' },
  { method: 'POST', path: '/api/v1/upload', auth: true, summary: 'Upload a file to R2' },
  { method: 'GET', path: '/api/v1/download/{filename}', auth: false, summary: 'Download a file from R2' }
];

export function routeIndex() {
  return endpoints.map(function (e) { return { method: e.method, path: e.path, auth: e.auth, summary: e.summary }; });
}

export function openApiSpec() {
  const paths = {};
  for (const e of endpoints) {
    const method = e.method.toLowerCase();
    const pathItem = paths[e.path] || {};
    pathItem[method] = { summary: e.summary, security: e.auth ? [{ bearerAuth: [] }] : [], responses: { '200': { description: 'Success' } } };
    paths[e.path] = pathItem;
  }
  return {
    openapi: '3.1.0',
    info: { title: 'Dhankund CRM API', version: '1.0.0', description: 'Hono.js API on Cloudflare Workers. Data in D1, files in R2, FCM for push only.' },
    servers: [{ url: 'https://dhankund.com' }],
    components: { securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } } },
    paths: paths
  };
}

export function docsHtml() {
  const rows = endpoints.map(function (e) {
    return '<tr><td>' + e.method + '</td><td>' + e.path + '</td><td>' + (e.auth ? 'Bearer JWT' : 'Public') + '</td><td>' + e.summary + '</td></tr>';
  }).join('');
  return '<!doctype html><html><head><meta charset="utf-8"><title>Dhankund CRM API</title><style>body{font-family:system-ui,sans-serif;margin:2rem;background:#0f172a;color:#e2e8f0}table{border-collapse:collapse;width:100%}td,th{border:1px solid #334155;padding:.5rem;text-align:left}code{color:#7dd3fc}h1{color:#f8fafc}</style></head><body><h1>Dhankund CRM API</h1><p>OpenAPI: <a href="/api/openapi.json">/api/openapi.json</a> &middot; Index: <a href="/api">/api</a></p><table><thead><tr><th>Method</th><th>Path</th><th>Auth</th><th>Description</th></tr></thead><tbody>' + rows + '</tbody></table></body></html>';
}
