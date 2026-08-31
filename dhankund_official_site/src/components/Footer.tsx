import Link from "next/link";

export default function Footer() {
  return (
    <footer className="bg-slate-900 text-slate-300 py-12 mt-auto">
      <div className="container mx-auto px-6 grid grid-cols-1 md:grid-cols-4 gap-8">
        <div className="col-span-1 md:col-span-2">
          <Link href="/" className="text-2xl font-extrabold text-white flex items-center gap-2 mb-4">
            <span className="bg-accent text-white p-1 rounded-md text-sm">DG</span>
            Dhankund Global
          </Link>
          <p className="text-slate-400 max-w-sm mb-6">
            Empowering your financial journey. Dhankund provides comprehensive loan solutions and business consulting services across India.
          </p>
          <p className="text-slate-400 text-sm">
            &copy; {new Date().getFullYear()} Dhankund Global Private Limited. All rights reserved.
          </p>
        </div>
        
        <div>
          <h4 className="text-white font-semibold mb-4">Quick Links</h4>
          <ul className="space-y-2 text-sm">
            <li><Link href="/" className="hover:text-white transition-colors">Home</Link></li>
            <li><Link href="/about" className="hover:text-white transition-colors">About Us</Link></li>
            <li><Link href="/contact" className="hover:text-white transition-colors">Contact</Link></li>
          </ul>
        </div>
        
        <div>
          <h4 className="text-white font-semibold mb-4">Legal</h4>
          <ul className="space-y-2 text-sm">
            <li><Link href="/privacy" className="hover:text-white transition-colors">Privacy Policy</Link></li>
            <li><Link href="/terms" className="hover:text-white transition-colors">Terms & Conditions</Link></li>
          </ul>
        </div>
      </div>
    </footer>
  );
}
