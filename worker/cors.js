// CORS policy for the API. Kept in its own module so the allow list can be tested
// without booting the whole Worker (and without pulling Hono into the test run).
//
// Native apps (Android/iOS) send no Origin header and are not affected by CORS.
// Add a frontend domain with the ALLOWED_ORIGINS worker variable, comma separated:
//   wrangler secret put ALLOWED_ORIGINS      (or [env.production.vars] in wrangler.toml)

export const DEFAULT_ALLOWED_ORIGINS = [
  'https://crm.dhankund.com',
  'https://www.dhankund.com',
  'https://dhankund.com',
  'https://dsa.dhankund.com',
  'https://api.dhankund.com',
];

export function allowedOrigins(env) {
  const raw = (env && env.ALLOWED_ORIGINS ? String(env.ALLOWED_ORIGINS) : '').trim();
  if (!raw) return DEFAULT_ALLOWED_ORIGINS.slice();
  return raw
    .split(',')
    .map(function (value) { return value.trim(); })
    .filter(Boolean);
}

export function isOriginAllowed(env, origin) {
  const value = (origin || '').trim();
  if (!value) return false;
  return allowedOrigins(env).indexOf(value) >= 0;
}
