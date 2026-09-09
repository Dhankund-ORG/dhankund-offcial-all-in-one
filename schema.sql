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
  min_cibil INTEGER,
  min_income TEXT,
  min_ticket_size TEXT,
  max_ticket_size TEXT,
  ticket_size TEXT,
  max_loan_amount TEXT,
  ltv_ratio TEXT,
  m_profile_allowed TEXT,
  max_allowed_bounces INTEGER,
  geo_radius TEXT,
  login_fee TEXT,
  interest_rate TEXT,
  processing_fee TEXT,
  special_features TEXT,
  tat_days TEXT,
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
