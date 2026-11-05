output "service_url" {
  value = google_cloud_run_v2_service.service.uri
}

output "topic" {
  value = google_pubsub_topic.topic.id
}

output "subscription" {
  value = google_pubsub_subscription.sub.id
}

output "invoker_service_account" {
  value = google_service_account.invoker.email
}

output "sql_instance_connection_name" {
  value = google_sql_database_instance.postgres.connection_name
}

output "sql_database" {
  value = google_sql_database.app.name
}

output "sql_password_secret" {
  value = google_secret_manager_secret.db_password.secret_id
}
