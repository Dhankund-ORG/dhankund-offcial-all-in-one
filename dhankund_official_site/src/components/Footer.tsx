import Link from "next/link";

export default function Footer() {
  return (
    <footer className="bg-slate-900 text-slate-300 py-12 mt-auto">
      <div className="container mx-auto px-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
        <div>
          <Link href="/" className="text-2xl font-extrabold text-white flex items-center gap-2 mb-4">
            <span className="bg-accent text-white p-1 rounded-md text-sm">DG</span>
            Dhankund Global
          </Link>
          <p className="text-slate-400 mb-6 text-sm leading-relaxed">
            Empowering your financial journey. Dhankund provides comprehensive loan solutions and business consulting services across India.
          </p>
          <p className="text-slate-500 text-xs">
            &copy; {new Date().getFullYear()} Dhankund Global Private Limited. All rights reserved.
          </p>
        </div>
        
        <div>
          <h4 className="text-white font-semibold mb-4">Quick Links</h4>
          <ul className="space-y-2 text-sm">
            <li><Link href="/" className="hover:text-white transition-colors">Home</Link></li>
            <li><Link href="/blog" className="hover:text-white transition-colors">Blog</Link></li>
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

        <div>
          <h4 className="text-white font-semibold mb-4">Contact Info</h4>
          <div className="space-y-3 text-sm text-slate-400">
            <div>
              <span className="text-slate-200 block font-medium">Office:</span>
              <p className="leading-snug">LG Floor, Glass Cabin No. 2, Orbit Mall, Vijaynagar, AB Road, Indore 452010</p>
            </div>
            <div>
              <span className="text-slate-200 block font-medium">Phone:</span>
              <p><a href="tel:+919669084666" className="hover:text-white transition-colors">+91 96690 84666</a></p>
              <p><a href="tel:+916268147177" className="hover:text-white transition-colors">+91 62681 47177</a></p>
            </div>
            <div>
              <span className="text-slate-200 block font-medium">Email:</span>
              <p><a href="mailto:info@dhankund.com" className="hover:text-white transition-colors">info@dhankund.com</a></p>
              <p><a href="mailto:dhankundloans@gmail.com" className="hover:text-white transition-colors">dhankundloans@gmail.com</a></p>
            </div>
          </div>
        </div>
      </div>
    </footer>
  );
}
