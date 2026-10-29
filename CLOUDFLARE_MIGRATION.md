# Cloudflare account-to-account migration

The CRM has an **Admin -> Cloudflare Migration** page that copies a D1 database
and an R2 bucket from one Cloudflare account to another. It is driven by the
browser, one bounded batch at a time, so it does not need a long-running server
or a local CLI.

## Required Cloudflare API tokens

Create one token **per account** in the Cloudflare dashboard. Use the narrowest
scope possible:

| Permission | Why it is needed |
| --- | --- |
| Account Settings: Read | Read the account name and verify the token |
| D1: Edit | List tables, export, reset and import the database |
| Workers R2 Storage: Edit | List, download, upload and create R2 buckets/objects |

Scope the token to the specific account. Do not use a Global API Key. The
tokens are sent only with the individual requests made by the migration page;
they are never written to D1, R2, browser storage or logs.

## How to run a migration

1. Open `crm.dhankund.com` and sign in as an admin.
2. Open **Cloudflare Migration** in the sidebar.
3. Fill in Account 1 (source) and Account 2 (destination):
   - Account ID (32 hex characters)
   - API token
   - D1 database ID (leave blank on the destination to create a new one)
   - R2 bucket name (leave blank on the destination to create a new one)
4. Select D1, R2, or both.
5. Optionally enable **Auto-create destination resources** and choose the new
   database/bucket names.
6. Click **Validate accounts** and review the preflight panel.
7. Click **Start migration**. The live log shows every step: export, import,
   table verification, R2 batches and object verification.
8. Only enable **Reset destination D1 before import** when the destination
   database is disposable. It drops every table and view before importing, but
   only after the source export has finished successfully. If the export fails,
   the destination is left untouched.

## Why the apex redirect runs after the site deploy

The official site Worker owns `www.dhankund.com`. The apex redirect Worker owns
`dhankund.com`. Deploy the site first so Wrangler detaches the apex custom
domain from it, then the redirect Worker attaches to the now-free apex hostname.
Running them in the other order would make the two custom-domain claims
conflict.

## Limits

- D1 export/import is capped at 90 MB in this web tool.
- R2 objects are capped at 50 MB each, and one request moves a bounded batch
  (time and byte limits) to stay inside Worker memory.
- R2 counting/verification is capped at 2,000 objects per action; results are
  marked `capped` when the cap is reached.
- Larger D1 databases should be moved with `wrangler d1 export` / `wrangler d1
  import`. Larger R2 objects or buckets should be moved with `rclone` using the
  R2 S3 API. The web tool reports these cases as skipped objects instead of
  failing the whole migration.

## Apex to www redirect

`dhankund.com` permanently redirects to `www.dhankund.com`:

- The official site Worker is bound to `www.dhankund.com`.
- `dhankund_official_site/apex_redirect_worker.js` is a small Worker bound to
  `dhankund.com`. It returns a `301` to the same path and query on the `www`
  host.
- `.github/workflows/official_site_deploy.yml` deploys the official site first
  and the apex Worker afterwards, so the apex custom domain is free when the
  redirect Worker attaches to it.
