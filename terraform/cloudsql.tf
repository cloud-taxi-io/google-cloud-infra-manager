# --- Cloud SQL for PostgreSQL (with PostGIS) --------------------------------
resource "google_project_service" "sql_apis" {
  for_each = toset([
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_sql_database_instance" "postgres" {
  name                = var.sql_instance_name
  region              = var.region
  database_version    = var.sql_database_version
  deletion_protection = var.sql_deletion_protection

  settings {
    tier              = var.sql_tier
    edition           = "ENTERPRISE"
    availability_type = var.sql_high_availability ? "REGIONAL" : "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.sql_disk_size_gb
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
      # No authorized networks: connect through the Cloud SQL connector / Auth Proxy.
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "02:00"
    }

    maintenance_window {
      day  = 7
      hour = 3
    }
  }

  depends_on = [google_project_service.sql_apis]
}

resource "google_sql_database" "app" {
  name     = var.sql_database_name
  instance = google_sql_database_instance.postgres.name
}

# Generated password, stored in Secret Manager
resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  name     = var.sql_user_name
  instance = google_sql_database_instance.postgres.name
  password = random_password.db.result
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.sql_instance_name}-${var.sql_user_name}-password"
  replication {
    auto {}
  }
  depends_on = [google_project_service.sql_apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}
