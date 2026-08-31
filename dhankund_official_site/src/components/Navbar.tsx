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
          <a href="#download" className="btn-primary px-4 py-2 text-sm rounded-lg shadow-none hover:shadow-md">
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
        </nav>
      )}
    </header>
  );
}
