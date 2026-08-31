export default function TermsAndConditions() {
  return (
    <div className="py-20 bg-slate-50">
      <div className="container mx-auto px-6 max-w-4xl">
        <h1 className="text-4xl lg:text-5xl font-bold text-slate-900 mb-6 text-center">Terms and Conditions</h1>
        <p className="text-center text-slate-500 mb-12">Last updated: August 2026</p>
        
        <div className="bg-white p-8 md:p-12 rounded-3xl shadow-sm border border-slate-200 prose prose-slate max-w-none text-slate-700 space-y-8">
          
          <section>
            <h2 className="text-2xl font-bold text-slate-900 mb-4">1. Introduction</h2>
            <p>
              Welcome to Dhankund Global Private Limited. These Terms and Conditions govern your use of our website, applications, and services. By accessing or using our platform, you agree to be bound by these terms.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-slate-900 mb-4">2. Services Provided</h2>
            <p>
              Dhankund acts as a financial consultancy and loan service facilitator, connecting clients with partner banks and NBFCs. We do not lend money directly but assist in the processing and facilitation of loans.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-slate-900 mb-4">3. User Responsibilities</h2>
            <ul className="list-disc pl-6 space-y-2">
              <li>You must provide accurate, current, and complete information during the application process.</li>
              <li>You are responsible for maintaining the confidentiality of your account credentials.</li>
              <li>You agree not to use the platform for any illegal or unauthorized purpose.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-slate-900 mb-4">4. DSA Partner Terms</h2>
            <p>
              If you are registered as a Direct Selling Agent (DSA) via our DSA Banker app:
            </p>
            <ul className="list-disc pl-6 space-y-2 mt-2">
              <li>You must ensure that you have the explicit consent of any leads/clients before submitting their data to our platform.</li>
              <li>Payouts and commissions are subject to the successful disbursement of loans by the respective financial institutions and adherence to our internal policies.</li>
              <li>Dhankund reserves the right to terminate your partner account if fraudulent activities or misrepresentations are detected.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-slate-900 mb-4">5. Limitation of Liability</h2>
            <p>
              Dhankund Global Private Limited shall not be liable for any indirect, incidental, special, or consequential damages resulting from the use or inability to use our services, or from the approval/rejection of loan applications by third-party banks.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-slate-900 mb-4">6. Governing Law</h2>
            <p>
              These Terms shall be governed by and construed in accordance with the laws of India. Any disputes arising under or in connection with these terms shall be subject to the exclusive jurisdiction of the courts located in Indore, Madhya Pradesh.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-bold text-slate-900 mb-4">Contact Us</h2>
            <p>
              If you have any questions about these Terms, please contact us at <a href="mailto:info@dhankund.com" className="text-primary hover:underline">info@dhankund.com</a>.
            </p>
          </section>

        </div>
      </div>
    </div>
  );
}
