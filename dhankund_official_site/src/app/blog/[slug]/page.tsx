"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import MarkdownContent from "../../../components/MarkdownContent";
import { getPostBySlug, resolveUrl, formatDate, type BlogPost } from "../../../lib/blog";

export const runtime = "edge";

export default function BlogPostPage() {
  const { slug } = useParams<{ slug: string }>();
  const [post, setPost] = useState<BlogPost | null>(null);
  const [status, setStatus] = useState<"loading" | "found" | "missing">("loading");

  useEffect(() => {
    let cancelled = false;
    async function load() {
      const found = await getPostBySlug(String(slug ?? ""));
      if (cancelled) return;
      if (found) {
        setPost(found);
        setStatus("found");
        if (found.seo_title || found.title) {
          document.title = `${found.seo_title || found.title} | Dhankund`;
        }
      } else {
        setStatus("missing");
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [slug]);

  if (status === "loading") {
    return (
      <div className="container max-w-3xl mx-auto px-6 py-24 text-center text-slate-500">
        लेख लोड हो रहा है...
      </div>
    );
  }

  if (status === "missing" || !post) {
    return (
      <div className="container max-w-3xl mx-auto px-6 py-24 text-center">
        <p className="text-xl font-semibold mb-2">लेख नहीं मिला</p>
        <p className="text-slate-500 mb-6">यह लेख उपलब्ध नहीं है।</p>
        <Link href="/blog" className="btn-outline">
          ← सभी लेख देखें
        </Link>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center">
      {post.cover_image ? (
        <section className="w-full h-72 md:h-96 bg-slate-100">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={resolveUrl(post.cover_image)}
            alt={post.title}
            className="w-full h-full object-cover"
          />
        </section>
      ) : null}

      <article className="container max-w-3xl mx-auto px-6 py-12">
        <div className="flex items-center gap-2 mb-4">
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

        <h1 className="text-3xl md:text-4xl font-extrabold text-slate-900 leading-tight mb-4">
          {post.title}
        </h1>

        <div className="flex items-center gap-3 text-sm text-slate-500 mb-8 pb-6 border-b border-slate-200">
          {post.author_name && <span className="font-semibold text-slate-700">{post.author_name}</span>}
          <span>•</span>
          <span>{formatDate(post.published_at)}</span>
          {post.views > 0 && (
            <>
              <span>•</span>
              <span>{post.views.toLocaleString("en-IN")} पढ़े</span>
            </>
          )}
        </div>

        <div className="blog-content">
          <MarkdownContent content={post.content || ""} />
        </div>

        {post.tags.length > 0 && (
          <div className="flex flex-wrap gap-2 mt-10 pt-6 border-t border-slate-200">
            {post.tags.map((tag) => (
              <span key={tag} className="bg-slate-100 text-slate-600 text-xs font-medium px-3 py-1.5 rounded-full">
                #{tag}
              </span>
            ))}
          </div>
        )}

        <div className="mt-12 text-center">
          <Link href="/blog" className="btn-outline">
            ← सभी लेख देखें
          </Link>
        </div>
      </article>
    </div>
  );
}