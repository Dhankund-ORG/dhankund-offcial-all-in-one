// Dynamic blog routes for the Dhankund website.
// Handles /blog (live listing) and /blog/:slug (live article) on every request
// by fetching from the shared API, so a newly published post appears instantly
// without a redeploy. Server-rendered HTML keeps the pages SEO friendly.

const API_BASE = "https://api.dhankund.com";
const SITE_URL = "https://www.dhankund.com";
const SITE_NAME = "Dhankund";

interface BlogPost {
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
  published_at: string | null;
  views: number;
}

interface BlogCategory {
  id: string;
  name: string;
  slug: string;
  language: string;
}

function escapeHtml(str: string | null | undefined): string {
  return String(str ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function resolveUrl(url: string | null | undefined): string {
  if (!url) return "";
  if (/^https?:\/\//.test(url)) return url;
  return API_BASE + url;
}

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  ];
  return `${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()}`;
}

// ---------- minimal, safe Markdown rendering ----------

function renderInline(text: string): string {
  let t = escapeHtml(text);
  t = t.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_m, alt, src) => {
    const url = resolveUrl(String(src).trim());
    return `<img src="${escapeHtml(url)}" alt="${escapeHtml(alt)}" loading="lazy" />`;
  });
  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, label, href) => {
    const u = String(href).trim();
    const safe = u.startsWith("http") ? u : SITE_URL + (u.startsWith("/") ? u : "/" + u);
    return `<a href="${escapeHtml(safe)}" target="_blank" rel="noopener noreferrer">${label}</a>`;
  });
  t = t.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  t = t.replace(/\*([^*]+)\*/g, "<em>$1</em>");
  t = t.replace(/`([^`]+)`/g, "<code>$1</code>");
  return t;
}

function renderMarkdown(md: string | null | undefined): string {
  const lines = String(md ?? "").split("\n");
  const html: string[] = [];
  let inList = false;
  let inBlockquote = false;

  function closeList() {
    if (inList) {
      html.push("</ul>");
      inList = false;
    }
  }
  function closeQuote() {
    if (inBlockquote) {
      html.push("</blockquote>");
      inBlockquote = false;
    }
  }

  for (const raw of lines) {
    const line = raw.replace(/\r$/, "");
    const trimmed = line.trim();

    if (trimmed === "") {
      closeList();
      closeQuote();
      continue;
    }
    if (/^#{1,4}\s/.test(trimmed)) {
      closeList();
      closeQuote();
      const level = trimmed.match(/^#+/)?.[0].length ?? 2;
      html.push(`<h${level}>${renderInline(trimmed.replace(/^#+\s*/, ""))}</h${level}>`);
      continue;
    }
    if (/^---+$/.test(trimmed)) {
      closeList();
      closeQuote();
      html.push("<hr />");
      continue;
    }
    if (/^>\s?/.test(trimmed)) {
      closeList();
      if (!inBlockquote) {
        html.push("<blockquote>");
        inBlockquote = true;
      }
      html.push(`<p>${renderInline(trimmed.replace(/^>\s?/, ""))}</p>`);
      continue;
    }
    const ulMatch = trimmed.match(/^[-*]\s+(.*)/);
    if (ulMatch) {
      closeQuote();
      if (!inList) {
        html.push("<ul>");
        inList = true;
      }
      html.push(`<li>${renderInline(ulMatch[1])}</li>`);
      continue;
    }
    const olMatch = trimmed.match(/^\d+[.)]\s+(.*)/);
    if (olMatch) {
      closeQuote();
      if (!inList) {
        html.push("<ol>");
        inList = true;
      }
      html.push(`<li>${renderInline(olMatch[1])}</li>`);
      continue;
    }
    closeList();
    closeQuote();
    html.push(`<p>${renderInline(line)}</p>`);
  }
  closeList();
  closeQuote();
  return html.join("");
}

// ---------- layout ----------

