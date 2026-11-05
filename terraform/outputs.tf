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
