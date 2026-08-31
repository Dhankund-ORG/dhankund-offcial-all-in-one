export default function About() {
  return (
    <div className="py-20 bg-slate-50">
      <div className="container mx-auto px-6">
        <div className="max-w-4xl mx-auto">
          <h1 className="text-4xl lg:text-5xl font-bold text-slate-900 mb-8 text-center">About Dhankund Global</h1>
          
          <div className="glass-panel p-8 md:p-12 mb-12">
            <h2 className="text-2xl font-bold text-primary mb-4">Who We Are</h2>
            <p className="text-slate-700 text-lg mb-6 leading-relaxed">
              Dhankund Global Private Limited is a leading financial consultancy and loan service provider based in Indore, Madhya Pradesh, India. We specialize in connecting individuals and businesses with the optimal financial solutions tailored to their unique needs.
            </p>
            <p className="text-slate-700 text-lg leading-relaxed">
              Our extensive network of partner banks, NBFCs, and financial institutions allows us to offer competitive rates and seamless processing for a wide array of financial products.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-8 mb-12">
            <div className="bg-white p-8 rounded-2xl shadow-sm border border-slate-100">
              <h3 className="text-xl font-bold text-slate-900 mb-3">Our Mission</h3>
              <p className="text-slate-600">
                To simplify the financial journey for our clients by providing transparent, accessible, and highly efficient loan and consulting services. We strive to be the bridge between financial aspirations and reality.
              </p>
            </div>
            <div className="bg-white p-8 rounded-2xl shadow-sm border border-slate-100">
              <h3 className="text-xl font-bold text-slate-900 mb-3">Our Vision</h3>
              <p className="text-slate-600">
                To emerge as India's most trusted and reliable financial partner, empowering millions of individuals and expanding a robust B2B network of successful Direct Selling Agents.
              </p>
            </div>
          </div>
          
          <div className="bg-primary text-white p-10 rounded-3xl text-center shadow-lg">
            <h2 className="text-2xl font-bold mb-4">Join Our Journey</h2>
            <p className="text-blue-100 mb-8 max-w-2xl mx-auto">
              Whether you are looking for financial assistance or a partnership opportunity to grow your career as a financial consultant, Dhankund is here for you.
            </p>
            <a href="/contact" className="bg-white text-primary px-8 py-3 rounded-xl font-bold hover:bg-slate-100 transition-colors">Get in Touch</a>
          </div>
        </div>
      </div>
    </div>
  );
}
