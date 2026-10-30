import type { Metadata } from "next";
import { getPosts, getCategories } from "../../lib/blog";
import BlogListView from "../../components/BlogListView";

export const metadata: Metadata = {
  title: "Blog | Dhankund",
  description:
    "Dhankund Blog — loan tips, DSA guides and business insights. Read the latest articles from the Dhankund team.",
};

export default async function BlogPage() {
  const [data, categories] = await Promise.all([
    getPosts({ limit: 100 }),
    getCategories(),
  ]);

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

      {/* Listing */}
      <section className="w-full py-10 bg-white">
        <BlogListView posts={data.posts} categories={categories} />
      </section>
    </div>
  );
}