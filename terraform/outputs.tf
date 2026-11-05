output "service_url" {
  value = google_cloud_run_v2_service.api.uri
}

output "api_service_account" {
  value = google_service_account.api.email
}

output "migrate_job" {
  description = "Run before each new image: gcloud run jobs execute <name> --region <api_region> --wait"
  value       = google_cloud_run_v2_job.migrate.name
}

output "locations_topic" {
  value = google_pubsub_topic.locations.id
}

output "locations_subscription" {
  value = google_pubsub_subscription.locations_push.id
}

output "locations_dead_letter_subscription" {
  value = google_pubsub_subscription.locations_dlq.id
}

output "vm_name" {
  value = google_compute_instance.test_vm.name
}

output "vm_ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.test_vm.name} --zone ${google_compute_instance.test_vm.zone} --tunnel-through-iap --project ${var.project_id}"
}

output "identity_auth_domain" {
  description = "Default Firebase/Identity Platform auth domain for the client SDK"
  value       = "${var.project_id}.firebaseapp.com"
}

output "identity_google_sign_in_enabled" {
  value = var.identity_google_client_id != ""
}
