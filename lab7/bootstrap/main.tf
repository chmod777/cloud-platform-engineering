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
locals {
  project = "cloud-platform-engineering-hs"
  number  = "565473613966"
}
resource "google_storage_bucket" "state" {
  name                        = "cpe-hs-lab3-state-565473613966"
  location                    = "EUROPE-WEST9"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  versioning { enabled = true }
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 7
      with_state                 = "ARCHIVED"
    }
    action { type = "Delete" }
  }
  lifecycle { prevent_destroy = true }
}
resource "google_service_account" "plan" {
  account_id   = "lab7-terraform-plan"
  display_name = "Lab 7 CI plan identity - no infrastructure write permissions"
}
resource "google_project_iam_custom_role" "plan" {
  role_id     = "lab7TerraformPlan"
  title       = "Lab 7 Terraform read-only refresh"
  description = "Read only the resource types used by the isolated Lab 3 root"
  permissions = [
    "artifactregistry.repositories.get", "artifactregistry.repositories.list",
    "iam.serviceAccounts.get", "iam.serviceAccounts.list",
    "run.services.get", "run.services.list",
    "serviceusage.services.get", "serviceusage.services.list",
    "resourcemanager.projects.get"
  ]
}
resource "google_project_iam_member" "plan_read" {
  project = local.project
  role    = google_project_iam_custom_role.plan.name
  member  = "serviceAccount:${google_service_account.plan.email}"
}
resource "google_storage_bucket_iam_member" "state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.plan.email}"
}
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "lab7-github"
  display_name              = "Lab 7 GitHub Actions"
}
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
  }
  attribute_condition = "assertion.repository_id == '1438231492' && assertion.repository_owner_id == '10074904' && assertion.ref == 'refs/heads/master' && assertion.event_name == 'workflow_dispatch' && assertion.workflow_ref == 'chmod777/cloud-platform-engineering/.github/workflows/cloud-plan.yml@refs/heads/master'"
  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}
resource "google_service_account_iam_member" "federation" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${local.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository_id/1438231492"
}
output "provider" { value = google_iam_workload_identity_pool_provider.github.name }
output "service_account" { value = google_service_account.plan.email }
output "state_bucket" { value = google_storage_bucket.state.name }
