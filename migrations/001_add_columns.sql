-- Auto-generated schema migration: adds new columns to existing tables
-- This file is run AFTER schema.sql during deploy.
-- ALTER TABLE fails if column already exists — the deploy script handles this.

-- Users table: add 29 new columns
ALTER TABLE users ADD COLUMN profile_completed INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN profile_picture_url TEXT;
ALTER TABLE users ADD COLUMN fcm_token TEXT;
ALTER TABLE users ADD COLUMN kyc_pan TEXT;
ALTER TABLE users ADD COLUMN kyc_aadhaar TEXT;
ALTER TABLE users ADD COLUMN kyc_doc_url TEXT;
ALTER TABLE users ADD COLUMN bank_name TEXT;
ALTER TABLE users ADD COLUMN bank_account_holder TEXT;
ALTER TABLE users ADD COLUMN bank_account_number TEXT;
ALTER TABLE users ADD COLUMN bank_ifsc TEXT;
ALTER TABLE users ADD COLUMN bank_proof_url TEXT;
ALTER TABLE users ADD COLUMN gender TEXT;
ALTER TABLE users ADD COLUMN company TEXT;
ALTER TABLE users ADD COLUMN address TEXT;
ALTER TABLE users ADD COLUMN current_experience TEXT;
ALTER TABLE users ADD COLUMN total_experience TEXT;
ALTER TABLE users ADD COLUMN segment TEXT;
ALTER TABLE users ADD COLUMN profession TEXT;
ALTER TABLE users ADD COLUMN about TEXT;
ALTER TABLE users ADD COLUMN partner_name TEXT;
ALTER TABLE users ADD COLUMN partner_mobile TEXT;
ALTER TABLE users ADD COLUMN gumasta_url TEXT;
ALTER TABLE users ADD COLUMN id_card_url TEXT;
ALTER TABLE users ADD COLUMN manager_name TEXT;
ALTER TABLE users ADD COLUMN manager_mobile TEXT;
ALTER TABLE users ADD COLUMN area_manager_name TEXT;
ALTER TABLE users ADD COLUMN area_manager_mobile TEXT;
ALTER TABLE users ADD COLUMN nominee_name TEXT;
ALTER TABLE users ADD COLUMN office_address TEXT;

-- Registrations table: add 21 new columns
ALTER TABLE registrations ADD COLUMN name TEXT;
ALTER TABLE registrations ADD COLUMN mobile TEXT;
ALTER TABLE registrations ADD COLUMN email TEXT;
ALTER TABLE registrations ADD COLUMN gender TEXT;
ALTER TABLE registrations ADD COLUMN company TEXT;
ALTER TABLE registrations ADD COLUMN address TEXT;
ALTER TABLE registrations ADD COLUMN current_experience TEXT;
ALTER TABLE registrations ADD COLUMN total_experience TEXT;
ALTER TABLE registrations ADD COLUMN segment TEXT;
ALTER TABLE registrations ADD COLUMN profession TEXT;
ALTER TABLE registrations ADD COLUMN about TEXT;
ALTER TABLE registrations ADD COLUMN partner_name TEXT;
ALTER TABLE registrations ADD COLUMN partner_mobile TEXT;
ALTER TABLE registrations ADD COLUMN gumasta_url TEXT;
ALTER TABLE registrations ADD COLUMN id_card_url TEXT;
ALTER TABLE registrations ADD COLUMN manager_name TEXT;
ALTER TABLE registrations ADD COLUMN manager_mobile TEXT;
ALTER TABLE registrations ADD COLUMN area_manager_name TEXT;
ALTER TABLE registrations ADD COLUMN area_manager_mobile TEXT;
ALTER TABLE registrations ADD COLUMN nominee_name TEXT;
ALTER TABLE registrations ADD COLUMN office_address TEXT;
