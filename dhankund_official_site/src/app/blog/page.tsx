import Link from "next/link";
import type { Metadata } from "next";
import { getPosts, getCategories, resolveUrl, formatDate, API_BASE } from "../../lib/blog";

export const metadata: Metadata = {
  title: "Blog | Dhankund",
  description:
    "Dhankund Blog — loan tips, DSA guides and business insights. Read the latest articles from the Dhankund team.",
};

export default async function BlogPage({
  searchParams,
}: {
  searchParams: Promise<{ category?: string; language?: string; q?: string }>;
}) {
  const sp = await searchParams;
  const [data, categories] = await Promise.all([
    getPosts({ category: sp.category, language: sp.language, q: sp.q }),
    getCategories(),
  ]);

  const activeCategory = sp.category || "";
  const activeLanguage = sp.language || "";
  const query = sp.q || "";

  const blogCards = data.posts.length ? (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
      {data.posts.map((post) => (
        <Link
          key={post.id}
          href={`/blog/${post.slug}`}
          className="glass-panel group overflow-hidden hover:shadow-xl transition-shadow flex flex-col"
        >
          <div className="h-48 w-full bg-slate-100 overflow-hidden">
            {post.cover_image ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={resolveUrl(post.cover_image)}
                alt={post.title}
                className="w-full h-full object-cover group-hover:scale-105 transition-transform"
              />
            ) : (
              <div className="w-full h-full flex items-center justify-center bg-gradient-to-br from-primary to-accent text-white text-3xl font-extrabold">
                {post.title.slice(0, 1).toUpperCase()}
              </div>
            )}
          </div>
          <div className="p-6 flex flex-col flex-1">
            <div className="flex items-center gap-2 mb-3">
              {post.category_name && (
                <span className="bg-primary/10 text-primary text-xs font-bold px-2.5 py-1 rounded-full">
                  {post.category_name}
                </span>
              )}
              {post.language === "hi" && (
                <span className="bg-emerald-50 text-emerald-700 text-xs font-semibold px-2.5 py-1 rounded-full">
                  हिंदी
                </span>
              )}
            </div>
            <h2 className="text-xl font-bold text-slate-900 mb-2 leading-snug group-hover:text-primary transition-colors">
              {post.title}
            </h2>
            {post.excerpt && (
              <p className="text-slate-600 text-sm leading-relaxed mb-4 line-clamp-3">{post.excerpt}</p>
            )}
            <div className="mt-auto flex items-center justify-between text-xs text-slate-400">
              <span>{formatDate(post.published_at)}</span>
              <span className="font-medium text-primary">पढ़ें →</span>
            </div>
          </div>
        </Link>
      ))}
    </div>
  ) : (
    <div className="text-center py-20 text-slate-500">
      <p className="text-xl font-semibold mb-2">कोई लेख नहीं मिला</p>
      <p>कुछ और खोजने की कोशिश करें, या नए लेख जल्द आ रहे हैं।</p>
    </div>
  );

  return (
    <div className="flex flex-col items-center">
      {/* Header */}
      <section className="w-full bg-slate-50 py-16 lg:py-20">
        <div className="container mx-auto px-6 text-center">
          <h1 className="text-4xl lg:text-5xl font-extrabold text-slate-900 mb-4">
            Dhankund <span className="text-transparent bg-clip-text bg-gradient-to-r from-primary to-accent">Blog</span>
          </h1>
          <p className="text-slate-600 max-w-2xl mx-auto">
            लोन टिप्स, DSA गाइड और बिज़नेस की जानकारी — Dhankund टीम की ओर से नए लेख।
          </p>
        </div>
      </section>

      {/* Filters */}
      <section className="w-full py-10 bg-white">
        <div className="container mx-auto px-6">
          <div className="flex flex-wrap items-center gap-3 mb-8">
            <Link
              href="/blog"
              className={`px-4 py-2 rounded-full text-sm font-medium border transition-colors ${
                !activeCategory
                  ? "bg-primary text-white border-primary"
                  : "border-slate-300 text-slate-600 hover:border-primary hover:text-primary"
              }`}
            >
              सभी
            </Link>
            {categories.map((cat) => (
              <Link
                key={cat.id}
                href={`/blog?category=${encodeURIComponent(cat.slug)}`}
                className={`px-4 py-2 rounded-full text-sm font-medium border transition-colors ${
                  activeCategory === cat.slug
                    ? "bg-primary text-white border-primary"
                    : "border-slate-300 text-slate-600 hover:border-primary hover:text-primary"
                }`}
              >
                {cat.name}
              </Link>
            ))}
            <Link
              href={activeLanguage === "hi" ? `/blog${activeCategory ? `?category=${encodeURIComponent(activeCategory)}` : ""}` : `/blog${activeCategory ? `?category=${encodeURIComponent(activeCategory)}` : "?language=hi"}`}
              className={`px-4 py-2 rounded-full text-sm font-medium border transition-colors ${
                activeLanguage === "hi"
                  ? "bg-emerald-600 text-white border-emerald-600"
                  : "border-slate-300 text-slate-600 hover:border-emerald-600 hover:text-emerald-700"
              }`}
            >
              हिंदी लेख
            </Link>
          </div>

          {query && (
            <p className="text-sm text-slate-500 mb-4">
              “{query}” के लिए {data.total} परिणाम — <Link href="/blog" className="text-primary font-medium">सभी दिखाएँ</Link>
            </p>
          )}

          {blogCards}
        </div>
      </section>
    </div>
  );
}