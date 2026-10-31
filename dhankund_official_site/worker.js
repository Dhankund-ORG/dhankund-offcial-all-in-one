// Dhankund website entry Worker.
// Wraps next-on-pages Next.js output and provides live, SEO-optimized,
// server-rendered blog routes (/blog, /blog/:slug), dynamic XML sitemap (/sitemap.xml),
// robots.txt (/robots.txt), and an advanced Blog Authoring Studio (/blog/admin)
// with OTP login restricted exclusively to mobile number 6268147177.
import nextWorker from "./.vercel/output/static/_worker.js/index.js";

const SITE_NAME = "Dhankund";
const AUTHORIZED_BLOG_MOBILE = "6268147177";

// ---------- Helpers ----------

function getApiBase(reqUrl) {
  const host = new URL(reqUrl).hostname;
  if (host.includes("dev.") || host.includes("preview")) {
    return "https://dev.api.dhankund.com";
  }
  return "https://api.dhankund.com";
}

function getSiteUrl(reqUrl) {
  const u = new URL(reqUrl);
  return `${u.protocol}//${u.host}`;
}

function escapeHtml(str) {
  return String(str ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function resolveUrl(url, apiBase) {
  if (!url) return "";
  if (/^https?:\/\//.test(url)) return url;
  return (apiBase || "https://api.dhankund.com") + url;
}

function formatDate(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const months = [
    "जनवरी", "फ़रवरी", "मार्च", "अप्रैल", "मई", "जून",
    "जुलाई", "अगस्त", "सितंबर", "अक्टूबर", "नवंबर", "दिसंबर",
  ];
  return `${d.getDate()} ${months[d.getMonth()]} ${d.getFullYear()}`;
}

function estimateReadTime(text) {
  const words = String(text ?? "").trim().split(/\s+/).filter(Boolean).length;
  const mins = Math.max(1, Math.ceil(words / 180));
  return `${mins} मिनट पढ़ें`;
}

function renderInline(text, siteUrl, apiBase) {
  let t = escapeHtml(text);
  t = t.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_m, alt, src) => {
    const url = resolveUrl(String(src).trim(), apiBase);
    return `<img src="${escapeHtml(url)}" alt="${escapeHtml(alt)}" loading="lazy" />`;
  });
  t = t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_m, label, href) => {
    const u = String(href).trim();
    const safe = u.startsWith("http") ? u : (siteUrl || "") + (u.startsWith("/") ? u : "/" + u);
    return `<a href="${escapeHtml(safe)}" target="_blank" rel="noopener noreferrer">${label}</a>`;
  });
  t = t.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  t = t.replace(/\*([^*]+)\*/g, "<em>$1</em>");
  t = t.replace(/`([^`]+)`/g, "<code>$1</code>");
  return t;
}

function renderMarkdown(md, siteUrl, apiBase) {
  const lines = String(md ?? "").split("\n");
  const html = [];
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
      const text = trimmed.replace(/^#+\s*/, "");
      const id = text.toLowerCase().replace(/[^\p{L}\p{M}\p{N}\s-]/gu, "").trim().replace(/\s+/g, "-");
      html.push(`<h${level} id="${escapeHtml(id)}">${renderInline(text, siteUrl, apiBase)}</h${level}>`);
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
      html.push(`<p>${renderInline(trimmed.replace(/^>\s?/, ""), siteUrl, apiBase)}</p>`);
      continue;
    }
    const ulMatch = trimmed.match(/^[-*]\s+(.*)/);
    if (ulMatch) {
      closeQuote();
      if (!inList) {
        html.push("<ul>");
        inList = true;
      }
      html.push(`<li>${renderInline(ulMatch[1], siteUrl, apiBase)}</li>`);
      continue;
    }
    const olMatch = trimmed.match(/^\d+[.)]\s+(.*)/);
    if (olMatch) {
      closeQuote();
      if (!inList) {
        html.push("<ol>");
        inList = true;
      }
      html.push(`<li>${renderInline(olMatch[1], siteUrl, apiBase)}</li>`);
      continue;
    }
    closeList();
    closeQuote();
    html.push(`<p>${renderInline(line, siteUrl, apiBase)}</p>`);
  }
  closeList();
  closeQuote();
  return html.join("");
}

// ---------- Base Page Layout ----------

function layout(opts) {
  const siteUrl = opts.siteUrl || "https://www.dhankund.com";
  const canonicalUrl = `${siteUrl}${opts.canonical || "/blog"}`;
  const pageTitle = opts.title ? `${opts.title} | ${SITE_NAME}` : `Dhankund — Loan Tips, DSA Guide & Finance Insights`;
  const pageDesc = opts.description || "धनकुण्ड (Dhankund) — सम्पूर्ण भारत में पर्सनल लोन, होम लोन, बिजनेस लोन और DSA पार्टनर गाइड। सर्वश्रेष्ठ ब्याज दरों और त्वरित लोन प्रक्रिया की सम्पूर्ण जानकारी।";
  const ogImage = opts.image || `${siteUrl}/globe.svg`;
  const jsonLdScripts = (opts.jsonLd || []).map((schema) => `<script type="application/ld+json">${JSON.stringify(schema)}</script>`).join("\n");

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
<title>${escapeHtml(pageTitle)}</title>
<meta name="description" content="${escapeHtml(pageDesc)}" />
<meta name="keywords" content="${escapeHtml(opts.keywords || 'personal loan indore, home loan best rate, business loan india, low cibil score loan, dhankund banker, loan against property')}" />
<meta name="robots" content="index, follow, max-snippet:-1, max-image-preview:large, max-video-preview:-1" />
<link rel="canonical" href="${escapeHtml(canonicalUrl)}" />

<!-- Open Graph / Facebook -->
<meta property="og:locale" content="hi_IN" />
<meta property="og:type" content="${opts.type || "website"}" />
<meta property="og:title" content="${escapeHtml(pageTitle)}" />
<meta property="og:description" content="${escapeHtml(pageDesc)}" />
<meta property="og:url" content="${escapeHtml(canonicalUrl)}" />
<meta property="og:site_name" content="Dhankund Global Private Limited" />
<meta property="og:image" content="${escapeHtml(ogImage)}" />

<!-- Twitter -->
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="${escapeHtml(pageTitle)}" />
<meta name="twitter:description" content="${escapeHtml(pageDesc)}" />
<meta name="twitter:image" content="${escapeHtml(ogImage)}" />

<!-- Google Rich Snippets Structured Data -->
${jsonLdScripts}

<style>
:root {
  --primary: #093a7a;
  --primary-light: #1e40af;
  --accent: #2563eb;
  --emerald: #059669;
  --gold: #d97706;
  --bg-slate: #f8fafc;
}
* { box-sizing: border-box; }
body { margin:0; font-family:'Inter',system-ui,-apple-system,sans-serif; background:var(--bg-slate); color:#0f172a; min-height:100vh; display:flex; flex-direction:column; line-height:1.6; }
a { text-decoration:none; color:inherit; }
.container { width:100%; max-width:1200px; margin:0 auto; padding:0 24px; }
.site-header { position:sticky; top:0; z-index:50; background:rgba(255,255,255,0.92); backdrop-filter:blur(10px); border-bottom:1px solid #e2e8f0; }
.header-inner { display:flex; align-items:center; justify-content:space-between; padding:16px 24px; max-width:1200px; margin:0 auto; }
.brand { font-size:24px; font-weight:800; color:var(--primary); display:flex; align-items:center; gap:8px; }
.brand .logo { background:var(--primary); color:#fff; padding:3px 8px; border-radius:8px; font-size:14px; letter-spacing:1px; }
.nav { display:flex; gap:24px; font-weight:500; color:#334155; }
.nav-link { color:#334155; transition:color .15s; }
.nav-link:hover { color:var(--accent); }
.nav-link.active { color:var(--primary); font-weight:700; }
.header-actions { display:flex; align-items:center; gap:12px; }
.btn-author { display:inline-flex; align-items:center; gap:6px; padding:8px 16px; border-radius:10px; font-size:13px; font-weight:600; color:var(--primary); background:#eff6ff; border:1px solid #bfdbfe; transition:all .2s; }
.btn-author:hover { background:#dbeafe; }
.btn-primary { display:inline-flex; align-items:center; gap:6px; padding:9px 20px; border-radius:10px; font-weight:600; color:#fff; background:var(--primary); transition:all .2s; font-size:14px; }
.btn-primary:hover { background:var(--primary-light); transform:translateY(-1px); box-shadow:0 4px 12px rgba(9,58,122,0.25); }
.btn-outline { display:inline-block; padding:10px 22px; border-radius:10px; font-weight:600; color:var(--primary); border:2px solid var(--primary); transition:all .2s; font-size:14px; }
.btn-outline:hover { background:var(--primary); color:#fff; }
main { flex:1; }

/* Hero Section */
.page-header { background:linear-gradient(135deg,#093a7a 0%,#1e40af 100%); padding:64px 0 52px; text-align:center; color:#fff; position:relative; overflow:hidden; }
.page-header::after { content:''; position:absolute; bottom:0; left:0; right:0; height:24px; background:var(--bg-slate); clip-path:ellipse(60% 100% at 50% 100%); }
.page-header h1 { margin:0 0 14px; font-size:42px; font-weight:800; letter-spacing:-0.5px; }
.page-header p { margin:0 auto; max-width:680px; color:#cbd5e1; font-size:18px; line-height:1.6; }

/* Filters & Search */
.filters-bar { display:flex; flex-wrap:wrap; gap:12px; margin:36px 0 28px; align-items:center; justify-content:space-between; }
.filter-chips { display:flex; flex-wrap:wrap; gap:8px; align-items:center; }
.filter-link { padding:8px 18px; border-radius:999px; font-size:14px; font-weight:500; border:1px solid #cbd5e1; color:#475569; background:#fff; transition:all .15s; }
.filter-link:hover { border-color:var(--primary); color:var(--primary); }
.filter-link.active { background:var(--primary); color:#fff; border-color:var(--primary); font-weight:600; }
.search-box { display:flex; gap:8px; }
.search-box input { padding:9px 18px; border-radius:999px; border:1px solid #cbd5e1; font-size:14px; outline:none; min-width:240px; background:#fff; }
.search-box input:focus { border-color:var(--primary); }
.search-box button { padding:9px 20px; border-radius:999px; border:none; background:var(--primary); color:#fff; font-size:14px; font-weight:600; cursor:pointer; }

/* Blog Cards */
.posts-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(340px,1fr)); gap:30px; margin-bottom:56px; }
.card { background:#fff; border:1px solid #e2e8f0; border-radius:18px; overflow:hidden; box-shadow:0 4px 14px rgba(0,0,0,0.04); transition:all .25s ease; display:flex; flex-direction:column; position:relative; }
.card:hover { transform:translateY(-4px); box-shadow:0 16px 32px rgba(9,58,122,0.1); border-color:#cbd5e1; }
.card-cover { height:210px; background:#f1f5f9; overflow:hidden; position:relative; }
.card-cover img { width:100%; height:100%; object-fit:cover; transition:transform .4s ease; }
.card:hover .card-cover img { transform:scale(1.05); }
.card-body { padding:24px; display:flex; flex-direction:column; flex:1; }
.badges { display:flex; gap:8px; margin-bottom:12px; flex-wrap:wrap; }
.badge { font-size:11px; font-weight:700; padding:4px 10px; border-radius:999px; }
.badge-category { background:#e0f2fe; color:#0369a1; }
.badge-hindi { background:#d1fae5; color:#047857; }
.badge-views { background:#fef3c7; color:#b45309; }
.card h2 { margin:0 0 10px; font-size:20px; font-weight:700; line-height:1.4; color:#0f172a; }
.card p { margin:0 0 16px; color:#475569; font-size:14px; line-height:1.6; }
.card-meta { margin-top:auto; display:flex; justify-content:space-between; align-items:center; font-size:13px; color:#94a3b8; padding-top:14px; border-top:1px solid #f1f5f9; }
.card-meta .read { color:var(--primary); font-weight:700; display:inline-flex; align-items:center; gap:4px; }

/* Article Details */
.article-header { padding:48px 0 28px; max-width:820px; margin:0 auto; }
.breadcrumbs { font-size:13px; color:#64748b; margin-bottom:16px; display:flex; gap:6px; flex-wrap:wrap; }
.breadcrumbs a { color:var(--accent); }
.article-title { font-size:36px; font-weight:800; line-height:1.28; margin:0 0 16px; color:#0f172a; }
.article-meta-bar { display:flex; gap:16px; align-items:center; color:#64748b; font-size:14px; padding-bottom:20px; border-bottom:1px solid #e2e8f0; flex-wrap:wrap; }
.article-meta-bar .author { color:#0f172a; font-weight:600; display:inline-flex; align-items:center; gap:6px; }
.article-cover { max-width:940px; margin:0 auto 36px; border-radius:20px; overflow:hidden; box-shadow:0 12px 28px rgba(0,0,0,0.08); max-height:460px; }
.article-cover img { width:100%; height:100%; object-fit:cover; }
.article-body-wrapper { max-width:820px; margin:0 auto; padding-bottom:60px; }
.blog-content { font-size:17.5px; line-height:1.8; color:#334155; }
.blog-content h2 { font-size:26px; color:#0f172a; margin:36px 0 16px; padding-bottom:8px; border-bottom:2px solid #e2e8f0; }
.blog-content h3 { font-size:21px; color:#0f172a; margin:28px 0 12px; }
.blog-content p { margin:0 0 20px; }
.blog-content ul, .blog-content ol { padding-left:24px; margin:0 0 24px; }
.blog-content li { margin-bottom:8px; }
.blog-content blockquote { border-left:4px solid var(--primary); background:#eff6ff; border-radius:0 12px 12px 0; padding:16px 24px; margin:28px 0; color:#1e3a8a; font-style:italic; }
.blog-content a { color:var(--primary); font-weight:600; text-decoration:underline; }
.blog-content img { max-width:100%; border-radius:14px; margin:24px 0; }
.blog-content hr { border:none; border-top:1px solid #e2e8f0; margin:36px 0; }

/* FAQ Accordion */
.faq-box { background:#f8fafc; border:1px solid #e2e8f0; border-radius:16px; padding:28px; margin:40px 0; }
.faq-box h3 { margin:0 0 20px; font-size:22px; color:var(--primary); display:flex; align-items:center; gap:8px; }
.faq-item { margin-bottom:14px; background:#fff; border:1px solid #e2e8f0; border-radius:12px; overflow:hidden; }
.faq-question { padding:16px 20px; font-weight:700; color:#0f172a; cursor:pointer; display:flex; justify-content:space-between; align-items:center; }
.faq-answer { padding:0 20px 16px; color:#475569; font-size:15px; line-height:1.6; }

/* Lead CTA Banner */
.loan-cta-banner { background:linear-gradient(135deg,#093a7a,#1e40af); color:#fff; border-radius:18px; padding:32px 36px; margin:44px 0; display:flex; justify-content:space-between; align-items:center; gap:24px; box-shadow:0 16px 36px rgba(9,58,122,0.25); }
.loan-cta-banner h3 { margin:0 0 6px; font-size:24px; font-weight:800; color:#fff; }
.loan-cta-banner p { margin:0; color:#bfdbfe; font-size:15px; }

/* Share bar */
.share-bar { display:flex; gap:10px; align-items:center; margin:32px 0; padding:16px 0; border-top:1px solid #e2e8f0; border-bottom:1px solid #e2e8f0; flex-wrap:wrap; }
.share-btn { padding:8px 16px; border-radius:8px; font-size:13px; font-weight:600; display:inline-flex; align-items:center; gap:6px; cursor:pointer; }
.share-wa { background:#25d366; color:#fff; }
.share-tw { background:#0f172a; color:#fff; }
.share-copy { background:#e2e8f0; color:#334155; }

/* Footer */
.site-footer { background:#0f172a; color:#cbd5e1; padding:48px 0; margin-top:auto; }
.footer-inner { max-width:1200px; margin:0 auto; padding:0 24px; display:flex; flex-wrap:wrap; gap:36px; justify-content:space-between; }
.footer-brand { color:#fff; font-size:22px; font-weight:800; margin-bottom:12px; }
.footer-links a { display:block; color:#94a3b8; font-size:14px; margin-bottom:8px; }
.footer-links a:hover { color:#fff; }
.footer-copy { color:#64748b; font-size:13px; margin-top:16px; }

@media (max-width:768px) {
  .nav { display:none; }
  .page-header h1 { font-size:30px; }
  .article-title { font-size:26px; }
  .loan-cta-banner { flex-direction:column; text-align:center; }
  .filters-bar { flex-direction:column; align-items:stretch; }
  .search-box { width:100%; }
  .search-box input { flex:1; min-width:0; }
}
</style>
</head>
<body>
<header class="site-header">
  <div class="header-inner">
    <a class="brand" href="/"><span class="logo">DG</span>${SITE_NAME}</a>
    <nav class="nav">${nav}</nav>
    <div class="header-actions">
      <a class="btn-author" href="/blog/admin" title="ब्लॉग एडमिन लॉगिन (केवल 6268147177)">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
        लेखक लॉगिन
      </a>
      <a class="btn-primary" href="https://play.google.com/store/apps/details?id=com.dhankund.banker" target="_blank" rel="noopener noreferrer">Get App</a>
    </div>
  </div>
</header>
<main>${opts.body}</main>
<footer class="site-footer">
  <div class="footer-inner">
    <div>
      <div class="footer-brand">DG Dhankund Global</div>
      <p style="color:#94a3b8;font-size:14px;max-width:320px;line-height:1.6;">Empowering your financial journey. Comprehensive loan solutions and business consulting across India.</p>
      <div class="footer-copy">&copy; ${new Date().getFullYear()} Dhankund Global Private Limited. All rights reserved.</div>
    </div>
    <div class="footer-links">
      <div style="font-weight:600;color:#fff;margin-bottom:12px;">Quick Links</div>
      <a href="/">Home</a><a href="/blog">Blog</a><a href="/about">About Us</a><a href="/contact">Contact</a>
    </div>
    <div class="footer-links">
      <div style="font-weight:600;color:#fff;margin-bottom:12px;">Legal</div>
      <a href="/privacy">Privacy Policy</a><a href="/terms">Terms &amp; Conditions</a>
    </div>
    <div class="footer-links">
      <div style="font-weight:600;color:#fff;margin-bottom:12px;">Contact</div>
      <p style="color:#94a3b8;font-size:13px;margin:0 0 6px;">Phone: +91 62681 47177</p>
      <p style="color:#94a3b8;font-size:13px;margin:0 0 6px;">Email: info@dhankund.com</p>
      <p style="color:#94a3b8;font-size:13px;margin:0;">Indore, Madhya Pradesh</p>
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

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ---------- Blog Listing Page ----------

async function renderListing(request) {
  const url = new URL(request.url);
  const siteUrl = getSiteUrl(request.url);
  const apiBase = getApiBase(request.url);
  const category = url.searchParams.get("category") || "";
  const q = url.searchParams.get("q") || "";

  const params = new URLSearchParams({ limit: "100" });
  if (category) params.set("category", category);
  if (q) params.set("q", q);

  let posts = [];
  let categories = [];
  try {
    const [postRes, catRes] = await Promise.all([
      fetch(`${apiBase}/api/v1/blog?${params.toString()}`),
      fetch(`${apiBase}/api/v1/blog-categories`),
    ]);
    const postData = postRes.ok ? await postRes.json() : { posts: [] };
    posts = Array.isArray(postData.posts) ? postData.posts : [];
    categories = catRes.ok ? await catRes.json() : [];
  } catch (err) {
    console.error("Listing fetch failed", err);
  }

  const filterChips = ["", ...categories.map((c) => c.slug)].map((slug) => {
    const cat = categories.find((c) => c.slug === slug);
    const label = cat ? cat.name : "सभी लेख";
    const href = slug ? `/blog?category=${encodeURIComponent(slug)}` : "/blog";
    return `<a class="filter-link ${category === slug ? "active" : ""}" href="${href}">${escapeHtml(label)}</a>`;
  });

  const searchForm = `<form class="search-box" method="get" action="/blog">
      <input type="search" name="q" placeholder="लोन या वित्तीय जानकारी खोजें..." value="${escapeHtml(q)}" />
      <button type="submit">खोजें</button>
    </form>`;

  const cards = posts.length
    ? posts
        .map((post) => {
          const badges = [
            post.category_name ? `<span class="badge badge-category">${escapeHtml(post.category_name)}</span>` : "",
            post.language === "hi" ? `<span class="badge badge-hindi">हिंदी</span>` : "",
            Number(post.views) > 0 ? `<span class="badge badge-views">👁️ ${Number(post.views)}</span>` : "",
          ].join("");

          const cover = post.cover_image
            ? `<div class="card-cover"><img src="${escapeHtml(resolveUrl(post.cover_image, apiBase))}" alt="${escapeHtml(post.title)}" loading="lazy" /></div>`
            : `<div class="card-cover" style="display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,#093a7a,#1e40af);color:#fff;font-size:42px;font-weight:800;">DG</div>`;

          const excerpt = post.excerpt ? `<p>${escapeHtml(post.excerpt)}</p>` : "";
          const readTime = estimateReadTime(post.content);

          return `<a class="card" href="/blog/${encodeURIComponent(post.slug)}">
              ${cover}
              <div class="card-body">
                <div class="badges">${badges}</div>
                <h2>${escapeHtml(post.title)}</h2>
                ${excerpt}
                <div class="card-meta">
                  <span>${formatDate(post.published_at)} • ${readTime}</span>
                  <span class="read">पढ़ें &rarr;</span>
                </div>
              </div>
            </a>`;
        })
        .join("")
    : `<div style="text-align:center;padding:70px 20px;grid-column:1/-1;background:#fff;border-radius:16px;border:1px dashed #cbd5e1;">
        <h3 style="color:#334155;margin:0 0 8px;font-size:22px;">कोई लेख नहीं मिला</h3>
        <p style="color:#64748b;margin:0 0 20px;">कृपया कोई दूसरा कीवर्ड खोजें या सभी श्रेणियों के लेख देखें।</p>
        <a class="btn-outline" href="/blog">सभी लेख देखें</a>
      </div>`;

  const body = `
    <section class="page-header">
      <div class="container">
        <h1>धनकुण्ड <span style="color:#60a5fa;">ब्लॉग &amp; लोन गाइड</span></h1>
        <p>पर्सनल लोन, होम लोन, बिजनेस लोन एवं सिबिल स्कोर से जुड़ी नवीनतम जानकारी। गूगल पर सर्च किए जाने वाले सभी प्रमुख वित्तीय प्रश्नों के प्रामाणिक उत्तर।</p>
      </div>
    </section>

    <div class="container">
      <div class="filters-bar">
        <div class="filter-chips">${filterChips.join("")}</div>
        ${searchForm}
      </div>

      <div class="posts-grid">
        ${cards}
      </div>

      <!-- Lead CTA Box -->
      <div class="loan-cta-banner">
        <div>
          <h3>क्या आपको तुरंत लोन की आवश्यकता है?</h3>
          <p>धनकुण्ड के साथ न्यूनतम दस्तावेजों और आकर्षक ब्याज दरों पर तुरंत लोन स्वीकृति प्राप्त करें।</p>
        </div>
        <a class="btn-primary" style="background:#fff;color:var(--primary);font-size:15px;padding:12px 28px;white-space:nowrap;" href="https://play.google.com/store/apps/details?id=com.dhankund.banker" target="_blank" rel="noopener noreferrer">
          अभी आवेदन करें &rarr;
        </a>
      </div>
    </div>`;

  const jsonLd = [
    {
      "@context": "https://schema.org",
      "@type": "CollectionPage",
      "name": "Dhankund Blog & Loan Insights",
      "description": "Latest articles on personal loan, home loan, business loan and financial tips in India.",
      "url": `${siteUrl}/blog`,
      "publisher": {
        "@type": "Organization",
        "name": "Dhankund Global Private Limited",
        "url": siteUrl,
      },
    },
  ];

  return layout({
    title: "लोन टिप्स &amp; वित्तीय गाइड (Blog)",
    description: "धनकुण्ड लोन ब्लॉग: पर्सनल लोन, होम लोन, बिजनेस लोन और सिबिल स्कोर में सुधार की आसान गाइड।",
    keywords: "loan tips india, personal loan indore, home loan guide, business loan eligibility, cibil score tips, dhankund",
    active: "blog",
    siteUrl,
    canonical: "/blog",
    jsonLd,
    body,
  });
}

// ---------- Blog Detail Page (SEO Schema & Rich Snippets) ----------

async function renderDetail(request, slug) {
  const siteUrl = getSiteUrl(request.url);
  const apiBase = getApiBase(request.url);

  let post = null;
  try {
    const res = await fetch(`${apiBase}/api/v1/blog/${encodeURIComponent(slug)}`);
    if (res.ok) {
      post = await res.json();
    }
  } catch (err) {
    console.error("Detail fetch failed", err);
  }

  if (!post) {
    return layout({
      title: "लेख नहीं मिला",
      description: "अनुरोधित ब्लॉग लेख उपलब्ध नहीं है।",
      active: "blog",
      siteUrl,
      canonical: `/blog/${encodeURIComponent(slug)}`,
      body: `<div class="container" style="padding:80px 24px;text-align:center;">
        <h1 style="color:#0f172a;font-size:32px;margin-bottom:12px;">लेख नहीं मिला</h1>
        <p style="color:#64748b;margin-bottom:28px;">यह लेख हटा दिया गया है या इसका यूआरएल बदल गया है।</p>
        <a class="btn-outline" href="/blog">&larr; सभी लेख देखें</a>
      </div>`,
    });
  }

  const readTime = estimateReadTime(post.content);
  const postUrl = `${siteUrl}/blog/${encodeURIComponent(post.slug)}`;
  const shareText = encodeURIComponent(`${post.title} - धनकुण्ड ब्लॉग पर पढ़ें: ${postUrl}`);

  const badges = [
    post.category_name ? `<span class="badge badge-category">${escapeHtml(post.category_name)}</span>` : "",
    post.language === "hi" ? `<span class="badge badge-hindi">हिंदी</span>` : "",
    Number(post.views) > 0 ? `<span class="badge badge-views">👁️ ${Number(post.views)} बार पढ़ा गया</span>` : "",
  ].join("");

  const cover = post.cover_image
    ? `<div class="article-cover"><img src="${escapeHtml(resolveUrl(post.cover_image, apiBase))}" alt="${escapeHtml(post.title)}" /></div>`
    : "";

  const tags = Array.isArray(post.tags) && post.tags.length
    ? `<div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:36px;padding-top:20px;border-top:1px solid #e2e8f0;">
        ${post.tags.map((t) => `<span style="background:#eff6ff;color:#1e40af;font-size:12px;font-weight:600;padding:6px 14px;border-radius:999px;">#${escapeHtml(t)}</span>`).join("")}
      </div>`
    : "";

  // Render FAQs if present
  let faqsHtml = "";
  const faqsList = Array.isArray(post.faqs) ? post.faqs : [];
  if (faqsList.length > 0) {
    const faqItems = faqsList
      .map(
        (faq, idx) => `
        <div class="faq-item">
          <div class="faq-question">
            <span>${idx + 1}. ${escapeHtml(faq.question)}</span>
            <span>+</span>
          </div>
          <div class="faq-answer">${escapeHtml(faq.answer)}</div>
        </div>`,
      )
      .join("");

    faqsHtml = `
      <div class="faq-box">
        <h3>❓ महत्वपूर्ण प्रश्न एवं उत्तर (FAQs)</h3>
        ${faqItems}
      </div>`;
  }

  const body = `
    <div class="container">
      <div class="article-header">
        <div class="breadcrumbs">
          <a href="/">Home</a> &rsaquo;
          <a href="/blog">Blog</a> &rsaquo;
          <span>${escapeHtml(post.category_name || "General")}</span>
        </div>
        <div class="badges">${badges}</div>
        <h1 class="article-title">${escapeHtml(post.title)}</h1>
        <div class="article-meta-bar">
          <span class="author">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            ${escapeHtml(post.author_name || "Dhankund Team")}
          </span>
          <span>•</span>
          <span>📅 ${formatDate(post.published_at)}</span>
          <span>•</span>
          <span>⏱️ ${readTime}</span>
        </div>
      </div>

      ${cover}

      <div class="article-body-wrapper">
        <div class="blog-content">
          ${renderMarkdown(post.content, siteUrl, apiBase)}
        </div>

        ${faqsHtml}
        ${tags}

        <!-- Social Share Bar -->
        <div class="share-bar">
          <span style="font-size:14px;font-weight:700;color:#0f172a;">शेयर करें:</span>
          <a class="share-btn share-wa" href="https://api.whatsapp.com/send?text=${shareText}" target="_blank" rel="noopener noreferrer">
            WhatsApp पर शेयर करें
          </a>
          <a class="share-btn share-tw" href="https://twitter.com/intent/tweet?text=${shareText}" target="_blank" rel="noopener noreferrer">
            X (Twitter)
          </a>
          <button class="share-btn share-copy" onclick="navigator.clipboard.writeText(window.location.href);alert('लिंक कॉपी हो गया!');">
            📋 लिंक कॉपी करें
          </button>
        </div>

        <!-- Embedded Lead CTA Banner -->
        <div class="loan-cta-banner">
          <div>
            <h3>क्या आप लोन के लिए आवेदन करना चाहते हैं?</h3>
            <p>धनकुण्ड द्वारा परेशानी मुक्त, पारदर्शी एवं त्वरित लोन सहायता प्राप्त करें।</p>
          </div>
          <a class="btn-primary" style="background:#fff;color:var(--primary);white-space:nowrap;padding:12px 28px;" href="https://play.google.com/store/apps/details?id=com.dhankund.banker" target="_blank" rel="noopener noreferrer">
            लोन प्राप्त करें &rarr;
          </a>
        </div>

        <div style="text-align:center;margin-top:40px;">
          <a class="btn-outline" href="/blog">&larr; सभी लेखों पर वापस जाएं</a>
        </div>
      </div>
    </div>`;

  // Schema.org BlogPosting
  const blogPostingSchema = {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "mainEntityOfPage": {
      "@type": "WebPage",
      "@id": postUrl,
    },
    "headline": post.title,
    "description": post.excerpt || post.seo_description || post.title,
    "image": post.cover_image ? resolveUrl(post.cover_image, apiBase) : `${siteUrl}/globe.svg`,
    "author": {
      "@type": "Organization",
      "name": post.author_name || "Dhankund Team",
      "url": siteUrl,
    },
    "publisher": {
      "@type": "Organization",
      "name": "Dhankund Global Private Limited",
      "logo": {
        "@type": "ImageObject",
        "url": `${siteUrl}/globe.svg`,
      },
    },
    "datePublished": post.published_at || new Date().toISOString(),
    "dateModified": post.updated_at || post.published_at || new Date().toISOString(),
    "inLanguage": post.language === "hi" ? "hi-IN" : "en-IN",
  };

  // Schema.org BreadcrumbList
  const breadcrumbSchema = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      { "@type": "ListItem", "position": 1, "name": "Home", "item": siteUrl },
      { "@type": "ListItem", "position": 2, "name": "Blog", "item": `${siteUrl}/blog` },
      { "@type": "ListItem", "position": 3, "name": post.title, "item": postUrl },
    ],
  };

  const jsonLd = [blogPostingSchema, breadcrumbSchema];

  // Schema.org FAQPage if FAQs exist
  if (faqsList.length > 0) {
    jsonLd.push({
      "@context": "https://schema.org",
      "@type": "FAQPage",
      "mainEntity": faqsList.map((f) => ({
        "@type": "Question",
        "name": f.question,
        "acceptedAnswer": {
          "@type": "Answer",
          "text": f.answer,
        },
      })),
    });
  }

  return layout({
    title: post.seo_title || post.title,
    description: post.seo_description || post.excerpt || post.title,
    keywords: post.keywords || `${post.title}, loan tips, dhankund finance`,
    active: "blog",
    type: "article",
    siteUrl,
    canonical: `/blog/${encodeURIComponent(post.slug)}`,
    image: post.cover_image ? resolveUrl(post.cover_image, apiBase) : undefined,
    jsonLd,
    body,
  });
}

// ---------- XML Sitemap (/sitemap.xml) ----------

async function renderSitemap(request) {
  const siteUrl = getSiteUrl(request.url);
  const apiBase = getApiBase(request.url);

  let posts = [];
  try {
    const res = await fetch(`${apiBase}/api/v1/blog?limit=100`);
    if (res.ok) {
      const data = await res.json();
      posts = Array.isArray(data.posts) ? data.posts : [];
    }
  } catch (e) {
    console.error("Sitemap posts fetch error:", e);
  }

  const staticUrls = [
    { loc: `${siteUrl}/`, priority: "1.0", changefreq: "daily" },
    { loc: `${siteUrl}/blog`, priority: "0.9", changefreq: "hourly" },
    { loc: `${siteUrl}/about`, priority: "0.8", changefreq: "monthly" },
    { loc: `${siteUrl}/contact`, priority: "0.8", changefreq: "monthly" },
    { loc: `${siteUrl}/privacy`, priority: "0.5", changefreq: "yearly" },
    { loc: `${siteUrl}/terms`, priority: "0.5", changefreq: "yearly" },
  ];

  const blogUrls = posts.map((p) => ({
    loc: `${siteUrl}/blog/${encodeURIComponent(p.slug)}`,
    lastmod: (p.updated_at || p.published_at || new Date().toISOString()).split("T")[0],
    priority: "0.8",
    changefreq: "weekly",
  }));

  const allUrls = [...staticUrls, ...blogUrls];

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${allUrls
  .map(
    (u) => `  <url>
    <loc>${escapeHtml(u.loc)}</loc>
    ${u.lastmod ? `<lastmod>${escapeHtml(u.lastmod)}</lastmod>` : ""}
    <changefreq>${u.changefreq}</changefreq>
    <priority>${u.priority}</priority>
  </url>`,
  )
  .join("\n")}
</urlset>`;

  return new Response(xml, {
    status: 200,
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
      "Cache-Control": "public, max-age=3600",
    },
  });
}

