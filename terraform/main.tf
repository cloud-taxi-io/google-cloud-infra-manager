terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {
  project_id = var.project_id
}

# --- APIs -------------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# --- Pub/Sub topic ----------------------------------------------------------
resource "google_pubsub_topic" "topic" {
  name       = var.topic_name
  depends_on = [google_project_service.apis]
}

# --- Service account used by Pub/Sub to call Cloud Run ----------------------
resource "google_service_account" "invoker" {
  account_id   = "pubsub-invoker"
  display_name = "Pub/Sub push invoker"
}

# Allow the Pub/Sub service agent to mint OIDC tokens for the invoker SA
resource "google_service_account_iam_member" "pubsub_token_creator" {
  service_account_id = google_service_account.invoker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  depends_on         = [google_project_service.apis]
}

# --- Cloud Run service ------------------------------------------------------
resource "google_cloud_run_v2_service" "service" {
  name                = var.service_name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
    containers {
      image = var.image
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# Service stays private: only the invoker SA may call it
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  name     = google_cloud_run_v2_service.service.name
  location = google_cloud_run_v2_service.service.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.invoker.email}"
}

# --- Push subscription ------------------------------------------------------
resource "google_pubsub_subscription" "sub" {
  name  = var.subscription_name
  topic = google_pubsub_topic.topic.id

  ack_deadline_seconds = 10

  push_config {
    push_endpoint = google_cloud_run_v2_service.service.uri
    oidc_token {
      service_account_email = google_service_account.invoker.email
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.invoker,
    google_service_account_iam_member.pubsub_token_creator,
  ]
}
