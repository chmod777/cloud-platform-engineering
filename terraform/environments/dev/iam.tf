resource "google_project_iam_member" "iap_access" {
  lifecycle {
    prevent_destroy = true
  }

  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "user:hassensiad@gmail.com"
}

resource "google_project_iam_member" "os_login" {
  lifecycle {
    prevent_destroy = true
  }

  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = "user:hassensiad@gmail.com"
}