function layout(opts: { title: string; description: string; active: string; body: string }): Response {
  const navItems = [
    { href: "/", label: "Home", key: "home" },
    { href: "/blog", label: "Blog", key: "blog" },
    { href: "/about", label: "About Us", key: "about" },
    { href: "/contact", label: "Contact", key: "contact" },
    { href: "/privacy", label: "Privacy Policy", key: "privacy" },
    { href: "/terms", label: "Terms", key: "terms" },
  ];
  const nav = navItems
    .map(
      (item) =>
        `<a href="${item.href}" class="${item.key === opts.active ? "nav-link active" : "nav-link"}">${item.label}</a>`,
    )
    .join("");
  const html = `<!doctype html>
<html lang="hi">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(opts.title)}</title>
<meta name="description" content="${escapeHtml(opts.description)}" />
<link rel="canonical" href="${SITE_URL}${opts.active === "blog" ? "/blog" : "/blog/" + opts.active}" />
<style>
:root { --primary:#1e3a8a; --primary-hover:#1e40af; --accent:#3b82f6; }
* { box-sizing: border-box; }
body { margin:0; font-family:'Inter',system-ui,-apple-system,sans-serif; background:#f8fafc; color:#0f172a; min-height:100vh; display:flex; flex-direction:column; }
a { text-decoration:none; }
.container { width:100%; max-width:1200px; margin:0 auto; padding:0 24px; }
.site-header { position:sticky; top:0; z-index:50; background:rgba(255,255,255,0.85); backdrop-filter:blur(8px); border-bottom:1px solid #e2e8f0; }
.header-inner { display:flex; align-items:center; justify-content:space-between; padding:16px 24px; max-width:1200px; margin:0 auto; }
.brand { font-size:24px; font-weight:800; color:var(--primary); display:flex; align-items:center; gap:8px; }
.brand .logo { background:var(--primary); color:#fff; padding:2px 6px; border-radius:6px; font-size:14px; }
.nav { display:flex; gap:24px; font-weight:500; color:#334155; }
.nav-link { color:#334155; transition:color .15s; }
.nav-link:hover { color:var(--accent); }
.nav-link.active { color:var(--primary); font-weight:700; }
.btn-primary { display:inline-block; padding:10px 24px; border-radius:12px; font-weight:600; color:#fff; background:var(--primary); transition:all .2s; }
.btn-primary:hover { background:var(--primary-hover); }
.btn-outline { display:inline-block; padding:10px 24px; border-radius:12px; font-weight:600; color:var(--primary); border:2px solid var(--primary); transition:all .2s; }
.btn-outline:hover { background:var(--primary); color:#fff; }
main { flex:1; }
.page-header { background:#f1f5f9; padding:56px 0; text-align:center; }
.page-header h1 { margin:0 0 12px; font-size:40px; font-weight:800; color:#0f172a; }
.page-header p { margin:0 auto; max-width:640px; color:#475569; font-size:17px; line-height:1.6; }
.section { padding:40px 0; }
.posts-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(320px,1fr)); gap:28px; }
.card { background:#fff; border:1px solid #e2e8f0; border-radius:16px; overflow:hidden; box-shadow:0 4px 12px rgba(0,0,0,0.05); transition:box-shadow .2s; display:flex; flex-direction:column; color:#0f172a; }
.card:hover { box-shadow:0 12px 24px rgba(0,0,0,0.1); }
.card-cover { height:200px; background:#f1f5f9; overflow:hidden; }
.card-cover img { width:100%; height:100%; object-fit:cover; transition:transform .3s; }
.card:hover .card-cover img { transform:scale(1.05); }
.card-body { padding:22px; display:flex; flex-direction:column; flex:1; }
.badges { display:flex; gap:8px; margin-bottom:12px; flex-wrap:wrap; }
.badge { font-size:11px; font-weight:700; padding:4px 10px; border-radius:999px; }
.badge-primary { background:rgba(30,58,138,0.1); color:var(--primary); }
.badge-hindi { background:#d1fae5; color:#047857; }
.card h2 { margin:0 0 10px; font-size:20px; font-weight:700; line-height:1.35; }
.card p { margin:0 0 14px; color:#475569; font-size:14px; line-height:1.6; }
.card-meta { margin-top:auto; display:flex; justify-content:space-between; align-items:center; font-size:12px; color:#94a3b8; }
.card-meta .read { color:var(--primary); font-weight:600; }
.article { max-width:768px; margin:0 auto; padding:48px 24px; }
.article h1 { font-size:34px; font-weight:800; line-height:1.25; margin:0 0 8px; color:#0f172a; }
.article-meta { display:flex; gap:12px; align-items:center; color:#64748b; font-size:14px; margin:0 0 32px; padding-bottom:20px; border-bottom:1px solid #e2e8f0; }
.article-meta .author { color:#334155; font-weight:600; }
.blog-content { font-size:17px; line-height:1.75; color:#334155; }
.blog-content h2 { font-size:26px; color:#0f172a; margin:32px 0 16px; }
.blog-content h3 { font-size:21px; color:#0f172a; margin:28px 0 14px; }
.blog-content p { margin:0 0 20px; }
.blog-content ul, .blog-content ol { padding-left:24px; margin:0 0 20px; }
.blog-content li { margin-bottom:6px; }
.blog-content a { color:var(--primary); font-weight:500; text-decoration:underline; }
.blog-content blockquote { border-left:4px solid var(--primary); background:#f8fafc; border-radius:0 8px 8px 0; padding:12px 20px; margin:24px 0; color:#475569; font-style:italic; }
.blog-content code { background:#f1f5f9; color:var(--primary); padding:2px 6px; border-radius:4px; font-size:0.9em; }
.blog-content img { max-width:100%; border-radius:12px; margin:20px 0; }
.blog-content hr { border:none; border-top:1px solid #e2e8f0; margin:32px 0; }
.tags { display:flex; flex-wrap:wrap; gap:8px; margin-top:36px; padding-top:24px; border-top:1px solid #e2e8f0; }
.tag { background:#f1f5f9; color:#475569; font-size:12px; font-weight:500; padding:6px 12px; border-radius:999px; }
.filters { display:flex; flex-wrap:wrap; gap:10px; margin-bottom:32px; align-items:center; }
.filter-link { padding:8px 16px; border-radius:999px; font-size:14px; font-weight:500; border:1px solid #cbd5e1; color:#475569; transition:all .15s; }
.filter-link:hover { border-color:var(--primary); color:var(--primary); }
.filter-link.active { background:var(--primary); color:#fff; border-color:var(--primary); }
.filter-search { margin-left:auto; display:flex; gap:8px; }
.filter-search input { padding:8px 16px; border-radius:999px; border:1px solid #cbd5e1; font-size:14px; outline:none; }
.filter-search input:focus { border-color:var(--primary); }
.filter-search button { padding:8px 20px; border-radius:999px; border:none; background:var(--primary); color:#fff; font-size:14px; font-weight:600; cursor:pointer; }
.empty { text-align:center; padding:60px 0; color:#64748b; }
.empty p { font-size:18px; font-weight:600; margin-bottom:8px; color:#334155; }
.site-footer { background:#0f172a; color:#cbd5e1; padding:40px 0; margin-top:auto; }
.footer-inner { max-width:1200px; margin:0 auto; padding:0 24px; display:flex; flex-wrap:wrap; gap:24px; justify-content:space-between; }
.footer-brand { color:#fff; font-size:20px; font-weight:800; margin-bottom:12px; }
.footer-links a { display:block; color:#94a3b8; font-size:14px; margin-bottom:8px; }
.footer-links a:hover { color:#fff; }
.footer-copy { color:#64748b; font-size:12px; margin-top:16px; }
@media (max-width:768px) {
  .nav { display:none; }
  .page-header h1 { font-size:30px; }
  .article h1 { font-size:26px; }
  .filter-search { margin-left:0; width:100%; }
}
</style>
</head>
<body>
<header class="site-header">
  <div class="header-inner">
    <a class="brand" href="/"><span class="logo">DG</span>${SITE_NAME}</a>
    <nav class="nav">${nav}</nav>
    <a class="btn-primary" href="https://play.google.com/store/apps/details?id=com.dhankund.banker" target="_blank" rel="noopener noreferrer">Get App</a>
  </div>
</header>
<main>${opts.body}</main>
<footer class="site-footer">
  <div class="footer-inner">
    <div>
      <div class="footer-brand">DG Dhankund Global</div>
      <p style="color:#94a3b8;font-size:14px;max-width:300px;line-height:1.6;">Empowering your financial journey. Loan solutions and business consulting across India.</p>
      <div class="footer-copy">&copy; ${new Date().getFullYear()} Dhankund Global Private Limited. All rights reserved.</div>
    </div>
    <div class="footer-links">
      <div style="font-weight:600;color:#fff;margin-bottom:10px;">Quick Links</div>
      <a href="/">Home</a><a href="/about">About Us</a><a href="/contact">Contact</a>
    </div>
    <div class="footer-links">
      <div style="font-weight:600;color:#fff;margin-bottom:10px;">Legal</div>
      <a href="/privacy">Privacy Policy</a><a href="/terms">Terms &amp; Conditions</a>
    </div>
  </div>
</footer>
</body>
</html>`;
  return new Response(html, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ---------- routes ----------

async function renderListing(context: { request: Request }): Promise<Response> {
  const url = new URL(context.request.url);
  const category = url.searchParams.get("category") || "";
  const q = url.searchParams.get("q") || "";

  const params = new URLSearchParams({ limit: "100" });
  if (category) params.set("category", category);
  if (q) params.set("q", q);

  const [postRes, catRes] = await Promise.all([
    fetch(`${API_BASE}/api/v1/blog?${params.toString()}`),
    fetch(`${API_BASE}/api/v1/blog-categories`),
  ]);
  const postData = postRes.ok ? await postRes.json() : { posts: [] as BlogPost[] };
  const posts: BlogPost[] = Array.isArray(postData.posts) ? postData.posts : [];
  const categories: BlogCategory[] = catRes.ok ? ((await catRes.json()) as BlogCategory[]) : [];

  const filterChips = ["", ...categories.map((c) => c.slug)].map((slug) => {
    const cat = categories.find((c) => c.slug === slug);
    const label = cat ? cat.name : "सभी";
    const href = slug ? `/blog?category=${encodeURIComponent(slug)}` : "/blog";
    return `<a class="filter-link ${category === slug ? "active" : ""}" href="${href}">${escapeHtml(label)}</a>`;
  });

  const searchForm = `<form class="filter-search" method="get" action="/blog">
      <input type="search" name="q" placeholder="लेख खोजें..." value="${escapeHtml(q)}" />
      <button type="submit">खोजें</button>
    </form>`;

  const cards = posts.length
    ? posts
        .map((post) => {
          const badges = [
            post.category_name ? `<span class="badge badge-primary">${escapeHtml(post.category_name)}</span>` : "",
            post.language === "hi" ? `<span class="badge badge-hindi">हिंदी</span>` : "",
          ].join("");
          const cover = post.cover_image
            ? `<div class="card-cover"><img src="${escapeHtml(resolveUrl(post.cover_image))}" alt="${escapeHtml(post.title)}" /></div>`
            : `<div class="card-cover" style="display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#1e3a8a,#3b82f6);"><span style="color:#fff;font-size:36px;font-weight:800;">${escapeHtml(post.title.slice(0, 1).toUpperCase())}</span></div>`;
          const excerpt = post.excerpt
            ? `<p>${escapeHtml(post.excerpt)}</p>`
            : "";
          return `<a class="card" href="/blog/${encodeURIComponent(post.slug)}">
              ${cover}
              <div class="card-body">
                <div class="badges">${badges}</div>
                <h2>${escapeHtml(post.title)}</h2>
                ${excerpt}
                <div class="card-meta"><span>${formatDate(post.published_at)}</span><span class="read">पढ़ें →</span></div>
              </div>
            </a>`;
        })
        .join("")
    : `<div class="empty"><p>कोई लेख नहीं मिला</p>कुछ और खोजने की कोशिश करें, या नए लेख जल्द आ रहे हैं।</div>`;

  const body = `
    <section class="page-header">
      <h1>Dhankund <span style="background:linear-gradient(90deg,#1e3a8a,#3b82f6);-webkit-background-clip:text;background-clip:text;color:transparent;">Blog</span></h1>
      <p>लोन टिप्स, DSA गाइड और बिज़नेस की जानकारी — Dhankund टीम की ओर से नए लेख।</p>
    </section>
    <section class="section">
      <div class="container">
        <div class="filters">${filterChips.join("")}${searchForm}</div>
        <div class="posts-grid">${cards}</div>
      </div>
    </section>`;

  return layout({
    title: "Blog | Dhankund",
    description: "Dhankund Blog — loan tips, DSA guides and business insights.",
    active: "blog",
    body,
  });
}

async function renderDetail(context: { request: Request }, slug: string): Promise<Response> {
  const res = await fetch(`${API_BASE}/api/v1/blog/${encodeURIComponent(slug)}`);
  if (!res.ok) {
    return layout({
      title: "लेख नहीं मिला | Dhankund",
      description: "Requested blog post was not found.",
      active: "blog",
      body: `<div class="article"><div class="empty"><p>लेख नहीं मिला</p>यह लेख उपलब्ध नहीं है।<p style="margin-top:20px;"><a class="btn-outline" href="/blog">← सभी लेख देखें</a></p></div></div>`,
    });
  }
  const post = (await res.json()) as BlogPost;

  const badges = [
    post.category_name ? `<span class="badge badge-primary">${escapeHtml(post.category_name)}</span>` : "",
    post.language === "hi" ? `<span class="badge badge-hindi">हिंदी</span>` : "",
  ].join("");

  const cover = post.cover_image
    ? `<section style="width:100%;height:340px;overflow:hidden;background:#f1f5f9;"><img src="${escapeHtml(resolveUrl(post.cover_image))}" alt="${escapeHtml(post.title)}" style="width:100%;height:100%;object-fit:cover;" /></section>`
    : "";

  const meta = [
    post.author_name ? `<span class="author">${escapeHtml(post.author_name)}</span>` : "",
    `<span>•</span>`,
    `<span>${formatDate(post.published_at)}</span>`,
    post.views > 0 ? `<span>•</span><span>${post.views.toLocaleString("en-IN")} पढ़े</span>` : "",
  ].join(" ");

  const tags = post.tags.length
    ? `<div class="tags">${post.tags.map((t) => `<span class="tag">#${escapeHtml(t)}</span>`).join("")}</div>`
    : "";

  const body = `
    ${cover}
    <article class="article">
      <div class="badges">${badges}</div>
      <h1>${escapeHtml(post.title)}</h1>
      <div class="article-meta">${meta}</div>
      <div class="blog-content">${renderMarkdown(post.content)}</div>
      ${tags}
      <p style="text-align:center;margin-top:40px;"><a class="btn-outline" href="/blog">← सभी लेख देखें</a></p>
    </article>`;

  return layout({
    title: `${post.title} | Dhankund`,
    description: post.excerpt || post.title,
    active: "blog",
    body,
  });
}

export async function onRequestGet(context: { request: Request }): Promise<Response> {
  try {
    const url = new URL(context.request.url);
    const slug = url.pathname.replace(/^\/blog\/?/, "").trim();
    if (!slug) return await renderListing(context);
    return await renderDetail(context, decodeURIComponent(slug));
  } catch (e) {
    console.error("blog function error:", e);
    return json({ error: "Server error" }, 500);
  }
}

export async function onRequestOptions(): Promise<Response> {
  return new Response(null, { status: 204 });
}