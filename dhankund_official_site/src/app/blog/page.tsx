import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Blog | Dhankund",
  description: "Dhankund Blog — loan tips, DSA guides and business insights.",
};

export default async function BlogPage() {
  return (
    <div className="flex flex-col items-center">
      <section className="w-full bg-slate-50 py-16">
        <div className="container mx-auto px-6 text-center">
          <h1 className="text-4xl font-extrabold text-slate-900 mb-4">Dhankund Blog</h1>
          <p className="text-slate-600">Blog page diagnostic build.</p>
        </div>
      </section>
    </div>
  );
}