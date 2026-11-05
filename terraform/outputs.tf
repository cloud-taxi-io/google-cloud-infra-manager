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

output "vm_name" {
  value = google_compute_instance.test_vm.name
}

output "vm_ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.test_vm.name} --zone ${google_compute_instance.test_vm.zone} --tunnel-through-iap --project ${var.project_id}"
}
