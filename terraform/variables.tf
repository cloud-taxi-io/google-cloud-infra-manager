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
  default = "test-vm"
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
  description = "Attach an ephemeral external IPv4. Not free (about 3-4 USD/month), so off by default."
  default     = false
}

variable "install_timescaledb" {
  type        = bool
  description = "Install PostgreSQL 15 + PostGIS + TimescaleDB on the VM at first boot. Requires outbound internet (vm_cloud_nat or vm_external_ip)."
  default     = false
}

variable "vm_cloud_nat" {
  type        = bool
  description = "Create a Cloud Router + Cloud NAT so the VM can reach the internet without a public IP (about 1 USD/month)."
  default     = false
}
