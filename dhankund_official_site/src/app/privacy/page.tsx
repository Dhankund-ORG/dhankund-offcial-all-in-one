export default function PrivacyPolicy() {
  return (
    <div className="py-20 bg-slate-50">
      <div className="container mx-auto px-6 max-w-4xl">
        <h1 className="text-4xl lg:text-5xl font-bold text-slate-900 mb-6 text-center">Privacy Policy</h1>
        <p className="text-center text-slate-500 mb-12">Last updated: August 2026</p>
        
        <div className="bg-white p-8 md:p-12 rounded-3xl shadow-sm border border-slate-200 prose prose-slate max-w-none">
          <p className="text-lg text-slate-700 mb-8">
            Dhankund Global Private Limited ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you visit our website, use our upcoming User Application, or use our DSA Banker Application.
          </p>

          <hr className="my-10 border-slate-200" />

          {/* Section A: General Users */}
          <section className="mb-12">
            <h2 className="text-2xl font-bold text-primary mb-6 flex items-center gap-3">
              <span className="bg-blue-100 text-primary w-8 h-8 rounded-full flex items-center justify-center text-sm">A</span>
              For General Users & Website Visitors
            </h2>
            <div className="space-y-6 text-slate-700">
              <div>
                <h3 className="text-xl font-semibold mb-2">1. Information We Collect</h3>
                <p>We may collect personal identification information such as your name, email address, phone number, and financial details when you voluntarily submit them through our website forms or the User Application to inquire about loan services.</p>
              </div>
              
              <div>
                <h3 className="text-xl font-semibold mb-2">2. How We Use Your Information</h3>
                <p>We use the information collected to:</p>
                <ul className="list-disc pl-6 mt-2 space-y-1">
                  <li>Process your loan inquiries and applications.</li>
                  <li>Communicate with you regarding our services.</li>
                  <li>Improve our website and user experience.</li>
                  <li>Comply with legal and regulatory requirements.</li>
                </ul>
              </div>

              <div>
                <h3 className="text-xl font-semibold mb-2">3. Data Sharing and Security</h3>
                <p>Your data is securely stored and only shared with our trusted banking and NBFC partners solely for the purpose of processing your loan applications. We do not sell your personal data to third parties.</p>
              </div>
            </div>
          </section>

          <hr className="my-10 border-slate-200" />

          {/* Section B: DSA Partners */}
          <section className="mb-12">
            <h2 className="text-2xl font-bold text-indigo-600 mb-6 flex items-center gap-3">
              <span className="bg-indigo-100 text-indigo-600 w-8 h-8 rounded-full flex items-center justify-center text-sm">B</span>
              For DSA Partners & Bankers (DSA App)
            </h2>
            <div className="space-y-6 text-slate-700">
              <div>
                <h3 className="text-xl font-semibold mb-2">1. Information We Collect</h3>
                <p>When you register as a Direct Selling Agent (DSA) or Partner, we collect your professional details, KYC documents (PAN, Aadhar, etc.), bank account details for payouts, and business contact information.</p>
              </div>
              
              <div>
                <h3 className="text-xl font-semibold mb-2">2. Lead Data Management</h3>
                <p>Any customer data (leads) you upload or manage through the DSA Banker app is treated with the highest confidentiality. We use this data exclusively to process the loan applications you initiate. You represent that you have obtained necessary consent from your clients before uploading their data to our platform.</p>
              </div>

              <div>
                <h3 className="text-xl font-semibold mb-2">3. App Permissions</h3>
                <p>The DSA Banker app may request permissions for Camera/Storage (for uploading KYC documents), Notifications (for application status updates), and Network access. These are strictly used for the core functionality of the app.</p>
              </div>
            </div>
          </section>

          <hr className="my-10 border-slate-200" />

          <section>
            <h2 className="text-2xl font-bold text-slate-900 mb-4">Contact Us</h2>
            <p className="text-slate-700">
              If you have any questions about this Privacy Policy, please contact us at: <br/>
              <strong>Email:</strong> <a href="mailto:info@dhankund.com" className="text-primary hover:underline">info@dhankund.com</a> <br/>
              <strong>Address:</strong> Indore, Madhya Pradesh, India
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
