"use client";

import Link from "next/link";
import { useState } from "react";

export default function Navbar() {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 bg-white/80 backdrop-blur-md border-b border-slate-200 shadow-sm">
      <div className="container mx-auto px-6 py-4 flex justify-between items-center">
        <Link href="/" className="text-2xl font-extrabold text-primary flex items-center gap-2">
          <span className="bg-primary text-white p-1 rounded-md text-sm">DG</span>
          Dhankund
        </Link>

        {/* Desktop Menu */}
        <nav className="hidden md:flex space-x-8 items-center font-medium text-slate-700">
          <Link href="/" className="hover:text-accent transition-colors">Home</Link>
          <Link href="/about" className="hover:text-accent transition-colors">About Us</Link>
          <Link href="/contact" className="hover:text-accent transition-colors">Contact</Link>
          <Link href="/privacy" className="hover:text-accent transition-colors">Privacy Policy</Link>
          <Link href="/terms" className="hover:text-accent transition-colors">Terms</Link>
          <a
            href="https://play.google.com/store/apps/details?id=com.dhankund.banker"
            target="_blank"
            rel="noopener noreferrer"
            className="btn-primary px-4 py-2 text-sm rounded-lg shadow-none hover:shadow-md inline-flex items-center gap-2"
          >
            <svg className="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 24 24">
              <path d="M3.609 1.814L13.792 12l-10.183 10.186c-.166-.112-.314-.265-.432-.452L.15 13.351C-.05 13.003-.05 10.997.15 10.65L3.177 2.266c.118-.187.266-.34.432-.452zM15.419 13.627l4.088 2.378c1.332.775 1.332 2.035 0 2.81l-2.022 1.177-7.986-7.985 5.92-5.92zM15.419 10.373L9.5 4.453l7.986-7.985 2.022 1.177c1.332.775 1.332 2.035 0 2.81l-4.088 2.378zM14.61 12l2.366-2.366L21.5 12l-4.524 2.366L14.61 12z"/>
            </svg>
            Get App
          </a>
        </nav>

        {/* Mobile Menu Toggle */}
        <button className="md:hidden text-slate-700" onClick={() => setIsOpen(!isOpen)}>
          <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            {isOpen ? (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            ) : (
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            )}
          </svg>
        </button>
      </div>

      {/* Mobile Menu */}
      {isOpen && (
        <nav className="md:hidden bg-white border-b border-slate-200 px-6 py-4 flex flex-col space-y-4 font-medium text-slate-700 shadow-lg">
          <Link href="/" onClick={() => setIsOpen(false)} className="hover:text-accent">Home</Link>
          <Link href="/about" onClick={() => setIsOpen(false)} className="hover:text-accent">About Us</Link>
          <Link href="/contact" onClick={() => setIsOpen(false)} className="hover:text-accent">Contact</Link>
          <Link href="/privacy" onClick={() => setIsOpen(false)} className="hover:text-accent">Privacy Policy</Link>
          <Link href="/terms" onClick={() => setIsOpen(false)} className="hover:text-accent">Terms</Link>
          <a
            href="https://play.google.com/store/apps/details?id=com.dhankund.banker"
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => setIsOpen(false)}
            className="btn-primary px-4 py-2.5 text-sm rounded-lg text-center flex items-center justify-center gap-2 mt-2"
          >
            <svg className="w-4 h-4 flex-shrink-0" fill="currentColor" viewBox="0 0 24 24">
              <path d="M3.609 1.814L13.792 12l-10.183 10.186c-.166-.112-.314-.265-.432-.452L.15 13.351C-.05 13.003-.05 10.997.15 10.65L3.177 2.266c.118-.187.266-.34.432-.452zM15.419 13.627l4.088 2.378c1.332.775 1.332 2.035 0 2.81l-2.022 1.177-7.986-7.985 5.92-5.92zM15.419 10.373L9.5 4.453l7.986-7.985 2.022 1.177c1.332.775 1.332 2.035 0 2.81l-4.088 2.378zM14.61 12l2.366-2.366L21.5 12l-4.524 2.366L14.61 12z"/>
            </svg>
            Get App
          </a>
        </nav>
      )}
    </header>
  );
}
