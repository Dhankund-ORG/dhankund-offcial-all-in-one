# Dhankund - All-in-one setup guide

This repository contains three projects that share one Firebase project and one Cloudflare R2 bucket:

- DSA-Banker-flutter app - Flutter app for DSA/Bankers/Partners and customers
- dhankund_crm - Flutter web CRM (admin/staff)
- dhankund_official_site - Next.js site + upload/download backend (Next.js on Pages + Pages Functions fallback)

## 1. Firebase config (do NOT commit secrets)

Each Flutter app reads its Firebase config from a local config.env file (git-ignored).

DSA app:

    cp "DSA-Banker-flutter app/config.env.example" "DSA-Banker-flutter app/config.env"

CRM:

    cp dhankund_crm/config.env.example dhankund_crm/config.env

Fill in the real Firebase web/android/ios JSON values in config.env.

## 2. Upload backend (shared R2 bucket)

Both apps upload files by POSTing to /api/upload?filename=... on the base URL (default https://dhankund.com).

- Next.js routes live in dhankund_official_site/src/app/api/upload and .../api/download
- Cloudflare Pages Functions fallback lives in dhankund_official_site/functions/api/upload.ts and .../download/[[filename]].ts

The R2 bucket binding must be named R2_BUCKET in wrangler.toml / Pages settings.

## 3. Firestore rules

firestore.rules covers all three projects. Admin = users/{uid} role 'admin' OR 'staff'. Deploy with: firebase deploy --only firestore:rules

## 4. Field conventions

- loan_applications use user_id (not userId or email) for owner checks.
- referrals use referrer_id.
- registrations use uid.
