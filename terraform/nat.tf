# --- Cloud NAT: outbound internet for the VM without a public IP ------------
# Cost: about 1 USD/month for one VM (0.0014 USD/h) + 0.045 USD per GB processed.
# Not covered by the free tier. The VM stays unreachable from the internet (no public IP).
locals {
  vm_region = replace(var.vm_zone, "/-[a-z]$/", "")
}

resource "google_compute_router" "vm" {
  count   = var.vm_cloud_nat ? 1 : 0
  name    = "${var.vm_name}-router"
  region  = local.vm_region
  network = var.vm_network

  depends_on = [google_project_service.compute]
}

resource "google_compute_router_nat" "vm" {
  count                              = var.vm_cloud_nat ? 1 : 0
  name                               = "${var.vm_name}-nat"
  router                             = google_compute_router.vm[0].name
  region                             = local.vm_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}
