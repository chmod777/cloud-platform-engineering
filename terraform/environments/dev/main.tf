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
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "platform_vpc" {
  lifecycle {
    prevent_destroy = true
  }

  name                    = "platform-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "app_subnet" {
  lifecycle {
    prevent_destroy = true
  }

  name          = "app-subnet"
  ip_cidr_range = "10.10.1.0/24"
  region        = var.region
  network       = google_compute_network.platform_vpc.id
}

resource "google_compute_subnetwork" "mgmt_subnet" {
  lifecycle {
    prevent_destroy = true
  }

  name          = "mgmt-subnet"
  ip_cidr_range = "10.10.2.0/24"
  region        = var.region
  network       = google_compute_network.platform_vpc.id
}
resource "google_compute_subnetwork" "mgmt_subnet_be" {
  lifecycle {
    prevent_destroy = true
  }

  name          = "mgmt-subnet-be"
  ip_cidr_range = "10.10.3.0/24"
  region        = "europe-west1"
  network       = google_compute_network.platform_vpc.id
}
