# Dhankund CRM

Production-ready control centre for Dhankund. The CRM is a Flutter Web app served by Cloudflare Workers Assets, with a Hono.js API running in the same Worker. All business data lives in Cloudflare D1, uploaded files live in R2, and Firebase is used only for FCM push notifications.

## Architecture

- Frontend: Flutter Web (build/web), served as Worker Assets.
- API: Hono.js (worker.js) on Cloudflare Workers.
- Database: Cloudflare D1 (database name dhankund-crm).
- Files: Cloudflare R2 bucket (dhankund-storage).
- Push: Firebase Cloud Messaging via a service account (optional). No other Firebase services are used.

## API

The API is discoverable:

- GET /api - JSON route index
- GET /api/openapi.json - OpenAPI 3.1 specification
- GET /docs - HTML documentation
- Business routes live under /api/v1

## Authentication

- Email and password only.
- Passwords are stored as PBKDF2-SHA256 hashes (100,000 iterations) in D1. Plain text passwords are never stored.
- Login issues an HS256 JWT signed with the SESSION_SECRET secret.
- The client keeps the token in shared_preferences and sends it as an Authorization: Bearer header.
- Login is restricted to users whose role is admin or staff.
- On the first login, if no user exists for ADMIN_EMAIL and the submitted password equals ADMIN_PASSWORD, an admin account is created in D1. After that, use the regular login flow.

## Secrets

Set these as Cloudflare Worker secrets and as GitHub Actions secrets for the deploy workflow.

Required:

- SESSION_SECRET - random string used to sign JWTs
- ADMIN_EMAIL - bootstrap admin email
- ADMIN_PASSWORD - bootstrap admin password
- D1_DATABASE_ID - Cloudflare D1 database id (replaces FILL_ME_D1_DATABASE_ID in wrangler.toml)
- CLOUDFLARE_API_TOKEN - Cloudflare API token
- CLOUDFLARE_ACCOUNT_ID - Cloudflare account id

Optional (only for push notifications):

- FIREBASE_PROJECT_ID - defaults to dhankund when unset
- FIREBASE_SERVICE_ACCOUNT - the JSON service account key

## Local development

1. Create a D1 database named dhankund-crm in the Cloudflare dashboard and put its id in wrangler.toml (database_id).
2. Run: npm install
3. Apply the schema: npx wrangler d1 execute dhankund-crm --remote --file=schema.sql
4. Set secrets: npx wrangler secret put SESSION_SECRET (and the other secrets listed above)
5. Start the Worker locally: npx wrangler dev
6. Build the frontend: flutter build web --release

## Deployment

Pushing to the master branch triggers .github/workflows/crm_flutter_web_deploy.yml. It installs Node and Flutter dependencies, validates required secrets, injects the D1 database id, applies the D1 schema, sets Worker secrets, builds Flutter Web, and deploys with wrangler deploy.

Pull requests run .github/workflows/ci_crm.yml, which syntax-checks the Worker JavaScript, runs flutter analyze, flutter test, and a release web build.

## Data model

All tables are defined in schema.sql: users, registrations, loan_applications, referrals, admin_posts, news_feed, statuses, bank_policies, broadcast_history, and fcm_tokens. Timestamps are ISO-8601 strings. Demo and mock data have been removed; the UI renders real D1 data only.

## Notes

- File upload (POST /api/v1/upload) requires Bearer auth. File download (GET /api/v1/download/filename) is intentionally public so images can be rendered with simple URLs.
- The API base URL is read from config.env (API_BASE_URL). When it is empty, the client falls back to the same origin, which works for the combined Worker and Assets deployment.
