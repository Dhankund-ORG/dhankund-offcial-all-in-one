CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE,
  password_hash TEXT,
  role TEXT,
  name TEXT,
  mobile TEXT,
  kyc_completed INTEGER NOT NULL DEFAULT 0,
  bank_details_completed INTEGER NOT NULL DEFAULT 0,
  profile_completed INTEGER NOT NULL DEFAULT 0,
  profile_picture_url TEXT,
  fcm_token TEXT,
  kyc_pan TEXT,
  kyc_aadhaar TEXT,
  kyc_doc_url TEXT,
  bank_name TEXT,
  bank_account_holder TEXT,
  bank_account_number TEXT,
  bank_ifsc TEXT,
  bank_proof_url TEXT,
  gender TEXT,
  company TEXT,
  address TEXT,
  current_experience TEXT,
  total_experience TEXT,
  segment TEXT,
  profession TEXT,
  about TEXT,
  partner_name TEXT,
  partner_mobile TEXT,
  gumasta_url TEXT,
  id_card_url TEXT,
  manager_name TEXT,
  manager_mobile TEXT,
  area_manager_name TEXT,
  area_manager_mobile TEXT,
  nominee_name TEXT,
  office_address TEXT,
  data TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS registrations (
  id TEXT PRIMARY KEY,
  uid TEXT,
  role TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  name TEXT,
  mobile TEXT,
  email TEXT,
  gender TEXT,
  company TEXT,
  address TEXT,
  current_experience TEXT,
  total_experience TEXT,
  segment TEXT,
  profession TEXT,
  about TEXT,
  partner_name TEXT,
  partner_mobile TEXT,
  gumasta_url TEXT,
  id_card_url TEXT,
  manager_name TEXT,
  manager_mobile TEXT,
  area_manager_name TEXT,
  area_manager_mobile TEXT,
  nominee_name TEXT,
  office_address TEXT,
  data TEXT,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS loan_applications (
  id TEXT PRIMARY KEY,
  loan_type TEXT,
  full_name TEXT,
  pan_number TEXT,
  aadhaar_number TEXT,
  mobile_number TEXT,
  email TEXT,
  loan_amount TEXT,
  salary TEXT,
  turnover TEXT,
  father_name TEXT,
  mother_name TEXT,
  marital_status TEXT,
  spouse_name TEXT,
  occupation TEXT,
  personal_email TEXT,
  official_email TEXT,
  current_address TEXT,
  office_address TEXT,
  ref1_name TEXT,
  ref1_mobile TEXT,
  ref1_address TEXT,
  ref2_name TEXT,
  ref2_mobile TEXT,
  ref2_address TEXT,
  applicant_documents TEXT,
  co_applicants TEXT,
  status TEXT NOT NULL DEFAULT 'Pending',
  login_company_name TEXT,
  bank_executive_name TEXT,
  gender TEXT,
  applicant_cibil INTEGER,
  submitted_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS referrals (
  id TEXT PRIMARY KEY,
  referrer_id TEXT,
  friend_name TEXT,
  friend_mobile TEXT,
  friend_email TEXT,
  relationship TEXT,
  loan_type TEXT,
  estimated_amount TEXT,
  consent_given INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'Invited',
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS admin_posts (
  id TEXT PRIMARY KEY,
  uid TEXT,
  name TEXT,
  title TEXT,
  content TEXT,
  imageUrl TEXT,
  timestamp TEXT
);

CREATE TABLE IF NOT EXISTS news_feed (
  id TEXT PRIMARY KEY,
  uid TEXT,
  name TEXT,
  role TEXT,
  company TEXT,
  profilePictureUrl TEXT,
  mobile TEXT,
  content TEXT,
  imageUrl TEXT,
  likes TEXT,
  timestamp TEXT
);

CREATE TABLE IF NOT EXISTS blog_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'hi',
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS blog_posts (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  slug TEXT NOT NULL,
  content TEXT,
  excerpt TEXT,
  cover_image TEXT,
  category_id TEXT,
  category_name TEXT,
  tags TEXT,
  language TEXT NOT NULL DEFAULT 'hi',
  status TEXT NOT NULL DEFAULT 'draft',
  author_name TEXT NOT NULL DEFAULT 'Dhankund Team',
  seo_title TEXT,
  seo_description TEXT,
  keywords TEXT,
  faqs TEXT,
  published_at TEXT,
  updated_at TEXT,
  views INTEGER NOT NULL DEFAULT 0,
  created_at TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_blog_posts_slug ON blog_posts (slug);
CREATE INDEX IF NOT EXISTS idx_blog_posts_status ON blog_posts (status, published_at);
CREATE INDEX IF NOT EXISTS idx_blog_posts_category ON blog_posts (category_id);

CREATE TABLE IF NOT EXISTS statuses (
  id TEXT PRIMARY KEY,
  uid TEXT,
  name TEXT,
  role TEXT,
  company TEXT,
  mobile TEXT,
  text TEXT,
  gradientIndex INTEGER,
  mediaUrl TEXT,
  mediaType TEXT,
  profilePictureUrl TEXT,
  timestamp TEXT
);

CREATE TABLE IF NOT EXISTS bank_policies (
  id TEXT PRIMARY KEY,
  bank_name TEXT,
  banker_name TEXT,
  banker_mobile TEXT,
  office_address TEXT,
  l1_manager_name TEXT,
  l1_manager_mobile TEXT,
  l2_manager_name TEXT,
  l2_manager_mobile TEXT,
  loan_type TEXT,
  product_type TEXT,
  vertical TEXT,
  segment TEXT,
  min_cibil INTEGER,
  min_income TEXT,
  min_ticket_size TEXT,
  max_ticket_size TEXT,
  ticket_size TEXT,
  max_loan_amount TEXT,
  ltv_ratio TEXT,
  ltv_on_plot TEXT,
  m_profile_allowed TEXT,
  max_allowed_bounces INTEGER,
  geo_radius TEXT,
  login_fee TEXT,
  interest_rate TEXT,
  processing_fee TEXT,
  special_features TEXT,
  tat_days TEXT,
  age_limit TEXT,
  foir_norms TEXT,
  existing_obligations TEXT,
  employment_stability TEXT,
  repayment_tenure TEXT,
  road_winding_property_funding TEXT,
  gram_panchayat_property_funding TEXT,
  notary_to_registry_funding TEXT,
  gram_panchayat_patta_funding TEXT,
  dron_patta_funding TEXT,
  highest_ticket_size_notary TEXT,
  high_tension_line_funding TEXT,
  without_diversion_property_funding TEXT,
  only_diversion_property_funding TEXT,
  akvn_property_funding TEXT,
  green_belt_property_funding TEXT,
  plot_purchase TEXT,
  plot_mortgage TEXT,
  is_salary_slip_required TEXT,
  residence_ownership_type TEXT,
  business_ownership_type TEXT,
  is_gst_required TEXT,
  is_itr_required TEXT,
  is_udyam_required TEXT,
  is_current_account_required TEXT,
  bankings_considered TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS broadcast_history (
  id TEXT PRIMARY KEY,
  audiences TEXT,
  send_whatsapp INTEGER NOT NULL DEFAULT 0,
  send_email INTEGER NOT NULL DEFAULT 0,
  send_push INTEGER NOT NULL DEFAULT 0,
  subject TEXT,
  message TEXT,
  recipient_count INTEGER NOT NULL DEFAULT 0,
  timestamp TEXT
);

CREATE TABLE IF NOT EXISTS fcm_tokens (
  token TEXT PRIMARY KEY,
  user_id TEXT,
  platform TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_registrations_role ON registrations (role);
CREATE INDEX IF NOT EXISTS idx_registrations_uid ON registrations (uid);
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_loans_submitted_at ON loan_applications (submitted_at);
CREATE INDEX IF NOT EXISTS idx_loans_email ON loan_applications (email);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals (referrer_id);

CREATE TABLE IF NOT EXISTS banners (
  id TEXT PRIMARY KEY,
  title TEXT,
  subtitle TEXT,
  color_hex TEXT,
  image_url TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS password_reset_otps (
  email TEXT NOT NULL,
  otp TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS otp_rate_limits (
  email TEXT NOT NULL,
  requested_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS blocked_ips (
  ip TEXT PRIMARY KEY,
  block_type TEXT NOT NULL,
  reason TEXT,
  violation_count INTEGER DEFAULT 1,
  expires_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ip_security_logs (
  id TEXT PRIMARY KEY,
  ip TEXT NOT NULL,
  email TEXT,
  user_agent TEXT,
  country TEXT,
  action TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_blocked_ips_ip ON blocked_ips(ip);
CREATE INDEX IF NOT EXISTS idx_ip_security_logs_ip ON ip_security_logs(ip);
CREATE INDEX IF NOT EXISTS idx_ip_security_logs_created ON ip_security_logs(created_at);

-- Seed CRM Admin User
-- The password_hash is left NULL on purpose: the login handler derives the
-- correct PBKDF2 hash from the ADMIN_PASSWORD worker secret on first login,
-- so the admin credentials always follow the GitHub Actions secrets. The
-- ON CONFLICT clause never overwrites an existing hash on redeploys.
INSERT INTO users (
  id, email, password_hash, role, name, 
  kyc_completed, bank_details_completed, profile_completed, 
  created_at, updated_at
) VALUES (
  'admin_dhankund', 
  'dhankundloans@gmail.com', 
  NULL, 
  'admin', 
  'Dhankund Admin', 
  1, 1, 1, 
  CURRENT_TIMESTAMP, 
  CURRENT_TIMESTAMP
) ON CONFLICT(email) DO NOTHING;

CREATE TABLE IF NOT EXISTS blog_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  language TEXT NOT NULL DEFAULT 'hi',
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS blog_admin_otps (
  mobile TEXT NOT NULL,
  otp TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_blog_admin_otps_mobile ON blog_admin_otps(mobile);

-- Seed Initial Blog Categories for Dhankund Loan Services
INSERT OR IGNORE INTO blog_categories (id, name, slug, language, created_at) VALUES
  ('cat_personal_loan', 'पर्सनल लोन (Personal Loan)', 'personal-loan', 'hi', CURRENT_TIMESTAMP),
  ('cat_home_loan', 'होम लोन (Home Loan)', 'home-loan', 'hi', CURRENT_TIMESTAMP),
  ('cat_business_loan', 'बिजनेस लोन (Business Loan)', 'business-loan', 'hi', CURRENT_TIMESTAMP),
  ('cat_lap', 'लोन अगेंस्ट प्रॉपर्टी (LAP)', 'loan-against-property', 'hi', CURRENT_TIMESTAMP),
  ('cat_cibil_tips', 'सिबिल स्कोर गाइड (CIBIL Tips)', 'cibil-score-guide', 'hi', CURRENT_TIMESTAMP),
  ('cat_dsa_guide', 'DSA पार्टनर गाइड (DSA Guide)', 'dsa-guide', 'hi', CURRENT_TIMESTAMP);
