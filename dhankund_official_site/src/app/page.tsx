import Link from "next/link";

export default function Home() {
  return (
    <div className="flex flex-col items-center">
      {/* Hero Section */}
      <section className="w-full relative overflow-hidden bg-slate-50 py-24 lg:py-32">
        <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-blue-400/20 blur-[120px] rounded-full"></div>
        <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-indigo-400/20 blur-[120px] rounded-full"></div>
        
        <div className="container mx-auto px-6 text-center relative z-10 animate-fade-up">
          <h1 className="text-5xl lg:text-7xl font-extrabold text-slate-900 tracking-tight mb-6">
            Empower Your <span className="text-transparent bg-clip-text bg-gradient-to-r from-primary to-accent">Financial Journey</span>
          </h1>
          <p className="text-lg lg:text-xl text-slate-600 max-w-2xl mx-auto mb-10">
            Dhankund Global Private Limited provides premier loan services, business consulting, and a powerful platform for Direct Selling Agents (DSA) across India.
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <Link href="/about" className="btn-primary w-full sm:w-auto">
              Learn More
            </Link>
            <Link href="/contact" className="btn-outline w-full sm:w-auto">
              Contact Us
            </Link>
          </div>
        </div>
      </section>

      {/* Services Section */}
      <section className="w-full py-20 bg-white">
        <div className="container mx-auto px-6">
          <div className="text-center mb-16">
            <h2 className="text-3xl lg:text-4xl font-bold text-slate-900 mb-4">Our Services</h2>
            <p className="text-slate-600 max-w-xl mx-auto">Discover how Dhankund can help you achieve your financial and professional goals.</p>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="glass-panel p-8 hover:shadow-xl transition-shadow">
              <div className="w-12 h-12 bg-blue-100 text-primary rounded-xl flex items-center justify-center mb-6">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
              </div>
              <h3 className="text-xl font-bold text-slate-900 mb-3">Loan Solutions</h3>
              <p className="text-slate-600">Comprehensive loan assistance for individuals and businesses, tailored to your specific financial needs with transparent processing.</p>
            </div>
            
            <div className="glass-panel p-8 hover:shadow-xl transition-shadow">
              <div className="w-12 h-12 bg-indigo-100 text-indigo-600 rounded-xl flex items-center justify-center mb-6">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
              </div>
              <h3 className="text-xl font-bold text-slate-900 mb-3">DSA Partner Network</h3>
              <p className="text-slate-600">Join our growing network of Direct Selling Agents. Use our DSA Banker app to manage leads, track payouts, and expand your B2B network.</p>
            </div>
            
            <div className="glass-panel p-8 hover:shadow-xl transition-shadow">
              <div className="w-12 h-12 bg-purple-100 text-purple-600 rounded-xl flex items-center justify-center mb-6">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>
              </div>
              <h3 className="text-xl font-bold text-slate-900 mb-3">Business Consulting</h3>
              <p className="text-slate-600">Strategic consulting services to help your business optimize operations, manage finances, and achieve sustainable growth.</p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section id="download" className="w-full py-20 bg-primary text-white">
        <div className="container mx-auto px-6 text-center">
          <h2 className="text-3xl lg:text-4xl font-bold mb-6">Ready to join the Dhankund Network?</h2>
          <p className="text-lg text-blue-100 mb-10 max-w-2xl mx-auto">
            Download our specialized apps designed for our users and DSA partners to streamline your experience.
          </p>
          <div className="flex flex-col sm:flex-row justify-center gap-6">
            <a href="#" className="bg-white text-primary px-8 py-4 rounded-xl font-bold hover:bg-blue-50 transition-colors shadow-lg flex items-center justify-center gap-2">
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M17.523 15.3414C17.523 11.2335 20.8984 9.19379 21.0543 9.09249C18.9958 6.07119 15.6983 5.61719 14.5363 5.56549C12.1813 5.32169 9.87836 6.94509 8.67566 6.94509C7.47286 6.94509 5.59026 5.61719 3.65586 5.66909C1.12786 5.71969 -1.24684 7.14079 0.00766023 11.0261C0.37056 12.0366 1.13966 14.1543 2.50206 16.1264C3.89676 18.1519 5.50086 20.4682 7.74756 20.5201C9.94316 20.571 10.7675 19.2312 13.3108 19.2312C15.854 19.2312 16.626 20.5201 18.8727 20.4682C21.1713 20.4165 22.5655 18.3541 23.9082 16.3813C25.433 14.1543 26.0526 12.0125 26.1042 11.9099C26.0526 11.8593 22.8465 10.6433 22.7946 15.3414H17.523ZM14.4847 3.53509C15.723 2.06289 16.5518 -0.0152069 16.345  -1.99341C14.6366 -1.94261 12.3577 0.997293 11.17 2.47059C10.1332 3.73719 9.14816 5.86659 9.35516 7.79429C11.2759 7.94729 13.2458 5.00799 14.4847 3.53509Z"/></svg>
              App Store
            </a>
            <a href="#" className="bg-white text-primary px-8 py-4 rounded-xl font-bold hover:bg-blue-50 transition-colors shadow-lg flex items-center justify-center gap-2">
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M3.609 1.814L13.792 12l-10.183 10.186c-.166-.112-.314-.265-.432-.452L.15 13.351C-.05 13.003-.05 10.997.15 10.65L3.177 2.266c.118-.187.266-.34.432-.452zM15.419 13.627l4.088 2.378c1.332.775 1.332 2.035 0 2.81l-2.022 1.177-7.986-7.985 5.92-5.92zM15.419 10.373L9.5 4.453l7.986-7.985 2.022 1.177c1.332.775 1.332 2.035 0 2.81l-4.088 2.378zM14.61 12l2.366-2.366L21.5 12l-4.524 2.366L14.61 12z"/></svg>
              Google Play
            </a>
          </div>
        </div>
      </section>
    </div>
  );
}
