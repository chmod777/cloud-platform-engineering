resource "google_compute_instance" "mgmt_vm" {
  name         = "vm-mgmt-01"
  machine_type = "e2-micro"
  zone         = "europe-west1-b"

  tags = ["mgmt-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.mgmt_subnet_be.id

    # No access_config: no external IP address
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  service_account {
    email  = google_service_account.mgmt_vm.email
    scopes = ["cloud-platform"]
  }

  labels = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
