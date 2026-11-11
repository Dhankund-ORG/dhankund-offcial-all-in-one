# WhatsApp Cloud API module (CRM)

Production code for WhatsApp messaging inside the Dhankund CRM: send, receive,
templates (Hindi + English), media through R2, consent, and bulk campaigns.
Built only on Cloudflare — Workers, D1, R2, Durable Objects. No BSP, no
third-party SDK, Firebase stays FCM-only.

## Files

| File | What it does |
| --- | --- |
| `worker/whatsapp.js` | Graph API client, retries, error mapping, phone normalisation, webhook signature, inbound parsing, sending, media download/upload |
| `worker/whatsapp_schema.js` | `ensureWhatsappSchema()` + the SQL for the seven `wa_*` tables |
| `worker/whatsapp_templates.js` | Template create / edit / delete / list / sync, Hindi + English pairs, preview |
| `worker/whatsapp_audience.js` | Audience builder over existing tables, dedupe, consent filtering |
| `worker/whatsapp_broadcast.js` | Campaign engine, per-recipient rows, batch sender, Durable Object, cron resume |
| `worker/whatsapp_routes.js` | All HTTP routes; registered from `worker.js` |
| `test/whatsapp.test.js` | 21 unit tests (`node --test`) |

`worker.js` changes are two imports plus the block above `export default app;`.

## Environment / secrets

Add these as GitHub Secrets and push them with `wrangler secret put` in
`deploy_api.yml`, exactly like `SESSION_SECRET`:

| Secret | Required | Purpose |
| --- | --- | --- |
| `WHATSAPP_ACCESS_TOKEN` | yes | Permanent System User token |
| `WHATSAPP_PHONE_NUMBER_ID` | yes | Number that sends the messages |
| `WHATSAPP_BUSINESS_ACCOUNT_ID` | yes | WABA id, used for templates |
| `WHATSAPP_VERIFY_TOKEN` | yes | Webhook challenge token (any long random string) |
| `WHATSAPP_APP_SECRET` | yes | Meta app secret, verifies `X-Hub-Signature-256` |
| `WHATSAPP_WEBHOOK_PATH_SECRET` | recommended | Extra lock: the callback URL itself carries this random segment |
| `WHATSAPP_API_VERSION` | optional | Defaults to `v21.0` |

The module never logs a token, an app secret or a full phone number.

## Webhook

Register this URL in the Meta app dashboard (WhatsApp → Configuration →
Callback URL) and subscribe to the `messages` field:

```
https://api.dhankund.com/api/v1/whatsapp/webhook/<WHATSAPP_WEBHOOK_PATH_SECRET>
```

Without `WHATSAPP_WEBHOOK_PATH_SECRET` the plain path also works, but the path
secret is recommended: a leaked verify token alone is then not enough to post
fake events. Three checks run on every request:

1. path secret (if configured) → otherwise 404;
2. `X-Hub-Signature-256` HMAC-SHA256 over the raw body with the app secret → otherwise 401;
3. duplicate `event_id` in `wa_webhook_events` → skipped, so Meta retries never double-post.

The route answers Meta immediately and does the work in `waitUntil`.

## Routes

