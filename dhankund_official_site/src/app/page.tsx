export default function Home() {
  return (
    <>
      <header>
        <div className="container nav-container">
          <div className="logo">Dhankund</div>
          <nav>
            <a href="#" className="btn btn-primary">Partner with Us</a>
          </nav>
        </div>
      </header>

      <main>
        <section className="hero">
          <div className="container">
            <h1>Empowering Your Financial Journey</h1>
            <p>
              Dhankund Global Private Limited is your trusted loan service provider
              and consultancy firm. We bridge the gap between you and your dreams.
            </p>
            <a href="#services" className="btn btn-primary">Explore Our Services</a>
          </div>
        </section>

        <section id="services" className="container features">
          <div className="feature-card glass-panel">
            <h3>Personal Loans</h3>
            <p>
              Get quick approval for personal loans with competitive interest rates
              and flexible repayment options tailored just for you.
            </p>
          </div>
          <div className="feature-card glass-panel">
            <h3>Business Loans</h3>
            <p>
              Scale your business with our customized financial solutions. Easy
              processing and minimum documentation required.
            </p>
          </div>
          <div className="feature-card glass-panel">
            <h3>Consultancy</h3>
            <p>
              Expert financial advice to help you make informed decisions about
              investments, loans, and wealth management.
            </p>
          </div>
        </section>
      </main>
    </>
  );
}
