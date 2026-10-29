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
  region  = "europe-west9"
}
variable "deploy" {
  type    = bool
  default = false
}
variable "image" {
  type    = string
  default = ""
  validation {
    condition     = var.image == "" || can(regex("^europe-west9-docker\\.pkg\\.dev/cloud-platform-engineering-hs/lab3-api/api@sha256:[0-9a-f]{64}$", var.image))
    error_message = "Use the SHA-256 image digest from the lab3-api repository."
  }
}
resource "google_project_service" "apis" {
  for_each           = toset(["run.googleapis.com", "artifactregistry.googleapis.com", "iam.googleapis.com"])
  project            = "cloud-platform-engineering-hs"
  service            = each.value
  disable_on_destroy = false
}
resource "google_artifact_registry_repository" "api" {
  location      = "europe-west9"
  repository_id = "lab3-api"
  format        = "DOCKER"
  description   = "Temporary Lab 3 images; delete after the session"
  depends_on    = [google_project_service.apis]
}
resource "google_service_account" "runtime" {
  account_id   = "lab3-api-runtime"
  display_name = "LAB 3 API without project roles"
  depends_on   = [google_project_service.apis]
}
resource "google_cloud_run_v2_service" "api" {
  count               = var.deploy ? 1 : 0
  name                = "lab3-api"
  location            = "europe-west9"
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"
  scaling {
    min_instance_count = 0
    max_instance_count = 1
  }
  template {
    service_account                  = google_service_account.runtime.email
    timeout                          = "10s"
    max_instance_request_concurrency = 10
    containers {
      image = var.image
      ports { container_port = 8080 }
      env {
        name  = "APP_ENV"
        value = "lab3"
      }
      resources {
        limits            = { cpu = "1", memory = "256Mi" }
        cpu_idle          = true
        startup_cpu_boost = false
      }
    }
  }
  lifecycle {
    precondition {
      condition     = var.image != ""
      error_message = "A published image identified by its digest is required."
    }
  }
  depends_on = [google_project_service.apis]
}
output "url" {
  value = try(google_cloud_run_v2_service.api[0].uri, null)
}
