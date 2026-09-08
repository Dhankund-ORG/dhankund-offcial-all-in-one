-- Users Table
CREATE TABLE IF NOT EXISTS users (
    uid TEXT PRIMARY KEY,
    name TEXT,
    email TEXT,
    mobile TEXT,
    role TEXT,
    profile_completed BOOLEAN DEFAULT 0,
    kyc_completed BOOLEAN DEFAULT 0,
    bank_details_completed BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    kyc_pan TEXT,
    kyc_aadhaar TEXT,
    kyc_doc_url TEXT,
    bank_name TEXT,
    bank_account_holder TEXT,
    bank_account_number TEXT,
    bank_ifsc TEXT
);

-- Loan Applications
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
    status TEXT,
    login_company_name TEXT,
    bank_executive_name TEXT,
    gender TEXT,
    applicant_cibil INTEGER,
    applicant_documents TEXT, -- JSON string
    co_applicants TEXT, -- JSON string
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Referrals
CREATE TABLE IF NOT EXISTS referrals (
    id TEXT PRIMARY KEY,
    referrer_id TEXT,
    friend_name TEXT,
    friend_mobile TEXT,
    friend_email TEXT,
    relationship TEXT,
    loan_type TEXT,
    estimated_amount TEXT,
    consent_given BOOLEAN DEFAULT 0,
    status TEXT DEFAULT 'Invited',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Registrations (DSA, Banker, Partner grouped into one or separate)
CREATE TABLE IF NOT EXISTS registrations (
    id TEXT PRIMARY KEY,
    role_type TEXT, -- DSA, BANKER, PARTNER
    uid TEXT,
    name TEXT,
    email TEXT,
    mobile TEXT,
    gender TEXT,
    gumasta_url TEXT,
    id_card_url TEXT,
    company TEXT,
    address TEXT,
    office_address TEXT,
    current_exp TEXT,
    total_exp TEXT,
    segment TEXT,
    profession TEXT,
    about TEXT,
    nominee_name TEXT,
    status TEXT DEFAULT 'pending',
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Admin Posts
CREATE TABLE IF NOT EXISTS admin_posts (
    id TEXT PRIMARY KEY,
    uid TEXT,
    name TEXT,
    title TEXT,
    content TEXT,
    image_url TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- News Feed
CREATE TABLE IF NOT EXISTS news_feed (
    id TEXT PRIMARY KEY,
    author_id TEXT,
    title TEXT,
    content TEXT,
    image_url TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Statuses (Stories)
CREATE TABLE IF NOT EXISTS statuses (
    id TEXT PRIMARY KEY,
    author_id TEXT,
    image_url TEXT,
    text_content TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Bank Policies
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
    ltv_ratio TEXT,
    m_profile_allowed TEXT,
    max_allowed_bounces INTEGER,
    geo_radius TEXT,
    login_fee TEXT,
    interest_rate TEXT,
    processing_fee TEXT,
    special_features TEXT,
    tat_days TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Broadcast History
CREATE TABLE IF NOT EXISTS broadcast_history (
    id TEXT PRIMARY KEY,
    audiences TEXT, -- JSON array of strings
    send_whatsapp BOOLEAN,
    send_email BOOLEAN,
    subject TEXT,
    message TEXT,
    recipient_count INTEGER,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
