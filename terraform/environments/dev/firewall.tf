# Allow SSH access through Google Identity-Aware Proxy
resource "google_compute_firewall" "allow_iap_ssh" {
  lifecycle {
    prevent_destroy = true
  }

  name    = "allow-iap-ssh"
  network = google_compute_network.platform_vpc.name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["mgmt-server"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  description = "Allow SSH access through Google IAP"
}

# Allow management subnet to access application HTTPS
resource "google_compute_firewall" "allow_mgmt_to_app" {
  lifecycle {
    prevent_destroy = true
  }

  name    = "allow-mgmt-to-app"
  network = google_compute_network.platform_vpc.name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = ["10.10.2.0/24"]
  target_tags   = ["app-server"]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  description = "Allow HTTPS from management subnet to application servers"
}