Public: `GET|POST /api/v1/whatsapp/webhook[/:secret]`.
Everything else requires a CRM session; `admin`/`staff` only.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/api/v1/whatsapp/status` | Config check, counts, last webhook event |
| GET | `/api/v1/whatsapp/threads` | Inbox list with unread counts |
| GET | `/api/v1/whatsapp/messages?phone=` | One conversation (`&mark_read=1` to mark read) |
| POST | `/api/v1/whatsapp/send` | One message: text, template or media |
| POST | `/api/v1/whatsapp/mark-read` | Read receipt to Meta |
| POST | `/api/v1/whatsapp/media` | Upload (multipart) → R2 + Meta media id |
| GET | `/api/v1/whatsapp/media/:key` | Stream a stored file |
| GET | `/api/v1/whatsapp/templates` | Cached templates |
| POST | `/api/v1/whatsapp/templates/sync` | Pull templates from Meta |
| POST | `/api/v1/whatsapp/templates/preview` | Render body with variables |
| POST | `/api/v1/whatsapp/templates` | Create (`language: "both"` = hi + en) |
| PUT | `/api/v1/whatsapp/templates/:id` | Edit (Meta resets it to PENDING) |
| DELETE | `/api/v1/whatsapp/templates/:id` | Delete one language |
| DELETE | `/api/v1/whatsapp/templates/by-name/:name` | Delete every language of a name |
| GET | `/api/v1/whatsapp/audience/sources` | Available sources and filters |
| POST | `/api/v1/whatsapp/audience/preview` | Count, skips and sample before sending |
| GET/POST | `/api/v1/whatsapp/broadcasts` | List / create a campaign |
| GET | `/api/v1/whatsapp/broadcasts/:id` | Progress and per-status counts |
| POST | `/api/v1/whatsapp/broadcasts/:id/tick` | Send one batch (cron / manual) |
| POST | `/api/v1/whatsapp/broadcasts/:id/pause\|resume` | Stop / continue |
| GET/POST | `/api/v1/whatsapp/contacts` | List contacts / set consent |
| POST | `/api/v1/whatsapp/contacts/:id/convert-lead` | Turn a chat into a CRM lead |

## Creating a Hindi + English template

One call creates both languages:

```bash
curl -X POST https://api.dhankund.com/api/v1/whatsapp/templates \
  -H "Authorization: Bearer $CRM_TOKEN" -H "Content-Type: application/json" \
  -d '{
    "name": "loan_status_update",
    "category": "UTILITY",
    "language": "both",
    "header": { "text": "Dhankund" },
    "perLanguage": {
      "hi": { "body": "नमस्ते {{1}}, आपके लोन {{2}} की स्थिति अब {{3}} है।" },
      "en": { "body": "Hello {{1}}, your loan {{2}} status is now {{3}}." }
    },
    "footer": "Dhankund Global Pvt Ltd",
    "buttons": [{ "type": "QUICK_REPLY", "text": "धन्यवाद" }]
  }'
```

Rules enforced before anything reaches Meta: name is `[a-z0-9_]`, body ≤ 1024
characters, header ≤ 60, footer ≤ 60, at most 10 buttons, and every `{{n}}`
placeholder gets an example value (Meta rejects templates without examples).

## Audience sources

`registrations`, `loans`, `referrals`, `insurance`, `users`, `contacts` — all
read from tables the CRM already writes, so no data has to be re-entered.
Filters: `role`, `status`, `loan_type`, `insurance_type`, `opt_in_status`,
`search`. Phone numbers are normalised to E.164, duplicates are dropped, and
`requireOptIn` (default true) keeps only contacts whose `wa_contacts.opt_in_status`
is `opted_in`. Preview first:

```bash
curl -X POST .../api/v1/whatsapp/audience/preview \
  -d '{"sources":["loans","referrals"],"filters":{"status":"Pending"},"requireOptIn":true}'
```

## Broadcast engine

`POST /broadcasts` writes one `wa_broadcast_recipients` row per person and kicks
the Durable Object. The DO sends 20 messages per batch (max 50) and re-arms its
alarm until the queue is empty, so no single request runs for the whole
campaign. A Cron Trigger calls `resumePendingBroadcasts()` every 5 minutes for
campaigns that stopped because an isolate was recycled. A `190` (bad token) or
`368` (blocked account) pauses the campaign instead of burning the list.

`wrangler.toml` additions:

```toml
[env.production]
# … existing keys …
crons = ["*/5 * * * *"]

[[env.production.durable_objects.bindings]]
name = "WHATSAPP_SENDER"
class_name = "WhatsappBroadcastSender"

[[env.production.migrations]]
tag = "v1"
new_sqlite_classes = ["WhatsappBroadcastSender"]
```

The module works without the DO too: campaigns then advance on the cron or on
`/tick`.

## Media

Outbound: `POST /media` (multipart) stores the file in
`wa-media/out/YYYY-MM/…`, uploads it to Meta and returns `media_id`; pass that
to `/send` with `type: "image"` (or `document`, `video`, `audio`).
Inbound: the webhook downloads the file immediately into
`wa-media/in/YYYY-MM/<wa_message_id>.<ext>`, because Meta deletes its own media
after about 30 days. Files are served only through an authenticated route.

## Lead integration

Every inbound message upserts `wa_contacts` and tries to match an existing lead
by phone across `loan_applications`, `referrals` and `registrations`. If nothing
matches, the contact is stored with `source = inbound` and can be converted with
`POST /contacts/:id/convert-lead`, which creates a `referrals` row (same shape as
the website contact form) and links it back.

## Tests

```bash
node --test test/
```

21 WhatsApp tests cover phone normalisation, signature verification, webhook
parsing, template building and validation, audience dedupe and consent, opt-out
keywords and media extensions. Graph API calls are never made in tests.

## Not covered yet

The Flutter screens (inbox, template manager, broadcast page) are the next step;
the API above is what they will call. Nothing here is deployed — it needs the
secrets, the `wrangler.toml` additions and a merge to `master`.