// ---------- Robots.txt (/robots.txt) ----------

function renderRobots(request) {
  const siteUrl = getSiteUrl(request.url);
  const robots = `User-agent: *
Allow: /
Disallow: /blog/admin

Sitemap: ${siteUrl}/sitemap.xml
`;
  return new Response(robots, {
    status: 200,
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}

// ---------- Blog Authoring Studio (/blog/admin) ----------

async function renderAdmin(request) {
  const siteUrl = getSiteUrl(request.url);
  const apiBase = getApiBase(request.url);

  const html = `<!doctype html>
<html lang="hi">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>धनकुण्ड एसईओ ब्लॉग स्टूडियो (Blog Admin)</title>
<meta name="robots" content="noindex, nofollow" />
<style>
:root {
  --primary: #093a7a;
  --primary-hover: #1e40af;
  --accent: #2563eb;
  --emerald: #059669;
  --gold: #d97706;
  --danger: #dc2626;
  --bg-slate: #f8fafc;
}
* { box-sizing: border-box; }
body { margin:0; font-family:'Inter',system-ui,-apple-system,sans-serif; background:var(--bg-slate); color:#0f172a; min-height:100vh; display:flex; flex-direction:column; line-height:1.5; }
.admin-header { background:#fff; border-bottom:1px solid #e2e8f0; padding:14px 24px; display:flex; justify-content:space-between; align-items:center; position:sticky; top:0; z-index:40; box-shadow:0 1px 4px rgba(0,0,0,0.03); }
.brand { font-size:20px; font-weight:800; color:var(--primary); display:flex; align-items:center; gap:8px; text-decoration:none; }
.brand .logo { background:var(--primary); color:#fff; padding:2px 7px; border-radius:6px; font-size:12px; }
.admin-badge { background:#eff6ff; color:#1e40af; font-size:12px; font-weight:700; padding:5px 12px; border-radius:999px; border:1px solid #bfdbfe; }
.btn { display:inline-flex; align-items:center; gap:6px; padding:9px 18px; border-radius:10px; font-size:14px; font-weight:600; cursor:pointer; border:none; transition:all .15s; }
.btn-primary { background:var(--primary); color:#fff; }
.btn-primary:hover { background:var(--primary-hover); }
.btn-secondary { background:#f1f5f9; color:#334155; }
.btn-secondary:hover { background:#e2e8f0; }
.btn-danger { background:#fee2e2; color:#991b1b; }
.btn-danger:hover { background:#fecaca; }
.btn-success { background:#d1fae5; color:#065f46; }
.btn-success:hover { background:#a7f3d0; }

.container { max-width:1200px; margin:0 auto; padding:28px 20px; width:100%; }

/* Auth Card */
.auth-card { max-width:440px; margin:60px auto; background:#fff; border-radius:20px; padding:36px; box-shadow:0 12px 32px rgba(0,0,0,0.06); border:1px solid #e2e8f0; text-align:center; }
.auth-card h2 { margin:0 0 8px; font-size:24px; color:var(--primary); }
.auth-card p { color:#64748b; font-size:14px; margin:0 0 24px; line-height:1.5; }
.auth-card .notice { background:#fef3c7; border:1px solid #fde68a; color:#92400e; padding:10px 14px; border-radius:10px; font-size:12px; font-weight:600; margin-bottom:20px; text-align:left; }
.input-group { margin-bottom:18px; text-align:left; }
.input-group label { display:block; font-size:13px; font-weight:600; color:#334155; margin-bottom:6px; }
.input-group input, .input-group select, .input-group textarea { width:100%; padding:10px 14px; border:1px solid #cbd5e1; border-radius:10px; font-size:14px; outline:none; transition:border-color .15s; font-family:inherit; }
.input-group input:focus, .input-group select:focus, .input-group textarea:focus { border-color:var(--primary); box-shadow:0 0 0 3px rgba(9,58,122,0.1); }
.alert-box { padding:12px; border-radius:10px; font-size:13px; margin-bottom:16px; display:none; }
.alert-error { background:#fee2e2; color:#991b1b; border:1px solid #fca5a5; }
.alert-success { background:#d1fae5; color:#065f46; border:1px solid #6ee7b7; }

/* Dashboard Studio */
.studio-grid { display:grid; grid-template-columns:1fr 380px; gap:28px; }
.card-box { background:#fff; border-radius:16px; border:1px solid #e2e8f0; padding:24px; box-shadow:0 4px 14px rgba(0,0,0,0.03); margin-bottom:24px; }
.tabs { display:flex; gap:12px; border-bottom:1px solid #e2e8f0; margin-bottom:24px; }
.tab-btn { padding:12px 20px; border:none; background:none; font-size:15px; font-weight:600; color:#64748b; cursor:pointer; border-bottom:3px solid transparent; }
.tab-btn.active { color:var(--primary); border-bottom-color:var(--primary); }

/* Toolbar */
.toolbar { display:flex; flex-wrap:wrap; gap:6px; margin-bottom:8px; padding:6px; background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; }
.tool-btn { padding:5px 10px; border:1px solid #cbd5e1; background:#fff; border-radius:6px; font-size:12px; font-weight:600; cursor:pointer; color:#334155; }
.tool-btn:hover { background:#f1f5f9; border-color:#94a3b8; }

/* Google SERP Simulator */
.serp-card { background:#fff; border:1px solid #e2e8f0; border-radius:14px; padding:18px; margin-top:16px; box-shadow:0 2px 8px rgba(0,0,0,0.04); }
.serp-url { font-size:12px; color:#202124; display:flex; align-items:center; gap:6px; margin-bottom:4px; }
.serp-title { font-size:18px; color:#1a0dab; font-weight:500; text-decoration:none; display:block; margin-bottom:4px; line-height:1.3; }
.serp-desc { font-size:13px; color:#4d5156; line-height:1.5; }

/* SEO Health Meter */
.meter-box { background:#f0fdf4; border:1px solid #bbf7d0; border-radius:14px; padding:18px; }
.meter-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; }
.meter-title { font-weight:700; color:#166534; font-size:15px; }
.meter-score { font-size:20px; font-weight:800; color:#15803d; }
.meter-item { font-size:12.5px; margin-bottom:6px; display:flex; align-items:center; gap:6px; color:#374151; }
.meter-item.pass { color:#15803d; font-weight:600; }
.meter-item.fail { color:#991b1b; }

/* Posts Table */
.posts-table { width:100%; border-collapse:collapse; font-size:14px; }
.posts-table th { text-align:left; padding:12px; background:#f8fafc; color:#475569; font-weight:600; border-bottom:1px solid #e2e8f0; }
.posts-table td { padding:14px 12px; border-bottom:1px solid #e2e8f0; vertical-align:middle; }
.status-pill { display:inline-block; padding:3px 10px; border-radius:999px; font-size:11px; font-weight:700; }
.status-published { background:#d1fae5; color:#065f46; }
.status-draft { background:#fef3c7; color:#92400e; }

@media (max-width:900px) {
  .studio-grid { grid-template-columns:1fr; }
}
</style>
</head>
<body>

<header class="admin-header">
  <a class="brand" href="/blog">
    <span class="logo">DG</span>
    <span>Dhankund Blog Studio</span>
  </a>
  <div id="topActions" style="display:none;align-items:center;gap:12px;">
    <span class="admin-badge">अधिकृत मोबाइल: ${AUTHORIZED_BLOG_MOBILE}</span>
    <button class="btn btn-secondary" onclick="logoutAdmin()">लॉगआउट</button>
  </div>
</header>

<main class="container">
  <!-- 1. LOGIN SCREEN (Strictly restricted to 6268147177 with ID & Password) -->
  <div id="loginSection" class="auth-card">
    <div style="font-size:40px;margin-bottom:12px;">🔐</div>
    <h2>लेखक &amp; एडमिन लॉगिन</h2>
    <p>धनकुण्ड की आधिकारिक वेबसाइट पर एसईओ ब्लॉग पोस्ट करने हेतु अपनी यूजर आईडी एवं पासवर्ड से लॉगिन करें।</p>
    
    <div class="notice">
      🔒 <strong>सुरक्षा सूचना:</strong> केवल अधिकृत आईडी (<strong>6268147177</strong>) एवं पासवर्ड द्वारा ही लॉगिन अनुमत है।
    </div>

    <div id="loginAlert" class="alert-box"></div>

    <form id="loginForm" onsubmit="handleLogin(event)">
      <div class="input-group">
        <label for="adminId">यूजर आईडी / मोबाइल नंबर:</label>
        <input type="text" id="adminId" value="6268147177" placeholder="6268147177" required />
      </div>
      <div class="input-group">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
          <label for="adminPassword" style="margin-bottom:0;">पासवर्ड (Password):</label>
          <span style="font-size:12px;color:var(--accent);cursor:pointer;user-select:none;" onclick="togglePasswordVisibility()">👁️ पासवर्ड देखें/छिपाएं</span>
        </div>
        <input type="password" id="adminPassword" placeholder="पासवर्ड दर्ज करें..." required />
      </div>
      <button type="submit" id="loginSubmitBtn" class="btn btn-primary" style="width:100%;justify-content:center;padding:12px;font-size:15px;margin-top:8px;">
        लॉगिन करें एवं स्टूडियो खोलें &rarr;
      </button>
    </form>
  </div>

  <!-- 2. STUDIO DASHBOARD -->
  <div id="studioSection" style="display:none;">
    <div class="tabs">
      <button class="tab-btn active" id="tabCreateBtn" onclick="switchTab('create')">✍️ नया ब्लॉग लिखें</button>
      <button class="tab-btn" id="tabManageBtn" onclick="switchTab('manage')">📂 सभी ब्लॉग प्रबंधित करें</button>
    </div>

    <!-- TAB 1: CREATE / EDIT BLOG -->
    <div id="tabCreate">
      <div class="studio-grid">
        <!-- Left: Form -->
        <div>
          <div class="card-box">
            <h3 style="margin:0 0 16px;color:var(--primary);font-size:18px;">१. मुख्य ब्लॉग विवरण (Core Content)</h3>
            
            <div class="input-group">
              <label for="postTitle">ब्लॉग शीर्षक (Title): <span id="titleCount" style="color:#64748b;font-weight:normal;">(0/60)</span></label>
              <input type="text" id="postTitle" placeholder="उदाहरण: तुरंत पर्सनल लोन कैसे पाएं? (5 आसान स्टेप्स)" oninput="onTitleChange()" />
            </div>

            <div class="input-group">
              <label for="postSlug">यूआरएल स्लग (URL Slug):</label>
              <input type="text" id="postSlug" placeholder="instant-personal-loan-guide" oninput="updateSerpPreview()" />
            </div>

            <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
              <div class="input-group">
                <label for="postCategory">लोन श्रेणी (Category):</label>
                <select id="postCategory" onchange="updateSerpPreview()">
                  <option value="">श्रेणी चुनें...</option>
                </select>
              </div>
              <div class="input-group">
                <label for="postKeyword">लक्षित फोकस कीवर्ड (Focus Keyword):</label>
                <input type="text" id="postKeyword" placeholder="जैसे: personal loan indore" oninput="updateSeoScore()" />
              </div>
            </div>

            <div class="input-group">
              <label for="postExcerpt">संक्षिप्त विवरण (Excerpt / Short Summary):</label>
              <textarea id="postExcerpt" rows="2" placeholder="ब्लॉग का संक्षिप्त सार जो कार्ड्स में दिखेगा..."></textarea>
            </div>

            <div class="input-group">
              <label for="postCover">कवर इमेज (Cloudflare R2 या URL):</label>
              <div style="display:flex;gap:8px;">
                <input type="text" id="postCover" placeholder="https://..." style="flex:1;" oninput="onCoverChange()" />
                <label class="btn btn-secondary" style="margin:0;cursor:pointer;">
                  📁 अपलोड
                  <input type="file" id="coverFileInput" accept="image/*" style="display:none;" onchange="uploadImage(event)" />
                </label>
              </div>
              <div id="coverPreviewBox" style="margin-top:10px;display:none;height:140px;border-radius:10px;overflow:hidden;background:#f1f5f9;">
                <img id="coverPreviewImg" src="" style="width:100%;height:100%;object-fit:cover;" />
              </div>
            </div>

            <div class="input-group">
              <label for="postContent">ब्लॉग की मुख्य सामग्री (Markdown / HTML Content):</label>
              <div class="toolbar">
                <button type="button" class="tool-btn" onclick="insertFormat('## ', ' शीर्षक')">H2</button>
                <button type="button" class="tool-btn" onclick="insertFormat('### ', ' उप-शीर्षक')">H3</button>
                <button type="button" class="tool-btn" onclick="insertFormat('**', '**', 'बोल्ड शब्द')">Bold</button>
                <button type="button" class="tool-btn" onclick="insertFormat('*', '*', 'इटैलिक')">Italic</button>
                <button type="button" class="tool-btn" onclick="insertFormat('- ', ' लिस्ट बिंदु')">• List</button>
                <button type="button" class="tool-btn" onclick="insertFormat('1. ', ' क्रमांक')">1. Num</button>
                <button type="button" class="tool-btn" onclick="insertFormat('> 💡 **लोन टिप:** ', 'धनकुण्ड के साथ तुरंत लोन अप्रूवल प्राप्त करें।')">Tip Box</button>
                <button type="button" class="tool-btn" onclick="insertFormat('[लोन आवेदन लिंक](', 'https://play.google.com/store/apps/details?id=com.dhankund.banker)')">Link</button>
              </div>
              <textarea id="postContent" rows="14" placeholder="यहाँ अपने ब्लॉग की विस्तृत जानकारी लिखें... आप हेडिंग्स, लिस्ट्स और टिप्स जोड़ सकते हैं।" oninput="updateSeoScore()"></textarea>
            </div>
          </div>

          <!-- FAQ Builder for Google Rich Snippets -->
          <div class="card-box">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;">
              <h3 style="margin:0;color:var(--primary);font-size:18px;">२. अक्सर पूछे जाने वाले प्रश्न (Google FAQ Schema)</h3>
              <button type="button" class="btn btn-secondary" style="font-size:12px;padding:6px 12px;" onclick="addFaqRow()">+ FAQ जोड़ें</button>
            </div>
            <p style="font-size:13px;color:#64748b;margin:0 0 14px;">गूगल सर्च में आपके ब्लॉग के नीचे प्रश्नोत्तर रिच स्निपेट्स दिखाने के लिए प्रश्न जोड़ें:</p>
            <div id="faqContainer"></div>
          </div>
        </div>

        <!-- Right: SEO Live Analyzer & Preview -->
        <div>
          <!-- Google SERP Live Preview -->
          <div class="card-box" style="position:sticky;top:80px;">
            <h3 style="margin:0 0 12px;font-size:16px;color:#0f172a;">🔍 गूगल सर्च लाइव प्रीव्यू (SERP Preview)</h3>
            <p style="font-size:12px;color:#64748b;margin:0 0 12px;">यह ब्लॉग गूगल सर्च में उपयोगकर्ताओं को इस तरह दिखाई देगा:</p>
            
            <div class="serp-card">
              <div class="serp-url">
                <span style="background:#093a7a;color:#fff;border-radius:50%;width:16px;height:16px;display:inline-flex;align-items:center;justify-content:center;font-size:9px;font-weight:bold;">DG</span>
                <span>https://www.dhankund.com &rsaquo; blog &rsaquo; <span id="serpSlugPreview">slug</span></span>
              </div>
              <div class="serp-title" id="serpTitlePreview">ब्लॉग का शीर्षक यहाँ दिखेगा</div>
              <div class="serp-desc" id="serpDescPreview">मेटा विवरण यहाँ दिखेगा... गूगल सर्च इंजन उपयोगकर्ताओं को यह जानकारी पढ़कर आकर्षित करेगा।</div>
            </div>

            <!-- Meta Description -->
            <div class="input-group" style="margin-top:20px;">
              <label for="postMetaDesc">एसईओ मेटा विवरण: <span id="descCount" style="color:#64748b;font-weight:normal;">(0/160)</span></label>
              <textarea id="postMetaDesc" rows="3" placeholder="150-160 अक्षरों का आकर्षक सारांश लिखें जो गूगल सर्च में दिखेगा..." oninput="onDescChange()"></textarea>
            </div>

            <!-- SEO Health Score -->
            <div class="meter-box" style="margin-top:20px;">
              <div class="meter-header">
                <div class="meter-title">⚡ एसईओ गुणवत्ता स्कोर</div>
                <div class="meter-score" id="seoScoreText">0/100</div>
              </div>
              <div class="meter-item" id="chkKeywordTitle">⚪ शीर्षक में फोकस कीवर्ड</div>
              <div class="meter-item" id="chkKeywordDesc">⚪ मेटा विवरण में फोकस कीवर्ड</div>
              <div class="meter-item" id="chkKeywordSlug">⚪ स्लग में फोकस कीवर्ड</div>
              <div class="meter-item" id="chkWordCount">⚪ पर्याप्त शब्द संख्या (300+ शब्द)</div>
              <div class="meter-item" id="chkHeadings">⚪ हेडिंग्स (H2/H3) का उपयोग</div>
              <div class="meter-item" id="chkFaqs">⚪ गूगल एफएक्यू स्कीमा जोड़ा गया</div>
            </div>

            <!-- Action Buttons -->
            <div style="margin-top:24px;display:flex;flex-direction:column;gap:10px;">
              <input type="hidden" id="editingPostId" value="" />
              <button class="btn btn-primary" style="justify-content:center;padding:12px;font-size:15px;" onclick="saveBlogPost('published')">
                🚀 तुरंत लाइव प्रकाशित करें
              </button>
              <button class="btn btn-secondary" style="justify-content:center;padding:10px;" onclick="saveBlogPost('draft')">
                💾 ड्राफ्ट के रूप में सहेजें
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- TAB 2: MANAGE POSTS -->
    <div id="tabManage" style="display:none;">
      <div class="card-box">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:18px;">
          <h3 style="margin:0;color:var(--primary);font-size:20px;">प्रकाशित एवं ड्राफ्ट लेख</h3>
          <button class="btn btn-secondary" onclick="loadAdminPosts()">🔄 ताज़ा करें</button>
        </div>
        <div style="overflow-x:auto;">
          <table class="posts-table">
            <thead>
              <tr>
                <th>शीर्षक</th>
                <th>श्रेणी</th>
                <th>स्थिति</th>
                <th>व्यूज</th>
                <th>दिनांक</th>
                <th>क्रियाएँ</th>
              </tr>
            </thead>
            <tbody id="postsTableBody">
              <tr><td colspan="6" style="text-align:center;color:#64748b;padding:30px;">लोड हो रहा है...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</main>

<script>
const API_BASE = "${apiBase}";
const AUTHORIZED_MOBILE = "${AUTHORIZED_BLOG_MOBILE}";
let categoriesList = [];

function escapeHtml(str) {
  if (str == null) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function checkExistingSession() {
  const token = localStorage.getItem('dhankund_blog_token');
  if (token) {
    showStudio();
  }
}

function showAlert(msg, isError = true) {
  const box = document.getElementById('loginAlert');
  box.className = 'alert-box ' + (isError ? 'alert-error' : 'alert-success');
  box.textContent = msg;
  box.style.display = 'block';
}

function togglePasswordVisibility() {
  const pwd = document.getElementById('adminPassword');
  pwd.type = pwd.type === 'password' ? 'text' : 'password';
}

async function handleLogin(e) {
  if (e) e.preventDefault();
  const idInput = document.getElementById('adminId').value.trim();
  const password = document.getElementById('adminPassword').value.trim();
  const btn = document.getElementById('loginSubmitBtn');

  if (!idInput) {
    showAlert('कृपया यूजर आईडी दर्ज करें।', true);
    return;
  }
  if (!password) {
    showAlert('कृपया पासवर्ड दर्ज करें।', true);
    return;
  }

  showAlert('सत्यापन किया जा रहा है...', false);
  btn.disabled = true;
  btn.textContent = 'सत्यापित हो रहा है...';

  try {
    const res = await fetch(API_BASE + '/api/v1/blog-admin/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id: idInput, password: password })
    });
    const data = await res.json();
    if (!res.ok) {
      showAlert(data.error || 'अमान्य आईडी या पासवर्ड। कृपया पुनः प्रयास करें।', true);
      btn.disabled = false;
      btn.textContent = 'लॉगिन करें एवं स्टूडियो खोलें →';
      return;
    }

    localStorage.setItem('dhankund_blog_token', data.token);
    showAlert('सफलतापूर्वक लॉगिन हो गया!', false);
    setTimeout(() => {
      showStudio();
    }, 400);
  } catch (err) {
    showAlert('सर्वर से संपर्क करने में असमर्थ। कृपया इंटरनेट कनेक्शन जांचें।', true);
    btn.disabled = false;
    btn.textContent = 'लॉगिन करें एवं स्टूडियो खोलें →';
  }
}


function logoutAdmin() {
  localStorage.removeItem('dhankund_blog_token');
  location.reload();
}

function showStudio() {
  document.getElementById('loginSection').style.display = 'none';
  document.getElementById('studioSection').style.display = 'block';
  document.getElementById('topActions').style.display = 'flex';
  loadCategories();
  loadAdminPosts();
}

function switchTab(tab) {
  if (tab === 'create') {
    document.getElementById('tabCreate').style.display = 'block';
    document.getElementById('tabManage').style.display = 'none';
    document.getElementById('tabCreateBtn').classList.add('active');
    document.getElementById('tabManageBtn').classList.remove('active');
  } else {
    document.getElementById('tabCreate').style.display = 'none';
    document.getElementById('tabManage').style.display = 'block';
    document.getElementById('tabCreateBtn').classList.remove('active');
    document.getElementById('tabManageBtn').classList.add('active');
    loadAdminPosts();
  }
}

async function loadCategories() {
  try {
    const res = await fetch(API_BASE + '/api/v1/blog-categories');
    if (res.ok) {
      categoriesList = await res.json();
      const sel = document.getElementById('postCategory');
      sel.innerHTML = '<option value="">श्रेणी चुनें...</option>' +
        categoriesList.map(c => '<option value="' + c.id + '" data-name="' + c.name + '">' + c.name + '</option>').join('');
    }
  } catch (e) {}
}

function slugifyText(text) {
  return String(text || '')
    .toLowerCase()
    .trim()
    .replace(/[^\u0900-\u097F\w\s-]/gu, '')
    .replace(/\\s+/g, '-')
    .replace(/-+/g, '-');
}

function onTitleChange() {
  const title = document.getElementById('postTitle').value;
  document.getElementById('titleCount').textContent = '(' + title.length + '/60)';
  if (!document.getElementById('editingPostId').value) {
    document.getElementById('postSlug').value = slugifyText(title);
  }
  updateSerpPreview();
  updateSeoScore();
}

function onDescChange() {
  const desc = document.getElementById('postMetaDesc').value;
  document.getElementById('descCount').textContent = '(' + desc.length + '/160)';
  updateSerpPreview();
  updateSeoScore();
}

function onCoverChange() {
  const url = document.getElementById('postCover').value.trim();
  const box = document.getElementById('coverPreviewBox');
  const img = document.getElementById('coverPreviewImg');
  if (url) {
    img.src = url;
    box.style.display = 'block';
  } else {
    box.style.display = 'none';
  }
}

async function uploadImage(e) {
  const file = e.target.files[0];
  if (!file) return;
  const token = localStorage.getItem('dhankund_blog_token');
  const filename = 'blog_' + Date.now() + '_' + file.name.replace(/[^a-zA-Z0-9._-]/g, '');

  try {
    const res = await fetch(API_BASE + '/api/v1/upload?filename=' + encodeURIComponent(filename), {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': file.type || 'image/jpeg'
      },
      body: await file.arrayBuffer()
    });
    const data = await res.json();
    if (res.ok && data.url) {
      document.getElementById('postCover').value = data.url;
      onCoverChange();
      alert('इमेज सफलतापूर्वक R2 बकेट पर अपलोड हो गई!');
    } else {
      alert('अपलोड विफल: ' + (data.error || 'कृपया पुनः प्रयास करें'));
    }
  } catch (err) {
    alert('इमेज अपलोड करते समय त्रुटि हुई');
  }
}

function updateSerpPreview() {
  const title = document.getElementById('postTitle').value.trim() || 'ब्लॉग का शीर्षक यहाँ दिखेगा';
  const slug = document.getElementById('postSlug').value.trim() || 'slug';
  const desc = document.getElementById('postMetaDesc').value.trim() || 'मेटा विवरण यहाँ दिखेगा...';

  document.getElementById('serpTitlePreview').textContent = title;
  document.getElementById('serpSlugPreview').textContent = slug;
  document.getElementById('serpDescPreview').textContent = desc;
}

function updateSeoScore() {
  const kw = document.getElementById('postKeyword').value.trim().toLowerCase();
  const title = document.getElementById('postTitle').value.toLowerCase();
  const desc = document.getElementById('postMetaDesc').value.toLowerCase();
  const slug = document.getElementById('postSlug').value.toLowerCase();
  const content = document.getElementById('postContent').value;
  const wordCount = content.trim().split(/\\s+/).filter(Boolean).length;
  const faqs = getFaqsData();

  let score = 0;

  function updateCheck(elId, pass, passText, failText) {
    const el = document.getElementById(elId);
    if (pass) {
      el.className = 'meter-item pass';
      el.textContent = '✅ ' + passText;
      score += 16.6;
    } else {
      el.className = 'meter-item fail';
      el.textContent = '❌ ' + failText;
    }
  }

  updateCheck('chkKeywordTitle', kw && title.includes(kw), 'शीर्षक में फोकस कीवर्ड मौजूद है', 'शीर्षक में फोकस कीवर्ड जोड़ें');
  updateCheck('chkKeywordDesc', kw && desc.includes(kw), 'मेटा विवरण में फोकस कीवर्ड मौजूद है', 'मेटा विवरण में फोकस कीवर्ड जोड़ें');
  updateCheck('chkKeywordSlug', kw && slug.includes(slugifyText(kw)), 'स्लग में फोकस कीवर्ड मौजूद है', 'स्लग में फोकस कीवर्ड जोड़ें');
  updateCheck('chkWordCount', wordCount >= 200, 'पर्याप्त सामग्री (' + wordCount + ' शब्द)', 'विस्तृत सामग्री लिखें (कम से कम 200 शब्द)');
  updateCheck('chkHeadings', content.includes('##') || content.includes('<h3>'), 'हेडिंग्स (H2/H3) शामिल हैं', 'सामग्री में H2 या H3 हेडिंग जोड़ें');
  updateCheck('chkFaqs', faqs.length > 0, 'गूगल एफएक्यू स्कीमा (' + faqs.length + ' प्रश्न)', 'गूगल रिच स्निपेट्स के लिए FAQ जोड़ें');

  const finalScore = Math.min(100, Math.round(score));
  document.getElementById('seoScoreText').textContent = finalScore + '/100';
}

function insertFormat(prefix, suffix, placeholder) {
  const textarea = document.getElementById('postContent');
  const start = textarea.selectionStart;
  const end = textarea.selectionEnd;
  const text = textarea.value;
  const selected = text.substring(start, end) || placeholder || '';
  const replacement = prefix + selected + (suffix || '');
  textarea.value = text.substring(0, start) + replacement + text.substring(end);
  textarea.focus();
  textarea.selectionStart = start + prefix.length;
  textarea.selectionEnd = start + prefix.length + selected.length;
  updateSeoScore();
}

function addFaqRow(q = '', a = '') {
  const container = document.getElementById('faqContainer');
  if (!container) return;
  const row = document.createElement('div');
  row.className = 'faq-builder-row';
  row.style.cssText = 'background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:12px;margin-bottom:10px;';

  const header = document.createElement('div');
  header.style.cssText = 'display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;';
  const label = document.createElement('span');
  label.style.cssText = 'font-size:12px;font-weight:700;color:var(--primary);';
  label.textContent = 'FAQ प्रश्न व उत्तर';
  const delBtn = document.createElement('button');
  delBtn.type = 'button';
  delBtn.style.cssText = 'background:none;border:none;color:#dc2626;cursor:pointer;font-size:12px;font-weight:600;';
  delBtn.textContent = 'हटाएं ✕';
  delBtn.onclick = function() {
    row.remove();
    updateSeoScore();
  };
  header.appendChild(label);
  header.appendChild(delBtn);

  const qInput = document.createElement('input');
  qInput.type = 'text';
  qInput.className = 'faq-q-input';
  qInput.placeholder = 'प्रश्न लिखें (उदा. पर्सनल लोन के लिए सिबिल स्कोर कितना होना चाहिए?)...';
  qInput.value = q || '';
  qInput.style.cssText = 'width:100%;padding:8px 10px;border:1px solid #cbd5e1;border-radius:6px;font-size:13px;margin-bottom:6px;box-sizing:border-box;';
  qInput.oninput = updateSeoScore;

  const aInput = document.createElement('textarea');
  aInput.className = 'faq-a-input';
  aInput.placeholder = 'विस्तृत उत्तर लिखें...';
  aInput.rows = 2;
  aInput.value = a || '';
  aInput.style.cssText = 'width:100%;padding:8px 10px;border:1px solid #cbd5e1;border-radius:6px;font-size:13px;box-sizing:border-box;';
  aInput.oninput = updateSeoScore;

  row.appendChild(header);
  row.appendChild(qInput);
  row.appendChild(aInput);
  container.appendChild(row);
  updateSeoScore();
}

function getFaqsData() {
  const rows = document.querySelectorAll('.faq-builder-row');
  const faqs = [];
  rows.forEach(r => {
    const qEl = r.querySelector('.faq-q-input');
    const aEl = r.querySelector('.faq-a-input');
    const q = qEl ? qEl.value.trim() : '';
    const a = aEl ? aEl.value.trim() : '';
    if (q && a) faqs.push({ question: q, answer: a });
  });
  return faqs;
}

async function saveBlogPost(targetStatus) {
  const token = localStorage.getItem('dhankund_blog_token');
  const editId = document.getElementById('editingPostId').value;
  const title = document.getElementById('postTitle').value.trim();
  const slug = document.getElementById('postSlug').value.trim();
  const catSel = document.getElementById('postCategory');
  const catId = catSel.value;
  const catName = catSel.options[catSel.selectedIndex]?.dataset.name || '';
  const keyword = document.getElementById('postKeyword').value.trim();
  const excerpt = document.getElementById('postExcerpt').value.trim();
  const cover = document.getElementById('postCover').value.trim();
  const content = document.getElementById('postContent').value.trim();
  const metaDesc = document.getElementById('postMetaDesc').value.trim() || excerpt;
  const faqs = getFaqsData();

  if (!title) {
    alert('कृपया ब्लॉग शीर्षक दर्ज करें।');
    return;
  }
  if (!content) {
    alert('कृपया ब्लॉग सामग्री दर्ज करें।');
    return;
  }

  const payload = {
    title,
    slug,
    category_id: catId || null,
    category_name: catName || null,
    excerpt,
    cover_image: cover || null,
    content,
    seo_title: title,
    seo_description: metaDesc,
    keywords: keyword || null,
    faqs,
    language: 'hi',
    status: targetStatus,
    author_name: 'Dhankund Team'
  };

  const url = editId ? (API_BASE + '/api/v1/admin/blog/' + editId) : (API_BASE + '/api/v1/admin/blog');
  const method = editId ? 'PUT' : 'POST';

  try {
    const res = await fetch(url, {
      method: method,
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });
    const data = await res.json();
    if (res.ok) {
      alert(targetStatus === 'published' ? '🎉 ब्लॉग सफलतापूर्वक लाइव प्रकाशित हो गया!' : '💾 ड्राफ्ट सहेज लिया गया!');
      resetForm();
      switchTab('manage');
    } else {
      alert('त्रुटि: ' + (data.error || 'सहेजने में असमर्थ'));
    }
  } catch (err) {
    alert('सर्वर से संपर्क करने में असमर्थ');
  }
}

function resetForm() {
  document.getElementById('editingPostId').value = '';
  document.getElementById('postTitle').value = '';
  document.getElementById('postSlug').value = '';
  document.getElementById('postCategory').value = '';
  document.getElementById('postKeyword').value = '';
  document.getElementById('postExcerpt').value = '';
  document.getElementById('postCover').value = '';
  document.getElementById('postContent').value = '';
  document.getElementById('postMetaDesc').value = '';
  document.getElementById('faqContainer').innerHTML = '';
  onCoverChange();
  onTitleChange();
  onDescChange();
}

async function loadAdminPosts() {
  const token = localStorage.getItem('dhankund_blog_token');
  const tbody = document.getElementById('postsTableBody');
  try {
    const res = await fetch(API_BASE + '/api/v1/admin/blog', {
      headers: { 'Authorization': 'Bearer ' + token }
    });
    if (!res.ok) return;
    const posts = await res.json();

    if (!posts.length) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:#64748b;padding:24px;">अभी कोई ब्लॉग पोस्ट नहीं है। पहला ब्लॉग लिखें!</td></tr>';
      return;
    }

    tbody.innerHTML = posts.map(p => {
      const isPub = p.status === 'published';
      const pill = isPub ? '<span class="status-pill status-published">प्रकाशित</span>' : '<span class="status-pill status-draft">ड्राफ्ट</span>';
      return \`
        <tr>
          <td>
            <strong>\${escapeHtml(p.title)}</strong><br/>
            <small style="color:#64748b;">/blog/\${escapeHtml(p.slug)}</small>
          </td>
          <td>\${escapeHtml(p.category_name || '-')}</td>
          <td>\${pill}</td>
          <td>👁️ \${p.views || 0}</td>
          <td>\${(p.published_at || p.created_at || '').split('T')[0]}</td>
          <td>
            <div style="display:flex;gap:6px;">
              <button class="btn btn-secondary" style="padding:4px 8px;font-size:12px;" onclick="editPost('\${p.id}')">संपादित</button>
              <a class="btn btn-secondary" style="padding:4px 8px;font-size:12px;" href="/blog/\${encodeURIComponent(p.slug)}" target="_blank">देखें</a>
              <button class="btn btn-danger" style="padding:4px 8px;font-size:12px;" onclick="deletePost('\${p.id}')">हटाएं</button>
            </div>
          </td>
        </tr>
      \`;
    }).join('');
  } catch (err) {}
}

async function editPost(id) {
  const token = localStorage.getItem('dhankund_blog_token');
  try {
    const res = await fetch(API_BASE + '/api/v1/admin/blog', {
      headers: { 'Authorization': 'Bearer ' + token }
    });
    const posts = await res.json();
    const p = posts.find(x => x.id === id);
    if (!p) return;

    document.getElementById('editingPostId').value = p.id;
    document.getElementById('postTitle').value = p.title || '';
    document.getElementById('postSlug').value = p.slug || '';
    document.getElementById('postCategory').value = p.category_id || '';
    document.getElementById('postKeyword').value = p.keywords || '';
    document.getElementById('postExcerpt').value = p.excerpt || '';
    document.getElementById('postCover').value = p.cover_image || '';
    document.getElementById('postContent').value = p.content || '';
    document.getElementById('postMetaDesc').value = p.seo_description || p.excerpt || '';

    // Load FAQs
    const faqCont = document.getElementById('faqContainer');
    faqCont.innerHTML = '';
    const faqs = Array.isArray(p.faqs) ? p.faqs : [];
    faqs.forEach(f => addFaqRow(f.question, f.answer));

    onCoverChange();
    onTitleChange();
    onDescChange();
    switchTab('create');
  } catch (err) {}
}

async function deletePost(id) {
  if (!confirm('क्या आप वाकई इस ब्लॉग को हटाना चाहते हैं?')) return;
  const token = localStorage.getItem('dhankund_blog_token');
  try {
    const res = await fetch(API_BASE + '/api/v1/admin/blog/' + id, {
      method: 'DELETE',
      headers: { 'Authorization': 'Bearer ' + token }
    });
    if (res.ok) {
      loadAdminPosts();
    }
  } catch (err) {}
}

checkExistingSession();
</script>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

// ---------- Main Cloudflare Worker Handler ----------

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    // 1. Dynamic XML Sitemap (/sitemap.xml)
    if (pathname === "/sitemap.xml") {
      return await renderSitemap(request);
    }

    // 2. Robots.txt (/robots.txt)
    if (pathname === "/robots.txt") {
      return renderRobots(request);
    }

    // 3. Blog Authoring Studio (/blog/admin)
    if (pathname === "/blog/admin") {
      return await renderAdmin(request);
    }

    // 4. Live Blog Listing & Dynamic Article Routes (/blog, /blog/:slug)
    if (pathname === "/blog" || pathname.startsWith("/blog/")) {
      try {
        const slug = pathname.replace(/^\/blog\/?/, "").trim();
        if (!slug) return await renderListing(request);
        return await renderDetail(request, decodeURIComponent(slug));
      } catch (e) {
        console.error("Blog render error:", e);
        return json({ error: "Server error" }, 500);
      }
    }

    // 5. Fallback to next-on-pages Next.js worker
    return nextWorker.fetch(request, env, ctx);
  },
};