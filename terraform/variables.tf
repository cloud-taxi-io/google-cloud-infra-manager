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

# --- Cloud SQL --------------------------------------------------------------
variable "sql_instance_name" {
  type    = string
  default = "postgis-db"
}

variable "sql_database_version" {
  type    = string
  default = "POSTGRES_16"
}

variable "sql_tier" {
  type        = string
  description = "Machine tier, e.g. db-custom-1-3840 or db-custom-2-7680"
  default     = "db-custom-1-3840"
}

variable "sql_disk_size_gb" {
  type    = number
  default = 20
}

variable "sql_high_availability" {
  type        = bool
  description = "REGIONAL (HA) when true, ZONAL otherwise"
  default     = false
}

variable "sql_deletion_protection" {
  type    = bool
  default = true
}

variable "sql_database_name" {
  type    = string
  default = "app"
}

variable "sql_user_name" {
  type    = string
  default = "app"
}
