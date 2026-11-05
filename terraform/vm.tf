# --- Free-tier test VM ------------------------------------------------------
# Compute Engine free tier (per billing account, per month):
#   - 1 x e2-micro, ONLY in us-west1, us-central1 or us-east1
#   - 30 GB standard persistent disk (pd-standard)
#   - 1 GB outbound network traffic from North America
# An external IPv4 address is NOT free, so none is attached by default.
# Reach the VM with IAP:  gcloud compute ssh test-vm --zone <zone> --tunnel-through-iap
resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_instance" "test_vm" {
  name         = var.vm_name
  zone         = var.vm_zone
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    network = var.vm_network

    dynamic "access_config" {
      for_each = var.vm_external_ip ? [1] : []
      content {}
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    preemptible       = false
    automatic_restart = true
  }

  labels = {
    purpose = "test"
  }

  depends_on = [google_project_service.compute]
}

# Allow SSH only from Google's IAP range
resource "google_compute_firewall" "iap_ssh" {
  name    = "${var.vm_name}-allow-iap-ssh"
  network = var.vm_network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = []

  depends_on = [google_project_service.compute]
}
