// Shared helpers for the Dhankund blog (server-side data fetching).
export const API_BASE = "https://api.dhankund.com";

export interface BlogCategory {
  id: string;
  name: string;
  slug: string;
  language: string;
}

export interface BlogPost {
  id: string;
  title: string;
  slug: string;
  content: string | null;
  excerpt: string | null;
  cover_image: string | null;
  category_id: string | null;
  category_name: string | null;
  tags: string[];
  language: string;
  status: string;
  author_name: string | null;
  seo_title: string | null;
  seo_description: string | null;
  published_at: string | null;
  updated_at: string | null;
  views: number;
}

// The upload endpoint returns relative paths like /api/v1/download/<file>.
export function resolveUrl(url: string | null | undefined): string {
  if (!url) return "";
  if (/^https?:\/\//.test(url)) return url;
  return API_BASE + url;
}

export async function getPosts(opts: {
  category?: string;
  language?: string;
  q?: string;
  limit?: number;
}): Promise<{ posts: BlogPost[]; total: number }> {
  const params = new URLSearchParams();
  if (opts.category) params.set("category", opts.category);
  if (opts.language) params.set("language", opts.language);
  if (opts.q) params.set("q", opts.q);
  params.set("limit", String(opts.limit ?? 50));
  try {
    const res = await fetch(`${API_BASE}/api/v1/blog?${params.toString()}`, {
      cache: "no-store",
    });
    if (!res.ok) return { posts: [], total: 0 };
    const data = await res.json();
    return {
      posts: Array.isArray(data.posts) ? (data.posts as BlogPost[]) : [],
      total: Number(data.total) || 0,
    };
  } catch {
    return { posts: [], total: 0 };
  }
}

export async function getPostBySlug(slug: string): Promise<BlogPost | null> {
  try {
    const res = await fetch(`${API_BASE}/api/v1/blog/${encodeURIComponent(slug)}`, {
      cache: "no-store",
    });
    if (!res.ok) return null;
    return (await res.json()) as BlogPost;
  } catch {
    return null;
  }
}

export async function getCategories(): Promise<BlogCategory[]> {
  try {
    const res = await fetch(`${API_BASE}/api/v1/blog-categories`, {
      cache: "no-store",
    });
    if (!res.ok) return [];
    const data = await res.json();
    return Array.isArray(data) ? (data as BlogCategory[]) : [];
  } catch {
    return [];
  }
}

const MONTHS = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

// Edge-runtime safe date formatting (no Intl locale dependency).
export function formatDate(iso: string | null | undefined): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}