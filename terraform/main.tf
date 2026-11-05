terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
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
    "secretmanager.googleapis.com",
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

locals {
  pubsub_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  # Fixed audience for the push OIDC token (avoids a dependency cycle on the service URL).
  pubsub_audience = "${var.service_name}-pubsub-push"
}

# --- Pub/Sub: driver GPS ----------------------------------------------------
resource "google_pubsub_topic" "locations" {
  name                       = var.topic_name
  message_retention_duration = "86400s"
  depends_on                 = [google_project_service.apis]
}

# Messages that still fail after max_delivery_attempts land here instead of retrying forever.
resource "google_pubsub_topic" "locations_dlq" {
  name       = "${var.topic_name}-dlq"
  depends_on = [google_project_service.apis]
}

resource "google_pubsub_subscription" "locations_dlq" {
  name                       = "${var.topic_name}-dlq-sub"
  topic                      = google_pubsub_topic.locations_dlq.id
  message_retention_duration = "604800s"
  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_topic_iam_member" "dlq_publisher" {
  topic  = google_pubsub_topic.locations_dlq.id
  role   = "roles/pubsub.publisher"
  member = local.pubsub_agent
}

# --- Service accounts -------------------------------------------------------
# Identity used by Pub/Sub to sign push requests (OIDC)
resource "google_service_account" "invoker" {
  account_id   = "pubsub-invoker"
  display_name = "Pub/Sub push invoker"
}

resource "google_service_account_iam_member" "pubsub_token_creator" {
  service_account_id = google_service_account.invoker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.pubsub_agent
  depends_on         = [google_project_service.apis]
}

# Runtime identity of the API: least privilege, no project-wide editor role.
resource "google_service_account" "api" {
  account_id   = var.service_name
  display_name = "VTC API (Cloud Run runtime)"
}

# DATABASE_URL (with the password) is created outside Terraform so the password never
# lands in the Terraform state. See README.
data "google_secret_manager_secret" "database_url" {
  secret_id  = var.database_url_secret
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_iam_member" "api_database_url" {
  secret_id = data.google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_pubsub_topic_iam_member" "api_publisher" {
  topic  = google_pubsub_topic.locations.id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.api.email}"
}

# Firebase Admin SDK: verify_id_token(check_revoked=True) reads the user record.
resource "google_project_iam_member" "api_firebase_viewer" {
  project = var.project_id
  role    = "roles/firebaseauth.viewer"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# --- Cloud Run: API -------------------------------------------------------------
resource "google_cloud_run_v2_service" "api" {
  name                = var.service_name
  location            = var.api_region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Direct VPC egress: reach PostgreSQL on the VM's internal IP. Internet traffic
    # (Firebase, Pub/Sub) does not go through the VPC.
    vpc_access {
      network_interfaces {
        network    = var.vm_network
        subnetwork = var.vm_network
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = data.google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "FIREBASE_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "LOCATIONS_TOPIC"
        value = google_pubsub_topic.locations.name
      }
      env {
        name  = "PUBSUB_AUDIENCE"
        value = local.pubsub_audience
      }
      env {
        name  = "PUBSUB_SERVICE_ACCOUNT"
        value = google_service_account.invoker.email
      }

      startup_probe {
        http_get {
          path = "/healthz"
        }
        period_seconds    = 3
        failure_threshold = 10
      }
      liveness_probe {
        http_get {
          path = "/healthz"
        }
        period_seconds = 30
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.api_database_url,
  ]
}

# Public: the mobile app sends a Firebase ID token, not a Google IAM token.
# Security relies on JWT verification + PostgreSQL RBAC, and on the OIDC check for /pubsub/push.
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# --- Cloud Run job: database migrations (alembic upgrade head) ---------------
resource "google_cloud_run_v2_job" "migrate" {
  name                = "${var.service_name}-migrate"
  location            = var.api_region
  deletion_protection = false

  template {
    task_count = 1
    template {
      service_account = google_service_account.api.email
      max_retries     = 0
      timeout         = "600s"

      vpc_access {
        network_interfaces {
          network    = var.vm_network
          subnetwork = var.vm_network
        }
        egress = "PRIVATE_RANGES_ONLY"
      }

      containers {
        image   = var.image
        command = ["alembic"]
        args    = ["upgrade", "head"]
        env {
          name = "DATABASE_URL"
          value_source {
            secret_key_ref {
              secret  = data.google_secret_manager_secret.database_url.secret_id
              version = "latest"
            }
          }
        }
      }
    }
  }

  depends_on = [google_secret_manager_secret_iam_member.api_database_url]
}

# --- Push subscription: Pub/Sub -> /pubsub/push --------------------------------
resource "google_pubsub_subscription" "locations_push" {
  name  = var.subscription_name
  topic = google_pubsub_topic.locations.id

  ack_deadline_seconds       = 30
  message_retention_duration = "86400s"

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.api.uri}/pubsub/push"
    oidc_token {
      service_account_email = google_service_account.invoker.email
      audience              = local.pubsub_audience
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.locations_dlq.id
    max_delivery_attempts = 10
  }

  expiration_policy {
    ttl = ""
  }

  depends_on = [
    google_service_account_iam_member.pubsub_token_creator,
    google_pubsub_topic_iam_member.dlq_publisher,
  ]
}

# Pub/Sub must be allowed to ack messages it forwards to the dead-letter topic.
resource "google_pubsub_subscription_iam_member" "dlq_subscriber" {
  subscription = google_pubsub_subscription.locations_push.id
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}
