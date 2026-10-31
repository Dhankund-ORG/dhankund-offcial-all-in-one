import { first, safeJson } from './db.js';

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
export function blogPostOut(row) {
  return Object.assign({}, row, {
    tags: safeJson(row.tags, []),
    faqs: safeJson(row.faqs, []),
    views: Number(row.views) || 0,
  });
}