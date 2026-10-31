import { all, first, run, safeJson } from './db.js';

// Keeps Unicode letters (Devanagari etc.) and numbers, so Hindi titles get
// readable slugs while staying URL-safe.
export function slugify(text) {
  return String(text || '')
    .toLowerCase()
    .trim()
    .replace(/['"“”‘’]/g, '')
    .replace(/[^\p{L}\p{M}\p{N}\s-]/gu, ' ')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

export async function uniqueBlogSlug(env, slug, excludeId) {
  let base = slug || 'post';
  let candidate = base;
  let n = 1;
  for (;;) {
    const existing = await first(env, 'SELECT id FROM blog_posts WHERE slug = ? AND id != ?', [candidate, excludeId || '']);
    if (!existing) return candidate;
    n += 1;
    candidate = base + '-' + n;
  }
}

let blogSchemaEnsured = false;
export async function ensureBlogSchema(env) {
  if (blogSchemaEnsured || !env || !env.DB) return;
  try {
    const cols = await all(env, 'PRAGMA table_info(blog_posts)');
    const colNames = new Set((cols || []).map(function (c) { return c.name; }));
    if (colNames.size > 0) {
      if (!colNames.has('keywords')) {
        await run(env, 'ALTER TABLE blog_posts ADD COLUMN keywords TEXT');
      }
      if (!colNames.has('faqs')) {
        await run(env, 'ALTER TABLE blog_posts ADD COLUMN faqs TEXT');
      }
      if (!colNames.has('views')) {
        await run(env, 'ALTER TABLE blog_posts ADD COLUMN views INTEGER NOT NULL DEFAULT 0');
      }
      if (!colNames.has('published_at')) {
        await run(env, 'ALTER TABLE blog_posts ADD COLUMN published_at TEXT');
      }
    }
    blogSchemaEnsured = true;
  } catch (err) {
    console.error('ensureBlogSchema warning:', err);
  }
}

export function blogPostOut(row) {
  return Object.assign({}, row, {
    tags: safeJson(row.tags, []),
    faqs: safeJson(row.faqs, []),
    views: Number(row.views) || 0,
  });
}