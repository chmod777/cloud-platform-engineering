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
}
resource "google_project_service" "secretmanager" {
  project            = "cloud-platform-engineering-hs"
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}
resource "google_service_account" "workload" {
  account_id   = "lab6-workload"
  display_name = "Temporary Lab 6 least-privilege workload"
}
resource "google_secret_manager_secret" "probe" {
  for_each  = toset(["allowed", "denied"])
  secret_id = "lab6-${each.key}"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}
resource "google_secret_manager_secret_iam_member" "read_one" {
  secret_id = google_secret_manager_secret.probe["allowed"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.workload.email}"
}
resource "google_service_account_iam_member" "operator_test" {
  service_account_id = google_service_account.workload.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:hassensiad@gmail.com"
}
