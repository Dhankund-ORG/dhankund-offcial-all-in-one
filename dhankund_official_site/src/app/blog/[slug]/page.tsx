import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import MarkdownContent from "../../../components/MarkdownContent";
import { getPostBySlug, getPosts, getCategories, resolveUrl, formatDate } from "../../../lib/blog";

export const dynamicParams = false;

// Build-time: pre-render every published post. New posts appear after the next
// deploy (admin publishing a post and triggering a redeploy).
export async function generateStaticParams() {
  const { posts } = await getPosts({ limit: 50 });
  return posts.map((post) => ({ slug: post.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) return { title: "Blog | Dhankund" };
  const title = post.seo_title || post.title;
  const description = post.seo_description || post.excerpt || post.title;
  const images = post.cover_image ? [resolveUrl(post.cover_image)] : [];
  return {
    title: `${title} | Dhankund`,
    description,
    openGraph: {
      title,
      description,
      type: "article",
      publishedTime: post.published_at || undefined,
      images,
    },
  };
}

export default async function BlogPostPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) notFound();

  const categories = await getCategories();
  const currentCategory = categories.find((c) => c.id === post.category_id);

  return (
    <div className="flex flex-col items-center">
      {/* Cover */}
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
            <Link
              href={`/blog?category=${encodeURIComponent(currentCategory?.slug || "")}`}
              className="bg-primary/10 text-primary text-xs font-bold px-2.5 py-1 rounded-full hover:bg-primary/20 transition-colors"
            >
              {post.category_name}
            </Link>
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
          {post.author_name && (
            <span className="font-semibold text-slate-700">{post.author_name}</span>
          )}
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
              <span
                key={tag}
                className="bg-slate-100 text-slate-600 text-xs font-medium px-3 py-1.5 rounded-full"
              >
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