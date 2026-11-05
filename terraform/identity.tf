# --- Google Identity Platform: authentication / user management for the app ---
# Free up to 50,000 monthly active users (email/password and social providers);
# Phone auth (SMS OTP), MFA by SMS and SAML/OIDC beyond the free tier are billed per SMS / MAU.
# Requires billing enabled on the project.
resource "google_project_service" "identity" {
  project            = var.project_id
  service            = "identitytoolkit.googleapis.com"
  disable_on_destroy = false
}

resource "google_identity_platform_config" "default" {
  project = var.project_id

  # Remove anonymous users automatically after 30 days
  autodelete_anonymous_users = true

  sign_in {
    allow_duplicate_emails = false

    email {
      enabled           = true
      password_required = true
    }

    # Sign-up and sign-in with a phone number + one-time code (OTP) sent by SMS
    phone_number {
      enabled = true
      # Fictitious numbers -> fixed codes, no SMS sent, no cost (for tests), e.g. { "+33612345678" = "123456" }
      test_phone_numbers = var.identity_test_phone_numbers
    }
  }

  # Limit the countries SMS can be sent to (protects against SMS pumping fraud and surprise bills)
  sms_region_config {
    allowlist_only {
      allowed_regions = var.identity_sms_allowed_regions
    }
  }

  # Domains allowed for OAuth redirects (add your app domain)
  authorized_domains = var.identity_authorized_domains

  # Password policy and brute-force protection are configured from the console / API;
  # blocking functions can be added later.

  depends_on = [google_project_service.identity]
}

# Optional: "Sign in with Google". Needs an OAuth 2.0 client created in the console
# (APIs & Services -> Credentials). Leave the variables empty to skip.
resource "google_identity_platform_default_supported_idp_config" "google" {
  count = var.identity_google_client_id != "" ? 1 : 0

  project       = var.project_id
  idp_id        = "google.com"
  enabled       = true
  client_id     = var.identity_google_client_id
  client_secret = var.identity_google_client_secret

  depends_on = [google_identity_platform_config.default]
}
