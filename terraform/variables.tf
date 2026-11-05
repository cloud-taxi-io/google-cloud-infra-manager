variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Region for Cloud Run"
  default     = "europe-west1"
}

variable "image" {
  type        = string
  description = "Container image for the Cloud Run service (Artifact Registry URL)"
}

variable "topic_name" {
  type    = string
  default = "mon-topic"
}

variable "subscription_name" {
  type    = string
  default = "ma-sub"
}

variable "service_name" {
  type    = string
  default = "mon-service"
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "max_instances" {
  type    = number
  default = 10
}

# --- Free-tier VM -----------------------------------------------------------
variable "vm_name" {
  type    = string
  default = "timescaledb"
}

variable "vm_zone" {
  type        = string
  description = "Must be in us-west1, us-central1 or us-east1 to stay in the free tier"
  default     = "us-central1-a"

  validation {
    condition     = can(regex("^(us-west1|us-central1|us-east1)-[a-z]$", var.vm_zone))
    error_message = "Free tier only applies to zones in us-west1, us-central1 and us-east1."
  }
}

variable "vm_network" {
  type    = string
  default = "default"
}

variable "vm_external_ip" {
  type        = bool
  description = "Attach an ephemeral external IPv4. Not free (about 3.65 USD/month; 0.005 USD/h). Needed to download packages."
  default     = true
}

variable "install_timescaledb" {
  type        = bool
  description = "Install PostgreSQL 18 + PostGIS + TimescaleDB on the VM at first boot. Requires vm_external_ip = true to download packages."
  default     = true
}


# --- Identity Platform ------------------------------------------------------
variable "identity_authorized_domains" {
  type        = list(string)
  description = "Domains authorized for OAuth redirects (e.g. your app domain)"
  default     = ["localhost"]
}

variable "identity_google_client_id" {
  type        = string
  description = "OAuth 2.0 client ID for Sign in with Google. Leave empty to skip."
  default     = ""
}

variable "identity_google_client_secret" {
  type        = string
  description = "OAuth 2.0 client secret for Sign in with Google (stored in Terraform state)."
  default     = ""
  sensitive   = true
}

variable "identity_sms_allowed_regions" {
  type        = list(string)
  description = "ISO 3166-1 alpha-2 country codes to which verification SMS may be sent (SMS region allowlist)"
  default     = ["DZ", "FR"]
}

variable "identity_test_phone_numbers" {
  type        = map(string)
  description = "Test phone numbers -> fixed 6-digit code. No SMS is sent for them (free, for development only)."
  default     = {}
}
