-- Sets the admin credentials to exactly match the GitHub Actions secrets.
-- The password_hash is cleared so the login handler derives the correct
-- bcrypt hash from the ADMIN_PASSWORD worker secret on the next login.
UPDATE users SET password_hash = NULL, email = '__ADMIN_EMAIL__' WHERE role = 'admin';