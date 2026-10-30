terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}
provider "google" {
  project = "cloud-platform-engineering-hs"
  region  = "europe-west1"
}
variable "nat_enabled" {
  type    = bool
  default = false
}
locals {
  project = "cloud-platform-engineering-hs"
  network = "projects/${local.project}/global/networks/platform-vpc"
}
resource "google_compute_instance" "probe" {
  for_each = {
    mgmt = { subnet = "mgmt-subnet-be", region = "europe-west1", zone = "europe-west1-b" }
    app  = { subnet = "app-subnet", region = "europe-west9", zone = "europe-west9-b" }
  }
  name         = "lab5-${each.key}"
  zone         = each.value.zone
  machine_type = "e2-micro"
  tags         = each.key == "app" ? ["mgmt-server", "app-server"] : ["mgmt-server", "lab5-egress"]
  boot_disk {
    auto_delete = true
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }
  network_interface {
    subnetwork = "projects/${local.project}/regions/${each.value.region}/subnetworks/${each.value.subnet}"
  }
  metadata = { enable-oslogin = "TRUE" }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  labels = { lab = "lab5", managed_by = "terraform" }
}
resource "google_compute_router" "egress" {
  count   = var.nat_enabled ? 1 : 0
  name    = "lab5-egress"
  network = local.network
  region  = "europe-west1"
}
resource "google_compute_router_nat" "egress" {
  count                              = var.nat_enabled ? 1 : 0
  name                               = "lab5-egress"
  router                             = google_compute_router.egress[0].name
  region                             = "europe-west1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name                    = "projects/${local.project}/regions/europe-west1/subnetworks/mgmt-subnet-be"
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE"]
  }
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
output "probe_ips" {
  value = { for k, vm in google_compute_instance.probe : k => vm.network_interface[0].network_ip }
}

resource "google_compute_firewall" "https_egress" {
  count              = var.nat_enabled ? 1 : 0
  name               = "lab5-allow-https-egress"
  network            = local.network
  direction          = "EGRESS"
  priority           = 900
  target_tags        = ["lab5-egress"]
  destination_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}
resource "google_compute_firewall" "deny_egress" {
  count              = var.nat_enabled ? 1 : 0
  name               = "lab5-deny-other-egress"
  network            = local.network
  direction          = "EGRESS"
  priority           = 1000
  target_tags        = ["lab5-egress"]
  destination_ranges = ["0.0.0.0/0"]
  deny { protocol = "all" }
}
