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
