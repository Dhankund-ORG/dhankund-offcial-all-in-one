"use client";

import Link from "next/link";
import { useState } from "react";
import type { BlogPost, BlogCategory } from "../lib/blog";
import { resolveUrl, formatDate } from "../lib/blog";

// Client-side category filter/search for the statically generated blog listing.
export default function BlogListView({
  posts,
  categories,
}: {
  posts: BlogPost[];
  categories: BlogCategory[];
}) {
  const [activeCategory, setActiveCategory] = useState("");
  const [query, setQuery] = useState("");

  const filtered = posts.filter((post) => {
    const matchesCategory = !activeCategory || post.category_id === activeCategory;
    const q = query.toLowerCase();
    const matchesQuery =
      q.length === 0 ||
      post.title.toLowerCase().includes(q) ||
      (post.excerpt || "").toLowerCase().includes(q);
    return matchesCategory && matchesQuery;
  });

  return (
    <div className="container mx-auto px-6">
      <div className="flex flex-wrap items-center gap-3 mb-8">
        <button
          onClick={() => setActiveCategory("")}
          className={`px-4 py-2 rounded-full text-sm font-medium border transition-colors cursor-pointer ${
            !activeCategory
              ? "bg-primary text-white border-primary"
              : "border-slate-300 text-slate-600 hover:border-primary hover:text-primary"
          }`}
        >
          सभी
        </button>
        {categories.map((cat) => (
          <button
            key={cat.id}
            onClick={() => setActiveCategory(cat.id)}
            className={`px-4 py-2 rounded-full text-sm font-medium border transition-colors cursor-pointer ${
              activeCategory === cat.id
                ? "bg-primary text-white border-primary"
                : "border-slate-300 text-slate-600 hover:border-primary hover:text-primary"
            }`}
          >
            {cat.name}
          </button>
        ))}
        <div className="ml-auto">
          <input
            type="search"
            placeholder="लेख खोजें..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="px-4 py-2 rounded-full border border-slate-300 text-sm focus:outline-none focus:border-primary"
          />
        </div>
      </div>

      {filtered.length ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {filtered.map((post) => (
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
      )}
    </div>
  );
}