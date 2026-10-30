"use client";

import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

// Renders Markdown on the client so the edge-runtime server page stays clean
// (react-markdown pulls React hooks that only resolve in a client bundle).
export default function MarkdownContent({ content }: { content: string }) {
  return <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>;
}